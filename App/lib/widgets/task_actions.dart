import 'dart:async';

import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/widgets/task_form_entry.dart';

/// The one way to add a task: `Añadir tarea` opens the capture sheet,
/// listening with Pro or free dictations left. Without either it reads
/// `Nueva tarea` and opens the task form: free text makes tasks only with
/// Pro (DECISIONS.md, 2026-10-18 later). Once this month's free dictations
/// are used up, its first tap that month says why, once. Its space is
/// reserved so it never covers the agenda.
class TaskActions extends ConsumerStatefulWidget {
  const TaskActions({
    super.key,
    this.projectId,
    this.person,
    this.page,
    this.day,
  });

  /// The project a new task goes to, when the user can add to it.
  final String? projectId;

  /// The person whose chip is on, on a shared project's page: a new task
  /// there is theirs (D7).
  final ProjectMember? person;

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
    if (ref.read(opensFormProvider)) {
      _deciding = true;
      try {
        await openTaskForm(
          context,
          projectId: widget.projectId,
          person: widget.person,
          day: widget.day,
          page: widget.page,
        );
      } finally {
        _deciding = false;
      }
      return;
    }
    unawaited(
      showCaptureSheet(
        context,
        projectId: widget.projectId,
        person: widget.person,
        page: widget.page,
        day: widget.day,
      ),
    );
  }

  /// `Añadir tarea` with the mic, or + when it types while billing finds
  /// out; `Nueva tarea` with + when it opens the form.
  Widget _button(BuildContext context) {
    final form = ref.watch(opensFormProvider);
    // Read from the phone now, so the tap doesn't wait for it.
    if (form && ref.watch(freeVoiceUsedUpProvider)) {
      ref.watch(freeVoiceNoticeProvider);
    }
    return FilledButton.icon(
      onPressed: () => unawaited(_add()),
      icon: Icon(
        !form && ref.watch(voiceAvailableProvider)
            ? Icons.mic_none_rounded
            : Icons.add_rounded,
      ),
      label: Text(form ? context.l10n.newTask : context.l10n.addTask),
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
