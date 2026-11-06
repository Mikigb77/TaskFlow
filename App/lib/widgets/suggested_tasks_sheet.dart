import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/widgets/note_task.dart';

/// Whether a meeting's [task] starts ticked in «Tareas sugeridas»: said as
/// a to-do (not only floated), and for the person themselves («yo», «I»,
/// their own first name) or nobody named. A task for someone else starts unticked (the owner, 2026-11-06),
/// [firstName] being the account's.
bool suggestedTaskTicked(MeetingTask? task, String firstName) {
  if (task == null) return true;
  if (!task.sure) return false;
  final who = task.who?.trim().toLowerCase();
  if (who == null || who.isEmpty || meetingSpeakerWords.hasMatch(who)) {
    return true;
  }
  final me = firstName.trim().toLowerCase();
  return me.isNotEmpty && who.contains(me);
}

/// «Tareas sugeridas» (the owner, 2026-11-06): [lines], a meeting note's
/// open lines that made no task yet, as a list with a box each, the clear
/// to-dos ticked. «Añadir (n)» makes the ticked ones at once, each with its
/// steps and the day its words say; «Añadir todas» makes every one. A
/// line's pencil opens it in the review, to change its day or steps first
/// (PR #23's cards). Leaving adds nothing: the note keeps every line.
Future<void> showSuggestedTasks(
  BuildContext context,
  Task note, {
  required List<ChecklistItem> lines,
}) async {
  if (lines.isEmpty || note.id == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  MeetingNoteTasks? tasks;
  try {
    tasks = await MeetingNoteMarks.tasks(
      container.read(meetingNoteMarksDatabaseProvider),
      container.read(captureOwnerProvider),
      note.id!,
    );
  } catch (_) {
    /* Each line, ticked, without steps. */
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => SuggestedTasksSheet(note: note, lines: lines, tasks: tasks),
  );
}

class SuggestedTasksSheet extends ConsumerStatefulWidget {
  const SuggestedTasksSheet({
    super.key,
    required this.note,
    required this.lines,
    this.tasks,
  });
  final Task note;
  final List<ChecklistItem> lines;
  final MeetingNoteTasks? tasks;

  @override
  ConsumerState<SuggestedTasksSheet> createState() =>
      _SuggestedTasksSheetState();
}

class _SuggestedTasksSheetState extends ConsumerState<SuggestedTasksSheet> {
  late final Set<String> _ticked = {
    for (final line in widget.lines)
      if (suggestedTaskTicked(
        widget.tasks?.tasks[line.id],
        ref.read(authProvider).account?.firstName ?? '',
      ))
        line.id,
  };
  bool _saving = false;

  Future<void> _add(Set<String> ids) async {
    if (_saving || ids.isEmpty) return;
    setState(() => _saving = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(navigator.context);
    final strings = context.l10n;
    final note = widget.note;
    final lines = widget.lines.where((line) => ids.contains(line.id)).toList();
    try {
      final made = await saveNoteLines(container, note, lines, widget.tasks);
      if (!mounted) return;
      navigator.pop();
      final tasks = container.read(taskProvider).value ?? const <Task>[];
      final saved = [
        for (final id in made.values)
          ?tasks.where((task) => task.id == id).firstOrNull,
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.captureTasksAdded(made.length)),
          action: saved.isEmpty
              ? null
              : SnackBarAction(
                  label: strings.meetingViewTask(saved.length),
                  onPressed: () {
                    final shown = navigator.context;
                    if (shown.mounted) showNoteTasks(shown, saved);
                  },
                ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.meetingSuggestedFailed)),
      );
    }
  }

  void _review(ChecklistItem line) {
    final navigator = Navigator.of(context);
    navigator.pop();
    final shown = navigator.context;
    if (shown.mounted) {
      createTaskFromNote(shown, widget.note, lines: [line]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = {for (final line in widget.lines) line.id};
    final allTicked = _ticked.length == all.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Text(
            l10n.meetingSuggestedTitle,
            style: theme.textTheme.titleLarge,
            semanticsLabel: l10n.meetingSuggestedTitle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            l10n.meetingSuggestedHelp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final line in widget.lines)
                _row(context, line, widget.tasks?.tasks[line.id]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!allTicked && all.length > 1)
                OutlinedButton(
                  key: const ValueKey('suggested-add-all'),
                  onPressed: _saving ? null : () => _add(all),
                  child: Text(l10n.meetingSuggestedAddAll(all.length)),
                ),
              FilledButton(
                key: const ValueKey('suggested-add'),
                onPressed: _saving || _ticked.isEmpty
                    ? null
                    : () => _add({..._ticked}),
                child: Text(l10n.meetingSuggestedAdd(_ticked.length)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ChecklistItem line, MeetingTask? task) {
    final l10n = context.l10n;
    final details = [
      if (task != null && !task.sure) l10n.meetingSuggestedMaybe,
      if (task != null && task.steps.isNotEmpty)
        l10n.reviewStepCount(task.steps.length),
    ].join(' · ');
    return CheckboxListTile(
      key: ValueKey('suggested-${line.id}'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      value: _ticked.contains(line.id),
      onChanged: _saving
          ? null
          : (on) => setState(() {
              if (on ?? false) {
                _ticked.add(line.id);
              } else {
                _ticked.remove(line.id);
              }
            }),
      title: Text(line.title),
      subtitle: details.isEmpty ? null : Text(details),
      secondary: IconButton(
        tooltip: l10n.meetingSuggestedReview,
        icon: const Icon(Icons.edit_outlined),
        onPressed: _saving ? null : () => _review(line),
      ),
    );
  }
}

/// Makes [lines] of meeting note [note] into tasks at once, as the review
/// would with every card kept: each with its [tasks] steps (still to do) and
/// the day its words say, read against the meeting's. Returns the task each
/// line made, by line id, and links them to the note.
Future<Map<String, int>> saveNoteLines(
  ProviderContainer container,
  Task note,
  List<ChecklistItem> lines,
  MeetingNoteTasks? tasks,
) async {
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
    noteCaptureZone(container),
    text: note.title,
    projectId: projectId,
    source: 'note',
  );
  final lineOf = <String, String>{};
  final drafts = <CaptureDraft>[];
  for (final line in lines) {
    final made = noteLineTask(
      line,
      tasks?.tasks[line.id],
      day: tasks?.day,
      projectId: projectId,
    );
    final id = const Uuid().v4();
    lineOf[id] = line.id;
    drafts.add(
      CaptureDraft(
        id: id,
        task: made.copyWith(
          // Every step goes in, still to do.
          checklist: [
            for (final step in made.checklist)
              ChecklistItem(id: step.id, title: step.title),
          ],
        ),
      ),
    );
  }
  await store.update(session.copyWith(status: 'ready', drafts: drafts));
  final saved = await store.saveReady(
    session.id,
    owner,
    drafts.map((draft) => draft.id).toSet(),
  );
  final made = {
    for (final draft in saved.drafts)
      if ((lineOf[draft.id], draft.savedTaskId) case (final line?, final task?))
        line: task,
  };
  await container.read(taskProvider.notifier).showLocal();
  if (made.isNotEmpty && note.id != null) {
    await container.read(noteTaskLinksProvider).link(owner, note.id!, made);
    container.invalidate(noteTasksProvider);
  }
  return made;
}
