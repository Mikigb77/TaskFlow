import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

class VoiceTaskScreen extends ConsumerStatefulWidget {
  const VoiceTaskScreen({super.key});
  @override
  ConsumerState<VoiceTaskScreen> createState() => _VoiceTaskScreenState();
}

class _VoiceTaskScreenState extends ConsumerState<VoiceTaskScreen>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _words = TextEditingController();
  final _zone = TextEditingController();
  Timer? _timer;
  int _seconds = 0;
  String? _path;
  bool _recording = false;
  bool _busy = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (ModalRoute.of(context)?.settings.arguments == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _toggleRecording();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zone.text = ref.read(authProvider).account?.timezone ?? 'Europe/Madrid';
    _localTimezone();
  }

  Future<void> _localTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      if (mounted) _zone.text = zone.identifier;
    } catch (_) {/* Profile zone remains editable. */}
  }

  Future<void> _cleanup() async {
    final path = _path;
    _path = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {/* Already removed. */}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_recording && state != AppLifecycleState.resumed) _cancelRecording();
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _recording = false;
    try {
      await _recorder.cancel();
    } catch (_) {/* Recording may already have stopped on suspension. */}
    await _cleanup();
    if (mounted) {
      setState(() {
        _recording = false;
        _error =
            'Recording stopped when you left the app. Tap the microphone to start again.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(
        _recorder.dispose().catchError((Object _) {}).whenComplete(_cleanup));
    _words.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _timer?.cancel();
      setState(() {
        _recording = false;
        _busy = true;
      });
      try {
        final path = await _recorder.stop();
        if (mounted && path != null) await _createDraft(path: path);
      } catch (error) {
        if (mounted) {
          setState(() =>
              _error = 'Could not finish the recording. Please try again.');
        }
      } finally {
        await _cleanup();
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (!await _recorder.hasPermission()) {
        throw Exception(
            'Microphone permission is needed to record. You can type your task below.');
      }
      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      _path =
          '${directory.path}/taskflow-${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: _path!);
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _seconds = timer.tick);
        if (timer.tick >= 59) _toggleRecording();
      });
    } catch (error) {
      await _cleanup();
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDraft({String? path}) async {
    if (path == null && _words.text.trim().isEmpty) {
      setState(() => _error = 'Describe a task first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiClientProvider).request(
          'POST', 'ai/drafts/',
          audioPath: path,
          authenticated: ref.read(authProvider).account != null,
          data: {
            'timezone': _zone.text.trim(),
            'reference_time': DateTime.now().toUtc().toIso8601String(),
            if (path == null) 'text': _words.text.trim()
          });
      final response = Map<String, dynamic>.from(result as Map);
      final drafts = (response['tasks'] as List)
          .map((data) => TaskDraft.fromJson({
                ...Map<String, dynamic>.from(data as Map),
                'transcript': response['transcript']
              }))
          .toList();
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => ReviewTasksScreen(
                  drafts: drafts,
                  transcript: response['transcript'] as String)));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      await _cleanup();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const CustomAppBar(title: 'Voice capture'),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
                  children: [
                    const SectionLabel('From a thought to a plan'),
                    Text('Just say the word.',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                        'One thought or several. Dates and times are optional.',
                        style: TextStyle(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 28),
                    AppSurface(
                        child: Column(children: [
                      const SizedBox(height: 4),
                      Semantics(
                          button: true,
                          label: _recording
                              ? 'Stop and create draft'
                              : 'Record tasks',
                          child: Tooltip(
                              message: _recording
                                  ? 'Stop recording'
                                  : 'Record tasks',
                              child: Material(
                                color: _recording
                                    ? colors.errorContainer
                                    : colors.primaryContainer,
                                shape: const CircleBorder(),
                                child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _busy ? null : _toggleRecording,
                                    child: SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Icon(
                                            _recording
                                                ? Icons.stop_rounded
                                                : Icons.mic_none_rounded,
                                            size: 42,
                                            color: _recording
                                                ? colors.onErrorContainer
                                                : colors.primary))),
                              ))),
                      const SizedBox(height: 20),
                      Text(
                          _busy
                              ? 'Putting your plan together…'
                              : _recording
                                  ? 'Listening · 00:${_seconds.toString().padLeft(2, '0')}'
                                  : 'Tap to capture your tasks',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                          _recording
                              ? 'Tap again when you’re finished.'
                              : 'Up to 12 tasks in 60 seconds. Review everything\nbefore saving to Calendar or Inbox.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 13)),
                      if (_busy)
                        const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: LinearProgressIndicator()),
                      const SizedBox(height: 8),
                    ])),
                    const SizedBox(height: 16),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                            '“Doctor on Friday at 5 p.m. Bring my results.\nAlso buy coffee and water the plants every Sunday.”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.7,
                                fontStyle: FontStyle.italic))),
                    const SizedBox(height: 28),
                    const SectionLabel('Prefer to type?'),
                    TextField(
                        controller: _words,
                        enabled: !_recording && !_busy,
                        maxLines: 4,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                            labelText: 'Or type your plan',
                            hintText: 'Pick up groceries tomorrow at 6 p.m.…',
                            alignLabelWithHint: true,
                            counterText: '')),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed:
                            _recording || _busy ? null : () => _createDraft(),
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('Review tasks from text')),
                    if (ref.watch(authProvider).account == null)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                              'Try voice without an account. A small daily allowance is shared by devices on this connection.')),
                    const SizedBox(height: 16),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: const Icon(Icons.public_outlined, size: 20),
                        title: const Text('Time zone'),
                        subtitle: Text(_zone.text,
                            style: TextStyle(
                                fontSize: 12, color: colors.onSurfaceVariant)),
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextField(
                                  controller: _zone,
                                  enabled: !_recording && !_busy,
                                  decoration: const InputDecoration(
                                      labelText: 'Time zone'))),
                        ]),
                    const SizedBox(height: 12),
                    Text(
                        'Your words are sent to Google to create drafts. TaskFlow deletes its recording after processing.',
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant),
                        textAlign: TextAlign.center),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      MessageBanner(_error!, isError: true)
                    ],
                  ]))),
    );
  }
}
