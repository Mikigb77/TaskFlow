import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';

class EditTaskScreen extends ConsumerWidget {
  const EditTaskScreen({super.key, required this.taskId});
  final int taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(taskProvider)
      .when(
        data: (tasks) {
          final task = tasks.firstWhereOrNull((task) => task.id == taskId);
          if (task != null) {
            if (!ref.watch(listCanEditProvider(task.listId))) {
              return Scaffold(
                  appBar: CustomAppBar(title: context.l10n.viewOnlyTaskTitle),
                  body: EmptyState(
                      title: context.l10n.readOnlyList,
                      message: context.l10n.listEditingAccessHelp));
            }
            return TaskEditor(key: ValueKey(taskId), task: task);
          }
          return Scaffold(
              appBar: CustomAppBar(title: context.l10n.editTask),
              body: EmptyState(
                  title: context.l10n.taskUnavailable,
                  message: context.l10n.taskRemoved));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
            appBar: CustomAppBar(title: context.l10n.editTask),
            body: EmptyState(
                title: context.l10n.loadTaskError,
                message: context.l10n.tryLater)),
      );
}

/// What the `/newTask` route starts from.
class NewTaskArguments {
  const NewTaskArguments({
    this.day,
    this.projectId,
    this.page,
    this.showCalendar = false,
    this.words = '',
    this.captureId,
    this.askedToSpeak = false,
  });

  /// The day shown where the form was opened (Calendar's selected day, the
  /// timeline's): a later one is the new task's day, as for a capture (D9).
  final DateTime? day;

  /// The project the page adds to, when the user can add to it.
  final String? projectId;

  /// The task page that lands the new task instead of Calendar.
  final Object? page;

  /// Bring the Calendar tab forward once it is saved.
  final bool showCalendar;

  /// Words already heard, typed or shared: the title, and the notes for
  /// whatever follows its first sentence.
  final String words;

  /// The capture that holds [words]. The form keeps its title and notes
  /// there until the task is saved.
  final String? captureId;

  /// Opened by a way in that asks to speak (the widget, the voice
  /// shortcut): without the mic, the form says why.
  final bool askedToSpeak;
}

/// The task form in create mode, for accounts without Pro: free text makes
/// no tasks for them, the form does (DECISIONS.md, 2026-10-18 later).
class NewTaskScreen extends ConsumerStatefulWidget {
  const NewTaskScreen({super.key, this.arguments = const NewTaskArguments()});
  final NewTaskArguments arguments;
  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  late final Task _task = _start();

  Task _start() {
    final arguments = widget.arguments;
    final today = Task.day(ref.read(calendarClockProvider)());
    final shown = arguments.day == null ? null : Task.day(arguments.day!);
    // As Calendar's project choice does for a capture.
    final scoped = ref.read(projectScopeProvider).projectId;
    final lead = leadingTitle(arguments.words, taskTitleLength);
    return Task(
      title: lead.title.isEmpty
          ? ''
          : lead.title[0].toUpperCase() + lead.title.substring(1),
      notes: lead.rest.isEmpty ? null : lead.rest,
      priority: 1,
      // Today, or a day gone by, adds nothing.
      dueDate: shown != null && shown.isAfter(today) ? shown : null,
      hasTime: false,
      listId:
          arguments.projectId ??
          (ref.read(listCanEditProvider(scoped)) ? scoped : null),
    );
  }

  @override
  Widget build(BuildContext context) => TaskEditor(
    task: _task,
    page: widget.arguments.page,
    showCalendar: widget.arguments.showCalendar,
    captureId: widget.arguments.captureId,
    askedToSpeak: widget.arguments.askedToSpeak,
  );
}
