import 'dart:async';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the task form for a new task: how an account without Pro creates
/// tasks once there is no mic, or from the capture sheet's `Escribir`. The
/// first time in a month that its free dictations are used up, a notice
/// says why first, once; it offers the form and Pro. [words] are words
/// already heard, typed or shared, for the title and notes; [spoken] marks
/// words dictated, heard at [heardAt], whose day and time the form reads;
/// [captureId] is the capture that keeps them until the task is saved.
/// [askedToSpeak]
/// marks the ways in that ask to speak (the widget, the voice shortcut):
/// without the mic, the form says why. The form's route is pushed, not
/// awaited.
Future<void> openTaskForm(
  BuildContext context, {
  String? projectId,
  DateTime? day,
  Object? page,
  bool showCalendar = false,
  String words = '',
  bool spoken = false,
  DateTime? heardAt,
  String? captureId,
  bool askedToSpeak = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final free = container.read(authProvider).account?.freeVoice;
  if (container.read(freeVoiceUsedUpProvider) && free != null) {
    final resets = container.read(freeVoiceResetsProvider);
    final notice = await container
        .read(freeVoiceNoticeProvider.notifier)
        .claim(resets);
    if (!context.mounted) return;
    if (notice) {
      final create = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _UsedUpNotice(limit: free.limit, resets: resets),
      );
      if (!context.mounted || create == null) return;
      if (!create) {
        // `Ver Pro`, as the capture sheet's opens it.
        unawaited(Navigator.pushNamed(context, '/subscription'));
        return;
      }
    }
  }
  if (!context.mounted) return;
  unawaited(
    Navigator.pushNamed(
      context,
      '/newTask',
      arguments: NewTaskArguments(
        day: day,
        projectId: projectId,
        page: page,
        showCalendar: showCalendar,
        words: words,
        spoken: spoken,
        heardAt: heardAt,
        captureId: captureId,
        askedToSpeak: askedToSpeak,
      ),
    ),
  );
}

/// Free dictations used up: the form has no limit, and dictations come back
/// on [resets]. Pops true for `Crear una tarea`, false for `Ver Pro`.
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
            child: Text(l.freeVoiceNoticeCreate, textAlign: TextAlign.center),
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
