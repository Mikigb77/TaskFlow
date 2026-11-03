import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/meeting_screen.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/widgets/app_components.dart';

/// The meetings on this phone for the signed-in account; none signed out.
/// Notes reads it in the app's shell, so the meeting core starts with the
/// app: a recording that stopped under it is found (MN-12), and pieces
/// still waiting upload (MN-8).
final meetingsProvider = Provider<MeetingsState>((ref) {
  if (ref.watch(authProvider.select((s) => s.account == null))) {
    return const MeetingsState();
  }
  return ref.watch(meetingControllerProvider);
});

/// Asks before a meeting's audio goes for good (MN-25). [recording] keeps
/// on recording when the person says no.
Future<bool> confirmMeetingDiscard(
  BuildContext context, {
  bool recording = false,
}) async {
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      actionsOverflowButtonSpacing: 8,
      content: Text(l.meetingDiscardQuestion),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.discard),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(recording ? l.meetingKeepRecording : l.keep),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// What a meeting waiting for its notes says (MN-11): «Preparando tus
/// notas…», «Esperando conexión», or why it's held back.
String meetingWaitingLine(BuildContext context, Meeting meeting) {
  final l = context.l10n;
  return switch (meeting.problem) {
    MeetingProblem.offline => l.meetingWaitingConnection,
    MeetingProblem.proRequired => l.meetingProRequired,
    MeetingProblem.allowanceUsed => l.meetingAllowanceUsed,
    MeetingProblem.pieceFailed => l.meetingCantMakeNotes,
    // Its pieces were sent; the server kept them too long and forgot them.
    MeetingProblem.expired => l.meetingNotesExpired,
    _ => l.meetingPreparing,
  };
}

/// Whether [meeting] can only be discarded: a piece is lost, or the server
/// forgot what it had.
bool meetingLost(Meeting meeting) =>
    meeting.problem == MeetingProblem.pieceFailed ||
    meeting.problem == MeetingProblem.expired;

/// Why «Send first» left recordings behind (MN-13), from what's left in
/// [meetings]: one that can only be discarded, Pro or the month's time
/// holding one back, or else no connection.
String meetingSendFailure(AppLocalizations l, MeetingsState meetings) {
  final left = [...meetings.stopped, ...meetings.waiting];
  if (left.any(meetingLost)) return l.meetingSendFailedLost;
  if (left.any((m) => m.problem == MeetingProblem.proRequired)) {
    return l.meetingSendFailedPro;
  }
  if (left.any((m) => m.problem == MeetingProblem.allowanceUsed)) {
    return l.meetingSendFailedAllowance;
  }
  return l.meetingSendFailed;
}

/// Before signing out: the server hears of every meeting discarded or saved
/// here while this account's token still works, so a discard deletes the
/// meeting there at once (MN-25) and saved notes let it go (MN-24). Waits
/// at most [limit]; a server out of reach hears on this account's next
/// sign-in here, or its 30-day sweep deletes the meeting (MN-27).
Future<void> tellServerBeforeSignOut(
  MeetingController controller, {
  Duration limit = const Duration(seconds: 10),
}) async {
  try {
    await controller.uploadNow().timeout(limit);
  } catch (_) {
    /* Signing out goes on all the same. */
  }
}

/// The Notes tab's lines for meetings (MN-12, MN-26): the one recording
/// (when its screen was left), each recording that stopped by itself with
/// «Continuar», «Terminar» and «Descartar», and each waiting for its notes.
/// Nothing when there are none.
class MeetingBanners extends ConsumerWidget {
  const MeetingBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(meetingsProvider);
    final recording = meetings.recording;
    final cards = <Widget>[
      if (recording != null) _RecordingCard(recording),
      for (final meeting in meetings.stopped)
        MeetingStoppedCard(
          key: ValueKey('meeting-stopped-${meeting.id}'),
          meeting: meeting,
        ),
      for (final meeting in meetings.waiting)
        _WaitingCard(
          key: ValueKey('meeting-waiting-${meeting.id}'),
          meeting: meeting,
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
      ],
    );
  }
}

/// One meeting line. Its words are read out when its [state] changes (such
/// as «Esperando conexión»), not when it appears or as the time ticks, so
/// several lines opening Notes don't talk over each other.
/// [actions] are in reading order with the main one last: in a row it sits
/// at the end, and when they don't fit (large text) it comes first.
class _Card extends StatefulWidget {
  const _Card({
    super.key,
    required this.icon,
    required this.text,
    required this.actions,
    this.state,
    this.error = false,
  });
  final IconData icon;
  final String text;
  final List<Widget> actions;
  final Object? state;
  final bool error;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _changed = false;

  @override
  void didUpdateWidget(_Card old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _changed = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = widget.error
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return AppSurface(
      color: widget.error ? colors.errorContainer : colors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Its own node, read out once it changes: «Esperando conexión».
          Semantics(
            container: true,
            liveRegion: _changed,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, size: 20, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.text, style: TextStyle(color: foreground)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OverflowBar(
              spacing: 8,
              overflowSpacing: 8,
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.start,
              // Stacked, the main action (the last) is on top.
              overflowDirection: VerticalDirection.up,
              children: widget.actions,
            ),
          ),
        ],
      ),
    );
  }
}

/// A meeting line's button: [text] on screen, [label] for TalkBack, which
/// names the meeting so the lines' buttons can be told apart.
Widget _action(String text, String label, VoidCallback onPressed) => TextButton(
  onPressed: onPressed,
  child: Text(text, semanticsLabel: label),
);

class _RecordingCard extends StatelessWidget {
  const _RecordingCard(this.status);
  final MeetingRecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Card(
      key: const ValueKey('meeting-recording'),
      icon: Icons.mic_rounded,
      text: l.meetingRecordingNow(meetingElapsed(status.elapsed)),
      actions: [
        TextButton(
          onPressed: () => openMeetingRecorder(context),
          child: Text(l.meetingOpen),
        ),
      ],
    );
  }
}

/// A recording that stopped without Stop (MN-12): «Your recording stopped
/// at 1:42. Continue, finish or discard?».
class MeetingStoppedCard extends ConsumerWidget {
  const MeetingStoppedCard({super.key, required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(meetingControllerProvider.notifier);
    final time = meetingElapsed(meeting.recorded);
    return _Card(
      icon: Icons.pause_circle_outline_rounded,
      text: l.meetingStoppedAt(time),
      actions: [
        _action(l.discard, l.meetingDiscardNamed(time), () async {
          if (await confirmMeetingDiscard(context)) {
            await controller.discardMeeting(meeting.id);
          }
        }),
        _action(
          l.meetingFinish,
          l.meetingFinishNamed(time),
          () => unawaited(controller.finishMeeting(meeting.id)),
        ),
        _action(
          l.meetingContinue,
          l.meetingContinueNamed(time),
          () => openMeetingRecorder(context, continueId: meeting.id),
        ),
      ],
    );
  }
}

class _WaitingCard extends ConsumerWidget {
  const _WaitingCard({super.key, required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(meetingControllerProvider.notifier);
    final lost = meetingLost(meeting);
    return _Card(
      icon: switch (meeting.problem) {
        MeetingProblem.offline => Icons.cloud_off_outlined,
        _ when lost => Icons.error_outline,
        _ => Icons.hourglass_top_rounded,
      },
      error: lost,
      state: meeting.problem,
      text: meetingWaitingLine(context, meeting),
      actions: [
        _action(
          l.discard,
          l.meetingDiscardNamed(meetingElapsed(meeting.recorded)),
          () async {
            if (await confirmMeetingDiscard(context)) {
              await controller.discardMeeting(meeting.id);
            }
          },
        ),
        if (meeting.problem == MeetingProblem.proRequired)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed('/subscription', arguments: ProReason.meetingNotes),
            child: Text(l.voiceProAction),
          ),
      ],
    );
  }
}
