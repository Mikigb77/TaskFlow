import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:agenda/services/quick_schedule_parser.dart';
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
                  message: context.l10n.listEditingAccessHelp,
                ),
              );
            }
            return TaskEditor(key: ValueKey(taskId), task: task);
          }
          return Scaffold(
            appBar: CustomAppBar(title: context.l10n.editTask),
            body: EmptyState(
              title: context.l10n.taskUnavailable,
              message: context.l10n.taskRemoved,
            ),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
          appBar: CustomAppBar(title: context.l10n.editTask),
          body: EmptyState(
            title: context.l10n.loadTaskError,
            message: context.l10n.tryLater,
          ),
        ),
      );
}

/// What the `/newTask` route starts from.
class NewTaskArguments {
  const NewTaskArguments({
    this.day,
    this.projectId,
    this.person,
    this.page,
    this.showCalendar = false,
    this.words = '',
    this.readsDates = false,
    this.heardAt,
    this.captureId,
    this.askedToSpeak = false,
  });

  /// The day shown where the form was opened (Calendar's selected day, the
  /// timeline's): a later one is the new task's day, as for a capture (D9).
  final DateTime? day;

  /// The project the page adds to, when the user can add to it.
  final String? projectId;

  /// The person whose chip is on, on the shared project's page the form was
  /// opened from: a task going into [projectId] is theirs (D7).
  final ProjectMember? person;

  /// The task page that lands the new task instead of Calendar.
  final Object? page;

  /// Bring the Calendar tab forward once it is saved.
  final bool showCalendar;

  /// Words already heard, typed or shared: the title, and the notes for
  /// whatever follows its first sentence.
  final String words;

  /// [words] were dictated before `Escribir` (D2), or shared from another
  /// app (D3, 2026-10-20): the form reads their day and time once, as it
  /// opens, as `Guardar como tarea` does. Words typed stay as written.
  final bool readsDates;

  /// When [words] were heard or shared: the day they name counts from it.
  final DateTime? heardAt;

  /// The capture that holds [words]. The form keeps its title and notes
  /// there until the task is saved.
  final String? captureId;

  /// Opened by a way in that asks to speak (the widget, the voice
  /// shortcut): without the mic, the form says why.
  final bool askedToSpeak;

  /// Nothing to start from: no day, project, person, words or capture. The
  /// widget and the shortcuts open the form so (UX-2642).
  bool get blank =>
      day == null &&
      projectId == null &&
      person == null &&
      captureId == null &&
      words.isEmpty;
}

/// The route of the task form for a new task (`/newTask`). It knows whether
/// the form on it is still empty, so a second tap on the widget or a
/// shortcut opens no second form over it (UX-2110).
class NewTaskRoute extends MaterialPageRoute<void> {
  NewTaskRoute({required super.builder, super.settings});

  // The forms on screen.
  static final _open = <NewTaskRoute>{};

  /// No title typed in its form yet. The form keeps this from its first
  /// build on; until then it is empty.
  bool empty = true;

  @override
  void install() {
    super.install();
    _open.add(this);
  }

  @override
  void dispose() {
    _open.remove(this);
    super.dispose();
  }
}

/// Which form a widget or shortcut entry opens waits on top of [navigator],
/// still empty: its [NewTaskArguments.askedToSpeak] when the route on top is
/// a new task's form with nothing in its title, opened [NewTaskArguments.blank]
/// as an entry opens it; null otherwise. A form with a day, a project, a
/// person, words or a capture is never an entry's (UX-2110, UX-2642).
bool? emptyEntryFormOnTop(NavigatorState navigator) {
  for (final route in NewTaskRoute._open) {
    if (route.navigator != navigator || !route.isCurrent || !route.empty) {
      continue;
    }
    final arguments =
        route.settings.arguments as NewTaskArguments? ??
        const NewTaskArguments();
    return arguments.blank ? arguments.askedToSpeak : null;
  }
  return null;
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
    final now = ref.read(calendarClockProvider)();
    final today = Task.day(now);
    final shown = arguments.day == null ? null : Task.day(arguments.day!);
    // Today, or a day gone by, adds nothing.
    final later = shown != null && shown.isAfter(today) ? shown : null;
    // As Calendar's project choice does for a capture.
    final scoped = ref.read(projectScopeProvider).projectId;
    // Dictated or shared words name their day and time, as `Guardar como
    // tarea` reads them; an hour with no a. m. or p. m. stays in the title.
    final read = arguments.readsDates
        ? QuickScheduleParser.parse(
            arguments.words,
            arguments.heardAt ?? now,
            day: later,
            keepAmbiguousHour: true,
          )
        : null;
    // A day read from the words that has already gone by adds nothing either.
    final found = read != null && Task.day(read.date).isBefore(today)
        ? null
        : read;
    final deadline = found != null && found.isDeadline;
    final listId =
        arguments.projectId ??
        (ref.read(listCanEditProvider(scoped)) ? scoped : null);
    // Opened under a person's chip: the task is theirs, one tap to change.
    final person = listId != null && listId == arguments.projectId
        ? arguments.person
        : null;
    final lead = leadingTitle(
      found == null || found.title.isEmpty ? arguments.words : found.title,
      taskTitleLength,
    );
    return Task(
      title: lead.title.isEmpty
          ? ''
          : lead.title[0].toUpperCase() + lead.title.substring(1),
      notes: lead.rest.isEmpty ? null : lead.rest,
      priority: 1,
      dueDate: found == null
          ? later
          : deadline
          ? null
          : found.date,
      hasTime: found != null && !deadline && found.hasTime,
      deadline: deadline ? found.date : null,
      deadlineHasTime: deadline && found.hasTime,
      reminderAnchor: deadline ? 'deadline' : 'planned',
      listId: listId,
      assignment: person == null ? 'personal' : 'member',
      assigneeId: person?.id,
      assigneeName: person?.name,
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
