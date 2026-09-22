import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
import 'package:agenda/widgets/custom_app_bar.dart';

class VoiceTaskScreen extends ConsumerStatefulWidget {
  const VoiceTaskScreen(
      {super.key, this.captureId, this.startRecording = false});
  final String? captureId;
  final bool startRecording;
  @override
  ConsumerState<VoiceTaskScreen> createState() => _VoiceTaskScreenState();
}

class _VoiceTaskScreenState extends ConsumerState<VoiceTaskScreen>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _words = TextEditingController();
  late final CaptureStore _store;
  late final String _owner;
  CaptureSession? _session;
  String _zone = 'UTC';
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitude;
  Future<void> _writes = Future.value();
  Future<void>? _starting;
  Future<void>? _stopping;
  bool _recording = false;
  bool _busy = true;
  bool _initialized = false;
  bool _autoStart = false;
  bool _autoStarted = false;
  int _seconds = 0;
  double _level = 0;
  String? _error;
  late final NativeSpeech _speech;
  SpeechCapability _capability = const SpeechCapability();
  StreamSubscription<SpeechEvent>? _speechEvents;
  Completer<void>? _speechEnded;
  bool _nativeMode = false;
  bool _usingNative = false;
  bool _acceptSpeech = false;
  bool _holdToTalk = false;
  bool _holding = false;
  bool _holdSession = false;
  bool _probing = false;
  String? _language;
  String _nativePrefix = '';
  int _nativeRun = DateTime.now().millisecondsSinceEpoch % 2000000000;

  @override
  void initState() {
    super.initState();
    _store = ref.read(captureStoreProvider);
    _speech = ref.read(nativeSpeechProvider);
    _owner = ref.read(captureOwnerProvider);
    _zone = ref.read(authProvider).account?.timezone ?? 'UTC';
    WidgetsBinding.instance.addObserver(this);
    CaptureInterruption.active = _interruptCapture;
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autoStart = widget.startRecording ||
        ModalRoute.of(context)?.settings.arguments == true;
    _tryAutoStart();
  }

  Future<void> _load() async {
    try {
      _capability = await _speech.capability();
      _nativeMode = _capability.usable;
      try {
        _zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {/* Account or UTC fallback. */}
      await _store.cleanFinished(_owner);
      if (widget.captureId != null) {
        _session = await _store.read(widget.captureId!, _owner);
        if (_session == null || _session!.terminal) {
          throw StateError('This capture is no longer available.');
        }
        if (!mounted) return;
        _zone = _session!.timezone;
        _words.text = _session!.text;
        await CaptureDiagnostics(_store.database).record(CaptureEvent.resumed);
        if (_session!.drafts.isNotEmpty && mounted) {
          _review(_session!);
          return;
        }
        _error = _session!.error;
      }
    } catch (error) {
      _error = error.toString();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _initialized = true;
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _beginRecording();
      }
    });
  }

  Future<void> _ensureSession({bool audio = false, String text = ''}) async {
    if (_session != null) return;
    _session = await _store.create(_owner, _zone, text: text, audio: audio);
    await CaptureDiagnostics(_store.database).record(CaptureEvent.started);
    if (mounted) ref.invalidate(pendingCapturesProvider);
  }

  void _changedText(String text) {
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (text.trim().isEmpty && _session == null) return;
      await _ensureSession(text: text);
      _session = _session!
          .copyWith(text: text, status: _recording ? 'recording' : 'editing');
      await _store.update(_session!);
    });
    unawaited(_writes.catchError((Object error) {
      if (mounted) {
        setState(() => _error =
            'Could not keep this draft on your phone. ${error.toString()}');
      }
    }));
  }

  void _beginRecording() {
    if (_busy || _recording) return;
    _starting = _startRecording();
  }

  Future<void> _chooseLanguage(String? language) async {
    setState(() => _probing = true);
    final capability = await _speech.capability(language: language);
    if (!mounted) return;
    setState(() {
      _language = language;
      _capability = capability;
      _nativeMode = capability.usable;
      _probing = false;
    });
  }

  void _receiveSpeech(SpeechEvent event) {
    if (!_acceptSpeech || event.run != _nativeRun) return;
    if (event.text?.trim().isNotEmpty == true) {
      final words = [_nativePrefix, event.text!.trim()]
          .where((s) => s.isNotEmpty)
          .join(' ');
      final bounded = words.length > 4000 ? words.substring(0, 4000) : words;
      if (mounted) {
        _words.text = bounded;
        _words.selection = TextSelection.collapsed(offset: bounded.length);
      }
      _changedText(bounded);
    }
    if (event.level != null && mounted && _recording) {
      setState(() => _level = event.level!.clamp(0, 1));
    }
    if (event.error != null && mounted) setState(() => _error = event.error);
    if (event.terminal) {
      if (_speechEnded?.isCompleted == false) _speechEnded!.complete();
      // Automatic endpointing retains editable words. Only an explicit stop /
      // review action sends them for online extraction.
      if (_recording) unawaited(_finishRecording(submit: false));
    }
  }

  void _armTimer() {
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds = timer.tick);
      if (timer.tick >= 59) unawaited(_finishRecording(submit: false));
    });
  }

  Future<void> _startRecording() async {
    _holdSession = _holding;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writes;
      _usingNative = _nativeMode && _capability.usable;
      if (!_usingNative && _words.text.trim().isNotEmpty) {
        throw StateError(
            'Save or discard this typed capture before starting a recording.');
      }
      if (!await (_usingNative
          ? _speech.permission()
          : _recorder.hasPermission())) {
        throw StateError('Allow microphone access to record, or type below.');
      }
      if (!mounted) return;
      if (_session?.audioPath != null) {
        throw StateError(
            'Retry this recording or discard it before recording another.');
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
        _speechEvents ??=
            _speech.events.listen(_receiveSpeech, onError: (Object _) {
          _receiveSpeech(SpeechEvent(_nativeRun, 'error',
              error: 'Speech stopped. Your retained words are safe.'));
        });
        _recording = true;
        await _speech.start(_nativeRun, _capability.language);
        if (_recording) _armTimer();
        if (!mounted ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed ||
            (_holdSession && !_holding)) {
          await _finishRecording(submit: false);
        }
        return;
      }
      await _ensureSession(audio: true);
      if (_session!.audioPath == null) {
        _session =
            _session!.copyWith(audioPath: await _store.audioPathFor(_session!));
      }
      _session = _session!.copyWith(status: 'recording');
      await _store.update(_session!);
      if (!mounted) return;
      await _recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: _session!.audioPath!);
      _recording = true;
      _armTimer();
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          (_holdSession && !_holding)) {
        await _finishRecording(submit: false);
        return;
      }
      _amplitude = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((value) {
        if (mounted && _recording) {
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
        } catch (_) {/* Preserve the transcript. */}
      }
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishRecording({bool submit = true}) =>
      _stopping ??= _stopRecording(submit).whenComplete(() => _stopping = null);

  Future<void> _stopRecording(bool submit) async {
    if (!_recording) return;
    _recording = false;
    _timer?.cancel();
    await _amplitude?.cancel();
    if (mounted) {
      setState(() {
        _busy = true;
        _level = 0;
      });
    }
    try {
      if (_usingNative) {
        await _speech.stop(_nativeRun);
        await _speechEnded?.future
            .timeout(const Duration(seconds: 2), onTimeout: () {});
        _acceptSpeech = false;
        await _speech.cancel(_nativeRun);
        await _writes;
      } else {
        await _recorder.stop();
      }
      if (_session != null) {
        _session = _session!.copyWith(status: 'editing');
        await _store.update(_session!);
        await CaptureDiagnostics(_store.database)
            .record(CaptureEvent.recordingStopped, elapsedMs: _seconds * 1000);
      }
      if (mounted &&
          submit &&
          (!_usingNative || _session!.text.trim().isNotEmpty)) {
        await _process();
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = 'Your retained input is kept. ${error.toString()}');
      }
    } finally {
      _acceptSpeech = false;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_recording && state != AppLifecycleState.resumed) {
      unawaited(_finishRecording(submit: false));
    }
  }

  Future<void> _process() async {
    final api = ref.read(apiClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writes;
      if (_session == null && _words.text.trim().isEmpty) {
        throw StateError('Say or type what you need to do first.');
      }
      await _ensureSession(text: _words.text);
      final session = await CaptureProcessor(_store, api).process(_session!);
      _session = session;
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        _review(session);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            '${error.toString()}\nYour capture is kept on this phone.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _review(CaptureSession session) => Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
          builder: (_) => ReviewTasksScreen(session: session)));

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Discard this capture?'),
                content: const Text(
                    'The recording and unsaved drafts will be removed. Tasks already saved will stay.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Discard'))
                ]));
    if (confirmed != true) return;
    try {
      await _writes;
      if (_session != null) await _store.discard(_session!.id, _owner);
      if (mounted) {
        ref.invalidate(pendingCapturesProvider);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not discard this capture. It is still kept.');
      }
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
    super.dispose();
  }

  Future<void> _interruptCapture() async {
    await _writes;
    await _starting;
    await _finishRecording(submit: false);
  }

  Future<void> _release() async {
    try {
      await _writes;
      await _starting;
      await _finishRecording(submit: false);
      _acceptSpeech = false;
      await _speechEvents?.cancel();
      await _recorder.dispose();
    } catch (_) {/* The durable capture remains available on next launch. */}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recorded = _session?.audioPath != null;
    return Scaffold(
        appBar: const CustomAppBar(title: 'Capture a thought'),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    children: [
                      Text('What’s on your mind?',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                          'One task or several. Say it naturally, or type your plan.',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      AppSurface(
                          child: Column(children: [
                        GestureDetector(
                            onLongPressStart: _holdToTalk && !_busy && !recorded
                                ? (_) {
                                    _holding = true;
                                    _beginRecording();
                                  }
                                : null,
                            onLongPressEnd: _holdToTalk
                                ? (_) {
                                    _holding = false;
                                    unawaited(_finishRecording());
                                  }
                                : null,
                            onLongPressCancel: _holdToTalk
                                ? () {
                                    _holding = false;
                                    unawaited(_finishRecording(submit: false));
                                  }
                                : null,
                            child: Semantics(
                                button: true,
                                label: _recording
                                    ? 'Stop and create draft'
                                    : 'Record tasks',
                                child: IconButton.filledTonal(
                                    key: const ValueKey('capture-mic'),
                                    iconSize: 44,
                                    padding: const EdgeInsets.all(24),
                                    // Tooltip's long-press recognizer would consume
                                    // the hold gesture before the parent sees it.
                                    tooltip: _holdToTalk
                                        ? null
                                        : _recording
                                            ? 'Stop recording'
                                            : 'Record tasks',
                                    onPressed:
                                        _busy || (recorded && !_recording)
                                            ? null
                                            : () {
                                                if (_recording) {
                                                  unawaited(_finishRecording());
                                                } else {
                                                  _beginRecording();
                                                }
                                              },
                                    icon: Icon(_recording
                                        ? Icons.stop_rounded
                                        : Icons.mic_none_rounded)))),
                        const SizedBox(height: 16),
                        Text(
                            _recording
                                ? 'Listening · 00:${_seconds.toString().padLeft(2, '0')}'
                                : _busy
                                    ? 'Putting your plan together…'
                                    : recorded
                                        ? 'Recording kept on this phone'
                                        : 'Tap to speak',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        if (_recording)
                          LinearProgressIndicator(
                              value: _level,
                              semanticsLabel: 'Microphone input level'),
                        if (_busy) const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                            _recording
                                ? 'Tap stop when you’re finished. Up to 60 seconds.'
                                : _nativeMode
                                    ? 'On-device speech · ${_capability.language}. Words appear below and are kept as you speak.'
                                    : 'You can leave and return. Unfinished recordings are kept.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant)),
                      ])),
                      if (!recorded && !_recording && !_busy) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Speech options'),
                            subtitle: Text(_nativeMode
                                ? 'On-device live transcript'
                                : 'Saved audio · online transcription'),
                            children: [
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                if (_capability.usable)
                                  ChoiceChip(
                                      label: const Text('Live transcript'),
                                      selected: _nativeMode,
                                      onSelected: (_) =>
                                          setState(() => _nativeMode = true)),
                                ChoiceChip(
                                    label: const Text('Saved audio'),
                                    selected: !_nativeMode,
                                    onSelected: (_) =>
                                        setState(() => _nativeMode = false)),
                                PopupMenuButton<String>(
                                    tooltip: 'Speech language',
                                    enabled: !_probing,
                                    onSelected: (value) => _chooseLanguage(
                                        value == 'device' ? null : value),
                                    itemBuilder: (_) => [
                                          for (final entry in {
                                            'device': 'Device language',
                                            'en-US': 'English',
                                            'es-ES': 'Español'
                                          }.entries)
                                            CheckedPopupMenuItem(
                                                value: entry.key,
                                                checked:
                                                    (_language ?? 'device') ==
                                                        entry.key,
                                                child: Text(entry.value)),
                                        ],
                                    child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('Speech language'))),
                              ]),
                              if (!_capability.usable)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                        'On-device speech is unavailable for this language on this device. Record audio for online processing, or type.')),
                              if (_capability.onDevice && !_capability.usable)
                                Wrap(spacing: 8, children: [
                                  TextButton(
                                      onPressed: () async {
                                        try {
                                          final opened =
                                              await _speech.prepareLanguage(
                                                  _capability.language);
                                          if (mounted) {
                                            setState(() => _error = opened
                                                ? 'Speech setup was requested. Follow any Android prompt, then tap Check again. You can keep typing meanwhile.'
                                                : 'Speech setup is unavailable here. Use saved audio or type.');
                                          }
                                        } catch (_) {
                                          if (mounted) {
                                            setState(() => _error =
                                                'Could not open speech setup. Use saved audio or type.');
                                          }
                                        }
                                      },
                                      child: const Text(
                                          'Set up on-device speech')),
                                  TextButton(
                                      onPressed: _probing
                                          ? null
                                          : () => _chooseLanguage(_language),
                                      child: const Text('Check again')),
                                ]),
                              SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Hold to talk'),
                                  subtitle: const Text(
                                      'Hold the mic, then release. Tapping still works.'),
                                  value: _holdToTalk,
                                  onChanged: (value) =>
                                      setState(() => _holdToTalk = value)),
                            ]),
                      ],
                      if (!recorded) ...[
                        const SizedBox(height: 24),
                        TextField(
                            controller: _words,
                            readOnly: _busy || _recording,
                            onChanged: _changedText,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 4000,
                            decoration: InputDecoration(
                                labelText: _usingNative && _recording
                                    ? 'Live transcript'
                                    : 'Or type your plan',
                                hintText:
                                    'Doctor Friday at 5 p.m. Bring my results. Also buy coffee.',
                                counterText: '')),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: _busy || _recording ? null : _process,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(recorded
                              ? 'Try this recording'
                              : 'Review tasks from text')),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: MessageBanner(_error!, isError: true)),
                      if (_session != null)
                        TextButton(
                            onPressed: _busy || _recording ? null : _discard,
                            child: const Text('Discard capture')),
                      const SizedBox(height: 16),
                      if (ref.watch(authProvider).account == null)
                        const Text(
                            'Try voice without an account. A small daily allowance is shared by devices on this connection.'),
                      const SizedBox(height: 12),
                      Text(
                          'Live transcription uses on-device speech where available; no audio is retained in that mode. AI task extraction still needs the internet and sends your words to Google. Saved audio is transcribed online. Unfinished input stays on this phone until you save or discard it.',
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                    ]))));
  }
}
