import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/command_runner.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/capture_command_cards.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/widgets/reminder_ask_sheet.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_form_entry.dart';

// Each capture screen owns and releases its recorder. A factory also lets the
// interruption contract be exercised without recording from a test machine.
final captureRecorderFactoryProvider = Provider<AudioRecorder Function()>(
  (ref) => AudioRecorder.new,
);

/// Opens capture as a sheet over the current screen. Every way into capture —
/// the creation button, Notes, the widget, shortcuts, sharing and the pending
/// list — comes through here. [kind] is `note` from Notes, `task` elsewhere; a
/// resumed [captureId] keeps its own.
///
/// Saved tasks land on Calendar. A task page that opens capture passes itself
/// as [page] to show them there instead; [showCalendar] first goes back to
/// the Calendar tab. [day] is the day shown where capture opened (Calendar's
/// selected day, the timeline's day): when it is a later day, a task said or
/// typed without a date goes there.
///
/// The mic comes with Pro, or while free dictations are left; otherwise the
/// sheet types. Typed words go to the assistant only with Pro. [typing]
/// opens with the keyboard up (the text shortcut, shared text);
/// [askedToSpeak] marks the ways in that ask to speak (the widget, the voice
/// shortcut), which say why without it.
///
/// An account without Pro makes tasks from typed words only in the task
/// form (DECISIONS.md, 2026-10-18 later): a new task capture that would
/// only type opens the form instead, and so do typed or shared words with
/// no result yet (shared text, a capture resumed from `Sin guardar`), as
/// the form's title and notes. The sheet's keyboard, `Escribir`, opens the
/// form too.
Future<void> showCaptureSheet(
  BuildContext context, {
  String kind = 'task',
  String? projectId,
  String? captureId,
  bool startListening = true,
  Object? page,
  bool showCalendar = false,
  DateTime? day,
  bool typing = false,
  bool askedToSpeak = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(typesInFormProvider)) {
    if (captureId == null) {
      if (kind == 'task' &&
          (typing || !container.read(voiceAvailableProvider))) {
        return openTaskForm(
          context,
          projectId: projectId,
          day: day,
          page: page,
          showCalendar: showCalendar,
          askedToSpeak: askedToSpeak,
        );
      }
    } else {
      final typed = await _typedWords(container, captureId);
      if (!context.mounted) return;
      if (typed != null) {
        return openTaskForm(
          context,
          projectId: typed.projectId,
          day: typed.day,
          page: page,
          showCalendar: showCalendar,
          words: typed.text,
          captureId: typed.id,
        );
      }
    }
  }
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  final above = navigator.context;
  if (!above.mounted) return;
  final localizations = MaterialLocalizations.of(context);
  return navigator.push<void>(
    _CaptureSheetRoute(
      capturedThemes: InheritedTheme.capture(from: context, to: above),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      builder: (_) => _SheetFrame(
        child: _CaptureOrigin(
          page: page,
          showCalendar: showCalendar,
          child: VoiceTaskScreen(
            kind: kind,
            projectId: projectId,
            captureId: captureId,
            startListening: startListening,
            day: day,
            typing: typing,
            askedToSpeak: askedToSpeak,
          ),
        ),
      ),
    ),
  );
}

/// A task capture of typed or shared words with no result yet: for an
/// account without Pro, the form takes it. A dictation stays in the sheet.
Future<CaptureSession?> _typedWords(
  ProviderContainer container,
  String captureId,
) async {
  try {
    final session = await container
        .read(captureStoreProvider)
        .read(captureId, container.read(captureOwnerProvider));
    return session != null &&
            !session.terminal &&
            session.kind == 'task' &&
            !session.hasResult &&
            session.audioPath == null &&
            session.source != 'speech' &&
            session.text.trim().isNotEmpty
        ? session
        : null;
  } catch (_) {
    // The sheet reads it again, and says what went wrong.
    return null;
  }
}

/// Where the sheet was opened from, so a save can land there.
class _CaptureOrigin extends InheritedWidget {
  const _CaptureOrigin({
    required this.page,
    required this.showCalendar,
    required super.child,
  });
  final Object? page;
  final bool showCalendar;

  @override
  bool updateShouldNotify(_CaptureOrigin old) =>
      page != old.page || showCalendar != old.showCalendar;
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

  /// Messages about the sheet's own content (a removed draft, a partial save)
  /// show over the sheet instead of under it. The page's transparent scaffold
  /// takes the taps above the sheet, so it closes the way the scrim does.
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ScaffoldMessenger(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      // The sheet makes room for the keyboard itself.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () {
                if (barrierDismissible) unawaited(navigator?.maybePop());
              },
            ),
          ),
          super.buildPage(context, animation, secondaryAnimation),
        ],
      ),
    ),
  );
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

/// Leaving the sheet with something said, written or understood: the one
/// question, while listening, typing and on a result. It names the words:
/// [spoken] ones, or a text typed or shared. True keeps it pending, false
/// discards it, null (dismissed) stays.
Future<bool?> _askToKeep(BuildContext context, {required bool spoken}) =>
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // At large text on a small screen, the question scrolls instead of
        // overflowing.
        scrollable: true,
        title: Text(
          spoken
              ? context.l10n.captureKeepQuestion
              : context.l10n.captureKeepTextQuestion,
        ),
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

/// A change that only moves its task to another day or time: its button
/// reads `Cambiar fecha` and its message names the day.
bool _onlyMoved(UpdatePlan? plan) =>
    plan != null &&
    plan.schedule != null &&
    plan.title == null &&
    plan.deadline == null &&
    plan.priority == null &&
    plan.notes == null &&
    plan.assignee == null;

/// The capture sheet's content. Open it with [showCaptureSheet]. A recorder
/// is created only with the mic; without it every way in types.
class VoiceTaskScreen extends ConsumerWidget {
  const VoiceTaskScreen({
    super.key,
    this.captureId,
    this.startListening = true,
    this.kind = 'task',
    this.projectId,
    this.day,
    this.typing = false,
    this.askedToSpeak = false,
  });
  final String? captureId;
  final bool startListening;
  final String kind;
  final String? projectId;
  final DateTime? day;
  final bool typing;
  final bool askedToSpeak;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceAvailableProvider);
    if (!voice &&
        ref.watch(billingLoadingProvider) &&
        ref.watch(freeVoiceLeftProvider) == null) {
      // Until billing knows, don't guess between the mic and typing. With
      // none left on the saved account, the sheet types at once; it keeps
      // typing even if billing then finds Pro.
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _VoiceCaptureScreen(
      captureId: captureId,
      startListening: startListening,
      kind: kind,
      projectId: projectId,
      day: day,
      voice: voice,
      typing: typing,
      askedToSpeak: askedToSpeak,
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
    this.day,
    this.voice = true,
    this.typing = false,
    this.askedToSpeak = false,
  });
  final String kind;
  final String? projectId;
  final String? captureId;
  final bool startListening;
  final DateTime? day;

  /// The mic: Pro, or free dictations left. Without it the sheet only types.
  final bool voice;

  /// Opens typing, with the keyboard up, even with voice.
  final bool typing;

  /// Opened to speak: without voice, a line says why the sheet types.
  final bool askedToSpeak;
  @override
  ConsumerState<_VoiceCaptureScreen> createState() => _VoiceTaskScreenState();
}

class _VoiceTaskScreenState extends ConsumerState<_VoiceCaptureScreen>
    with WidgetsBindingObserver {
  // Decided when the sheet opens, and again on `Volver a decirlo`; typing
  // alone never creates a recorder.
  late bool _voice = widget.voice;
  AudioRecorder? _recorder;
  final _words = TextEditingController();
  final _wordsFocus = FocusNode();
  late final CaptureStore _store;
  late final String _owner;
  ProviderContainer? _container;
  CaptureSession? _session;
  late String _kind = widget.kind;
  String _zone = 'UTC';
  bool _timezoneFallback = false;
  Future<void>? _zoneLookup;
  // Per store (one for the app): owners whose finished captures were swept
  // this app session.
  static final _swept = Expando<Set<String>>();
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
  // Typing instead: the words become an editable field. Without voice, and
  // from a text entry, the sheet starts there.
  late bool _typing = !_voice || widget.typing;
  // The keep-or-discard question is up.
  bool _asking = false;
  int _seconds = 0;
  // The listening second the last new words arrived.
  int _wordsAt = 0;
  double _level = 0;
  String? _error;
  // Understanding the words failed: `Reintentar`, and `Guardar tal cual`.
  bool _failed = false;
  // The assistant has taken more than a few seconds.
  bool _slow = false;
  Timer? _slowTimer;
  // Counts understanding steps; saving as written ends the running one, so
  // its late answer changes nothing.
  int _attempts = 0;
  // The result saved as soon as it shows: words saved as written.
  String? _saveAtOnce;
  late final NativeSpeech _speech;
  SpeechCapability _capability = const SpeechCapability();
  // The recognizer's language, e.g. `ca-ES`, passed to every listening run.
  String _speechLanguage = '';
  // The privacy line, shown in the sheet only the first time the microphone
  // is used on this device; after that it lives in Ajustes › Voz.
  bool _privacy = false;
  StreamSubscription<SpeechEvent>? _speechEvents;
  Completer<void>? _speechEnded;
  bool _nativeMode = false;
  bool _usingNative = false;
  // This run's recognizer reported `ready`.
  bool _recognizerReady = false;
  bool _acceptSpeech = false;
  String _nativePrefix = '';
  int _nativeRun = DateTime.now().millisecondsSinceEpoch % 2000000000;
  final _openingWatch = Stopwatch()..start();
  Stopwatch? _listeningWatch;
  bool _firstWords = false;
  bool _typedStarted = false;
  // The recorder's file before any audio arrived: no capture holds it yet.
  String? _audioId;
  bool _movedToReview = false;
  bool _discarded = false;
  // `Escribir` without Pro handed the capture to the task form.
  bool _toForm = false;
  // The result, shown in this sheet once the words are understood.
  CaptureSession? _result;
  // `Volver a decirlo` starts a new capture for the same project.
  String? _projectId;
  // The result `Volver a decirlo` left: kept until new words are understood,
  // so Cancel can bring it back.
  CaptureSession? _previousResult;
  // Counts going back to the previous result, so an understanding step
  // already running knows its words were cancelled.
  int _returns = 0;

  void _showProblem(Object problem) {
    if (!mounted) return;
    setState(() => _error = CaptureProblem.from(problem));
  }

  @override
  void initState() {
    super.initState();
    if (_voice) _recorder = ref.read(captureRecorderFactoryProvider)();
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
    _wordsFocus.addListener(() {
      if (_wordsFocus.hasFocus) _sweepOnce();
    });
    // An earlier save's Undo must not follow the user into a new capture.
    // It lives on the app's messenger, not the sheet's own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = Navigator.maybeOf(context)?.context ?? context;
      ScaffoldMessenger.maybeOf(app)?.hideCurrentSnackBar();
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
        _voice &&
        widget.startListening &&
        !widget.typing &&
        !MediaQuery.accessibleNavigationOf(context);
    _tryAutoStart();
  }

  Future<void> _load() async {
    // Listening doesn't wait for the time zone; a new capture does.
    _zoneLookup = _lookUpZone();
    try {
      await ref.read(regionalProvider.notifier).ready;
      if (_voice && mounted) {
        // The language chosen in Voz, else the app's; never the phone's.
        final preferences = ref.read(regionalProvider);
        _speechLanguage = captureSpeechLanguage(context, preferences);
        _capability = await _speech.knownCapability(_speechLanguage);
        _nativeMode = _capability.usable && !preferences.speechOnline;
      }
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
        unawaited(
          CaptureDiagnostics(_store.database).record(CaptureEvent.resumed),
        );
        if (_session!.hasResult && mounted) {
          _review(_session!);
          return;
        }
        final error = _session!.error;
        final heard = _session!.audioPath != null;
        _error = error == null ? null : _problemFor(error, heard: heard);
        _failed = _session!.status == 'failed';
        if (_voice && CaptureProblem.usedUp(_error)) {
          // Free dictations came back, or Pro: trying again works now.
          _error = null;
        } else if (!_voice &&
            (heard || _session!.source == 'speech') &&
            ref.read(freeVoiceLeftProvider) == 0) {
          // Spoken words reopened with none left: they wait, or are saved as
          // written.
          _error = CaptureProblem.freeVoiceUsedUp;
        }
        // The server found no speech in its audio: nothing to keep.
        if (heard &&
            _error == CaptureProblem.noSpeech &&
            !_hasWords &&
            await _dropSilent(_session!)) {
          _failed = false;
        }
      }
    } catch (error) {
      _error = CaptureProblem.from(error);
    }
    if (!mounted) return;
    setState(() {
      _phase = _CapturePhase.idle;
      _initialized = true;
    });
    // Typing: the field takes focus, with the keyboard up.
    if (_typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _typing) _wordsFocus.requestFocus();
      });
    }
    unawaited(
      CaptureDiagnostics(_store.database).record(
        CaptureEvent.ready,
        elapsedMs: _openingWatch.elapsedMilliseconds,
      ),
    );
    _tryAutoStart();
  }

  /// The zone a new capture is stored in. A resumed capture keeps its own.
  Future<void> _lookUpZone() async {
    try {
      await ref.read(regionalProvider.notifier).ready;
      if (!mounted) return;
      final zone = await CaptureTimezone.resolve(
        ref.read(regionalProvider),
        accountTimezone: _zone,
      );
      if (!mounted || widget.captureId != null) return;
      setState(() {
        _zone = zone.identifier;
        _timezoneFallback = zone.fallback;
      });
    } catch (_) {
      /* The account's zone stays. */
    }
  }

  /// Leftover audio of saved and discarded captures goes once per app
  /// session, after listening or typing has begun. It never holds them up.
  void _sweepOnce() {
    if (!(_swept[_store] ??= <String>{}).add(_owner)) return;
    Future<void> sweep() async {
      try {
        await _store.cleanFinished(_owner);
      } catch (_) {
        /* Swept again next app session. */
      }
    }

    unawaited(sweep());
  }

  void _tryAutoStart() {
    if (!_initialized ||
        !_autoStart ||
        _autoStarted ||
        _session?.audioPath != null ||
        _words.text.trim().isNotEmpty ||
        _session?.hasResult == true) {
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
    String? id,
  }) async {
    if (_session != null) return;
    final now = ref.read(calendarClockProvider)();
    final day = widget.day == null ? null : Task.day(widget.day!);
    final scoped = ref.read(projectScopeProvider).projectId;
    final projectId =
        _projectId ??
        widget.projectId ??
        (ref.read(listCanEditProvider(scoped)) ? scoped : null);
    // Stored in the phone's zone, once it is known.
    await _zoneLookup;
    if (_session != null) return;
    _session = await _store.create(
      _owner,
      _zone,
      text: text,
      now: now,
      audio: audio,
      kind: _kind,
      projectId: projectId,
      source: source,
      id: id,
      // Spoken captures keep the Voz language, so online transcription
      // hears it too.
      language: _spokenLanguage(audio: audio, source: source),
      // Kept with the capture, so resuming it keeps the day. Today, or a day
      // gone by, adds nothing; notes never get a day.
      day: _kind == 'task' && day != null && day.isAfter(Task.day(now))
          ? day
          : null,
    );
    unawaited(CaptureDiagnostics(_store.database).record(CaptureEvent.started));
    if (mounted) ref.invalidate(pendingCapturesProvider);
  }

  String? _spokenLanguage({bool audio = false, String? source}) =>
      (audio || source == 'speech') && _speechLanguage.isNotEmpty
      ? _speechLanguage
      : null;

  /// The recorder stopped before any audio arrived: its file holds nothing,
  /// and no capture was kept.
  Future<void> _dropUnheardAudio() async {
    await _writes;
    final id = _audioId;
    if (_session != null || id == null) return;
    _audioId = null;
    try {
      await _store.removeAudioFile(id);
    } catch (_) {
      /* An empty file holds nothing. */
    }
  }

  static final _audioFormat = Platform.isAndroid
      ? CaptureSession.androidPcmWav
      : null;

  /// The recorder measured its first audio: keep its capture, so it survives
  /// the app being closed.
  void _keepAudio() {
    final id = _audioId;
    if (_session != null || id == null) return;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (_session != null || _audioId != id) return;
      await _ensureSession(audio: true, source: 'speech', id: id);
      _audioId = null;
      _session = _session!.copyWith(
        status: _recording ? 'recording' : 'editing',
        audioFormat: _audioFormat,
      );
      await _store.update(_session!);
    });
    unawaited(
      _writes.catchError((Object error) {
        _showProblem(CaptureProblem.writeFailed);
      }),
    );
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
      if (_session != null &&
          CaptureStore.isEmpty(_session!.copyWith(text: text))) {
        // Every word gone: nothing is kept.
        await _store.discard(_session!.id, _owner);
        _session = null;
        _container?.invalidate(pendingCapturesProvider);
        return;
      }
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
    // `listening`: the app's own microphone already keeps the words.
    if (event.kind == 'ready' || event.kind == 'listening' || text.isNotEmpty) {
      _listening();
    }
    if (event.kind == 'error' && !_recognizerReady) {
      // The recognizer never came up: the next capture asks again.
      _speech.forget(_speechLanguage);
    }
    if (event.kind == 'ready') {
      _recognizerReady = true;
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

  /// The first time the microphone is used on this device, the privacy line
  /// shows under the words for this capture; later captures leave it to Voz.
  void _showPrivacyOnce() {
    final preferences = ref.read(regionalProvider);
    if (preferences.privacyShown) return;
    setState(() => _privacy = true);
    unawaited(
      ref
          .read(regionalProvider.notifier)
          .set(preferences.withPrivacyShown())
          .catchError((Object _) {}),
    );
  }

  /// The microphone is really listening: show it and start the clock.
  void _listening() {
    if (!mounted || !_recording || _phase != _CapturePhase.starting) return;
    setState(() => _phase = _CapturePhase.listening);
    _armTimer();
    _announce(context.l10n.captureListening);
    _sweepOnce();
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
      _failed = false;
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
          : await _recorder!.hasPermission()
          ? SpeechPermission.granted
          : SpeechPermission.denied;
      if (access != SpeechPermission.granted) {
        unawaited(
          CaptureDiagnostics(
            _store.database,
          ).record(CaptureEvent.permissionDenied),
        );
        if (access == SpeechPermission.blocked) {
          if (mounted) setState(() => _micBlocked = true);
          return;
        }
        throw StateError('Allow microphone access to record, or type below.');
      }
      if (!mounted) return;
      if (_micBlocked) setState(() => _micBlocked = false);
      _showPrivacyOnce();
      if (_session?.audioPath != null) {
        throw StateError(
          'Retry this recording or discard it before recording another.',
        );
      }
      if (_usingNative) {
        // The capture is kept from the first words, not from listening.
        _nativePrefix = _words.text.trim();
        if (_session != null) {
          _session = _session!.copyWith(status: 'recording');
          await _store.update(_session!);
        }
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
        _recognizerReady = false;
        _listeningWatch = Stopwatch()..start();
        unawaited(
          CaptureDiagnostics(
            _store.database,
          ).record(CaptureEvent.nativeStarted),
        );
        // Listening shows, and its clock runs, from the recognizer's `ready`,
        // or earlier from `listening` when the app's own microphone keeps
        // the words (Android 13+).
        await _speech.start(
          _nativeRun,
          _speechLanguage,
          hints: speechHints(
            _speechLanguage,
            projects: ref.read(taskListsProvider).valueOrNull ?? const [],
          ),
        );
        if (!mounted || _leaving(WidgetsBinding.instance.lifecycleState)) {
          await _finishRecording(submit: false, interrupted: true);
        }
        return;
      }
      // The file is named before its capture exists: the capture is kept from
      // the first audio bytes, not from listening.
      final String path;
      if (_session == null) {
        path = await _store.audioPathForId(_audioId ??= const Uuid().v4());
      } else {
        path = _session!.audioPath ?? await _store.audioPathFor(_session!);
        _session = _session!.copyWith(
          audioPath: path,
          status: 'recording',
          audioFormat: _audioFormat,
          source: _session!.source ?? 'speech',
          language: _session!.language ?? _spokenLanguage(audio: true),
        );
        await _store.update(_session!);
      }
      if (!mounted) return;
      final recorder = _recorder!;
      _recorderStates ??= recorder.onStateChanged().listen(
        _receiveRecorderState,
        onError: (Object error) {
          if (mounted && _recording && !_usingNative) {
            _showProblem(error);
            unawaited(_finishRecording(submit: false));
          }
        },
      );
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pause,
        ),
        path: path,
      );
      _recording = true;
      _listeningWatch = Stopwatch()..start();
      // A call can take audio focus while start() is still awaiting the native
      // reply, before the state listener can see _recording=true.
      if (await recorder.isPaused() || !await recorder.isRecording()) {
        await _finishRecording(submit: false, interrupted: true);
        return;
      }
      if (!_recording) return;
      if (!mounted || _leaving(WidgetsBinding.instance.lifecycleState)) {
        await _finishRecording(submit: false, interrupted: true);
        return;
      }
      _listening();
      _amplitude = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((value) {
            _keepAudio();
            if (mounted && _phase == _CapturePhase.listening) {
              setState(() => _level = ((value.current + 60) / 60).clamp(0, 1));
            }
          });
    } catch (error) {
      _recording = false;
      _acceptSpeech = false;
      _timer?.cancel();
      if (_usingNative) {
        _speech.forget(_speechLanguage);
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
    // Cancel can go back to the result these words were said again for
    // while listening ends: then they are dropped, not understood.
    final returns = _returns;
    final replacing = _previousResult;
    final started = _session;
    bool wentBack() => replacing != null && _returns != returns;
    // Understanding runs on its own: going back from it never waits for the
    // server, and it owns the processing phase.
    var understanding = false;
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
        final finishWatch = Stopwatch()..start();
        await _speech.stop(_nativeRun);
        await _speechEnded?.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        );
        unawaited(
          CaptureDiagnostics(_store.database).record(
            CaptureEvent.recognizerFinish,
            elapsedMs: finishWatch.elapsedMilliseconds,
          ),
        );
        _acceptSpeech = false;
        await _speech.cancel(_nativeRun);
        await _writes;
      } else {
        await _recorder!.stop();
        await _dropUnheardAudio();
      }
      if (_session != null) {
        _session = _session!.copyWith(status: 'editing');
        await _store.update(_session!);
        unawaited(
          CaptureDiagnostics(_store.database).record(
            _usingNative
                ? CaptureEvent.nativeListening
                : CaptureEvent.recordingStopped,
            elapsedMs: _listeningWatch?.elapsedMilliseconds,
          ),
        );
      }
      if (wentBack()) {
        await _dropSaidAgain(started, replacing!);
      } else if (mounted &&
          submit &&
          _session != null &&
          (!_usingNative || _session!.text.trim().isNotEmpty)) {
        understanding = true;
        unawaited(_process());
      }
    } catch (error) {
      if (wentBack()) {
        await _dropSaidAgain(started, replacing!);
      } else {
        _showProblem(CaptureProblem.stopFailed);
      }
    } finally {
      _acceptSpeech = false;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        if (!understanding) {
          setState(() => _phase = _restingPhase(interrupted));
        }
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
    // Cancel can go back to the result these words were said again for
    // while they are understood: then they are dropped, not shown.
    final returns = _returns;
    final replacing = _previousResult;
    bool wentBack() => replacing != null && _returns != returns;
    // Saved as written meanwhile: whatever the assistant says is too late.
    final attempts = ++_attempts;
    bool superseded() => _attempts != attempts;
    var attempt = _session;
    var inputKept = false;
    setState(() {
      _phase = _CapturePhase.processing;
      _error = null;
      _failed = false;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || superseded()) return;
      setState(() => _slow = true);
      _announce(context.l10n.captureSlow);
    });
    try {
      await _writes;
      if (wentBack()) {
        await _dropSaidAgain(attempt ?? _session, replacing!);
        return;
      }
      if (_session == null && _words.text.trim().isEmpty) {
        throw StateError('Say or type what you need to do first.');
      }
      // Typed by an account without Pro: the form, never the parser.
      if (_typedForForm) {
        _attempts++;
        unawaited(_fillByHand());
        return;
      }
      await _ensureSession(text: _words.text);
      attempt = _session;
      if (wentBack()) {
        await _dropSaidAgain(attempt, replacing!);
        return;
      }
      inputKept = true;
      // Typed words go to the assistant only with Pro; spoken ones go with
      // free dictations too.
      final session = await CaptureProcessor(_store, api).process(
        attempt!,
        local: !ref.read(hasProProvider) && attempt.source != 'speech',
        now: ref.read(calendarClockProvider)(),
      );
      if (superseded()) return;
      if (wentBack()) {
        await _dropSaidAgain(session, replacing!);
        return;
      }
      _session = session;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        _review(session);
      }
    } catch (error) {
      if (superseded()) return;
      if (wentBack()) {
        await _dropSaidAgain(attempt, replacing!);
        return;
      }
      final problem = !inputKept && _session != null
          ? CaptureProblem.writeFailed
          : _problemFor(error, heard: attempt?.audioPath != null);
      // Saved audio with no speech in it: nothing to keep or retry. The
      // sheet waits to listen again, with the message still up.
      if (inputKept &&
          problem == CaptureProblem.noSpeech &&
          !_hasWords &&
          await _dropSilent(attempt!)) {
        if (mounted) {
          setState(() {
            _error = problem;
            _failed = false;
          });
        }
        return;
      }
      _showProblem(problem);
      if (mounted) {
        setState(() {
          _failed = inputKept;
          // Free dictations used up: the words stay, to edit or save as
          // written. Nothing is sent again.
          if (CaptureProblem.usedUp(problem)) _typing = true;
        });
      }
    } finally {
      if (!superseded()) {
        _slowTimer?.cancel();
        if (mounted) setState(() => _slow = false);
      }
      // After going back, the sheet may be listening or understanding new
      // words: a late answer leaves it as it is.
      if (mounted &&
          !superseded() &&
          !wentBack() &&
          _phase == _CapturePhase.processing) {
        setState(() => _phase = _CapturePhase.idle);
      }
    }
  }

  /// The problem to show: every 422 means no speech, but words sent as text
  /// weren't silent, so theirs is the plain failure.
  static String _problemFor(Object error, {required bool heard}) {
    final problem = CaptureProblem.from(error);
    return problem == CaptureProblem.noSpeech && !heard
        ? CaptureProblem.failed
        : problem;
  }

  /// Drop a capture whose saved audio held no speech, as erasing every word
  /// does. False when it couldn't be dropped: it stays to retry.
  Future<bool> _dropSilent(CaptureSession session) async {
    try {
      await _store.discard(session.id, _owner);
    } catch (_) {
      return false;
    }
    if (_session?.id == session.id) _session = null;
    _container?.invalidate(pendingCapturesProvider);
    return true;
  }

  /// Words that can be saved as written: saved audio with no words can't.
  bool get _hasWords => _words.text.trim().isNotEmpty;

  /// `Guardar tal cual`: the words as written, with the date they name, saved
  /// at once as any result is, while the assistant is slow or after it
  /// failed.
  Future<void> _saveAsWritten() async {
    final session = _session;
    if (session == null || !_hasWords) return;
    // The running understanding step, if any, is over for this sheet.
    _attempts++;
    _slowTimer?.cancel();
    setState(() {
      _phase = _CapturePhase.processing;
      _slow = false;
      _failed = false;
      _error = null;
    });
    try {
      await _writes;
      final written = await CaptureProcessor(
        _store,
        ref.read(apiClientProvider),
      ).asWritten(session, now: ref.read(calendarClockProvider)());
      if (!mounted) return;
      _session = written;
      _saveAtOnce = written.id;
      ref.invalidate(pendingCapturesProvider);
      _phase = _CapturePhase.idle;
      _review(written);
    } catch (error) {
      if (!mounted) return;
      _showProblem(error);
      setState(() {
        _failed = true;
        _phase = _CapturePhase.idle;
      });
    }
  }

  /// `Guardar tal cual` on a result whose commands found nothing: its words
  /// become a task, understood on the phone and saved at once. No command is
  /// applied, and nothing goes to the assistant, so no dictation is used.
  Future<void> _saveResultAsWritten(CaptureSession result) async {
    final words = result.transcript.trim().isNotEmpty
        ? result.transcript
        : result.text;
    final written = await CaptureProcessor(
      _store,
      ref.read(apiClientProvider),
    ).asWritten(result, text: words, now: ref.read(calendarClockProvider)());
    if (!mounted) return;
    _session = written;
    _saveAtOnce = written.id;
    ref.invalidate(pendingCapturesProvider);
    _review(written);
  }

  /// The result replaces the words in this same sheet.
  void _review(CaptureSession session) {
    _movedToReview = true;
    final previous = _previousResult;
    _previousResult = null;
    setState(() => _result = session);
    // The new words replace the result they were said again for.
    if (previous != null && previous.id != session.id) {
      unawaited(_dropPrevious(previous));
    }
  }

  Future<void> _dropPrevious(CaptureSession previous) async {
    try {
      await _store.discard(previous.id, _owner);
    } catch (_) {
      /* Kept in the pending list. */
    }
    _container?.invalidate(pendingCapturesProvider);
  }

  /// Cancel went back to [replacing] while the words said again for it were
  /// still being understood: drop their capture, and the result's session is
  /// the screen's again.
  Future<void> _dropSaidAgain(
    CaptureSession? attempt,
    CaptureSession replacing,
  ) async {
    if (attempt == null || attempt.id == replacing.id) return;
    if (_session?.id == attempt.id) _session = replacing;
    await _dropPrevious(attempt);
  }

  /// `Volver a decirlo`: keep the result aside, clear the words, and listen
  /// again. Cancel brings the result back until new words are understood.
  void _sayAgain(CaptureSession previous) {
    if (_result == null || !mounted) return;
    _previousResult = previous;
    _projectId = previous.projectId;
    _saveAtOnce = null;
    // The last free dictation may have just been used: then it types.
    _voice = _voice && ref.read(voiceAvailableProvider);
    _words.clear();
    _nativePrefix = '';
    _typedStarted = false;
    _audioId = null;
    setState(() {
      _result = null;
      _movedToReview = false;
      _session = null;
      _typing = !_voice;
      _error = null;
      _failed = false;
      _phase = _CapturePhase.idle;
      _initialized = true;
    });
    if (!_voice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _typing) _wordsFocus.requestFocus();
      });
      return;
    }
    // With TalkBack, listening waits for `Empezar a hablar`, as on opening.
    if (!MediaQuery.accessibleNavigationOf(context)) _beginRecording();
  }

  bool get _hasInput =>
      _words.text.trim().isNotEmpty || _session?.audioPath != null;

  /// Free dictations, as [build] and [_cancel] both see them. [watch] only
  /// from [build].
  ({bool usedUp, bool refused, bool waitsForMore}) _freeVoice({
    bool watch = false,
  }) {
    final hasPro = watch ? ref.watch(hasProProvider) : ref.read(hasProProvider);
    final left = watch
        ? ref.watch(freeVoiceLeftProvider)
        : ref.read(freeVoiceLeftProvider);
    final phase = _startPending ? _CapturePhase.starting : _phase;
    final resting =
        phase == _CapturePhase.idle || phase == _CapturePhase.paused;
    final recorded = _session?.audioPath != null;
    // This month's free dictations are used up: known from the saved count,
    // or from the server's refusal.
    final usedUp = !hasPro && (left == 0 || CaptureProblem.usedUp(_error));
    // Spoken words the assistant would refuse now: they are saved as written,
    // or wait for more dictations. Nothing asks again.
    final refused =
        usedUp && resting && (recorded || _session?.source == 'speech');
    // Only a recording, with no words to save: it waits.
    final waitsForMore = refused && recorded && !_hasWords;
    return (usedUp: usedUp, refused: refused, waitsForMore: waitsForMore);
  }

  /// Only a recording waits for more dictations, kept in Capturas pendientes:
  /// the sheet only closes. After `Volver a decirlo`, Cancel still goes back
  /// to the result.
  bool _recordingWaits() =>
      _freeVoice().waitsForMore && _previousResult == null;

  /// `Listo`: stop listening and continue with the words. Typed by an
  /// account without Pro, they go to the form.
  void _done() {
    if (_recording) {
      unawaited(_finishRecording());
    } else if (_typedForForm) {
      unawaited(_fillByHand());
    } else {
      unawaited(_process());
    }
  }

  /// Words typed (or shared) for a task by an account without Pro: they
  /// become a task only through the form, never the phone's parser. A
  /// dictation still goes to the assistant, and `Guardar tal cual` after it
  /// stays.
  bool get _typedForForm =>
      _kind == 'task' &&
      _hasWords &&
      _session?.audioPath == null &&
      _session?.source != 'speech' &&
      ref.read(typesInFormProvider);

  /// `Escribir`, for an account without Pro: the task form instead of
  /// typing here. Listening stops; words heard or typed so far go to the
  /// form as its title, with their capture, which the form keeps until the
  /// task is saved.
  Future<void> _fillByHand() async {
    if (_asking) return;
    _asking = true;
    var words = '';
    String? captureId;
    try {
      await _starting;
      await _finishRecording(submit: false, quiet: true);
      await _writes;
      words = _words.text.trim();
      final session = _session;
      if (session != null) {
        if (CaptureStore.isEmpty(session.copyWith(text: words))) {
          await _store.discard(session.id, _owner);
        } else {
          captureId = session.id;
        }
      }
      _toForm = true;
    } catch (_) {
      /* The capture stays pending; the words go to the form all the same. */
    } finally {
      _asking = false;
    }
    if (!mounted) return;
    ref.invalidate(pendingCapturesProvider);
    final navigator = Navigator.of(context);
    final origin = context.getInheritedWidgetOfExactType<_CaptureOrigin>();
    navigator.pop();
    unawaited(
      openTaskForm(
        navigator.context,
        projectId: _projectId ?? widget.projectId,
        day: widget.day,
        page: origin?.page,
        showCalendar: origin?.showCalendar ?? false,
        words: words,
        captureId: captureId,
      ),
    );
  }

  /// `Escribir`: stop listening, keep the words and edit them.
  Future<void> _typeInstead() async {
    setState(() => _typing = true);
    await _starting;
    await _finishRecording(submit: false, quiet: true);
    if (mounted) _wordsFocus.requestFocus();
  }

  /// Cancel, Back and a swipe down: close at once when nothing was said;
  /// otherwise ask once whether to keep it. After `Volver a decirlo`, the
  /// result comes back instead.
  Future<void> _cancel() async {
    if (_asking || !mounted) return;
    final previous = _previousResult;
    if (previous != null) {
      await _backToResult(previous);
      return;
    }
    if (_phase == _CapturePhase.processing) {
      Navigator.pop(context);
      return;
    }
    // Nothing to ask: a recording that waits is already kept.
    if (!_hasInput || _recordingWaits()) {
      Navigator.pop(context);
      return;
    }
    _asking = true;
    if (_recording) {
      unawaited(
        _finishRecording(submit: false, interrupted: true, quiet: true),
      );
    }
    // Words said, even when shown to type after, or words typed.
    final keep = await _askToKeep(
      context,
      spoken:
          !_typing ||
          _session?.source == 'speech' ||
          _session?.audioPath != null,
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

  /// Stop listening, drop the words said again, and show the result they
  /// were for, with its edits.
  Future<void> _backToResult(CaptureSession previous) async {
    // While they are understood, go back at once: the running step owns
    // their capture and drops it when it ends.
    if (_phase == _CapturePhase.processing) {
      // The assistant is told at once, so the dropped words use no free
      // dictation.
      final attempt = _session;
      if (attempt != null && attempt.id != previous.id) {
        CaptureProcessor(_store, ref.read(apiClientProvider)).cancel(attempt);
      }
      _returns++;
      _words.clear();
      ref.invalidate(pendingCapturesProvider);
      setState(() {
        _result = previous;
        _previousResult = null;
        _movedToReview = true;
        _typing = false;
        _error = null;
        _failed = false;
        _phase = _CapturePhase.idle;
      });
      return;
    }
    _asking = true;
    try {
      await _starting;
      await _finishRecording(submit: false, interrupted: true, quiet: true);
      await _writes;
      final started = _session;
      if (started != null && started.id != previous.id) {
        await _store.discard(started.id, _owner);
      }
    } catch (_) {
      /* The new words stay in the pending list. */
    } finally {
      _asking = false;
    }
    if (!mounted || _previousResult != previous) return;
    _words.clear();
    ref.invalidate(pendingCapturesProvider);
    _returns++;
    setState(() {
      _result = _previousResult;
      _previousResult = null;
      _movedToReview = true;
      _session = previous;
      _typing = false;
      _error = null;
      _failed = false;
    });
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
    _slowTimer?.cancel();
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
      await _recorder?.dispose();
      await _writes;
      final session = _session;
      if (!_movedToReview &&
          !_discarded &&
          !_toForm &&
          session != null &&
          !session.terminal) {
        if (session.text.trim().isEmpty &&
            session.audioPath == null &&
            !session.hasResult) {
          // Nothing was said: closing keeps nothing.
          await _store.discard(session.id, _owner);
          _container?.invalidate(pendingCapturesProvider);
        } else {
          unawaited(
            CaptureDiagnostics(
              _store.database,
            ).record(CaptureEvent.leftCapturePending),
          );
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
    final result = _result;
    if (result != null) {
      _holdScrim(false);
      final saveAtOnce = _saveAtOnce == result.id;
      return CaptureResult(
        // Saved as written from its own result: a new result, built afresh.
        key: ValueKey((result.id, saveAtOnce)),
        session: result,
        onSayAgain: _sayAgain,
        onSaveAsWritten: _saveResultAsWritten,
        saveAtOnce: saveAtOnce,
      );
    }
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
    final resting =
        phase == _CapturePhase.idle || phase == _CapturePhase.paused;
    final (:usedUp, :refused, :waitsForMore) = _freeVoice(watch: true);
    // Only a recording waits: the sheet only closes.
    final recordingWaits = waitsForMore && _previousResult == null;
    final usedUpLine = usedUp && (!_voice || refused)
        ? freeVoiceUsedUpText(
            l10n,
            ref.watch(freeVoiceResetsProvider),
            recording: waitsForMore,
          )
        : null;
    final status = switch (phase) {
      _CapturePhase.listening => l10n.listeningSeconds(
        '00:${_seconds.toString().padLeft(2, '0')}',
      ),
      _CapturePhase.starting => l10n.captureStarting,
      _CapturePhase.processing => l10n.captureUnderstanding,
      // The used-up line already says the recording is kept.
      _ when recorded && !waitsForMore => l10n.recordingKept,
      _CapturePhase.paused => l10n.capturePaused,
      _CapturePhase.idle => null,
    };
    final processing = phase == _CapturePhase.processing;
    final hint = processing && _slow
        ? l10n.captureSlow
        : !listening
        ? null
        : _seconds >= 50
        ? l10n.captureTimeLeft
        : _seconds - _wordsAt >= 5
        ? l10n.captureStillListening
        : null;
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
    final failed = _failed && resting;
    // The assistant is slow, or failed: the words can be saved as written.
    final saveAsWritten =
        _hasWords && _session != null && ((processing && _slow) || failed);
    // Without Pro, typed words make a task only in the form: the keyboard,
    // `Escribir`, opens it, and so does `Listo` on typed words.
    final byHand = _kind == 'task' && ref.watch(typesInFormProvider);
    final primary = <Widget>[
      if (waiting)
        FilledButton(
          autofocus: true,
          onPressed: _busy ? null : _beginRecording,
          child: Text(l10n.captureStartTalking),
        )
      else if (recordingWaits)
        FilledButton(
          key: const ValueKey('capture-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.captureClose),
        )
      else if (refused) ...[
        if (canContinue)
          FilledButton.tonal(
            onPressed: _busy ? null : _beginRecording,
            child: Text(l10n.captureContinue),
          ),
        if (_hasWords)
          FilledButton(
            onPressed: () => unawaited(_saveAsWritten()),
            child: Text(l10n.captureSaveAsWritten),
          ),
      ] else if (saveAsWritten) ...[
        if (failed)
          FilledButton.tonal(
            onPressed: _busy ? null : _done,
            child: Text(l10n.tryAgain),
          ),
        FilledButton(
          onPressed: () => unawaited(_saveAsWritten()),
          child: Text(l10n.captureSaveAsWritten),
        ),
      ] else if (failed)
        FilledButton(
          onPressed: _busy || !_hasInput ? null : _done,
          child: Text(l10n.tryAgain),
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
    // A recording that waits has no words to type.
    final Widget? words = _typing && !recordingWaits
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
              // Typed words understood on the phone become one task.
              hintText: _kind == 'note'
                  ? l10n.noteHint
                  : ref.watch(hasProProvider)
                  ? l10n.examplePlan
                  : l10n.exampleTask,
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
      // Free dictations used up: say when more come, and where Pro is.
      // Without a free count (an older server), opened to speak without
      // voice: say why it types.
      if (usedUpLine != null || (widget.askedToSpeak && !_voice)) ...[
        Semantics(
          liveRegion: usedUpLine != null,
          child: Text(
            usedUpLine ?? l10n.captureSpeakingIsPro,
            key: usedUpLine == null
                ? null
                : const ValueKey('free-voice-used-up'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            child: Text(l10n.voiceProAction),
          ),
        ),
      ],
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
    ];
    // Directly under the status line, read out when it appears.
    // A refusal for used-up dictations reads as the line above the words.
    final error =
        _error == null || (usedUpLine != null && CaptureProblem.usedUp(_error))
        ? null
        : MessageBanner(
            captureProblemText(l10n, _error!),
            isError: _error != CaptureProblem.setupRequested,
          );
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
              if (error != null)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(top: status == null ? 0 : 8),
                    child: error,
                  ),
                ),
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
              // One small line under the words, at most three lines tall (at
              // 2× text Catalan needs three), so it never takes the newest
              // words' room. The full note is on Voz.
              if (_privacy)
                Padding(
                  key: const ValueKey('capture-privacy'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.capturePrivacyLine,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
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
                // `Reintentar` and `Guardar tal cual` read in full only
                // stacked.
                stack: failed && saveAsWritten,
                showCancel: !recordingWaits,
                showType: !_typing && !recorded,
                byHand: byHand,
                onType: working
                    ? null
                    : byHand
                    ? () => unawaited(_fillByHand())
                    : () => unawaited(_typeInstead()),
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
  /// the keyboard. They share a row when it fits, and stack at large text or
  /// when [stack] asks. With [byHand] the keyboard is `Escribir`, named in
  /// full, and opens the form: the filled action takes the whole width above
  /// it.
  Widget _controls(
    BuildContext context,
    List<Widget> primary, {
    bool stack = false,
    bool showCancel = true,
    required bool showType,
    bool byHand = false,
    VoidCallback? onType,
  }) {
    final l10n = context.l10n;
    final cancel = showCancel
        ? TextButton(
            onPressed: () => unawaited(_cancel()),
            child: Text(l10n.cancel),
          )
        : null;
    final type = !showType
        ? null
        : byHand
        ? TextButton.icon(
            key: const ValueKey('capture-fill-by-hand'),
            onPressed: onType,
            icon: const Icon(Icons.keyboard_outlined),
            label: Text(l10n.captureTypeInstead),
          )
        : IconButton(
            tooltip: l10n.captureTypeInstead,
            onPressed: onType,
            icon: const Icon(Icons.keyboard_outlined),
          );
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
            !stack &&
            !(byHand && type != null) &&
            constraints.maxWidth >= (primary.length > 1 ? 440 : 280)) {
          return Row(
            children: [
              if (cancel != null) ...[cancel, const SizedBox(width: 8)],
              Expanded(child: side(primary)),
              if (type != null) ...[const SizedBox(width: 4), type],
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large || stack)
              for (var i = 0; i < primary.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                primary[i],
              ]
            else
              side(primary),
            if (cancel != null || type != null) ...[
              const SizedBox(height: 4),
              // `Escribir` goes under `Cancelar` when both don't fit.
              if (byHand)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [?cancel, ?type],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (cancel != null) Flexible(child: cancel),
                    ?type,
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The capture's result, inside the capture sheet: each thing to add with its
/// date as the main line, and one button that adds them. Saving closes the
/// sheet; an Undo after that reopens it on the restored result.
class CaptureResult extends ConsumerStatefulWidget {
  const CaptureResult({
    super.key,
    required this.session,
    this.onSayAgain,
    this.onSaveAsWritten,
    this.saveAtOnce = false,
  });
  final CaptureSession session;

  /// Saved as written: saved as soon as it shows, unless a detail still
  /// needs an answer (morning or afternoon).
  final bool saveAtOnce;

  /// Spoken captures: listen again. It gets the result as it is now, with
  /// its edits written, so Cancel can bring it back.
  final ValueChanged<CaptureSession>? onSayAgain;

  /// `Guardar tal cual`, when every command found nothing: the words become
  /// a task instead.
  final Future<void> Function(CaptureSession)? onSaveAsWritten;
  @override
  ConsumerState<CaptureResult> createState() => _CaptureResultState();
}

class _CaptureResultState extends ConsumerState<CaptureResult> {
  late CaptureSession _session = widget.session;
  late List<CaptureDraft> _items = _session.drafts;
  // Create a project, find, change or delete a task: each its own card.
  late List<CaptureCommand> _commands = _session.commands;
  late final CaptureStore _store;
  Future<void> _writes = Future.value();
  bool _saving = false;
  String? _expandedId;
  String? _error;
  final _reviewWatch = Stopwatch()..start();
  bool _finished = false;
  bool _asking = false;
  final _actions = GlobalKey();

  @override
  void initState() {
    super.initState();
    _store = ref.read(captureStoreProvider);
    unawaited(
      CaptureDiagnostics(_store.database).record(CaptureEvent.reviewOpened),
    );
    if (widget.saveAtOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _items.where((d) => d.pending);
        if (mounted && pending.isNotEmpty && pending.every((d) => d.ready)) {
          unawaited(_save());
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_finished &&
        (_items.any((d) => d.pending) || _commands.any((c) => c.pending))) {
      unawaited(
        CaptureDiagnostics(
          _store.database,
        ).record(CaptureEvent.leftReviewPending),
      );
      unawaited(
        CaptureDiagnostics(_store.database).record(
          CaptureEvent.reviewTime,
          elapsedMs: _reviewWatch.elapsedMilliseconds,
        ),
      );
    }
    super.dispose();
  }

  /// Messages shown while the sheet is open float just above its button,
  /// instead of covering it.
  EdgeInsets? _aboveActions() {
    if (!mounted) return null;
    final box = _actions.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    final app = MediaQuery.of(Navigator.of(context).context);
    final bottom = app.size.height - app.padding.bottom - top + 4;
    return EdgeInsets.fromLTRB(15, 5, 15, bottom.clamp(10, double.infinity));
  }

  Future<void> _change(CaptureDraft draft) async {
    final said = _items
        .where((d) => d.id == draft.id)
        .firstOrNull
        ?.projectSuggestion;
    // A choice for a project said serves every task that said it.
    final chosen = said != null && draft.projectSuggestion == null;
    setState(() {
      _items = _items
          .map(
            (d) => d.id == draft.id
                ? draft
                : chosen &&
                      d.pending &&
                      d.projectSuggestion != null &&
                      _sameProject(d.projectSuggestion!, said)
                ? _sameChoice(d, draft)
                : d,
          )
          .toList();
      _error = null;
    });
    await _write();
  }

  static bool _sameProject(String a, String b) =>
      foldForSearch(spokenProjectName(a)) ==
      foldForSearch(spokenProjectName(b));

  /// [draft] given the project choice made on [chosen]'s card.
  CaptureDraft _sameChoice(CaptureDraft draft, CaptureDraft chosen) {
    if (chosen.newProject != null) {
      return draft.copyWith(
        newProject: chosen.newProject,
        clearProjectSuggestion: true,
        assignmentReviewed: true,
      );
    }
    final project = (ref.read(taskListsProvider).valueOrNull ?? const [])
        .where((p) => p.id == chosen.task.listId)
        .firstOrNull;
    final member = draft.assignmentHints['member']?.trim().isNotEmpty == true;
    return draft.copyWith(
      task: taskWithProject(draft.task, project),
      clearProjectSuggestion: true,
      assignmentReviewed: !(project?.shared == true && member),
    );
  }

  Future<void> _changeCommand(CaptureCommand command) async {
    final before = _commands.where((c) => c.id == command.id).firstOrNull;
    final chose =
        command.kind == CommandKind.project &&
        command.choice != null &&
        before?.choice != command.choice;
    // An existing project taken instead of a new one: its tasks go there.
    final picked = chose && command.existing
        ? (ref.read(taskListsProvider).valueOrNull ?? const [])
              .where((p) => p.id == command.choice)
              .firstOrNull
        : null;
    // The project said created instead of the one the server matched: the
    // tasks it filed there go to the new one.
    final matched = command.existingListId;
    final created = chose && !command.existing && matched != null;
    bool inMatched(CaptureDraft draft) =>
        matched != null &&
        draft.newProject == null &&
        draft.task.listId == matched;
    setState(() {
      _commands = [
        for (final item in _commands) item.id == command.id ? command : item,
      ];
      if (picked != null) {
        _items = [
          for (final draft in _items)
            draft.pending &&
                    ((draft.newProject != null &&
                            _sameProject(draft.newProject!, command.name)) ||
                        (inMatched(draft) && picked.id != matched))
                ? draft.copyWith(
                    task: taskWithProject(draft.task, picked),
                    clearNewProject: true,
                  )
                : draft,
        ];
      }
      if (created) {
        _items = [
          for (final draft in _items)
            draft.pending && inMatched(draft)
                ? draft.copyWith(
                    task: taskWithProject(draft.task, null),
                    newProject: command.name,
                    assignmentReviewed: true,
                  )
                : draft,
        ];
      }
      _error = null;
    });
    await _write();
  }

  /// A project the confirming tap creates, renamed from a task's chip: its
  /// card and every task going there take the name [to], linked by the
  /// folded name as in [_removeCommand]. The name of a project the person
  /// can edit takes that project, as a tap on its row does. Nothing is
  /// created yet.
  Future<void> _renameProject(String from, String to) async {
    final name = to.trim();
    if (name.isEmpty || _saving) return;
    final key = foldForSearch(spokenProjectName(name));
    final same = editableProjects(
      ref.read(taskListsProvider).valueOrNull ?? const [],
    ).where((p) => foldForSearch(p.name.trim()) == key).firstOrNull;
    setState(() {
      _commands = [
        for (final command in _commands)
          command.kind == CommandKind.project &&
                  !command.removed &&
                  !command.existing &&
                  _sameProject(command.name, from)
              ? same != null
                    ? command.copyWith(choice: same.id)
                    : command.copyWith(name: name)
              : command,
      ];
      _items = [
        for (final draft in _items)
          draft.pending &&
                  draft.newProject != null &&
                  _sameProject(draft.newProject!, from)
              ? same != null
                    ? draft.copyWith(
                        task: taskWithProject(draft.task, same),
                        clearNewProject: true,
                      )
                    : draft.copyWith(newProject: name)
              : draft,
      ];
      _error = null;
    });
    await _write();
  }

  /// The projects whose card still asks which one is meant: two projects
  /// match, or one matched under another name. [names] holds the new
  /// projects' folded names, [lists] the ids of the matched projects the
  /// server filed tasks in. Their tasks wait for that choice.
  static ({Set<String> names, Set<String> lists}) _undecided(
    List<CommandView> views,
  ) {
    final asking = [
      for (final view in views)
        if (view.kind == CommandKind.project && view.blocking) view.command,
    ];
    return (
      names: {
        for (final command in asking)
          foldForSearch(spokenProjectName(command.name)),
      },
      lists: {
        for (final command in asking)
          if (command.existingListId case final id?) id,
      },
    );
  }

  static bool _draftReady(
    CaptureDraft draft,
    ({Set<String> names, Set<String> lists}) undecided,
  ) =>
      draft.ready &&
      (draft.newProject == null
          ? !undecided.lists.contains(draft.task.listId)
          : !undecided.names.contains(
              foldForSearch(spokenProjectName(draft.newProject!)),
            ));

  /// Every card as it is now, kept with the capture.
  Future<void> _write() async {
    final snapshot = _session.copyWith(
      drafts: _items,
      commands: _commands,
      status: 'ready',
    );
    _session = snapshot;
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => _store.update(snapshot));
    try {
      await _writes;
      unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.edited),
      );
      if (mounted) ref.invalidate(pendingCapturesProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.reviewWriteFailed);
      }
    }
  }

  /// The result holds commands, or a task that goes into a project the tap
  /// creates: it is applied with [_apply]. Every other result saves as it
  /// always has.
  bool get _usesCommands =>
      _commands.isNotEmpty ||
      _items.any((d) => d.pending && d.newProject != null);

  /// The cards of the commands still shown, worked out against the tasks
  /// and projects on the phone. [watch] only from [build].
  List<CommandView> _views({bool watch = false}) {
    if (_commands.isEmpty) return const [];
    final tasks = watch ? ref.watch(taskProvider) : ref.read(taskProvider);
    final projects = watch
        ? ref.watch(taskListsProvider)
        : ref.read(taskListsProvider);
    final auth = watch ? ref.watch(authProvider) : ref.read(authProvider);
    return [
      for (final command in _commands)
        if (command.shown)
          resolveCommand(
            command,
            tasks: tasks.valueOrNull ?? const [],
            projects: projects.valueOrNull ?? const [],
            accountId: auth.account?.id,
          ),
    ];
  }

  /// Something here still waits for the confirming tap, or for a choice.
  bool _worthKeeping() =>
      _items.any((d) => d.pending) ||
      _views().any((view) => view.actionable || view.blocking);

  Future<void> _save() async {
    if (_usesCommands) return _apply();
    if (_saving) return;
    // Leaving the step field keeps a step typed without Enter; focus
    // changes land in a microtask, so wait for that one first.
    _saving = true;
    FocusScope.of(context).unfocus();
    await Future<void>.microtask(() {});
    _saving = false;
    if (!mounted) return;
    final ready = _items.where((d) => d.ready).toList();
    if (_saving || ready.isEmpty) return;
    final saveWatch = Stopwatch()..start();
    unawaited(
      CaptureDiagnostics(_store.database).record(
        CaptureEvent.reviewTime,
        elapsedMs: _reviewWatch.elapsedMilliseconds,
      ),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(taskProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final strings = context.l10n;
    // Messages while the sheet stays open show over it; once it has closed,
    // on the screen underneath.
    final sheetMessages = ScaffoldMessenger.of(context);
    final appMessages = ScaffoldMessenger.of(navigator.context);
    final origin = context.getInheritedWidgetOfExactType<_CaptureOrigin>();
    final before = _session;
    final undoIds = <String, int>{};
    try {
      await _writes;
      final result = await _store.saveReady(
        _session.id,
        _session.ownerKey,
        ready.map((d) => d.id).toSet(),
      );
      _session = result;
      _items = result.drafts;
      for (final draft in result.drafts) {
        if (ready.any((d) => d.id == draft.id) && draft.savedTaskId != null) {
          undoIds[draft.id] = draft.savedTaskId!;
        }
      }
      unawaited(
        CaptureDiagnostics(_store.database).record(
          CaptureEvent.saved,
          elapsedMs: saveWatch.elapsedMilliseconds,
          count: ready.length,
        ),
      );
      _reviewWatch.reset();
      _finished = !_items.any((d) => d.pending);
      await notifier.showLocal();
      if (!mounted) return;
      ref.invalidate(pendingCapturesProvider);
      final remaining = _items.where((d) => d.pending).length;
      _finished = remaining == 0;
      final messenger = remaining == 0 ? appMessages : sheetMessages;
      EdgeInsets? margin() =>
          messenger == sheetMessages ? _aboveActions() : null;
      final tasks = ready.where((item) => !item.task.isNote).toList();
      // The tasks' days, earliest first: Calendar lands on the first. A task
      // with only a deadline lands on its deadline's day, where Calendar
      // lists it.
      final days =
          tasks
              .map((item) => item.task.dueDate ?? item.task.deadline)
              .whereType<DateTime>()
              .map(Task.day)
              .toSet()
              .toList()
            ..sort();
      final day = ready.length == 1 ? ready.single.task.dueDate : null;
      final due = ready.length == 1 ? ready.single.task.deadline : null;
      final added = ready.length > 1
          ? strings.captureTasksAdded(ready.length)
          : day != null
          ? strings.taskAddedOn(context.weekdayDate(day))
          : due != null
          ? strings.taskAddedDue(context.weekdayDate(due))
          : strings.taskSavedInbox;
      // Tasks on days other than the one Calendar lands on are out of sight:
      // name them.
      final otherDays = days.skip(1).toList();
      final message = tasks.isEmpty
          ? strings.noteSaved
          : remaining > 0
          ? '$added · ${strings.captureKeptForReview(remaining)}'
          : otherDays.length == 1
          ? '$added · ${strings.captureAlsoOn(context.weekdayDate(otherDays.single))}'
          : otherDays.length > 1
          ? '$added · ${strings.captureAlsoOnDays(otherDays.length)}'
          : added;
      // The landing Deshacer takes back, if any.
      CalendarFocus? focus;
      if (remaining == 0) {
        // From the pending list, back to Calendar, where the tasks land.
        if (origin?.showCalendar == true) {
          navigator.popUntil((route) => route.isFirst);
        } else {
          Navigator.pop(context);
        }
        // Calendar shows the earliest saved day, and the no-date row too
        // when a task has no date; a task page that opened capture shows
        // them itself.
        final ids = {
          for (final item in tasks)
            if (undoIds[item.id] != null) undoIds[item.id]!,
        };
        if (ids.isNotEmpty) {
          focus = CalendarFocus(
            days.firstOrNull,
            ids,
            page: origin?.page,
            showCalendar: origin?.showCalendar ?? false,
            undated: tasks.any(
              (item) => item.task.dueDate == null && item.task.deadline == null,
            ),
          );
          container.read(calendarFocusProvider.notifier).state = focus;
        }
      }
      final feedback = showFeedback(
        messenger,
        message,
        margin: margin(),
        actionLabel: strings.undo,
        onAction: () async {
          if (mounted && _saving) return;
          if (mounted) setState(() => _saving = true);
          try {
            if (container.read(captureOwnerProvider) != before.ownerKey) {
              return;
            }
            // Finish edits to other rows before restoring this save.
            await _writes;
            final restored = await _store.undoSave(before, undoIds);
            if (restored == null) {
              if (messenger.mounted) {
                unawaited(
                  showFeedback(
                    messenger,
                    strings.reviewUndoChanged,
                    margin: margin(),
                  ),
                );
              }
              return;
            }
            await container.read(taskProvider.notifier).showLocal();
            // The filter the landing widened comes back with the tasks gone.
            narrowAfterUndo(container, focus);
            container.invalidate(pendingCapturesProvider);
            if (mounted) {
              setState(() {
                _session = restored;
                _items = restored.drafts;
                _commands = restored.commands;
                _finished = false;
              });
              if (messenger.mounted) {
                unawaited(
                  showFeedback(
                    messenger,
                    strings.reviewUndoSaved,
                    margin: margin(),
                  ),
                );
              }
            } else if (navigator.mounted &&
                container.read(captureOwnerProvider) == before.ownerKey) {
              // The sheet opens again on the restored result. That is the
              // confirmation: a message would only hide under the sheet.
              unawaited(
                showCaptureSheet(
                  navigator.context,
                  captureId: restored.id,
                  startListening: false,
                  page: origin?.page,
                ),
              );
            }
          } catch (_) {
            if (messenger.mounted) {
              unawaited(
                showFeedback(messenger, strings.undoError, margin: margin()),
              );
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      );
      unawaited(feedback);
      if (remaining == 0) {
        askAboutRemindersAfterSave(
          context,
          ready.map((d) => d.task),
          feedback: feedback,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.saveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _remove(CaptureDraft item) {
    unawaited(_change(item.copyWith(removed: true)));
    unawaited(
      showFeedback(
        ScaffoldMessenger.of(context),
        context.l10n.reviewRemoved,
        margin: _aboveActions(),
        actionLabel: context.l10n.undo,
        onAction: () {
          if (mounted && !_saving) {
            unawaited(_change(item.copyWith(removed: false)));
          }
        },
      ),
    );
  }

  /// ✕ on a command's card: nothing happens for it. A new project taken out
  /// takes its tasks with it out of the project: they go without one.
  void _removeCommand(CaptureCommand command) {
    final name = command.kind == CommandKind.project
        ? foldForSearch(spokenProjectName(command.name))
        : null;
    final moved = <String, String>{
      for (final draft in _items)
        if (name != null &&
            draft.pending &&
            draft.newProject != null &&
            foldForSearch(spokenProjectName(draft.newProject!)) == name)
          draft.id: draft.newProject!,
    };
    void put({required bool back}) {
      setState(() {
        _commands = [
          for (final item in _commands)
            item.id == command.id ? item.copyWith(removed: !back) : item,
        ];
        _items = [
          for (final draft in _items)
            if (moved[draft.id] case final project?)
              back
                  ? draft.copyWith(newProject: project)
                  : draft.copyWith(clearNewProject: true)
            else
              draft,
        ];
        _error = null;
      });
      unawaited(_write());
    }

    put(back: false);
    final l = context.l10n;
    unawaited(
      showFeedback(
        ScaffoldMessenger.of(context),
        switch (command.kind) {
          CommandKind.delete => l.commandWontDelete,
          CommandKind.update => l.commandWontChange,
          // A search has no ✕.
          CommandKind.project || CommandKind.find => l.commandWontCreate,
        },
        margin: _aboveActions(),
        actionLabel: context.l10n.undo,
        onAction: () {
          if (mounted && !_saving) put(back: true);
        },
      ),
    );
  }

  /// D11: a whole repeating series is deleted only after asking, with
  /// `Conservar tarea` as the filled button. True deletes it, false keeps
  /// it, null (dismissed) does nothing yet.
  Future<bool?> _askToDeleteSeries(Task task) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      content: Text(context.l10n.deleteSeriesHelp(task.title)),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.delete),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.keepTask),
        ),
      ],
    ),
  );

  /// The confirming tap of a result with commands: the projects first, then
  /// the tasks in them, the changes and the deletions, all in one go. One
  /// `Deshacer` takes all of it back; what can't be done is taken back at
  /// once, and the result stays.
  Future<void> _apply() async {
    if (_saving) return;
    // As in _save: a step typed without Enter is kept first.
    _saving = true;
    FocusScope.of(context).unfocus();
    await Future<void>.microtask(() {});
    _saving = false;
    if (!mounted) return;
    for (final view in _views()) {
      if (view.kind != CommandKind.delete ||
          !view.actionable ||
          view.stored?.isRecurring != true) {
        continue;
      }
      final delete = await _askToDeleteSeries(view.stored!);
      if (!mounted || delete == null) return;
      if (!delete) {
        // `Conservar tarea`: the task stays, and the rest goes ahead.
        setState(() {
          _commands = [
            for (final item in _commands)
              item.id == view.command.id ? item.copyWith(removed: true) : item,
          ];
        });
        unawaited(_write());
      }
    }
    final views = _views();
    final undecided = _undecided(views);
    final ready = _items.where((d) => _draftReady(d, undecided)).toList();
    final actionable = views.where((view) => view.actionable).toList();
    if (ready.isEmpty && actionable.isEmpty) {
      if (!_worthKeeping()) await _finishEmpty();
      return;
    }
    final saveWatch = Stopwatch()..start();
    unawaited(
      CaptureDiagnostics(_store.database).record(
        CaptureEvent.reviewTime,
        elapsedMs: _reviewWatch.elapsedMilliseconds,
      ),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(taskProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final strings = context.l10n;
    final sheetMessages = ScaffoldMessenger.of(context);
    final appMessages = ScaffoldMessenger.of(navigator.context);
    final origin = context.getInheritedWidgetOfExactType<_CaptureOrigin>();
    final projects = ref.read(taskListsProvider).valueOrNull ?? const [];
    final api = ref.read(apiClientProvider);
    final accountId = ref.read(authProvider).account?.id;
    final runner = CommandRunner(
      notifier,
      ref.read(taskListStoreProvider),
      current: () => container.read(taskProvider).valueOrNull ?? const [],
    );
    final applied = AppliedCommands();
    final before = _session.copyWith(drafts: _items, commands: _commands);
    final readyIds = {for (final draft in ready) draft.id};
    final undoIds = <String, int>{};
    late CaptureSession written;
    var committed = false;
    try {
      await _writes;
      // The projects: those the cards create, and those ready tasks go to.
      // One with the same name already there is used, never a second one.
      String folded(String name) => foldForSearch(spokenProjectName(name));
      final ids = <String, String>{
        for (final view in views)
          if (view.command.existingId case final id?)
            folded(view.command.name): id,
      };
      final names = <String, String>{
        for (final view in actionable)
          if (view.kind == CommandKind.project)
            folded(view.command.name): view.projectName,
        for (final draft in ready)
          if (draft.newProject case final name?)
            folded(name): spokenProjectName(name),
      };
      for (final MapEntry(key: key, value: name) in names.entries) {
        if (ids.containsKey(key)) continue;
        final same = editableProjects(
          projects,
        ).where((p) => foldForSearch(p.name.trim()) == key).firstOrNull;
        ids[key] = same?.id ?? (await runner.createProject(name, applied)).id;
      }
      // The tasks into their projects: new ones are personal.
      final items = [
        for (final draft in _items)
          if (readyIds.contains(draft.id) &&
              draft.newProject != null &&
              ids[folded(draft.newProject!)] != null)
            draft.copyWith(
              task: draft.task.copyWith(
                listId: ids[folded(draft.newProject!)],
                assignment: 'personal',
                assigneeId: null,
                assigneeName: null,
              ),
            )
          else
            draft,
      ];
      for (final view in actionable) {
        if (view.kind == CommandKind.update) {
          await runner.update(
            view.plan!,
            series: view.command.series,
            applied: applied,
          );
        } else if (view.kind == CommandKind.delete) {
          await runner.delete(view.stored!, applied);
        }
      }
      // Done with: what was applied, and changes or deletions with nothing
      // to do (not found, or already as asked). Choices still wait.
      final handled = {
        for (final view in views)
          if (view.actionable ||
              (!view.blocking &&
                  (view.kind == CommandKind.update ||
                      view.kind == CommandKind.delete)))
            view.command.id,
      };
      written = _session.copyWith(
        drafts: items,
        commands: [
          for (final item in _commands)
            handled.contains(item.id) ? item.copyWith(done: true) : item,
        ],
        status: 'ready',
      );
      await _store.update(written);
      final result = await _store.saveReady(
        _session.id,
        _session.ownerKey,
        readyIds,
      );
      committed = true;
      _session = result;
      _items = result.drafts;
      _commands = result.commands;
      for (final draft in result.drafts) {
        if (readyIds.contains(draft.id) && draft.savedTaskId != null) {
          undoIds[draft.id] = draft.savedTaskId!;
        }
      }
    } catch (_) {
      if (!committed) {
        // Nothing half done: what was done is taken back.
        await runner.undoChanges(applied);
        await runner.takeBackProjects(applied, api: api, accountId: accountId);
        try {
          await _store.update(before.copyWith(status: 'ready'));
        } catch (_) {
          /* The capture keeps what it had. */
        }
        if (applied.projects.isNotEmpty) {
          container.invalidate(taskListsProvider);
        }
      }
      if (mounted) {
        setState(() {
          _error = CaptureProblem.saveFailed;
          _saving = false;
          if (!committed) {
            _session = before;
            _items = before.drafts;
            _commands = before.commands;
          }
        });
      }
      return;
    }
    try {
      unawaited(
        CaptureDiagnostics(_store.database).record(
          CaptureEvent.saved,
          elapsedMs: saveWatch.elapsedMilliseconds,
          count: ready.length + actionable.length,
        ),
      );
      _reviewWatch.reset();
      if (applied.projects.isNotEmpty) container.invalidate(taskListsProvider);
      await notifier.showLocal();
      if (!mounted) return;
      ref.invalidate(pendingCapturesProvider);
      final remaining =
          _items.where((d) => d.pending).length +
          _commands.where((c) => c.pending).length;
      _finished = remaining == 0;
      final messenger = remaining == 0 ? appMessages : sheetMessages;
      EdgeInsets? margin() =>
          messenger == sheetMessages ? _aboveActions() : null;
      final tasks = ready.where((item) => !item.task.isNote).toList();
      final landed = [
        for (final update in applied.updates)
          if (update.landed case final task?) task,
      ];
      // Calendar lands on the earliest day among those added and changed; a
      // task with only a deadline, on its deadline's day.
      final days = [
        for (final item in tasks) ?(item.task.dueDate ?? item.task.deadline),
        for (final task in landed) ?task.displayDate,
      ].map(Task.day).toSet().toList()..sort();
      final updates = actionable
          .where((view) => view.kind == CommandKind.update)
          .toList();
      final moved = updates.length == 1 ? updates.single.plan! : null;
      // Only moved to another day or time: the message names the day.
      final moving = _onlyMoved(moved) ? moved!.schedule : null;
      final day = ready.length == 1 ? ready.single.task.dueDate : null;
      final due = ready.length == 1 ? ready.single.task.deadline : null;
      final parts = [
        if (applied.projects.isNotEmpty)
          strings.commandProjectsCreated(applied.projects.length),
        if (ready.isNotEmpty)
          ready.length > 1
              ? strings.captureTasksAdded(ready.length)
              : day != null
              ? strings.taskAddedOn(context.weekdayDate(day))
              : due != null
              ? strings.taskAddedDue(context.weekdayDate(due))
              : strings.taskSavedInbox,
        if (applied.updates.isNotEmpty)
          moving != null
              ? moving.date == null
                    ? strings.movedInbox
                    : strings.movedOccurrenceDate(
                        context.weekdayDate(moving.date!),
                      )
              : strings.commandTasksChanged(applied.updates.length),
        if (applied.deleted.isNotEmpty)
          strings.commandTasksDeleted(applied.deleted.length),
      ];
      final message = remaining > 0
          ? '${parts.join(' · ')} · ${strings.captureKeptForReview(remaining)}'
          : parts.join(' · ');
      // One new project, with only its own new tasks and no changes: its
      // page opens, as making one by hand does, with the tasks lit.
      final project = applied.projects.length == 1 && applied.updates.isEmpty
          ? applied.projects.single
          : null;
      final opensProject =
          project != null &&
          written.drafts
              .where((draft) => readyIds.contains(draft.id))
              .every((draft) => draft.task.listId == project);
      MaterialPageRoute<void>? projectPage;
      CalendarFocus? focus;
      if (remaining == 0) {
        if (origin?.showCalendar == true) {
          navigator.popUntil((route) => route.isFirst);
        } else {
          Navigator.pop(context);
        }
        final ids = {
          for (final item in tasks)
            if (undoIds[item.id] != null) undoIds[item.id]!,
          for (final update in applied.updates) ?update.before.id,
        };
        if (opensProject) {
          projectPage = MaterialPageRoute<void>(
            builder: (_) =>
                HomeScreen(isRoot: false, listId: project, landing: ids),
          );
          unawaited(navigator.push(projectPage));
        } else if (ids.isNotEmpty) {
          focus = CalendarFocus(
            days.firstOrNull,
            ids,
            page: origin?.page,
            showCalendar: origin?.showCalendar ?? false,
            undated:
                tasks.any(
                  (item) =>
                      item.task.dueDate == null && item.task.deadline == null,
                ) ||
                landed.any((task) => task.displayDate == null),
          );
          container.read(calendarFocusProvider.notifier).state = focus;
        }
      }
      final feedback = showFeedback(
        messenger,
        message,
        margin: margin(),
        actionLabel: strings.undo,
        onAction: () async {
          if (mounted && _saving) return;
          if (mounted) setState(() => _saving = true);
          try {
            if (container.read(captureOwnerProvider) != before.ownerKey) {
              return;
            }
            await _writes;
            final changesBack = await runner.undoChanges(applied);
            // The tasks come out of the new projects before those go; the
            // result comes back as it was before the tap.
            final back = await _store.undoSave(
              written.copyWith(commands: before.commands),
              undoIds,
            );
            CaptureSession? restored;
            if (back != null) {
              restored = back.copyWith(
                drafts: [
                  for (final draft in back.drafts)
                    undoIds.containsKey(draft.id)
                        ? before.drafts.firstWhere((d) => d.id == draft.id)
                        : draft,
                ],
                commands: before.commands,
              );
              await _store.update(restored);
            }
            final projectsBack = await runner.takeBackProjects(
              applied,
              api: api,
              accountId: accountId,
            );
            if (applied.projects.isNotEmpty) {
              container.invalidate(taskListsProvider);
            }
            // The project is gone, so its page closes, with anything opened
            // from it; the result reopens over the screen underneath.
            final page = projectPage;
            if (projectsBack && page != null && page.isActive) {
              navigator.popUntil((route) => route == page);
              navigator.pop();
            }
            await container.read(taskProvider.notifier).showLocal();
            container.invalidate(pendingCapturesProvider);
            final whole = changesBack && projectsBack;
            if (whole && restored != null) narrowAfterUndo(container, focus);
            if (restored == null || !whole) {
              if (messenger.mounted) {
                unawaited(
                  showFeedback(
                    messenger,
                    restored == null
                        ? strings.reviewUndoChanged
                        : strings.undoError,
                    margin: margin(),
                  ),
                );
              }
              if (restored == null) return;
            }
            if (mounted) {
              setState(() {
                _session = restored!;
                _items = restored.drafts;
                _commands = restored.commands;
                _finished = false;
              });
              if (whole && messenger.mounted) {
                unawaited(
                  showFeedback(
                    messenger,
                    strings.reviewUndoSaved,
                    margin: margin(),
                  ),
                );
              }
            } else if (navigator.mounted &&
                container.read(captureOwnerProvider) == before.ownerKey) {
              // The sheet opens again on the restored result, as after a
              // save's Undo.
              unawaited(
                showCaptureSheet(
                  navigator.context,
                  captureId: restored.id,
                  startListening: false,
                  page: origin?.page,
                ),
              );
            }
          } catch (_) {
            if (messenger.mounted) {
              unawaited(
                showFeedback(messenger, strings.undoError, margin: margin()),
              );
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      );
      unawaited(feedback);
      // A deletion is sent once `Deshacer` is no longer offered.
      if (applied.deleted.isNotEmpty) {
        unawaited(
          feedback.then((controller) async {
            final reason = await controller?.closed;
            if (reason != SnackBarClosedReason.action && notifier.mounted) {
              unawaited(notifier.loadTasks());
            }
          }),
        );
      }
      if (remaining == 0 && ready.isNotEmpty) {
        askAboutRemindersAfterSave(
          context,
          ready.map((d) => d.task),
          feedback: feedback,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = CaptureProblem.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// `Volver a decirlo`: the edits are written first, so the result can come
  /// back as it was.
  Future<void> _sayAgain() async {
    // Said again, so not left pending.
    _finished = true;
    try {
      await _writes;
    } catch (_) {
      /* The edit's own error already shows. */
    }
    if (mounted) widget.onSayAgain?.call(_session);
  }

  /// `Guardar tal cual`: the words, not the commands, are what to keep.
  Future<void> _saveAsWritten() async {
    final save = widget.onSaveAsWritten;
    if (_saving || save == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _writes;
      _finished = true;
      await save(_session);
    } catch (_) {
      _finished = false;
      if (mounted) setState(() => _error = CaptureProblem.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Cancel, Back, a tap above the sheet and a swipe down: ask once whether
  /// to keep it, as while listening. With every card removed, it finishes as
  /// `Terminar` does. While saving, nothing happens.
  Future<void> _leave() async {
    if (_saving || _asking || !mounted) return;
    // Nothing waits (a search, a task not found): it only closes.
    if (!_worthKeeping()) {
      await _finishEmpty();
      return;
    }
    _asking = true;
    final keep = await _askToKeep(
      context,
      spoken: _session.source == 'speech' || _session.audioPath != null,
    );
    _asking = false;
    if (!mounted || keep == null || _saving) return;
    if (keep) {
      // The capture stays in the pending list.
      Navigator.pop(context);
    } else {
      await _discard();
    }
  }

  Future<void> _discard() async {
    try {
      // A failed edit doesn't keep it from being discarded.
      await _writes.catchError((Object _) {});
      await _store.discard(_session.id, _session.ownerKey);
      _finished = true;
      unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.discarded),
      );
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) setState(() => _error = CaptureProblem.discardFailed);
    }
  }

  /// `Cancelar` asks as Back does. `Volver a decirlo` (spoken words, while
  /// dictations are available) sits at the other end. They share a row, and
  /// stack at large text. With nothing to confirm (a search), [close]
  /// makes it `Cerrar`.
  Widget _exits(
    BuildContext context, {
    required bool canSayAgain,
    bool close = false,
  }) {
    final l = context.l10n;
    final cancel = TextButton(
      key: close ? const ValueKey('capture-result-close') : null,
      onPressed: _saving ? null : () => unawaited(Navigator.maybePop(context)),
      child: Text(close ? l.captureClose : l.cancel),
    );
    if (!canSayAgain) {
      return Align(alignment: AlignmentDirectional.centerStart, child: cancel);
    }
    final sayAgain = TextButton(
      onPressed: _saving ? null : () => unawaited(_sayAgain()),
      child: Text(l.captureSayAgain),
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 18) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancel, sayAgain],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: cancel),
        const SizedBox(width: 8),
        Flexible(child: sayAgain),
      ],
    );
  }

  Future<void> _finishEmpty() async {
    await _writes;
    await _store.discard(_session.id, _session.ownerKey);
    _finished = true;
    if (mounted) {
      ref.invalidate(pendingCapturesProvider);
      Navigator.pop(context);
    }
  }

  /// A command's card. A project's says how many tasks go there.
  Widget _commandCard(CommandView view, List<CaptureDraft> pending) {
    final command = view.command;
    void changed(CaptureCommand next) => unawaited(_changeCommand(next));
    void remove() => _removeCommand(command);
    final existing = command.existingId;
    return switch (view.kind) {
      CommandKind.project => ProjectCommandCard(
        key: ValueKey(command.id),
        view: view,
        enabled: !_saving,
        taskCount: pending
            .where(
              (draft) =>
                  (draft.newProject != null &&
                      _sameProject(draft.newProject!, command.name)) ||
                  (existing != null && draft.task.listId == existing),
            )
            .length,
        onChanged: changed,
        onRemove: remove,
      ),
      CommandKind.find => FindCommandCard(
        key: ValueKey(command.id),
        view: view,
      ),
      CommandKind.update => UpdateCommandCard(
        key: ValueKey(command.id),
        view: view,
        enabled: !_saving,
        onChanged: changed,
        onRemove: remove,
      ),
      CommandKind.delete => DeleteCommandCard(
        key: ValueKey(command.id),
        view: view,
        enabled: !_saving,
        onChanged: changed,
        onRemove: remove,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((d) => d.pending).toList();
    // Commands: one card each, the new projects before the tasks, and the
    // searches, changes and deletions after them, in the order said.
    final commands = _usesCommands;
    final views = commands ? _views(watch: true) : const <CommandView>[];
    final undecided = _undecided(views);
    final ready = pending.where((d) => _draftReady(d, undecided)).length;
    final cards = pending.length + views.length;
    final compact = commands ? cards > 1 : pending.length > 1;
    final actionable = views.where((view) => view.actionable).toList();
    final blocked =
        pending.any((d) => !_draftReady(d, undecided)) ||
        views.any((view) => view.blocking);
    final changes = actionable
        .where((view) => view.kind == CommandKind.update)
        .length;
    final deletes = actionable
        .where((view) => view.kind == CommandKind.delete)
        .length;
    final projects = actionable
        .where((view) => view.kind == CommandKind.project)
        .length;
    // Only things to read (a search, a task not found): nothing to tap.
    final readOnly =
        commands && cards > 0 && ready == 0 && actionable.isEmpty && !blocked;
    // New projects are named only when they are all the tap does: with a
    // deletion alone, the button names it and keeps the warning colour.
    final deleteOnly = commands && ready == 0 && changes == 0 && deletes > 0;
    // Every command found nothing («Cambia el aceite…» was a task): the
    // words can still become one.
    final asWritten =
        readOnly &&
        widget.onSaveAsWritten != null &&
        cards == views.length &&
        views.every(
          (view) =>
              view.notFound ||
              (view.kind == CommandKind.find && view.found.isEmpty),
        ) &&
        (_session.transcript.trim().isNotEmpty ||
            _session.text.trim().isNotEmpty);
    final l = context.l10n;
    final theme = Theme.of(context);
    final note =
        _session.kind == 'note' ||
        (_items.isNotEmpty && _items.every((d) => d.task.isNote));
    // "See what I said" and "Say it again" only fit words that were spoken.
    final spoken = _session.source == 'speech' || _session.audioPath != null;
    // Saying it again needs a dictation: with none left, Cancel stands alone.
    final sayAgain =
        spoken &&
        widget.onSayAgain != null &&
        ref.watch(voiceAvailableProvider);
    // With the keyboard up, only the button stays under the result.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Without Pro, a spoken result says how many free dictations are left,
    // once only a few are.
    final freeLeft = spoken ? ref.watch(freeVoiceLeftProvider) : null;
    final label = _saving
        ? l.saving
        : commands
        ? cards == 0
              ? l.captureFinish
              : ready == 0 && actionable.isEmpty
              ? l.captureCheckDetails
              : ready > 0 && changes > 0 && deletes > 0
              ? l.commandAddChangeAndDelete
              : ready > 0 && changes > 0
              ? l.commandAddAndChange
              : ready > 0 && deletes > 0
              ? l.commandAddAndDelete
              : ready > 0
              ? ready > 1 || pending.length > 1
                    ? l.captureAddTasks(ready)
                    : pending.single.task.dueDate != null
                    ? l.captureAddToCalendar
                    : l.captureAddTask
              : changes > 0 && deletes > 0
              ? l.commandChangeAndDelete
              : changes > 0
              ? changes == 1 &&
                        _onlyMoved(
                          actionable
                              .firstWhere(
                                (view) => view.kind == CommandKind.update,
                              )
                              .plan,
                        )
                    ? l.reschedule
                    : l.saveChangesSentence
              : deleteOnly
              ? l.delete
              : l.commandCreateProjects(projects)
        : pending.isEmpty
        ? l.captureFinish
        : ready == 0
        ? l.captureCheckDetails
        : note
        ? l.saveNote
        : compact
        ? l.captureAddTasks(ready)
        : pending.single.task.dueDate != null
        ? l.captureAddToCalendar
        : l.captureAddTask;
    final onSave = _saving
        ? null
        : commands
        ? cards == 0
              ? _finishEmpty
              : ready == 0 && actionable.isEmpty
              ? null
              : _save
        : pending.isEmpty
        ? _finishEmpty
        : ready == 0
        ? null
        : _save;
    // A heading only when everything here is something to add.
    final adding =
        compact &&
        views.every(
          (view) => view.kind == CommandKind.project && !view.command.existing,
        );
    Widget card(Widget child) => Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 0),
      child: child,
    );
    // A save closes the sheet itself; every other way out asks first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (adding)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  l.captureThingsToAdd(cards),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: MessageBanner(
                  captureProblemText(l, _error!),
                  isError: true,
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final view in views)
                      if (view.kind == CommandKind.project)
                        card(_commandCard(view, pending)),
                    for (final item in pending)
                      card(
                        CaptureReviewEditor(
                          key: ValueKey(item.id),
                          draft: item,
                          compact: compact,
                          expanded: _expandedId == item.id,
                          enabled: !_saving,
                          onExpand: () => setState(
                            () => _expandedId = _expandedId == item.id
                                ? null
                                : item.id,
                          ),
                          onChanged: (draft) => unawaited(_change(draft)),
                          onRemove: () => _remove(item),
                          onRenameProject: (from, to) =>
                              unawaited(_renameProject(from, to)),
                        ),
                      ),
                    for (final view in views)
                      if (view.kind != CommandKind.project)
                        card(_commandCard(view, pending)),
                    if (cards == 0)
                      EmptyState(
                        title: l.captureNothingToReview,
                        message: l.captureRemovedDraftsHelp,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              key: _actions,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A search needs no tap: it only shows its list.
                  if (!readOnly)
                    FilledButton.icon(
                      key: const ValueKey('save-drafts'),
                      // With every card removed, the button finishes
                      // instead.
                      onPressed: onSave,
                      style: deleteOnly
                          ? FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            )
                          : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              deleteOnly
                                  ? Icons.delete_outline_rounded
                                  : Icons.done_all_rounded,
                            ),
                      label: Text(label),
                    )
                  else if (asWritten)
                    FilledButton(
                      key: const ValueKey('result-save-as-written'),
                      onPressed: _saving
                          ? null
                          : () => unawaited(_saveAsWritten()),
                      child: Text(l.captureSaveAsWritten),
                    ),
                  if (!typing) ...[
                    if (freeLeft != null && freeLeft <= 3) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.freeVoiceLeft(freeLeft),
                        key: const ValueKey('free-voice-left'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: readOnly && !asWritten ? 0 : 12),
                    _exits(context, canSayAgain: sayAgain, close: readOnly),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(
                        spoken
                            ? Icons.graphic_eq_rounded
                            : Icons.short_text_rounded,
                        size: 20,
                      ),
                      title: Text(
                        spoken ? l.reviewOriginal : l.reviewOriginalText,
                        style: theme.textTheme.bodyMedium,
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        // Long words scroll here, so the button stays in view.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            child: SelectableText(_session.transcript),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
