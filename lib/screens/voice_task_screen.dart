import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/create_task_screen.dart';

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
  String? _path;
  bool _recording = false;
  bool _busy = false;
  String? _error;

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
      setState(() => _recording = true);
      _timer = Timer(const Duration(seconds: 59), _toggleRecording);
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
      final result = await ref
          .read(apiClientProvider)
          .request('POST', 'ai/draft/', audioPath: path, data: {
        'timezone': _zone.text.trim(),
        'reference_time': DateTime.now().toUtc().toIso8601String(),
        if (path == null) 'text': _words.text.trim()
      });
      final draft =
          TaskDraft.fromJson(Map<String, dynamic>.from(result as Map));
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => CreateTaskScreen(initialDraft: draft)));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      await _cleanup();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create with your voice')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('What do you need to do?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              '“On Friday at 5 p.m. I have a doctor appointment. Remind me to bring my blood test results.”'),
          const SizedBox(height: 24),
          Center(
              child: FilledButton.icon(
                  onPressed: _busy ? null : _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic, size: 32),
                  label: Text(
                      _recording ? 'Stop & create draft' : 'Record a task'))),
          const SizedBox(height: 12),
          Text(
              _recording
                  ? 'Listening… up to 60 seconds.'
                  : 'Audio is sent to Google for transcription. Review the draft before saving.',
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          TextField(
              controller: _words,
              enabled: !_recording && !_busy,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(
                  labelText: 'Or type your plan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder())),
          TextField(
              controller: _zone,
              enabled: !_recording && !_busy,
              decoration: const InputDecoration(labelText: 'Time zone')),
          const SizedBox(height: 20),
          OutlinedButton(
              onPressed: _recording || _busy ? null : () => _createDraft(),
              child: const Text('Create draft from text')),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.amber)),
        ]),
      );
}
