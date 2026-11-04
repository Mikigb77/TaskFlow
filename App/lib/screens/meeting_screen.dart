import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/meeting_banners.dart';

/// «Grabar una reunión» (MN-1): the recording screen, at once. Without
/// Pro, it shows the Pro screen over it, saying what Pro gives here (Pro
/// only is the build plan's decision, MEETING_NOTES_PLAN.md). [continueId]
/// goes on with a recording that stopped by itself (MN-12). A recording
/// already running opens as it is. A tap while one is open does nothing.
Future<void> openMeetingRecorder(
  BuildContext context, {
  String? projectId,
  String? continueId,
}) async {
  if (_recorderRoute?.isActive ?? false) return;
  final route = _recorderRoute = MaterialPageRoute<void>(
    builder: (_) => MeetingScreen(
      projectId: projectId,
      continueId: continueId,
      proFirst: true,
    ),
  );
  await Navigator.of(context).push(route);
}

/// The screen «Grabar una reunión» opened last.
Route<void>? _recorderRoute;

/// The recording notification's tap, Stop or Discard (MN-1, MN-25): the
/// recording screen does it, the one open when it's in front, else a new
/// one in its place.
Future<void> openMeetingNoticeAction(
  NavigatorState navigator,
  MeetingNoticeAction action,
) async {
  final open = _recordingScreen;
  if (open != null && open.mounted && open._stage == _Stage.recording) {
    final route = ModalRoute.of(open.context);
    if (route?.isCurrent ?? false) {
      open._act(action);
      return;
    }
    if (route != null && route.isActive) navigator.removeRoute(route);
  }
  await navigator.push(
    MaterialPageRoute<void>(builder: (_) => MeetingScreen(action: action)),
  );
}

/// The screen showing the recording now, if any.
_MeetingScreenState? _recordingScreen;

enum _Stage { starting, recording, refused, after }

/// Records a meeting, then waits for its notes and opens them (MN-1,
/// MN-7, MN-11): the elapsed time, a level that shows it's listening, a
/// large Stop and a smaller Discard that asks first (MN-25). After Stop, «Preparando tus
/// notas…» («Esperando conexión» without signal) until the note is saved,
/// which then opens in its place. Leaving it never stops the recording; the
/// Notes tab says it's still on.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({
    super.key,
    this.projectId,
    this.continueId,
    this.action,
    this.proFirst = false,
  });

  /// The project the note goes to.
  final String? projectId;

  /// A recording that stopped by itself, to go on with.
  final String? continueId;

  /// The recording notification's Stop or Discard, for the recording
  /// running now: the screen does it once open. It never starts one.
  final MeetingNoticeAction? action;

  /// Without Pro, the Pro screen first: Pro bought there goes straight on
  /// to recording; without it, this screen closes too.
  final bool proFirst;

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen>
    with WidgetsBindingObserver {
  var _stage = _Stage.starting;
  // Asking the core to record now: no second start at once.
  bool _starting = false;
  String? _id;
  MeetingStartProblem? _refused;
  bool _stopping = false;
  // Stop failed once the microphone had stopped: the recording screen
  // stays until Stop works (UX-2713).
  bool _stopFailed = false;
  // Discard confirmed: the recording going is not it ending by itself.
  bool _discarding = false;
  // The recording ended by itself (out of space, the microphone failed).
  bool _ended = false;
  // The meeting has been seen waiting: once it's gone without notes, it
  // was discarded.
  bool _listed = false;
  bool _opened = false;
  // Whether this screen was in front at its last build.
  bool _current = true;
  // Under about 300 MB free as it started: recording goes on (MN-6).
  bool _spaceLow = false;

  MeetingController get _controller =>
      ref.read(meetingControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Settings, or from Android's question: records once the
    // microphone is allowed.
    if (state == AppLifecycleState.resumed &&
        _stage == _Stage.refused &&
        (_refused == MeetingStartProblem.permission ||
            _refused == MeetingStartProblem.microphoneBlocked)) {
      unawaited(_recheckMicrophone());
    }
  }

  Future<void> _recheckMicrophone() async {
    try {
      if (!await _controller.microphoneAllowed()) return;
    } catch (_) {
      return;
    }
    if (mounted && _stage == _Stage.refused) unawaited(_record());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_id != null) TaskReminders.meetingsOnScreen.remove(_id);
    if (identical(_recordingScreen, this)) _recordingScreen = null;
    super.dispose();
  }

  void _show(String id) {
    if (_id != null && _id != id) TaskReminders.meetingsOnScreen.remove(_id);
    _id = id;
    TaskReminders.meetingsOnScreen.add(id);
  }

  /// Now recording [id]: the notification's buttons come here.
  void _recordingNow(String id) {
    _show(id);
    _stage = _Stage.recording;
    _recordingScreen = this;
  }

  /// The notification's Stop or Discard, while this screen records.
  void _act(MeetingNoticeAction action) {
    if (!mounted || _stage != _Stage.recording) return;
    switch (action) {
      case MeetingNoticeAction.stop:
        unawaited(_stop());
      case MeetingNoticeAction.discard:
        unawaited(_discard());
      case MeetingNoticeAction.open:
        break;
    }
  }

  Future<void> _checkSpace() async {
    try {
      final low = await _controller.recorder.roomIsLow();
      if (mounted && low != _spaceLow) setState(() => _spaceLow = low);
    } catch (_) {
      /* No warning when free space can't be known. */
    }
  }

  Future<void> _start() async {
    final running = ref.read(meetingsProvider).recording;
    if (widget.action != null) {
      // From the notification: only the recording running now.
      if (running == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _recordingNow(running.meetingId));
      _act(widget.action!);
      return;
    }
    if (running != null && widget.continueId == null) {
      setState(() => _recordingNow(running.meetingId));
      unawaited(_checkSpace());
      return;
    }
    if (running == null && widget.proFirst && !await _hasPro()) return;
    if (mounted) await _record();
  }

  /// Pro, once billing knows: without it, the Pro screen over this one.
  /// Pro bought there goes on; leaving it without Pro closes this screen,
  /// so Back from the Pro screen returns to where it was opened.
  Future<bool> _hasPro() async {
    // Billing may still be finding out: a paying customer is never sent to
    // the Pro screen for that.
    if (ref.read(billingLoadingProvider)) {
      final known = Completer<void>();
      final watch = ref.listenManual<bool>(billingLoadingProvider, (
        _,
        loading,
      ) {
        if (!loading && !known.isCompleted) known.complete();
      });
      await known.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      watch.close();
      if (!mounted) return false;
    }
    if (ref.read(hasProProvider)) return true;
    await Navigator.of(
      context,
    ).pushNamed('/subscription', arguments: ProReason.meetingNotes);
    if (!mounted) return false;
    if (ref.read(hasProProvider)) return true;
    _leave();
    return false;
  }

  /// Starts recording, or goes on with [MeetingScreen.continueId]: also
  /// «Permitir el micrófono», «Reintentar» and back from Settings.
  Future<void> _record() async {
    if (_starting) return;
    _starting = true;
    try {
      await _startRecording();
    } finally {
      _starting = false;
    }
  }

  Future<void> _startRecording() async {
    if (_stage != _Stage.starting) {
      setState(() {
        _stage = _Stage.starting;
        _refused = null;
      });
    }
    final l = context.l10n;
    final notice = meetingNotice(l);
    try {
      await ref.read(regionalProvider.notifier).ready;
    } catch (_) {
      /* The app's language is the hint then. */
    }
    if (!mounted) return;
    final language = captureSpeechLanguage(context, ref.read(regionalProvider));
    try {
      final meeting = widget.continueId != null
          ? await _controller.continueMeeting(
              widget.continueId!,
              notice: notice,
            )
          : await _controller.start(
              notice: notice,
              language: language,
              projectId: widget.projectId,
            );
      if (!mounted) return;
      setState(() => _recordingNow(meeting.id));
      unawaited(_checkSpace());
    } on MeetingStartRefused catch (error) {
      if (!mounted) return;
      final busy = ref.read(meetingsProvider).recording;
      setState(() {
        if (error.problem == MeetingStartProblem.busy && busy != null) {
          _recordingNow(busy.meetingId);
        } else {
          _refused = error.problem;
          _stage = _Stage.refused;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.refused);
    }
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    Meeting? meeting;
    try {
      meeting = await _controller.stop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _stopping = false;
          _stopFailed = true;
        });
        unawaited(showFeedback(messenger, l.meetingStopFailed));
      }
      return;
    }
    _stopFailed = false;
    if (!mounted) return;
    if (meeting == null) {
      // Only silence, under a minute: nothing is kept.
      unawaited(showFeedback(messenger, l.meetingNothingHeard));
      Navigator.of(context).pop();
      return;
    }
    // A minute or more judged all silence: kept, as a stopped meeting, to
    // ask first (UX-2717).
    final quiet = meeting.phase == MeetingPhase.interrupted;
    setState(() {
      _show(meeting!.id);
      _stage = _Stage.after;
    });
    _follow(ref.read(meetingsProvider));
    if (quiet) unawaited(_askQuiet(meeting.id));
  }

  /// «Casi no se oyó nada. ¿Hacer notas igualmente?» (UX-2717): «Hacer las
  /// notas» sends what it held, like any recording; «Descartar» deletes it
  /// (MN-25) and closes the screen. Dismissed, it's neither: the screen
  /// shows the stopped meeting's same choices, as Notes does.
  Future<void> _askQuiet(String id) async {
    final l = context.l10n;
    final makeNotes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('meeting-quiet-question'),
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        content: Text(l.meetingQuietQuestion),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.meetingMakeNotes),
          ),
        ],
      ),
    );
    if (!mounted || makeNotes == null) return;
    if (makeNotes) {
      try {
        // «Preparando tus notas…» follows, as after any Stop.
        await _controller.finishMeeting(id);
      } catch (_) {
        /* Still stopped: its choices stay on the screen. */
      }
      return;
    }
    _opened = true;
    try {
      await _controller.discardMeeting(id);
    } catch (_) {
      if (mounted) _opened = false;
      return;
    }
    if (mounted) _leave();
  }

  Future<void> _discard() async {
    if (_discarding ||
        !await confirmMeetingDiscard(context, recording: true) ||
        !mounted) {
      return;
    }
    setState(() => _discarding = true);
    try {
      await _controller.discardRecording();
    } catch (_) {
      if (mounted) setState(() => _discarding = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Follows the meeting through the controller's state: the recording
  /// ending by itself, and the notes arriving.
  void _follow(MeetingsState meetings) {
    final id = _id;
    if (!mounted || id == null || _opened) return;
    if (_stage == _Stage.recording) {
      if (_stopping || _discarding || meetings.recording?.meetingId == id) {
        return;
      }
      // Stop failed: Stop again, unless it has ended by itself since.
      if (_stopFailed && _controller.endOf(id) == null) return;
      setState(() {
        _ended = true;
        _stage = _Stage.after;
      });
    }
    if (_stage != _Stage.after) return;
    if (_ended && _controller.endOf(id) == MeetingRecorderEnd.empty) {
      // It ended by itself with only silence: nothing is kept, no notes
      // follow.
      _opened = true;
      unawaited(
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.meetingNothingHeard,
        ),
      );
      _leave();
      return;
    }
    final ready = meetings.ready.where((m) => m.id == id).firstOrNull;
    if (ready?.noteId != null) {
      // Another screen is on top: the note waits, in Notes too, and opens
      // here once this screen is in front again.
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _opened = true;
      unawaited(_controller.markSeen(id));
      // The note takes this screen's place: Back returns to Notes.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailScreen(taskId: ready!.noteId!),
        ),
      );
      return;
    }
    final listed = [
      ...meetings.waiting,
      ...meetings.stopped,
    ].any((m) => m.id == id);
    if (listed) {
      _listed = true;
    } else if (_listed) {
      // Discarded, here or from Notes.
      _opened = true;
      _leave();
    }
  }

  /// Closes this screen, also from under another one.
  void _leave() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      Navigator.of(context).pop();
    } else if (route?.isActive ?? false) {
      Navigator.of(context).removeRoute(route!);
    }
  }

  /// While recording: why its notes will wait, as its Notes line says
  /// once the server refused a piece; or that this month's meeting time is
  /// used, from the start (an earlier meeting was refused this month).
  String? _heldLine(AppLocalizations l, MeetingsState meetings) =>
      switch (meetings.recordingProblem) {
        MeetingProblem.allowanceUsed => l.meetingAllowanceUsed,
        MeetingProblem.proRequired => l.meetingProRequired,
        _ => meetings.allowanceUsed ? l.meetingAllowanceUsedStart : null,
      };

  @override
  Widget build(BuildContext context) {
    ref.listen<MeetingsState>(meetingsProvider, (_, next) => _follow(next));
    final meetings = ref.watch(meetingsProvider);
    // In front again: notes that became ready meanwhile open now.
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_current) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _follow(ref.read(meetingsProvider)),
      );
    }
    _current = current;
    final l = context.l10n;
    final status = meetings.recording?.meetingId == _id
        ? meetings.recording
        : null;
    final end = _ended && _id != null ? _controller.endOf(_id!) : null;
    return Scaffold(
      appBar: CustomAppBar(title: l.meetingScreenTitle),
      body: switch (_stage) {
        _Stage.starting => const Center(child: CircularProgressIndicator()),
        _Stage.recording => _Recording(
          status: status,
          spaceLow: _spaceLow,
          warning: _heldLine(l, meetings),
          stopFailed: _stopFailed || (status?.stopFailed ?? false),
        ),
        _Stage.refused => _Refused(problem: _refused, onRetry: _record),
        _Stage.after => _After(meetings: meetings, id: _id, end: end),
      },
      bottomNavigationBar: switch (_stage) {
        _Stage.recording => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const ValueKey('meeting-stop'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  onPressed: _stopping || _discarding ? null : _stop,
                  icon: const Icon(Icons.stop_rounded, size: 32),
                  label: Text(l.meetingStop, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    key: const ValueKey('meeting-discard'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _stopping || _discarding ? null : _discard,
                    child: Text(l.discard),
                  ),
                ),
              ],
            ),
          ),
        ),
        _Stage.starting => null,
        _ => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: OutlinedButton(
              key: const ValueKey('meeting-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.close),
            ),
          ),
        ),
      },
    );
  }
}

/// Scrolls when the text is large, centred when it fits.
class _Centered extends StatelessWidget {
  const _Centered({required this.children, this.vertical = 24});
  final List<Widget> children;

  /// The space above and below.
  final double vertical;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // The full width, so what's narrow stays centred (R1-P324-3).
          minWidth: math.max(0, constraints.maxWidth - 48),
          minHeight: math.max(0, constraints.maxHeight - 2 * vertical),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    ),
  );
}

class _Recording extends StatelessWidget {
  const _Recording({
    required this.status,
    this.spaceLow = false,
    this.warning,
    this.stopFailed = false,
  });
  final MeetingRecordingStatus? status;

  /// Little space left: it says so, and records on (MN-6).
  final bool spaceLow;

  /// Why this recording's notes will wait (Pro, the month's time); it
  /// records on.
  final String? warning;

  /// Stop failed once the microphone had stopped (UX-2713): it no longer
  /// says it's recording, only how much was recorded, until Stop works.
  final bool stopFailed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final elapsed = status?.elapsed ?? Duration.zero;
    final level = status?.level ?? 0;
    final instant = MediaQuery.disableAnimationsOf(context);
    // Large text: a smaller ring beside the time, the time's digits held
    // at 1.3×, closer lines and less space around them leave the line and
    // any warning whole above Parar.
    final big = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final ring = big ? 2 / 3 : 1.0;
    final leading = big ? 1.3 : null;
    // The level: a ring that grows as it hears. Only for the eyes.
    final meter = ExcludeSemantics(
      child: SizedBox.square(
        dimension: 136 * ring,
        child: Center(
          child: AnimatedContainer(
            key: const ValueKey('meeting-level'),
            duration: instant
                ? Duration.zero
                : const Duration(milliseconds: 120),
            width: (88 + 48 * level) * ring,
            height: (88 + 48 * level) * ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 40 * ring,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
    // Read on demand, not on every tick: no live region.
    final time = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Text(
        meetingElapsed(elapsed),
        key: const ValueKey('meeting-elapsed'),
        semanticsLabel: meetingElapsedLabel(l, elapsed),
        textAlign: TextAlign.center,
        style: theme.textTheme.displayMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return _Centered(
      vertical: big ? 16 : 24,
      children: [
        if (!big) ...[meter, const SizedBox(height: 16)],
        if (!stopFailed) ...[
          Text(
            l.meetingListening,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 4),
        ],
        if (big)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              meter,
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: time),
              ),
            ],
          )
        else
          time,
        // Before any warning, so it stays in view above Parar at large
        // text: leaving doesn't stop the recording.
        if (!stopFailed) ...[
          const SizedBox(height: 12),
          Text(
            l.meetingListeningHelp,
            key: const ValueKey('meeting-help'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: leading),
          ),
        ],
        if (warning != null) ...[
          const SizedBox(height: 12),
          Text(
            warning!,
            key: const ValueKey('meeting-held'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error, height: leading),
          ),
        ],
        if (spaceLow) ...[
          const SizedBox(height: 12),
          Text(
            l.meetingSpaceLowWarning,
            key: const ValueKey('meeting-space-low'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error, height: leading),
          ),
        ],
      ],
    );
  }
}

class _Refused extends StatelessWidget {
  const _Refused({required this.problem, required this.onRetry});
  final MeetingStartProblem? problem;

  /// Asks for the microphone again, or tries to start again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final microphone =
        problem == MeetingStartProblem.permission ||
        problem == MeetingStartProblem.microphoneBlocked;
    return _Centered(
      children: [
        EmptyState(
          title: null,
          icon: microphone ? Icons.mic_off_outlined : Icons.info_outline,
          message: switch (problem) {
            // Android still asks: ask again here. Settings only once it
            // doesn't.
            MeetingStartProblem.permission => l.meetingMicrophoneNeeded,
            MeetingStartProblem.microphoneBlocked => l.meetingMicrophoneBlocked,
            MeetingStartProblem.lowSpace => l.meetingLowSpace,
            _ => l.meetingStartFailed,
          },
          action: switch (problem) {
            MeetingStartProblem.permission => FilledButton(
              key: const ValueKey('meeting-allow-microphone'),
              onPressed: onRetry,
              child: Text(l.meetingAllowMicrophone),
            ),
            MeetingStartProblem.microphoneBlocked => FilledButton(
              onPressed: openAppSettings,
              child: Text(l.captureOpenSettings),
            ),
            MeetingStartProblem.lowSpace => null,
            _ => FilledButton(
              key: const ValueKey('meeting-retry'),
              onPressed: onRetry,
              child: Text(l.tryAgain),
            ),
          },
        ),
      ],
    );
  }
}

/// After Stop, or after the recording ended by itself ([end]).
class _After extends StatelessWidget {
  const _After({required this.meetings, required this.id, this.end});
  final MeetingsState meetings;
  final String? id;

  /// Why the recording ended by itself; null after Stop.
  final MeetingRecorderEnd? end;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final stopped = meetings.stopped.where((m) => m.id == id).firstOrNull;
    final failed = end == MeetingRecorderEnd.failed;
    if (stopped != null) {
      // Said why once, then the same choices as in Notes (UX-2703).
      return _Centered(
        children: [
          if (failed) ...[
            MessageBanner(
              l.meetingMicrophoneFailed,
              icon: Icons.mic_off_outlined,
            ),
            const SizedBox(height: 24),
            MeetingStoppedActions(meeting: stopped, centered: true),
          ] else
            MeetingStoppedCard(meeting: stopped),
        ],
      );
    }
    final waiting = meetings.waiting.where((m) => m.id == id).firstOrNull;
    final problem = waiting?.problem;
    final working = problem == null || problem == MeetingProblem.server;
    final offline = problem == MeetingProblem.offline;
    final line = waiting == null
        ? l.meetingPreparing
        : meetingWaitingLine(context, waiting);
    final lost = waiting != null && meetingLost(waiting);
    return _Centered(
      children: [
        if ((failed || end == MeetingRecorderEnd.lowSpace) &&
            waiting != null &&
            !lost) ...[
          MessageBanner(
            failed ? l.meetingMicrophoneFailed : l.meetingStoppedNoSpace,
            icon: failed
                ? Icons.mic_off_outlined
                : Icons.sd_card_alert_outlined,
          ),
          const SizedBox(height: 24),
        ],
        if (working)
          const SizedBox.square(
            dimension: 48,
            child: CircularProgressIndicator(),
          )
        else
          Icon(
            offline
                ? Icons.cloud_off_outlined
                : lost
                ? Icons.error_outline
                : Icons.hourglass_top_rounded,
            size: 48,
            color: lost ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
        const SizedBox(height: 20),
        // Read out as it changes: «Preparando tus notas…», then
        // «Esperando conexión».
        Semantics(
          liveRegion: true,
          child: Text(
            line,
            key: const ValueKey('meeting-status'),
            textAlign: TextAlign.center,
            style: working || offline
                ? theme.textTheme.headlineSmall
                : theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        if (working || offline) _AfterHelp(offline: offline),
        if (waiting != null &&
            (lost ||
                problem == MeetingProblem.proRequired ||
                problem == MeetingProblem.allowanceUsed))
          _AfterActions(meeting: waiting),
      ],
    );
  }
}

/// Under «Preparando tus notas…» or «Esperando conexión»: a notice when
/// the notes are ready only if the phone lets TaskFlow show one; else that
/// they'll be in Notas (UX-2801). No permission is asked here. Until the
/// phone answers, the line is kept blank at its size, so it doesn't change
/// words under the reader; it asks again when the app comes back, as the
/// notifications may have been turned on or off meanwhile.
class _AfterHelp extends ConsumerStatefulWidget {
  const _AfterHelp({required this.offline});
  final bool offline;

  @override
  ConsumerState<_AfterHelp> createState() => _AfterHelpState();
}

class _AfterHelpState extends ConsumerState<_AfterHelp>
    with WidgetsBindingObserver {
  /// Null until the phone answers: no promise until then.
  bool? _notices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    var allowed = false;
    try {
      allowed = (await ref.read(reminderAccessProvider).capability()).allowed;
    } catch (_) {
      /* Unknown: no promise. */
    }
    if (mounted) setState(() => _notices = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final notices = _notices ?? false;
    return Visibility(
      visible: _notices != null,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Text(
        widget.offline
            ? notices
                  ? l.meetingWaitingConnectionHelp
                  : l.meetingWaitingConnectionHelpNoNotice
            : notices
            ? l.meetingPreparingHelp
            : l.meetingPreparingHelpNoNotice,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _AfterActions extends ConsumerWidget {
  const _AfterActions({required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        // «Ver Pro» is taller than «Descartar»: one centre line (UX-2714).
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (meeting.problem == MeetingProblem.proRequired)
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/subscription', arguments: ProReason.meetingNotes),
              child: Text(l.voiceProAction),
            ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              if (await confirmMeetingDiscard(context)) {
                await ref
                    .read(meetingControllerProvider.notifier)
                    .discardMeeting(meeting.id);
              }
            },
            child: Text(l.discard),
          ),
        ],
      ),
    );
  }
}
