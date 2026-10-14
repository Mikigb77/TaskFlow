import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/l10n/region.dart';

class CapturesScreen extends ConsumerWidget {
  const CapturesScreen({super.key});

  String _title(BuildContext context, CaptureSession session) {
    if (session.remaining.isNotEmpty) return session.remaining.first.task.title;
    if (session.text.trim().isNotEmpty) return session.text.trim();
    if (session.transcript.trim().isNotEmpty) return session.transcript.trim();
    return context.l10n.voiceRecording;
  }

  /// What happens next. A recording that waits for free dictations says
  /// when it can be understood.
  String _help(BuildContext context, WidgetRef ref, CaptureSession session) {
    final l = context.l10n;
    if (session.remaining.isNotEmpty) {
      return l.captureDraftSummary(session.remaining.length);
    }
    if (session.audioPath != null &&
        session.text.trim().isEmpty &&
        !ref.watch(voiceAvailableProvider) &&
        (CaptureProblem.usedUp(session.error) ||
            ref.watch(freeVoiceLeftProvider) == 0)) {
      return freeVoiceUsedUpText(l, ref.watch(freeVoiceResetsProvider),
          recording: true);
    }
    return l.captureResumeHelp;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: CustomAppBar(title: context.l10n.unfinishedCaptures),
      body: ref.watch(pendingCapturesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: FilledButton(
                    onPressed: () => ref.invalidate(pendingCapturesProvider),
                    child: Text(context.l10n.tryAgain))),
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
                        EmptyState(
                            title: context.l10n.capturesCaughtUp,
                            message: context.l10n.capturesEmptyHelp),
                      for (final session in sessions)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppSurface(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(session.audioPath == null
                                      ? Icons.notes_rounded
                                      : Icons.mic_none_rounded),
                                  title: Text(_title(context, session),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${session.kind == 'note' ? context.l10n.note : context.l10n.tasks} · ${_help(context, ref, session)}'),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  // Saved tasks land back on Calendar.
                                  onTap: () => showCaptureSheet(context,
                                      captureId: session.id,
                                      startListening: false,
                                      showCalendar: true),
                                ))),
                    ])),
          ));
}
