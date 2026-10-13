import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/widgets/app_components.dart';

// Each capture screen owns and releases its recorder. A factory also lets the
// interruption contract be exercised without recording from a test machine.
final captureRecorderFactoryProvider = Provider<AudioRecorder Function()>(
  (ref) => AudioRecorder.new,
);

/// Opens capture as a sheet over the current screen. Every way into capture —
/// the creation button, Notes, the widget, shortcuts, sharing and the pending
/// list — comes through here. [kind] is `note` from Notes, `task` elsewhere; a
/// resumed [captureId] keeps its own.
Future<void> showCaptureSheet(
  BuildContext context, {
  String kind = 'task',
  String? projectId,
  String? captureId,
  bool startListening = true,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _CaptureSheetRoute(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      builder: (_) => _SheetFrame(
        child: VoiceTaskScreen(
          kind: kind,
          projectId: projectId,
          captureId: captureId,
          startListening: startListening,
        ),
      ),
    ),
  );
}

/// A modal bottom sheet whose scrim can't close it while capture is listening
/// or working. Swiping down is handled by [_SheetFrame], so it asks the same
/// question as Cancel and Back instead of closing at once.
class _CaptureSheetRoute extends ModalBottomSheetRoute<void> {
  _CaptureSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         enableDrag: false,
         showDragHandle: false,
       );

  bool _holdScrim = false;

  @override
  bool get barrierDismissible => !_holdScrim;

  void holdScrim(bool hold) {
    if (hold == _holdScrim) return;
    _holdScrim = hold;
    changedInternalState();
  }
}

/// The sheet's handle, safe area and keyboard room. A swipe down asks to close
/// the way Back does, so the capture can answer it.
class _SheetFrame extends StatefulWidget {
  const _SheetFrame({required this.child});
  final Widget child;
  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> {
  double _pulled = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragStart: (_) => _pulled = 0,
    onVerticalDragUpdate: (details) => _pulled += details.delta.dy,
    onVerticalDragEnd: (details) {
      if (_pulled > 72 || (details.primaryVelocity ?? 0) > 700) {
        unawaited(Navigator.maybePop(context));
      }
    },
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(child: widget.child),
          ],
        ),
      ),
    ),
  );
}

/// The capture sheet's content. Open it with [showCaptureSheet]. All recorder
/// entry points, including shortcuts and recovered sessions, pass through the
/// same paid-access gate before a recorder is created.
class VoiceTaskScreen extends ConsumerWidget {
  const VoiceTaskScreen({
    super.key,
    this.captureId,
    this.startListening = true,
    this.kind = 'task',
    this.projectId,
  });
  final String? captureId;
  final bool startListening;
  final String kind;
  final String? projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hasProProvider)) {
      return _VoiceCaptureScreen(
        captureId: captureId,
        startListening: startListening,
        kind: kind,
        projectId: projectId,
      );
    }
    final billing = ref.watch(subscriptionProvider);
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_none_rounded, size: 48),
            const SizedBox(height: 20),
            Text(
              context.l10n.voiceProRequired,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (billing.busy)
              const CircularProgressIndicator()
            else ...[
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/subscription'),
                child: Text(context.l10n.voiceProAction),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(subscriptionProvider.notifier).refresh(),
                child: Text(context.l10n.billingRefresh),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where a capture is. `starting` covers opening the screen and the moment
/// before the recognizer is ready; `paused` follows leaving the app or an
/// interruption that kept the words.
enum _CapturePhase { starting, idle, listening, paused, processing }

class _VoiceCaptureScreen extends ConsumerStatefulWidget {
  const _VoiceCaptureScreen({
    this.captureId,
    this.startListening = true,
    this.kind = 'task',
    this.projectId,
  });
  final String kind;
  final String? projectId;
  final String? captureId;
  final bool startListening;
  @override
  ConsumerState<_VoiceCaptureScreen> createState() => _VoiceTaskScreenState();
}

class _VoiceTaskScreenState extends ConsumerState<_VoiceCaptureScreen>
    with WidgetsBindingObserver {
  late final AudioRecorder _recorder;
  final _words = TextEditingController();
  final _wordsFocus = FocusNode();
  late final CaptureStore _store;
  late final String _owner;
  ProviderContainer? _container;
  CaptureSession? _session;
  late String _kind = widget.kind;
  String _zone = 'UTC';
  bool _timezoneFallback = false;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitude;
  StreamSubscription<RecordState>? _recorderStates;
  Future<void> _writes = Future.value();
  Future<void>? _starting;
  Future<void>? _stopping;
  bool _recording = false;
  _CapturePhase _phase = _CapturePhase.starting;
  bool get _busy =>
      _stopping != null ||
      _phase == _CapturePhase.processing ||
      (_phase == _CapturePhase.starting && !_recording);
  bool _micBlocked = false;
  bool _initialized = false;
  bool _autoStart = false;
  bool _autoStarted = false;
  // Opening listens on the next frame: show `starting` until then.
  bool _startPending = false;
  // Typing instead: the words become an editable field.
  bool _typing = false;
  // The keep-or-discard question is up.
  bool _asking = false;
  int _seconds = 0;
  // The listening second the last new words arrived.
  int _wordsAt = 0;
  double _level = 0;
  String? _error;
  bool _errorRetained = false;
  late final NativeSpeech _speech;
  SpeechCapability _capability = const SpeechCapability();
  StreamSubscription<SpeechEvent>? _speechEvents;
  Completer<void>? _speechEnded;
  bool _nativeMode = false;
  bool _usingNative = false;
  bool _acceptSpeech = false;
  String _nativePrefix = '';
  int _nativeRun = DateTime.now().millisecondsSinceEpoch % 2000000000;
  final _openingWatch = Stopwatch()..start();
  Stopwatch? _listeningWatch;
  bool _firstWords = false;
  bool _typedStarted = false;
  bool _movedToReview = false;
  bool _discarded = false;

  void _showProblem(Object problem, {bool retained = false}) {
    if (!mounted) return;
    setState(() {
      _error = CaptureProblem.from(problem);
      _errorRetained = retained && _error != CaptureProblem.gone;
    });
  }

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(captureRecorderFactoryProvider)();
    _store = ref.read(captureStoreProvider);
    unawaited(CaptureDiagnostics(_store.database).record(CaptureEvent.opened));
    _speech = ref.read(nativeSpeechProvider);
    // Project and people names for the speech hints, ready before listening.
    ref.read(taskListsProvider);
    _owner = ref.read(captureOwnerProvider);
    _zone = ref.read(authProvider).account?.timezone ?? 'UTC';
    WidgetsBinding.instance.addObserver(this);
    CaptureInterruption.active = _interruptCapture;
    // The sheet shows the words and the controls that fit them.
    _words.addListener(_wordsChanged);
    // An earlier save's Undo must not follow the user into a new capture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
    unawaited(_load());
  }

  void _wordsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
    // With TalkBack, listening waits for `Start talking`, so the screen
    // reader's own speech doesn't end up in the words.
    _autoStart =
        widget.startListening && !MediaQuery.accessibleNavigationOf(context);
    _tryAutoStart();
  }

  Future<void> _load() async {
    try {
      _capability = await _speech.capability();
      _nativeMode = _capability.usable;
      await ref.read(regionalProvider.notifier).ready;
      final zone = await CaptureTimezone.resolve(
        ref.read(regionalProvider),
        accountTimezone: _zone,
      );
      _zone = zone.identifier;
      _timezoneFallback = zone.fallback;
      await _store.cleanFinished(_owner);
      if (widget.captureId != null) {
        _session = await _store.read(widget.captureId!, _owner);
        if (_session == null || _session!.terminal) {
          throw StateError('This capture is no longer available.');
        }
        if (!mounted) return;
        _zone = _session!.timezone;
        _kind = _session!.kind;
        _timezoneFallback = false;
        _words.text = _session!.text;
        await CaptureDiagnostics(_store.database).record(CaptureEvent.resumed);
        if (_session!.drafts.isNotEmpty && mounted) {
          _review(_session!);
          return;
        }
        _error = _session!.error;
        _errorRetained = _error != null;
      }
    } catch (error) {
      _error = CaptureProblem.from(error);
    }
    if (!mounted) return;
    setState(() {
      _phase = _CapturePhase.idle;
      _initialized = true;
    });
    unawaited(
      CaptureDiagnostics(_store.database).record(
        CaptureEvent.ready,
        elapsedMs: _openingWatch.elapsedMilliseconds,
      ),
    );
    _tryAutoStart();
  }

  void _tryAutoStart() {
    if (!_initialized ||
        !_autoStart ||
        _autoStarted ||
        _session?.audioPath != null ||
        _words.text.trim().isNotEmpty ||
        _session?.drafts.isNotEmpty == true) {
      return;
    }
    _autoStarted = true;
    _startPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _startPending = false);
      if (!_typing && ModalRoute.of(context)?.isCurrent == true) {
        _beginRecording();
      }
    });
  }

  Future<void> _ensureSession({
    bool audio = false,
    String text = '',
    String? source,
  }) async {
    if (_session != null) return;
    _session = await _store.create(
      _owner,
      _zone,
      text: text,
      audio: audio,
      kind: _kind,
      projectId: widget.projectId ?? ref.read(projectScopeProvider).projectId,
      source: source,
    );
    await CaptureDiagnostics(_store.database).record(CaptureEvent.started);
    if (mounted) ref.invalidate(pendingCapturesProvider);
  }

  void _changedText(String text) {
    if (!_acceptSpeech && !_typedStarted && text.trim().isNotEmpty) {
      _typedStarted = true;
      unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.typedStarted),
      );
    }
    // The first words decide whether the AI may treat them as speech.
    final source = text.trim().isEmpty
        ? null
        : _acceptSpeech
        ? 'speech'
        : 'typed';
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (text.trim().isEmpty && _session == null) return;
      await _ensureSession(text: text, source: source);
      _session = _session!.copyWith(
        text: text,
        status: _recording ? 'recording' : 'editing',
        source: _session!.source ?? source,
      );
      await _store.update(_session!);
    });
    unawaited(
      _writes.catchError((Object error) {
        _showProblem(CaptureProblem.writeFailed);
      }),
    );
  }

  void _beginRecording() {
    if (_busy || _recording) return;
    _starting = _startRecording();
  }

  void _announce(String message) {
    if (!mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  void _receiveSpeech(SpeechEvent event) {
    if (!_acceptSpeech || event.run != _nativeRun) return;
    final text = event.text?.trim() ?? '';
    if (event.kind == 'ready' || text.isNotEmpty) _listening();
    if (event.kind == 'ready') {
      // A new recognizer attempt is starting: keep what the field shows, even
      // words the last attempt heard but never finalized.
      final shown = _words.text.trim();
      _nativePrefix = shown.length > 4000 ? shown.substring(0, 4000) : shown;
    }
    if (text.isNotEmpty) {
      _wordsAt = _seconds;
      if (!_firstWords) {
        _firstWords = true;
        unawaited(
          CaptureDiagnostics(_store.database).record(
            CaptureEvent.firstPartial,
            elapsedMs: _listeningWatch?.elapsedMilliseconds,
          ),
        );
      }
      // Committed segments append; the segment in progress shows after them
      // and is replaced as it changes.
      final words = [_nativePrefix, text].where((s) => s.isNotEmpty).join(' ');
      final bounded = words.length > 4000 ? words.substring(0, 4000) : words;
      if (event.kind == 'segment') _nativePrefix = bounded;
      if (mounted) {
        _words.text = bounded;
        _words.selection = TextSelection.collapsed(offset: bounded.length);
      }
      _changedText(bounded);
    }
    if (event.level != null && mounted && _phase == _CapturePhase.listening) {
      setState(() => _level = event.level!.clamp(0, 1));
    }
    if (event.error != null) _showProblem(event.error!);
    if (event.terminal) {
      if (_speechEnded?.isCompleted == false) _speechEnded!.complete();
      // Pauses never end listening. A run that ends while still listening was
      // interrupted (leaving the app) or failed: keep the words, don't send.
      if (_recording) {
        unawaited(
          _finishRecording(submit: false, interrupted: event.kind == 'ended'),
        );
      }
    }
  }

  /// The microphone is really listening: show it and start the clock.
  void _listening() {
    if (!mounted || !_recording || _phase != _CapturePhase.starting) return;
    setState(() => _phase = _CapturePhase.listening);
    _armTimer();
    _announce(context.l10n.captureListening);
  }

  void _armTimer() {
    _seconds = 0;
    _wordsAt = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds = timer.tick);
      // The time cap acts as if the user had stopped.
      if (timer.tick >= 60) unawaited(_finishRecording());
    });
  }

  static bool _leaving(AppLifecycleState? state) =>
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached;

  Future<void> _startRecording() async {
    setState(() {
      _phase = _CapturePhase.starting;
      _error = null;
      _errorRetained = false;
    });
    try {
      await _writes;
      _usingNative = _nativeMode && _capability.usable;
      if (!_usingNative && _words.text.trim().isNotEmpty) {
        throw StateError(
          'Save or discard this typed capture before starting a recording.',
        );
      }
      final access = _usingNative
          ? await _speech.permission()
          : await _recorder.hasPermission()
          ? SpeechPermission.granted
          : SpeechPermission.denied;
      if (access != SpeechPermission.granted) {
        await CaptureDiagnostics(
          _store.database,
        ).record(CaptureEvent.permissionDenied);
        if (access == SpeechPermission.blocked) {
          if (mounted) setState(() => _micBlocked = true);
          return;
        }
        throw StateError('Allow microphone access to record, or type below.');
      }
      if (!mounted) return;
      if (_micBlocked) setState(() => _micBlocked = false);
      if (_session?.audioPath != null) {
        throw StateError(
          'Retry this recording or discard it before recording another.',
        );
      }
      if (_usingNative) {
        await _ensureSession(text: _words.text);
        _nativePrefix = _words.text.trim();
        _session = _session!.copyWith(status: 'recording');
        await _store.update(_session!);
        if (!mounted) return;
        _speechEnded = Completer<void>();
        _nativeRun++;
        _acceptSpeech = true;
        _speechEvents ??= _speech.events.listen(
          _receiveSpeech,
          onError: (Object _) {
            _receiveSpeech(
              SpeechEvent(
                _nativeRun,
                'error',
                error: CaptureProblem.speechStopped,
              ),
            );
          },
        );
        _recording = true;
        _firstWords = false;
        _listeningWatch = Stopwatch()..start();
        unawaited(
          CaptureDiagnostics(
            _store.database,
          ).record(CaptureEvent.nativeStarted),
        );
        // Listening shows, and its clock runs, from the recognizer's `ready`.
        await _speech.start(
          _nativeRun,
          _capability.language,
          hints: speechHints(
            _capability.language,
            projects: ref.read(taskListsProvider).valueOrNull ?? const [],
          ),
        );
        if (!mounted || _leaving(WidgetsBinding.instance.lifecycleState)) {
          await _finishRecording(submit: false, interrupted: true);
        }
        return;
      }
      await _ensureSession(audio: true, source: 'speech');
      if (_session!.audioPath == null) {
        _session = _session!.copyWith(
          audioPath: await _store.audioPathFor(_session!),
        );
      }
      _session = _session!.copyWith(
        status: 'recording',
        audioFormat: Platform.isAndroid ? CaptureSession.androidPcmWav : null,
        source: _session!.source ?? 'speech',
      );
      await _store.update(_session!);
      if (!mounted) return;
      _recorderStates ??= _recorder.onStateChanged().listen(
        _receiveRecorderState,
        onError: (Object error) {
          if (mounted && _recording && !_usingNative) {
            _showProblem(error);
            unawaited(_finishRecording(submit: false));
          }
        },
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pause,
        ),
        path: _session!.audioPath!,
      );
      _recording = true;
      _listeningWatch = Stopwatch()..start();
      // A call can take audio focus while start() is still awaiting the native
      // reply, before the state listener can see _recording=true.
      if (await _recorder.isPaused() || !await _recorder.isRecording()) {
        await _finishRecording(submit: false, interrupted: true);
        return;
      }
      if (!_recording) return;
      if (!mounted || _leaving(WidgetsBinding.instance.lifecycleState)) {
        await _finishRecording(submit: false, interrupted: true);
        return;
      }
      _listening();
      _amplitude = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((value) {
            if (mounted && _phase == _CapturePhase.listening) {
              setState(() => _level = ((value.current + 60) / 60).clamp(0, 1));
            }
          });
    } catch (error) {
      _recording = false;
      _acceptSpeech = false;
      _timer?.cancel();
      if (_usingNative) {
        try {
          await _speech.cancel(_nativeRun);
        } catch (_) {
          /* Preserve the transcript. */
        }
      }
      _showProblem(error);
    } finally {
      await _stopping;
      if (mounted) {
        setState(() {
          if (_phase == _CapturePhase.starting && !_recording) {
            _phase = _CapturePhase.idle;
          }
        });
      }
    }
  }

  /// Ends listening. Only the user stopping, or the time cap, [submit]s;
  /// leaving the app or an interruption keeps the words: [interrupted].
  /// [quiet] stops without announcing: Cancel's dialog and Type's field take
  /// focus themselves.
  Future<void> _finishRecording({
    bool submit = true,
    bool interrupted = false,
    bool quiet = false,
  }) =>
      _stopping ??= _stopRecording(submit, interrupted, quiet).whenComplete(() {
        _stopping = null;
        if (mounted) setState(() {});
      });

  void _receiveRecorderState(RecordState state) {
    if (!mounted ||
        !_recording ||
        _usingNative ||
        state == RecordState.record) {
      return;
    }
    // Audio focus can be lost with TaskFlow still in the foreground. Finalize
    // the partial file without submitting it or leaving a paused mic labelled
    // "Listening" until the ordinary recording timer expires.
    unawaited(_finishRecording(submit: false, interrupted: true));
  }

  _CapturePhase _restingPhase(bool interrupted) =>
      interrupted &&
          (_words.text.trim().isNotEmpty || _session?.audioPath != null)
      ? _CapturePhase.paused
      : _CapturePhase.idle;

  Future<void> _stopRecording(bool submit, bool interrupted, bool quiet) async {
    if (!_recording) return;
    _recording = false;
    _listeningWatch?.stop();
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _phase = submit ? _CapturePhase.processing : _restingPhase(interrupted);
        _level = 0;
      });
      // Say what happened: `Done` when sending, `Paused` when listening was
      // cut off without the person asking.
      if (submit) {
        _announce(context.l10n.done);
      } else if (!quiet && _phase == _CapturePhase.paused) {
        _announce(context.l10n.capturePaused);
      }
    }
    await _amplitude?.cancel();
    try {
      if (_usingNative) {
        // The recognizer still has the last words: give it time to send them.
        await _speech.stop(_nativeRun);
        await _speechEnded?.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        );
        _acceptSpeech = false;
        await _speech.cancel(_nativeRun);
        await _writes;
      } else {
        await _recorder.stop();
      }
      if (_session != null) {
        _session = _session!.copyWith(status: 'editing');
        await _store.update(_session!);
        await CaptureDiagnostics(_store.database).record(
          _usingNative
              ? CaptureEvent.nativeListening
              : CaptureEvent.recordingStopped,
          elapsedMs: _listeningWatch?.elapsedMilliseconds,
        );
      }
      if (mounted &&
          submit &&
          (!_usingNative || _session!.text.trim().isNotEmpty)) {
        await _process();
      }
    } catch (error) {
      _showProblem(CaptureProblem.stopFailed);
    } finally {
      _acceptSpeech = false;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        setState(() => _phase = _restingPhase(interrupted));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` only means something covers the window (the notification
    // shade, a system dialog, the permission prompt): listening goes on.
    if (_recording && _leaving(state)) {
      unawaited(_finishRecording(submit: false, interrupted: true));
    }
    if (state == AppLifecycleState.resumed && _micBlocked) {
      unawaited(_checkMicrophone());
    }
  }

  /// Back from Settings: listen if the microphone is on now.
  Future<void> _checkMicrophone() async {
    try {
      if (!await Permission.microphone.isGranted) return;
    } catch (_) {
      return;
    }
    if (!mounted || !_micBlocked) return;
    setState(() => _micBlocked = false);
    _beginRecording();
  }

  Future<void> _process() async {
    final api = ref.read(apiClientProvider);
    var inputKept = false;
    setState(() {
      _phase = _CapturePhase.processing;
      _error = null;
      _errorRetained = false;
    });
    try {
      await _writes;
      if (_session == null && _words.text.trim().isEmpty) {
        throw StateError('Say or type what you need to do first.');
      }
      await _ensureSession(text: _words.text);
      inputKept = true;
      final session = await CaptureProcessor(_store, api).process(_session!);
      _session = session;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        _review(session);
      }
    } catch (error) {
      _showProblem(
        !inputKept && _session != null ? CaptureProblem.writeFailed : error,
        retained: inputKept,
      );
    } finally {
      if (mounted && _phase == _CapturePhase.processing) {
        setState(() => _phase = _CapturePhase.idle);
      }
    }
  }

  void _review(CaptureSession session) {
    _movedToReview = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewTasksScreen(session: session),
      ),
    );
  }

  bool get _hasInput =>
      _words.text.trim().isNotEmpty || _session?.audioPath != null;

  /// `Listo`: stop listening and continue with the words.
  void _done() {
    if (_recording) {
      unawaited(_finishRecording());
    } else {
      unawaited(_process());
    }
  }

  /// `Escribir`: stop listening, keep the words and edit them.
  Future<void> _typeInstead() async {
    setState(() => _typing = true);
    await _starting;
    await _finishRecording(submit: false, quiet: true);
    if (mounted) _wordsFocus.requestFocus();
  }

  /// Cancel, Back and a swipe down: close at once when nothing was said;
  /// otherwise ask once whether to keep it.
  Future<void> _cancel() async {
    if (_asking || !mounted) return;
    if (_phase == _CapturePhase.processing || !_hasInput) {
      Navigator.pop(context);
      return;
    }
    _asking = true;
    if (_recording) {
      unawaited(
        _finishRecording(submit: false, interrupted: true, quiet: true),
      );
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.captureKeepQuestion),
        content: Text(context.l10n.captureKeepHelp),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.keep),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted || keep == null) return;
    if (keep) {
      // The capture stays in the pending list.
      Navigator.pop(context);
    } else {
      await _discard();
    }
  }

  Future<void> _discard() async {
    try {
      await _stopping;
      await _writes;
      if (_session != null) await _store.discard(_session!.id, _owner);
      _discarded = true;
      unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.discarded),
      );
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        Navigator.pop(context);
      }
    } catch (_) {
      _showProblem(CaptureProblem.discardFailed);
    }
  }

  @override
  void dispose() {
    if (CaptureInterruption.active == _interruptCapture) {
      CaptureInterruption.active = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_release());
    _words.dispose();
    _wordsFocus.dispose();
    super.dispose();
  }

  Future<void> _interruptCapture() async {
    await _writes;
    await _starting;
    await _finishRecording(submit: false, interrupted: true);
  }

  Future<void> _release() async {
    try {
      await _writes;
      await _starting;
      await _finishRecording(submit: false);
      _acceptSpeech = false;
      await _speechEvents?.cancel();
      await _recorderStates?.cancel();
      await _recorder.dispose();
      await _writes;
      final session = _session;
      if (!_movedToReview &&
          !_discarded &&
          session != null &&
          !session.terminal) {
        if (session.text.trim().isEmpty &&
            session.audioPath == null &&
            session.drafts.isEmpty) {
          // Nothing was said: closing keeps nothing.
          await _store.discard(session.id, _owner);
          _container?.invalidate(pendingCapturesProvider);
        } else {
          await CaptureDiagnostics(
            _store.database,
          ).record(CaptureEvent.leftCapturePending);
        }
      }
    } catch (_) {
      /* The durable capture remains available on next launch. */
    }
  }

  /// While the sheet listens or works, a tap on the scrim doesn't close it.
  void _holdScrim(bool hold) {
    final route = ModalRoute.of(context);
    if (route is! _CaptureSheetRoute || route.barrierDismissible != hold) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => route.holdScrim(hold));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recorded = _session?.audioPath != null;
    final phase = _startPending ? _CapturePhase.starting : _phase;
    final listening = phase == _CapturePhase.listening;
    _holdScrim(
      _recording ||
          phase == _CapturePhase.starting ||
          phase == _CapturePhase.processing,
    );
    final status = switch (phase) {
      _CapturePhase.listening => l10n.listeningSeconds(
        '00:${_seconds.toString().padLeft(2, '0')}',
      ),
      _CapturePhase.starting => l10n.captureStarting,
      _CapturePhase.processing => l10n.puttingPlanTogether,
      _ when recorded => l10n.recordingKept,
      _CapturePhase.paused => l10n.capturePaused,
      _CapturePhase.idle => null,
    };
    final hint = !listening
        ? null
        : _seconds >= 50
        ? l10n.captureTimeLeft
        : _seconds - _wordsAt >= 5
        ? l10n.captureStillListening
        : null;
    final resting =
        phase == _CapturePhase.idle || phase == _CapturePhase.paused;
    // Nothing heard and nothing listening (TalkBack, or after a problem): one
    // button starts listening.
    final waiting = resting && !_typing && !_hasInput;
    // `Continue` only where listening stopped: a pause, or a voice capture
    // reopened. Shared or typed text never listened.
    final canContinue =
        (phase == _CapturePhase.paused ||
            (phase == _CapturePhase.idle && _session?.source == 'speech')) &&
        !_typing &&
        !recorded &&
        _nativeMode &&
        _words.text.trim().isNotEmpty;
    final primary = <Widget>[
      if (waiting)
        FilledButton(
          autofocus: true,
          onPressed: _busy ? null : _beginRecording,
          child: Text(l10n.captureStartTalking),
        )
      else ...[
        if (canContinue)
          FilledButton.tonal(
            onPressed: _busy ? null : _beginRecording,
            child: Text(l10n.captureContinue),
          ),
        FilledButton(
          onPressed: _busy || !_hasInput ? null : _done,
          child: Text(l10n.done),
        ),
      ],
    ];
    final wordsStyle = theme.textTheme.headlineSmall;
    final Widget? words = _typing
        ? TextField(
            key: const ValueKey('capture-words'),
            controller: _words,
            focusNode: _wordsFocus,
            readOnly: _busy || _recording,
            onChanged: _changedText,
            minLines: 1,
            maxLines: null,
            maxLength: 4000,
            keyboardType: TextInputType.multiline,
            style: wordsStyle,
            decoration: InputDecoration(
              hintText: _kind == 'note' ? l10n.noteHint : l10n.examplePlan,
              counterText: '',
            ),
          )
        : _words.text.trim().isEmpty
        ? null
        : Text(
            _words.text,
            key: const ValueKey('capture-heard'),
            style: wordsStyle,
          );
    final banners = <Widget>[
      if (_timezoneFallback) MessageBanner(l10n.timezoneFallback(_zone)),
      if (_micBlocked) ...[
        MessageBanner(
          l10n.captureMicrophoneBlocked,
          isError: true,
          icon: Icons.mic_off_outlined,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: openAppSettings,
            child: Text(l10n.captureOpenSettings),
          ),
        ),
      ],
      if (_error != null)
        MessageBanner(
          '${captureProblemText(l10n, _error!)}${_errorRetained ? '\n${l10n.captureKept}' : ''}',
          isError: _error != CaptureProblem.setupRequested,
        ),
    ];
    final working = phase == _CapturePhase.processing || _stopping != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status != null)
                Text(status, style: theme.textTheme.titleMedium),
              if (banners.isNotEmpty || words != null)
                Flexible(
                  // Reversed, so the newest words stay in view as they grow.
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final banner in banners)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: banner,
                          ),
                        ?words,
                      ],
                    ),
                  ),
                ),
              // Short, so it never pushes the newest words out of view.
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (!_typing) ...[
                const SizedBox(height: 16),
                Center(child: _ring(colors, phase)),
              ],
              const SizedBox(height: 16),
              _controls(
                context,
                primary,
                showType: !_typing && !recorded,
                onType: working ? null : () => unawaited(_typeInstead()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The level ring around a mic that isn't a button: listening is controlled
  /// only by the buttons below it.
  Widget _ring(ColorScheme colors, _CapturePhase phase) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: switch (phase) {
                _CapturePhase.processing => null,
                _CapturePhase.listening => _level,
                _ => 0,
              },
              strokeWidth: 4,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          Icon(
            Icons.mic_none_rounded,
            size: 32,
            color: phase == _CapturePhase.listening
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );

  /// `Cancelar`, the filled action (with `Seguir` beside it when paused) and
  /// the keyboard. They share a row when it fits, and stack at large text.
  Widget _controls(
    BuildContext context,
    List<Widget> primary, {
    required bool showType,
    VoidCallback? onType,
  }) {
    final l10n = context.l10n;
    final cancel = TextButton(
      onPressed: () => unawaited(_cancel()),
      child: Text(l10n.cancel),
    );
    final type = showType
        ? IconButton(
            tooltip: l10n.captureTypeInstead,
            onPressed: onType,
            icon: const Icon(Icons.keyboard_outlined),
          )
        : null;
    final large = MediaQuery.textScalerOf(context).scale(14) > 18;
    Widget side(List<Widget> buttons) => Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!large &&
            constraints.maxWidth >= (primary.length > 1 ? 440 : 280)) {
          return Row(
            children: [
              cancel,
              const SizedBox(width: 8),
              Expanded(child: side(primary)),
              if (type != null) ...[const SizedBox(width: 4), type],
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large)
              for (var i = 0; i < primary.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                primary[i],
              ]
            else
              side(primary),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: cancel),
                ?type,
              ],
            ),
          ],
        );
      },
    );
  }
}
