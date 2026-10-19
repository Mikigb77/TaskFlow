import 'dart:async';

import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/task_matcher.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/widgets/schedule_editor.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A command as its card shows it: what it found on the phone, and what the
/// confirming tap would do. Worked out again on every build, from the tasks
/// the phone has now.
class CommandView {
  const CommandView(
    this.command, {
    this.found = const [],
    this.matches = const [],
    this.target,
    this.stored,
    this.plan,
    this.viewOnly,
    this.asks = false,
  });
  final CaptureCommand command;

  /// `project`: two projects match the name said, or the one that matches
  /// has another name. The card asks whether to create it.
  final bool asks;

  /// `find`: the results: soonest first with a period, else newest first.
  final List<Task> found;

  /// `update` and `delete`: the tasks the words may mean.
  final List<Task> matches;

  /// The one meant, as shown (a repeating task's repetition): the only
  /// match, or the one tapped among several.
  final Task? target;

  /// [target] as stored: a repeating task's whole series.
  final Task? stored;

  /// `update`: what would change.
  final UpdatePlan? plan;

  /// `update` and `delete`, when nothing the person can edit matches: the
  /// first task that would, in a project they can only view.
  final Task? viewOnly;

  CommandKind get kind => command.kind;

  /// `project`: it asks, and nothing was tapped yet.
  bool get asking => asks && command.choice == null;

  /// Several tasks match and none was tapped yet.
  bool get choosing => target == null && matches.length > 1;

  /// The task to change or delete isn't on the phone.
  bool get notFound =>
      (kind == CommandKind.update || kind == CommandKind.delete) &&
      target == null &&
      !choosing;

  /// The confirming tap does something for it.
  bool get actionable => switch (kind) {
    CommandKind.project =>
      !command.existing &&
          (!asks || command.choice == CaptureCommand.createChoice),
    CommandKind.update => plan?.ready == true,
    CommandKind.delete => stored != null,
    CommandKind.find => false,
  };

  /// It waits for a tap on its card before the confirming tap can do it.
  bool get blocking => switch (kind) {
    CommandKind.project => asking,
    CommandKind.update =>
      choosing || plan?.needsDay == true || plan?.asksMember == true,
    CommandKind.delete => choosing,
    CommandKind.find => false,
  };

  /// A new project's name, as the person will see it.
  String get projectName => spokenProjectName(command.name);
}

/// Works out [command] against the phone's [tasks] and [projects].
CommandView resolveCommand(
  CaptureCommand command, {
  required List<Task> tasks,
  required List<TaskListInfo> projects,
  int? accountId,
}) {
  switch (command.kind) {
    case CommandKind.project:
      // A project matched under another name («Física y Química» for
      // «Química»): the person may have meant a new one.
      final matched = projects
          .where((p) => p.id == command.existingListId)
          .firstOrNull;
      return CommandView(
        command,
        asks:
            command.ambiguous ||
            (matched != null &&
                _fold(matched.name) != _fold(spokenProjectName(command.name))),
      );
    case CommandKind.find:
      return CommandView(
        command,
        found: TaskMatcher.find(
          tasks,
          command,
          accountId: accountId,
          projects: projects,
        ),
      );
    case CommandKind.update:
    case CommandKind.delete:
      bool canEdit(String? id) =>
          id == null || projects.any((p) => p.id == id && p.canEdit);
      final matches = TaskMatcher.targets(
        tasks,
        command.target,
        canEdit: canEdit,
      );
      // None to edit: the same search among all, for the line saying why.
      final viewOnly = matches.isNotEmpty
          ? null
          : TaskMatcher.targets(
              tasks,
              command.target,
              canEdit: (_) => true,
            ).where((task) => !canEdit(task.listId)).firstOrNull;
      final chosen = command.taskId == null
          ? null
          : matches.where((task) => task.id == command.taskId).firstOrNull;
      final target = chosen ?? (matches.length == 1 ? matches.single : null);
      final stored = target == null
          ? null
          : tasks.where((task) => task.id == target.id).firstOrNull;
      final plan = command.kind == CommandKind.update && stored != null
          ? planUpdate(
              task: stored,
              shown: target!,
              changes: command.changes,
              issues: command.issues,
              project: projects.where((p) => p.id == stored.listId).firstOrNull,
              accountId: accountId,
              day: command.day,
              member: command.memberId,
            )
          : null;
      return CommandView(
        command,
        matches: matches,
        target: stored == null ? null : target,
        stored: stored,
        plan: plan,
        viewOnly: viewOnly,
      );
  }
}

String _fold(String text) => foldForSearch(text).trim();

/// The projects like [name], in their order: those it starts, that start
/// it, or that contain it.
List<TaskListInfo> _similar(String name, List<TaskListInfo> projects) {
  final said = _fold(name);
  bool like(TaskListInfo project) {
    final own = _fold(project.name);
    return said.length >= 3 &&
        (own.startsWith(said) || said.startsWith(own) || own.contains(said));
  }

  return projects.where(like).toList();
}

/// The projects a task can go to: those the person can edit, not archived.
List<TaskListInfo> editableProjects(List<TaskListInfo> projects) =>
    projects.where((p) => p.canEdit && !p.inactive).toList();

/// A question of a dictation's result, in its tinted box, with the chips
/// that answer it.
class QuestionBox extends StatelessWidget {
  const QuestionBox({super.key, required this.question, required this.child});
  final String question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: theme.textTheme.bodyMedium),
            child,
          ],
        ),
      ),
    );
  }
}

/// One tap each: create the project said, take one like it ([first], the
/// one matched, before them), another from the project sheet, or, with
/// [onNone], none.
class ProjectChoices extends ConsumerWidget {
  const ProjectChoices({
    super.key,
    required this.name,
    required this.projects,
    required this.onCreate,
    required this.onPick,
    this.first,
    this.onNone,
    this.enabled = true,
  });
  final String name;

  /// Those the person can edit.
  final List<TaskListInfo> projects;
  final TaskListInfo? first;
  final VoidCallback onCreate;
  final ValueChanged<TaskListInfo> onPick;
  final VoidCallback? onNone;
  final bool enabled;

  /// Projects shown as chips; the rest are in the sheet.
  static const similar = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    Widget label(String text) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
    final shown = [
      ?first,
      ..._similar(name, projects).where((p) => p.id != first?.id),
    ].take(similar).toList();
    final more = projects.any((p) => !shown.any((s) => s.id == p.id));
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ActionChip(
          key: const ValueKey('project-choice-create'),
          avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: label(l.commandCreateNamed(name)),
          onPressed: enabled ? onCreate : null,
        ),
        for (final project in shown)
          ActionChip(
            key: ValueKey('project-choice-${project.id}'),
            avatar: Icon(
              Icons.folder_outlined,
              size: 18,
              color: taskListColor(project.color),
            ),
            label: label(project.name),
            onPressed: enabled ? () => onPick(project) : null,
          ),
        if (more)
          ActionChip(
            key: const ValueKey('project-choice-other'),
            avatar: const Icon(Icons.folder_open_outlined, size: 18),
            label: label(l.commandOtherProject),
            onPressed: !enabled
                ? null
                : () async {
                    final choice = await chooseTaskList(
                      context,
                      ref,
                      none: onNone != null,
                      selectedNone: false,
                    );
                    if (choice == null) return;
                    if (choice.project case final project?) {
                      onPick(project);
                    } else {
                      onNone?.call();
                    }
                  },
          ),
        if (onNone != null)
          ActionChip(
            key: const ValueKey('project-choice-none'),
            avatar: const Icon(Icons.folder_off_outlined, size: 18),
            label: label(l.noList),
            onPressed: enabled ? onNone : null,
          ),
      ],
    );
  }
}

/// The frame of a command's card, like a task's in a result of several. A
/// [destructive] card (a deletion) has the error colour's edge.
class _Frame extends StatelessWidget {
  const _Frame({required this.children, this.destructive = false});
  final List<Widget> children;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: destructive ? colors.error : colors.outlineVariant,
          width: destructive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// A card's first line: what it is about, with ✕ when it can be taken out.
class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.text,
    this.color,
    this.onRemove,
    this.removeLabel,
    this.enabled = true,
  });
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ExcludeSemantics(child: Icon(icon, size: 22, color: tint)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: removeLabel,
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded, size: 18),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}

/// A quieter line under a card's first: what was found, or why not.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 34, right: 8, bottom: 4),
      child: icon == null
          ? Text(text, style: style)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(text, style: style)),
              ],
            ),
    );
  }
}

/// A day and maybe a time: `Hoy · 17:00`, `mié, 21 oct`, `Sin fecha`.
String scheduleText(BuildContext context, Schedule schedule, {String? none}) {
  final date = schedule.date;
  if (date == null) return none ?? context.l10n.noDate;
  final day = context.dayLabel(date);
  return schedule.hasTime ? '$day · ${context.clockTime(date)}' : day;
}

String _words(List<String> words) => words.join(' ');

/// `project`: «Nuevo proyecto: Física», or «Ya tienes «Matemáticas»», or,
/// when two projects match, the choice between creating it and taking one.
class ProjectCommandCard extends ConsumerWidget {
  const ProjectCommandCard({
    super.key,
    required this.view,
    required this.taskCount,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
  });
  final CommandView view;

  /// How many tasks of the same dictation go to this project.
  final int taskCount;
  final ValueChanged<CaptureCommand> onChanged;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final command = view.command;
    final projects = ref.watch(taskListsProvider).valueOrNull ?? const [];
    final name = view.projectName;
    if (command.existing && !view.asking) {
      final id = command.existingId;
      final project = projects.where((p) => p.id == id).firstOrNull;
      return _Frame(
        children: [
          _Header(
            icon: Icons.folder_outlined,
            text: l.commandExistingProject(project?.name ?? name),
          ),
          if (taskCount > 0) _Note(l.commandExistingProjectTasks(taskCount)),
        ],
      );
    }
    if (view.asking) {
      return _Frame(
        children: [
          _Header(
            icon: Icons.create_new_folder_outlined,
            text: l.commandCreateProjectQuestion(name),
            onRemove: onRemove,
            removeLabel: l.commandDontCreate(name),
            enabled: enabled,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, right: 8, bottom: 4),
            child: ProjectChoices(
              name: name,
              projects: editableProjects(projects),
              first: editableProjects(
                projects,
              ).where((p) => p.id == command.existingListId).firstOrNull,
              enabled: enabled,
              onCreate: () => onChanged(
                command.copyWith(choice: CaptureCommand.createChoice),
              ),
              onPick: (project) =>
                  onChanged(command.copyWith(choice: project.id)),
            ),
          ),
        ],
      );
    }
    return _Frame(
      children: [
        _Header(
          icon: Icons.create_new_folder_outlined,
          text: l.commandNewProject(name),
          onRemove: onRemove,
          removeLabel: l.commandDontCreate(name),
          enabled: enabled,
        ),
      ],
    );
  }
}

/// `find`: the tasks found, in `TaskMatcher.find`'s order, completed ones
/// marked, each with its project and assignee. A tap opens the task. No
/// sentence answers.
class FindCommandCard extends ConsumerWidget {
  const FindCommandCard({super.key, required this.view});
  final CommandView view;

  /// Enough to scan in the sheet; the rest are counted.
  static const shown = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final command = view.command;
    final projects = ref.watch(taskListsProvider).valueOrNull ?? const [];
    final accountId = ref.watch(authProvider).account?.id;
    final project = projects.where((p) => p.id == command.listId).firstOrNull;
    final person = command.personId == null
        ? null
        : projects
              .expand((p) => p.people)
              .where((p) => p.id == command.personId)
              .firstOrNull;
    final mine = command.personId != null && command.personId == accountId;
    final heading = command.words.isNotEmpty
        ? l.commandFindWords(_words(command.words))
        : project != null && mine
        ? l.commandFindProjectMine(project.name)
        : project != null && person != null
        ? l.commandFindProjectPerson(project.name, person.name)
        : project != null
        ? l.commandFindProject(project.name)
        : mine
        ? l.commandFindMine
        : person != null
        ? l.commandFindPerson(person.name)
        : l.tasks;
    final unresolved =
        command.projectName != null || command.personName != null;
    final found = view.found;
    final scope = _findScope(context, command);
    return _Frame(
      children: [
        _Header(icon: Icons.search_rounded, text: heading),
        if (scope != null) _Note(scope),
        if (command.projectName != null)
          _Note(
            l.commandProjectNotFound(command.projectName!),
            icon: Icons.info_outline,
          ),
        if (command.personName != null)
          _Note(
            l.commandPersonNotFound(command.personName!),
            icon: Icons.info_outline,
          ),
        if (!unresolved && found.isEmpty)
          _Note(
            command.words.isEmpty
                ? l.commandFindNoneAtAll
                : l.commandFindNone(_words(command.words)),
          ),
        for (final task in found.take(shown)) _FoundRow(task: task),
        if (found.length > shown) _Note(l.commandMore(found.length - shown)),
        if (project != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(left: 22),
              child: TextButton.icon(
                key: const ValueKey('find-open-project'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => HomeScreen(
                      isRoot: false,
                      listId: project.id,
                      person: command.personId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(l.commandOpenProject(project.name)),
              ),
            ),
          ),
      ],
    );
  }
}

/// The period and the status a search used, under its heading: «Mañana»,
/// «Del lun, 19 oct al dom, 25 oct · Pendientes». Null when it used neither.
String? _findScope(BuildContext context, CaptureCommand command) {
  final l = context.l10n;
  final from = command.from;
  final to = command.to;
  final parts = [
    if (from != null && to != null)
      DateUtils.isSameDay(from, to)
          ? context.dayLabel(from)
          : l.commandFindPeriod(
              context.weekdayDate(from),
              context.weekdayDate(to),
            ),
    if (command.status == 'open') l.commandFindOpen,
    if (command.status == 'completed') l.commandFindDone,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// A task found: its title, then its day, project and assignee. A tap opens
/// its details, over the result.
class _FoundRow extends ConsumerWidget {
  const _FoundRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final projects = ref.watch(taskListsProvider).valueOrNull ?? const [];
    final project = projects.where((p) => p.id == task.listId).firstOrNull;
    final shown = task.isRecurring ? task.nextOpenOccurrence() : task;
    final completed = shown == null || shown.isCompleted;
    final day = shown ?? task;
    final details = [
      if (day.displayDate != null)
        taskDayLine(context, day)
      else if (task.deadline != null)
        taskDeadlineLabel(context, task),
      ?project?.name,
      if (project?.shared == true)
        responsibilityLabel(context, task, ref.watch(authProvider).account?.id),
      if (completed) l.commandCompleted,
    ];
    return InkWell(
      key: ValueKey('found-${task.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/taskDetails'),
          builder: (_) => TaskDetailScreen(
            taskId: task.id!,
            occurrenceDate: shown?.occurrenceDate,
            occurrenceKey: shown?.occurrenceKey,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: completed ? colors.onSurfaceVariant : null,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            ExcludeSemantics(
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Completed, as a found row says: the repetition shown, or the task (a
/// repeating one when none is left open).
bool _completed(Task task) => task.occurrenceDate != null
    ? task.isCompleted
    : (task.isRecurring ? task.nextOpenOccurrence() : task)?.isCompleted ??
          true;

/// Several tasks match: a short list to tap the one meant, and the rest
/// after «Ver N más».
class _Choice extends StatefulWidget {
  const _Choice({
    required this.view,
    required this.onChanged,
    required this.enabled,
  });
  final CommandView view;
  final ValueChanged<CaptureCommand> onChanged;
  final bool enabled;

  static const shown = 5;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final view = widget.view;
    final enabled = widget.enabled;
    final onChanged = widget.onChanged;
    final matches = view.matches;
    final more = _all ? 0 : matches.length - _Choice.shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final task in more > 0 ? matches.take(_Choice.shown) : matches)
          InkWell(
            key: ValueKey('choose-${view.command.id}-${task.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: enabled
                ? () => onChanged(view.command.copyWith(taskId: task.id))
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: theme.textTheme.bodyLarge),
                  Text(
                    [
                      task.displayDate == null && task.deadline != null
                          ? taskDeadlineLabel(context, task)
                          : taskDayLine(context, task),
                      if (_completed(task)) l.commandCompleted,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (more > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(left: 22),
              child: TextButton(
                key: ValueKey('choose-more-${view.command.id}'),
                onPressed: enabled ? () => setState(() => _all = true) : null,
                child: Text(l.commandShowMore(more)),
              ),
            ),
          ),
      ],
    );
  }
}

/// «Elegir otra», after one of several was tapped.
Widget _another(
  BuildContext context,
  CommandView view,
  ValueChanged<CaptureCommand> onChanged,
  bool enabled,
) => Align(
  alignment: AlignmentDirectional.centerStart,
  child: Padding(
    padding: const EdgeInsets.only(left: 22),
    child: TextButton(
      onPressed: enabled
          ? () => onChanged(view.command.copyWith(clearTaskId: true))
          : null,
      child: Text(context.l10n.commandChooseAnother),
    ),
  ),
);

/// Why the task wasn't found: a project that doesn't exist, a task in a
/// project the person can only view, or the words.
String _notFound(BuildContext context, CommandView view) {
  final l = context.l10n;
  final target = view.command.target;
  if (view.viewOnly case final task?) return l.commandViewOnly(task.title);
  if (target.projectName != null) {
    return l.commandProjectNotFound(target.projectName!);
  }
  return target.words.isEmpty
      ? l.commandTaskNotFoundPlain
      : l.commandTaskNotFound(_words(target.words));
}

/// «¿Qué día, a las 17:00?»: [time] as the app shows times, with the
/// article its hour as shown takes (`a la 1:00`).
String _whichDay(BuildContext context, ({int hour, int minute}) time) {
  final clock = TimeOfDay(hour: time.hour, minute: time.minute);
  final format = MaterialLocalizations.of(context).timeOfDayFormat(
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final hour = hourFormat(of: format) == HourFormat.h
      ? clock.hourOfPeriod
      : clock.hour;
  return context.l10n.commandWhichDay(
    hour,
    context.clockTime(DateTime(2000, 1, 1, time.hour, time.minute)),
  );
}

/// `update`: the task with each change as before → after, or the short list
/// to choose it from, or that it wasn't found.
class UpdateCommandCard extends ConsumerWidget {
  const UpdateCommandCard({
    super.key,
    required this.view,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
  });
  final CommandView view;
  final ValueChanged<CaptureCommand> onChanged;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final command = view.command;
    if (view.notFound) {
      return _Frame(
        children: [
          _Header(icon: Icons.edit_outlined, text: _notFound(context, view)),
        ],
      );
    }
    if (view.choosing) {
      return _Frame(
        children: [
          _Header(
            icon: Icons.edit_outlined,
            text: l.commandWhichToChange,
            onRemove: onRemove,
            removeLabel: l.commandDontChange(_words(command.target.words)),
            enabled: enabled,
          ),
          _Choice(view: view, onChanged: onChanged, enabled: enabled),
        ],
      );
    }
    final plan = view.plan!;
    final task = plan.task;
    final shown = plan.shown;
    final accountId = ref.watch(authProvider).account?.id;
    Widget line(IconData icon, String label, String before, String after) =>
        Semantics(
          label: l.commandChangeSemantics(label, before, after),
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(left: 34, right: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                Expanded(
                  child: Text(
                    '$before → $after',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        );
    final current = (date: shown.displayDate, hasTime: shown.hasTime);
    final deadline = (
      date: shown.displayDeadline ?? task.deadline,
      hasTime: task.deadlineHasTime,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    // A time said for a task with no day: the day it goes on, asked with
    // the time, so the time understood shows before a day is picked.
    final said = command.changes.time;
    final asksDay = said != null && (plan.needsDay || command.day != null);
    final picked = command.day == null ? null : Task.day(command.day!);
    final otherDay = picked != null && picked != today && picked != tomorrow;
    final problem = switch (plan.problem) {
      AssigneeProblem.notInProject => l.commandMemberNotIn(
        plan.problemName ?? '',
        ref
                .watch(taskListsProvider)
                .valueOrNull
                ?.where((p) => p.id == task.listId)
                .firstOrNull
                ?.name ??
            '',
      ),
      AssigneeProblem.needsShared => l.commandAssignNeedsShared,
      // With people to tap, the question box below says it.
      AssigneeProblem.ambiguous =>
        plan.namesakes.isNotEmpty
            ? null
            : l.commandAmbiguousMember(plan.problemName ?? ''),
      null => null,
    };
    return _Frame(
      children: [
        _Header(
          icon: Icons.edit_outlined,
          text: shown.title,
          onRemove: onRemove,
          removeLabel: l.commandDontChange(shown.title),
          enabled: enabled,
        ),
        if (_completed(shown)) _Note(l.commandCompleted),
        if (plan.title != null)
          line(Icons.short_text_rounded, l.taskTitle, task.title, plan.title!),
        if (plan.schedule case final schedule?)
          line(
            Icons.calendar_today_outlined,
            l.reviewSchedule,
            scheduleText(context, current),
            scheduleText(context, schedule),
          ),
        // The box spans the card, for the chips' room at large text.
        if (asksDay)
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 4, bottom: 8),
            child: QuestionBox(
              question: _whichDay(context, said),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (label, day) in [
                    (l.today, today),
                    (l.tomorrow, tomorrow),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: command.day == day,
                      onSelected: enabled
                          ? (_) => onChanged(command.copyWith(day: day))
                          : null,
                    ),
                  // The day picked shows here, as in the form.
                  ChoiceChip(
                    key: const ValueKey('command-pick-day'),
                    avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      otherDay ? context.weekdayDate(picked) : l.pickDay,
                    ),
                    selected: otherDay,
                    onSelected: !enabled
                        ? null
                        : (_) async {
                            final result = await editSchedule(
                              context,
                              date: command.day ?? today,
                              hasTime: false,
                              title: l.pickDay,
                              applyDays: true,
                            );
                            final date = result?.date;
                            if (date != null) {
                              onChanged(command.copyWith(day: Task.day(date)));
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        if (plan.deadline case final changed?)
          line(
            Icons.flag_outlined,
            l.deadline,
            scheduleText(context, deadline, none: l.deadlineUnset),
            scheduleText(context, changed, none: l.deadlineUnset),
          ),
        if (plan.priority case final priority?)
          line(
            Icons.flag_outlined,
            l.priority,
            context.priorityName(task.priority),
            context.priorityName(priority),
          ),
        if (plan.notes case final notes?)
          _Note(l.commandNotesAdd(notes), icon: Icons.notes_rounded),
        if (plan.assignee case final assignee?)
          line(
            Icons.person_outline,
            l.commandAssignee,
            responsibilityLabel(context, task, accountId),
            responsibilityLabel(
              context,
              task.copyWith(
                assignment: assignee.assignment,
                assigneeId: assignee.id,
                assigneeName: assignee.name,
              ),
              accountId,
            ),
          ),
        if (problem != null) _Note(problem, icon: Icons.info_outline),
        // Two or more people have the name said: one chip each, and they
        // stay once one is tapped, to tap another.
        if (plan.namesakes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 4, bottom: 8),
            child: QuestionBox(
              question: l.commandAmbiguousMember(
                command.changes.assigneeName ?? '',
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final person in plan.namesakes)
                    ChoiceChip(
                      key: ValueKey('command-member-${person.id}'),
                      label: Text(person.name),
                      selected:
                          !plan.asksMember && command.memberId == person.id,
                      onSelected: enabled
                          ? (_) =>
                                onChanged(command.copyWith(memberId: person.id))
                          : null,
                    ),
                ],
              ),
            ),
          ),
        // A repeating task's day or time: this repetition, or all of them,
        // as `Cambiar fecha` asks.
        if (plan.repeating && plan.schedule != null && !plan.seriesOnly)
          Padding(
            padding: const EdgeInsets.only(left: 34, right: 8, bottom: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final series in [false, true])
                  ChoiceChip(
                    key: ValueKey('command-series-$series'),
                    label: Text(series ? l.wholeSeries : l.thisOccurrence),
                    selected: command.series == series,
                    onSelected: enabled
                        ? (_) => onChanged(command.copyWith(series: series))
                        : null,
                  ),
              ],
            ),
          ),
        // Nothing to change: already as asked (unless a line above says
        // why not), or nothing asked, and then it opens to edit.
        if (plan.isEmpty && !plan.needsDay && plan.problem == null)
          plan.asked
              ? _Note(l.commandNothingToChange)
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: TextButton.icon(
                      key: const ValueKey('command-edit-task'),
                      onPressed: () => unawaited(
                        Navigator.pushNamed(
                          context,
                          '/editTask',
                          arguments: task.id,
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.editTask),
                    ),
                  ),
                ),
        if (view.matches.length > 1)
          _another(context, view, onChanged, enabled),
      ],
    );
  }
}

/// `delete`: the task, in the error colour, or the list to choose it from,
/// or that it wasn't found. Nothing is deleted before the confirming tap.
class DeleteCommandCard extends StatelessWidget {
  const DeleteCommandCard({
    super.key,
    required this.view,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
  });
  final CommandView view;
  final ValueChanged<CaptureCommand> onChanged;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final command = view.command;
    if (view.notFound) {
      return _Frame(
        children: [
          _Header(
            icon: Icons.delete_outline_rounded,
            text: _notFound(context, view),
          ),
        ],
      );
    }
    if (view.choosing) {
      return _Frame(
        children: [
          _Header(
            icon: Icons.delete_outline_rounded,
            text: l.commandWhichToDelete,
            onRemove: onRemove,
            removeLabel: l.commandDontDelete(_words(command.target.words)),
            enabled: enabled,
          ),
          _Choice(view: view, onChanged: onChanged, enabled: enabled),
        ],
      );
    }
    final shown = view.target!;
    final stored = view.stored!;
    final when = stored.isRecurring
        ? context.repeatLabel(stored)
        : shown.displayDate != null
        ? context.dayLabel(shown.displayDate!)
        : null;
    final error = Theme.of(context).colorScheme.error;
    return _Frame(
      destructive: true,
      children: [
        _Header(
          icon: Icons.delete_outline_rounded,
          text: when == null
              ? l.commandWillDelete(stored.title)
              : l.commandWillDeleteOn(stored.title, when),
          color: error,
          onRemove: onRemove,
          removeLabel: l.commandDontDelete(stored.title),
          enabled: enabled,
        ),
        if (_completed(shown)) _Note(l.commandCompleted),
        if (view.matches.length > 1)
          _another(context, view, onChanged, enabled),
      ],
    );
  }
}
