import 'dart:async';
import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/meeting_uploader.dart';
import 'package:agenda/services/task_database.dart';

/// WorkManager's unique name and task name for meeting uploads. The task
/// runs in the app's one background dispatcher (`reminderWorker`).
const meetingUploadWork = 'taskflow-meeting-upload';
const meetingUploadTask = 'upload-meetings';

/// Asks the phone to upload meetings in the background, also with the app
/// closed (MN-8).
abstract class MeetingScheduler {
  Future<void> schedule();
}

/// One WorkManager task at a time, run once the phone has a network; a
/// task that returns unfinished runs again after a growing pause.
class WorkmanagerMeetingScheduler implements MeetingScheduler {
  const WorkmanagerMeetingScheduler();

  @override
  Future<void> schedule() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().registerOneOffTask(
        meetingUploadWork,
        meetingUploadTask,
        constraints: Constraints(networkType: NetworkType.connected),
        // A task already waiting or running uploads every piece there is.
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (_) {
      /* The app uploads while open, and schedules again. */
    }
  }
}

/// The background task: uploads the signed-in account's meetings, and
/// finishes into notes those left unanswered for 7 days (MN-26). True when
/// nothing is left; false asks WorkManager to run it again later.
///
/// It never recovers interrupted recordings: the app may be recording in
/// another engine of the same process. That's the app's, on start.
Future<bool> runMeetingUploads({
  ApiClient? api,
  MeetingStore? store,
  DateTime Function()? clock,
  Duration budget = const Duration(minutes: 8),
  Future<void> Function(Duration)? wait,
}) async {
  final now = clock ?? DateTime.now;
  final sleep = wait ?? (Duration delay) => Future<void>.delayed(delay);
  try {
    // A refused login stops this task and leaves the saved session as it
    // is: the app, which the person sees, decides about signing out.
    final client = api ?? ApiClient(background: true);
    if (api == null) await client.restore();
    final account = client.account;
    if (account == null) return true;
    final owner = '${client.baseUrl}/users/${account.id}';
    final meetings = store ?? MeetingStore(TaskDatabase());
    await meetings.autoFinishStale(owner, now());
    final uploader = MeetingUploader(
      store: meetings,
      api: ApiMeetingApi(client, account.id),
      ownerKey: owner,
      clock: now,
    );
    final until = now().add(budget);
    while (true) {
      final pass = await uploader.run();
      if (pass.idle || pass.stopped) return true;
      if (pass.offline || pass.busy) return false;
      var delay = pass.nextDue!.difference(now());
      if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
      // A long pause is WorkManager's to wait, not a running task's.
      if (delay > const Duration(minutes: 2) || now().add(delay).isAfter(until)) {
        return false;
      }
      await sleep(delay);
    }
  } catch (_) {
    // A thrown task would never run again.
    return false;
  }
}
