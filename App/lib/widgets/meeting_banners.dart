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

/// Whether [meeting] can't be sent now: lost, or held back by Pro or the
/// month's time.
bool meetingHeldBack(Meeting meeting) =>
    meetingLost(meeting) || MeetingProblem.blocksUploads(meeting.problem);

/// Why the recordings left in [meetings] can't be sent (MN-13): one that
/// can only be discarded (with how many Discard deletes, when more than one
/// waits), or Pro or the month's time holding one back. Null when none is
/// known to be held back.
String? meetingHeldBackReason(AppLocalizations l, MeetingsState meetings) {
  final left = [...meetings.stopped, ...meetings.waiting];
  if (left.any(meetingLost)) {
    return left.length > 1
        ? '${l.meetingSendFailedLost} ${l.meetingDiscardDeletesAll(left.length)}'
        : l.meetingSendFailedLost;
  }
  if (left.any((m) => m.problem == MeetingProblem.proRequired)) {
    return l.meetingSendFailedPro;
  }
  if (left.any((m) => m.problem == MeetingProblem.allowanceUsed)) {
    return l.meetingSendFailedAllowance;
  }
  return null;
}

/// Why «Save notes and sign out» left recordings behind (MN-13): what holds
/// them back, else no connection, a refused login (uploads stop until it
/// signs in again), or notes taking longer than usual.
String meetingSendFailure(
  AppLocalizations l,
  MeetingsState meetings,
  MeetingSendResult result,
) =>
    meetingHeldBackReason(l, meetings) ??
    switch (result) {
      MeetingSendResult.offline => l.meetingSendFailed,
      MeetingSendResult.blocked => l.requestError('session'),
      _ => l.meetingSendSlow,
    };

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
/// «Hacer las notas», «Seguir grabando» and «Descartar», and each waiting
/// for its notes. Nothing when there are none.
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
/// [alignment] places them in a row; stacked, they start at the left.
class _Card extends StatefulWidget {
  const _Card({
    super.key,
    required this.icon,
    required this.text,
    required this.actions,
    this.state,
    this.error = false,
    this.alignment = MainAxisAlignment.end,
  });
  final IconData icon;
  final String text;
  final List<Widget> actions;
  final Object? state;
  final bool error;
  final MainAxisAlignment alignment;

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
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.actions.isEmpty ? 16 : 8),
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
          if (widget.actions.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OverflowBar(
                spacing: 8,
                overflowSpacing: 8,
                alignment: widget.alignment,
                overflowAlignment: OverflowBarAlignment.start,
                // Stacked, the main action (the last) is on top.
                overflowDirection: VerticalDirection.up,
                children: widget.actions,
              ),
            ),
          ],
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

/// «Descartar» on a meeting, in the error colour as everywhere (UX-2714);
/// on an [onError] card, the darker one that card's text uses, so it keeps
/// its contrast on the red. It asks first (MN-25).
class _DiscardButton extends ConsumerWidget {
  const _DiscardButton(this.meeting, {this.onError = false});
  final Meeting meeting;
  final bool onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: onError ? colors.onErrorContainer : colors.error,
      ),
      onPressed: () async {
        if (await confirmMeetingDiscard(context)) {
          await ref
              .read(meetingControllerProvider.notifier)
              .discardMeeting(meeting.id);
        }
      },
      child: Text(
        l.discard,
        semanticsLabel: l.meetingDiscardNamed(
          meetingLength(l, meeting.recorded),
        ),
      ),
    );
  }
}

/// Which recording [meeting] is, from when it started: «Grabación de hoy,
/// 10:15», «Grabación de ayer, 10:15» or «Grabación del martes 3 nov, 10:15»
/// (the weekday in full, as in the note's title: «mar» reads as "sea").
String meetingWhich(BuildContext context, Meeting meeting) {
  final l = context.l10n;
  final started = meeting.startedAt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(started.year, started.month, started.day);
  final time = context.clockTime(started);
  if (day == today) return l.meetingRecordingToday(time);
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return l.meetingRecordingYesterday(time);
  }
  return l.meetingRecordingOn(meetingDay(context.localeName, l, started), time);
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard(this.status);
  final MeetingRecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Card(
      key: const ValueKey('meeting-recording'),
      icon: Icons.mic_rounded,
      text: l.meetingRecordingNow(meetingLength(l, status.elapsed)),
      actions: [
        _action(
          l.meetingOpen,
          l.meetingOpenNamed,
          () => openMeetingRecorder(context),
        ),
      ],
    );
  }
}

/// A recording that stopped without Stop (MN-12): «Grabación de hoy, 10:15
/// · 1 h 42 min. Se cortó antes de que pulsaras Parar.», then its choices.
class MeetingStoppedCard extends StatelessWidget {
  const MeetingStoppedCard({super.key, required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Card(
      icon: Icons.pause_circle_outline_rounded,
      text: l.meetingStoppedCut(
        meetingWhich(context, meeting),
        meetingLength(l, meeting.recorded),
      ),
      actions: [MeetingStoppedActions(meeting: meeting)],
    );
  }
}

/// A stopped recording's choices (UX-2703): «Hacer las notas», the main
/// one; «Seguir grabando»; and «Descartar» apart on its own line. The
/// meeting screen shows them [centered] under why it stopped.
class MeetingStoppedActions extends ConsumerWidget {
  const MeetingStoppedActions({
    super.key,
    required this.meeting,
    this.centered = false,
  });
  final Meeting meeting;
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(meetingControllerProvider.notifier);
    final time = meetingLength(l, meeting.recorded);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          overflowAlignment: centered
              ? OverflowBarAlignment.center
              : OverflowBarAlignment.start,
          children: [
            FilledButton(
              onPressed: () => unawaited(controller.finishMeeting(meeting.id)),
              child: Text(
                l.meetingMakeNotes,
                semanticsLabel: l.meetingFinishNamed(time),
              ),
            ),
            _action(
              l.meetingKeepRecording,
              l.meetingContinueNamed(time),
              () => openMeetingRecorder(context, continueId: meeting.id),
            ),
          ],
        ),
        // Apart from the others, so it isn't tapped for one of them.
        const SizedBox(height: 12),
        _DiscardButton(meeting),
      ],
    );
  }
}

/// A meeting waiting for its notes. «Preparando tus notas…» lasts seconds,
/// so it has no button; held back, it offers «Descartar» (UX-2714).
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({super.key, required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lost = meetingLost(meeting);
    final preparing = meeting.problem == null;
    return _Card(
      icon: switch (meeting.problem) {
        MeetingProblem.offline => Icons.cloud_off_outlined,
        _ when lost => Icons.error_outline,
        _ => Icons.hourglass_top_rounded,
      },
      error: lost,
      state: meeting.problem,
      // «Descartar» at the start, as on the stopped lines (R1-P322-4).
      alignment: MainAxisAlignment.start,
      text: meetingWaitingLine(context, meeting),
      actions: [
        if (!preparing) _DiscardButton(meeting, onError: lost),
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
