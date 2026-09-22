import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/l10n/region.dart';

class CapturesScreen extends ConsumerWidget {
  const CapturesScreen({super.key});

  String _title(CaptureSession session) {
    if (session.remaining.isNotEmpty) return session.remaining.first.task.title;
    if (session.text.trim().isNotEmpty) return session.text.trim();
    if (session.transcript.trim().isNotEmpty) return session.transcript.trim();
    return 'Voice recording';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: const CustomAppBar(title: 'Unfinished captures'),
      body: ref.watch(pendingCapturesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: FilledButton(
                    onPressed: () => ref.invalidate(pendingCapturesProvider),
                    child: const Text('Retry loading captures'))),
            data: (sessions) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(pendingCapturesProvider);
                  await ref.read(pendingCapturesProvider.future);
                },
                child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (sessions.isEmpty)
                        const EmptyState(
                            title: 'All caught up',
                            message:
                                'Recordings and drafts you leave unfinished will be kept here.'),
                      for (final session in sessions)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppSurface(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(session.audioPath == null
                                      ? Icons.notes_rounded
                                      : Icons.mic_none_rounded),
                                  title: Text(_title(session),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${session.kind == 'note' ? context.l10n.note : context.l10n.tasks} · ${session.remaining.isNotEmpty ? '${session.remaining.length} drafts · ${session.ready.length} ready' : 'Kept on this phone · Tap to resume'}'),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => VoiceTaskScreen(
                                              captureId: session.id))),
                                ))),
                    ])),
          ));
}
