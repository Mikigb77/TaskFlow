import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no reminder shows under id 1, the meeting recorder’s notification', () {
    for (final row in [1, 2, 3, 400, 123456]) {
      final id = reminderNotificationId(row);
      expect(id, isNot(1));
      expect(reminderOfNotification(id), row);
    }
    // One scheduled under id 1 before it moved is still row 1's.
    expect(reminderOfNotification(1), 1);
  });

  group('P325 · meeting notifications', () {
    final es = lookupAppLocalizations(const Locale('es'));
    // A fixed "now" for the clock tests.
    final now = DateTime.utc(2026, 11, 3, 10, 30);

    test('UX-2810: the recording notification runs a clock from its start', () {
      final started = now.subtract(const Duration(minutes: 5));
      final android = meetingRecordingNotificationDetails(
        meetingNotice(es).at(started),
      ).android!;
      expect(android.usesChronometer, isTrue);
      expect(android.showWhen, isTrue);
      expect(android.when, started.millisecondsSinceEpoch);
      // Everything else stays: its channel, silent and ongoing, its buttons.
      expect(android.channelId, meetingRecordingChannel);
      expect(android.silent, isTrue);
      expect(android.ongoing, isTrue);
      expect(android.actions!.map((action) => action.id), [
        meetingStopAction,
        meetingDiscardAction,
      ]);
    });

    test('UX-2810: a continued meeting counts on from the time already recorded', () {
      final android = meetingRecordingNotificationDetails(
        meetingNotice(es).at(now.subtract(const Duration(minutes: 42))),
      ).android!;
      expect(android.usesChronometer, isTrue);
      expect(android.showWhen, isTrue);
      expect(
        android.when,
        now.millisecondsSinceEpoch - const Duration(minutes: 42).inMilliseconds,
      );
    });

    test('UX-2812: the note’s title first, the generic line under it (ES)', () async {
      expect(es.meetingNotesReady, 'Las notas de la reunión están listas');
      final plugin = _Plugin();
      await postMeetingNotesReady(
        plugin,
        const SavedMeetingNote(
          meetingId: 'meeting-1',
          ownerKey: 'https://api.example.invalid/users/7',
          noteId: 90,
          title: 'Precio del piloto',
        ),
        es,
      );
      final posted = plugin.posted.single;
      expect(posted.id, meetingNotesNotificationId);
      expect(posted.title, 'Precio del piloto');
      expect(posted.body, es.meetingNotesReady);
      // The tap still opens that note for that account.
      expect(jsonDecode(posted.payload!), {
        'meeting_note': 90,
        'owner': 'https://api.example.invalid/users/7',
        'meeting': 'meeting-1',
      });
    });

    test('UX-2812: a note with no title keeps the generic line as the title, and no text', () async {
      final plugin = _Plugin();
      await postMeetingNotesReady(
        plugin,
        const SavedMeetingNote(
          meetingId: 'meeting-1',
          ownerKey: 'local',
          noteId: 90,
          title: '  ',
        ),
        es,
      );
      final posted = plugin.posted.single;
      expect(posted.title, es.meetingNotesReady);
      expect(posted.body, isNull);
    });

    test('UX-2812: two meetings keep a notification each, tagged with their ids', () async {
      final plugin = _Plugin();
      for (final (meeting, note) in [('meeting-1', 90), ('meeting-2', 91)]) {
        await postMeetingNotesReady(
          plugin,
          SavedMeetingNote(
            meetingId: meeting,
            ownerKey: 'local',
            noteId: note,
            title: 'Notas $note',
          ),
          es,
        );
      }
      expect(plugin.posted.map((p) => p.id).toSet(), {
        meetingNotesNotificationId,
      });
      expect(plugin.posted.map((p) => p.tag), [
        meetingNotesTag('meeting-1', 90),
        meetingNotesTag('meeting-2', 91),
      ]);
      // Both still show: the second didn't replace the first.
      expect(plugin.active.map((n) => n.title), ['Notas 90', 'Notas 91']);
    });

    test('UX-2811: opening a note removes only that note’s notification', () async {
      final plugin = await _showing();
      await cancelMeetingNotesReady(plugin, noteId: 90);
      expect(plugin.cancelled, [
        (meetingNotesNotificationId, meetingNotesTag('meeting-1', 90)),
      ]);
      expect(plugin.active.map((n) => (n.id, n.tag)), [
        (meetingNotesNotificationId, meetingNotesTag('meeting-2', 91)),
        (reminderNotificationId(5), null),
        (meetingRecordingNotificationId, null),
      ]);
      // A note no notification opens: nothing goes.
      await cancelMeetingNotesReady(plugin, noteId: 404);
      expect(plugin.cancelled, hasLength(1));
    });

    test('UX-2811: signing out removes every "notes ready", and no reminder', () async {
      final plugin = await _showing();
      await cancelMeetingNotesReady(plugin);
      expect(
        plugin.cancelled.map((c) => c.$1).toSet(),
        {meetingNotesNotificationId},
      );
      expect(plugin.cancelled.map((c) => c.$2).toSet(), {
        meetingNotesTag('meeting-1', 90),
        meetingNotesTag('meeting-2', 91),
      });
      expect(plugin.active.map((n) => n.id), [
        reminderNotificationId(5),
        meetingRecordingNotificationId,
      ]);
    });

    test('UX-2811: the hooks the app calls are the ones that cancel', () {
      expect(MeetingHooks.notesSeen, TaskReminders.clearMeetingNotesReady);
      expect(MeetingHooks.noteOpened, TaskReminders.clearMeetingNoteReady);
    });
  });
}

/// Two meetings' "notes ready", a reminder and the recording showing.
Future<_Plugin> _showing() async {
  final plugin = _Plugin();
  final es = lookupAppLocalizations(const Locale('es'));
  for (final (meeting, note) in [('meeting-1', 90), ('meeting-2', 91)]) {
    await postMeetingNotesReady(
      plugin,
      SavedMeetingNote(
        meetingId: meeting,
        ownerKey: 'local',
        noteId: note,
        title: 'Notas $note',
      ),
      es,
    );
  }
  await plugin.show(
    id: reminderNotificationId(5),
    title: 'Dentista',
    payload: jsonEncode({'id': 5, 'token': 't'}),
  );
  await plugin.show(id: meetingRecordingNotificationId, title: 'Grabando');
  plugin.posted.clear();
  return plugin;
}

typedef _Posted = ({
  int id,
  String? title,
  String? body,
  String? tag,
  String? payload,
});

/// The notifications plugin as Android keeps them: one per id and tag, and
/// a showing one comes back with its tag but no payload.
class _Plugin extends Fake implements FlutterLocalNotificationsPlugin {
  final posted = <_Posted>[];
  final cancelled = <(int, String?)>[];
  final active = <ActiveNotification>[];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    final tag = notificationDetails?.android?.tag;
    posted.add((
      id: id,
      title: title,
      body: body,
      tag: tag,
      payload: payload,
    ));
    active
      ..removeWhere((n) => n.id == id && n.tag == tag)
      ..add(
        ActiveNotification(
          id: id,
          title: title,
          body: body,
          tag: tag,
        ),
      );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add((id, tag));
    active.removeWhere((n) => n.id == id && n.tag == tag);
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async =>
      List.of(active);
}
