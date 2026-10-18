import 'dart:async';

import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/screens/voice_task_screen.dart';

/// The one way to add a task: `Añadir tarea` opens the capture sheet,
/// listening with Pro or free dictations left, and typing without them.
/// Once an account without Pro has used this month's free dictations it
/// reads `Escribir tarea`, and its first tap that month says why, once. Its
/// space is reserved so it never covers the agenda.
class TaskActions extends ConsumerStatefulWidget {
  const TaskActions({super.key, this.projectId, this.page, this.day});

  /// The project a new task goes to, when the user can add to it.
  final String? projectId;

  /// A task page that shows what capture saves, instead of Calendar.
  final Object? page;

  /// The day shown: Calendar's selected day or the timeline's.
  final DateTime? day;

  @override
  ConsumerState<TaskActions> createState() => _TaskActionsState();
}

class _TaskActionsState extends ConsumerState<TaskActions> {
  // A tap is finding out whether the used-up notice shows.
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, ask once whether speech works on the phone, so
    // the first capture listens without waiting for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_warm()));
  }

  Future<void> _warm() async {
    if (!mounted || !ref.read(voiceAvailableProvider)) return;
    try {
      await ref.read(regionalProvider.notifier).ready;
    } catch (_) {
      /* Voz's choice falls back to the app's language. */
    }
    if (!mounted) return;
    ref
        .read(nativeSpeechProvider)
        .warm(captureSpeechLanguage(context, ref.read(regionalProvider)));
  }

  Future<void> _add() async {
    if (_deciding) return;
    final free = ref.read(authProvider).account?.freeVoice;
    if (ref.read(freeVoiceUsedUpProvider) && free != null) {
      final resets = ref.read(freeVoiceResetsProvider);
      _deciding = true;
      final bool notice;
      try {
        notice = await ref.read(freeVoiceNoticeProvider.notifier).claim(resets);
      } finally {
        _deciding = false;
      }
      if (!mounted) return;
      if (notice) {
        final write = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => _UsedUpNotice(limit: free.limit, resets: resets),
        );
        if (!mounted || write == null) return;
        if (!write) {
          // `Ver Pro`, as the capture sheet's opens it.
          unawaited(Navigator.pushNamed(context, '/subscription'));
          return;
        }
      }
    }
    unawaited(
      showCaptureSheet(
        context,
        projectId: widget.projectId,
        page: widget.page,
        day: widget.day,
      ),
    );
  }

  /// `Añadir tarea` with the mic, or + when it types; `Escribir tarea` with
  /// a pencil once this month's free dictations are used up.
  Widget _button(BuildContext context) {
    final writes = ref.watch(freeVoiceUsedUpProvider);
    // Read from the phone now, so the tap doesn't wait for it.
    if (writes) ref.watch(freeVoiceNoticeProvider);
    return FilledButton.icon(
      onPressed: () => unawaited(_add()),
      icon: Icon(
        writes
            ? Icons.edit_outlined
            : ref.watch(voiceAvailableProvider)
            ? Icons.mic_none_rounded
            : Icons.add_rounded,
      ),
      label: Text(writes ? context.l10n.writeTask : context.l10n.addTask),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ref
            .watch(pendingCapturesProvider)
            .when(
              data: (sessions) => sessions.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/captures'),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(
                        context.l10n.pendingCaptureCount(sessions.length),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => TextButton(
                onPressed: () => Navigator.pushNamed(context, '/captures'),
                child: Text(context.l10n.checkCaptures),
              ),
            ),
        SizedBox(width: double.infinity, child: _button(context)),
      ],
    ),
  );
}

/// Free dictations used up: typing has no limit, and dictations come back
/// on [resets]. Pops true for `Escribir una tarea`, false for `Ver Pro`.
class _UsedUpNotice extends StatelessWidget {
  const _UsedUpNotice({required this.limit, required this.resets});
  final int limit;
  final DateTime resets;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('free-voice-notice'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Read out by TalkBack as the sheet opens; its own node, so the
          // line under it isn't read as part of the heading.
          Semantics(
            container: true,
            header: true,
            liveRegion: true,
            child: Text(
              l.freeVoiceNoticeTitle(limit),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          // Read after the heading, not before it.
          Semantics(
            container: true,
            child: Text(
              l.freeVoiceNoticeBody(limit, context.shortDate(resets.toLocal())),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.freeVoiceNoticeWrite, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.voiceProAction, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
