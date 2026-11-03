import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';

/// Whether [note] offers «Crear tarea»: a note with steps still open, as a
/// meeting's note has its to-dos (MN-22).
bool noteMakesTask(Task note) =>
    note.isNote && note.checklist.any((step) => !step.done());

/// «Crear tarea» (MN-22): the capture's review, with one task titled like
/// [note] and its open steps as the checklist, so the person can drop the
/// ones they don't want and set a day before saving. Nothing is saved
/// until they confirm there. Leaving the review asks, as for any capture,
/// whether to keep it in `Sin guardar` or discard it.
Future<void> createTaskFromNote(BuildContext context, Task note) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final store = container.read(captureStoreProvider);
  final owner = container.read(captureOwnerProvider);
  final projectId =
      note.listId != null && container.read(listCanEditProvider(note.listId))
      ? note.listId
      : null;
  try {
    await container.read(regionalProvider.notifier).ready;
  } catch (_) {
    /* The account's zone then. */
  }
  final session = await store.create(
    owner,
    _zone(container),
    text: note.title,
    projectId: projectId,
    source: 'typed',
  );
  final drafts = [
    CaptureDraft(
      id: const Uuid().v4(),
      task: Task(
        title: note.title,
        priority: 1,
        listId: projectId,
        checklist: [
          for (final step in note.checklist)
            if (!step.done()) ChecklistItem(title: step.title),
        ],
      ),
    ),
  ];
  await store.update(
    session.copyWith(
      status: 'ready',
      // The review's «Texto original»: the note, to look back at.
      transcript: note.notes?.trim().isNotEmpty == true
          ? note.notes
          : note.title,
      drafts: drafts,
    ),
  );
  container.invalidate(pendingCapturesProvider);
  if (!context.mounted) return;
  await showCaptureSheet(
    context,
    captureId: session.id,
    startListening: false,
    useScope: false,
  );
}

/// The capture's zone, as the task form picks it: the one chosen in
/// Ajustes, then the account's, then UTC.
String _zone(ProviderContainer container) {
  final chosen = container.read(regionalProvider).captureTimezone;
  if (CaptureTimezone.valid(chosen)) return chosen!;
  final account = container.read(authProvider).account?.timezone;
  return CaptureTimezone.valid(account) ? account! : 'UTC';
}
