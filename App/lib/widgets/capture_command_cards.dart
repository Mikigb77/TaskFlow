import 'dart:async';
import 'dart:math' as math;

import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/bulk_plan.dart';
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
import 'package:intl/intl.dart' show DateFormat;

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
    this.bulk,
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

  /// `update`, `delete` and `complete`, when nothing the person can edit
  /// matches: the first task that would, in a project they can only view.
  final Task? viewOnly;

  /// A bulk command's set: the tasks its card lists, and what the tap does.
  final BulkPlan? bulk;

  CommandKind get kind => command.kind;

  /// `project`: it asks, and nothing was tapped yet.
  bool get asking => asks && command.choice == null;

  /// Several tasks match and none was tapped yet.
  bool get choosing => target == null && matches.length > 1;

  /// The task to change, delete or complete isn't on the phone.
  bool get notFound =>
      (kind == CommandKind.update ||
          kind == CommandKind.delete ||
          kind == CommandKind.complete) &&
      bulk == null &&
      target == null &&
      !choosing;

  /// `complete`: the task meant is done already.
  bool get alreadyDone =>
      kind == CommandKind.complete &&
      bulk == null &&
      target != null &&
      TaskMatcher.done(target!);

  /// The confirming tap does something for it.
  bool get actionable => switch (kind) {
    CommandKind.project =>
      !command.existing &&
          (!asks || command.choice == CaptureCommand.createChoice),
    CommandKind.update => bulk != null ? bulk!.count > 0 : plan?.ready == true,
    CommandKind.delete => bulk != null ? bulk!.count > 0 : stored != null,
    CommandKind.complete =>
      bulk != null ? bulk!.count > 0 : stored != null && !alreadyDone,
    CommandKind.find => false,
  };

  /// It waits for a tap on its card before the confirming tap can do it.
  bool get blocking => switch (kind) {
    CommandKind.project => asking,
    CommandKind.update =>
      bulk != null
          ? bulk!.waits
          : choosing || plan?.needsDay == true || plan?.asksMember == true,
    CommandKind.delete ||
    CommandKind.complete => bulk != null ? bulk!.waits : choosing,
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
    case CommandKind.complete:
      if (command.bulk) {
        return CommandView(
          command,
          bulk: planBulk(
            command,
            tasks: tasks,
            projects: projects,
            accountId: accountId,
          ),
        );
      }
      bool canEdit(String? id) =>
          id == null || projects.any((p) => p.id == id && p.canEdit);
      final completing = command.kind == CommandKind.complete;
      final matches = TaskMatcher.targets(
        tasks,
        command.target,
        canEdit: canEdit,
        completing: completing,
      );
      // None to edit: the same search among all, for the line saying why.
      final viewOnly = matches.isNotEmpty
          ? null
          : TaskMatcher.targets(
              tasks,
              command.target,
              canEdit: (_) => true,
              completing: completing,
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

/// The projects like [name], at most [ProjectChoices.similar], in their
/// order: first those it starts, that start it, or that contain it; then
/// those that start with its first 4 letters («Mates»: «Matemáticas»).
/// Accents and case don't count.
@visibleForTesting
List<TaskListInfo> similarProjects(String name, List<TaskListInfo> projects) {
  final said = _fold(name);
  if (said.length < 3) return const [];
  bool like(TaskListInfo project) {
    final own = _fold(project.name);
    return own.startsWith(said) || said.startsWith(own) || own.contains(said);
  }

  final start = said.length >= 4 ? said.substring(0, 4) : null;
  return [
    ...projects.where(like),
    if (start != null)
      ...projects.where((p) => !like(p) && _fold(p.name).startsWith(start)),
  ].take(ProjectChoices.similar).toList();
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
    this.candidates = const [],
    this.onNone,
    this.enabled = true,
  });
  final String name;

  /// Those the person can edit.
  final List<TaskListInfo> projects;
  final TaskListInfo? first;

  /// The ids of the projects the server matched, best first. Those among
  /// [projects] are the ones like [name]; without any, they're guessed from
  /// the names.
  final List<String> candidates;
  final VoidCallback onCreate;
  final ValueChanged<TaskListInfo> onPick;
  final VoidCallback? onNone;
  final bool enabled;

  /// Projects shown as chips; the rest are in the sheet.
  static const similar = 3;

  /// A chip's icon keeps its room at any text size.
  static const _avatarBox = BoxConstraints.tightFor(width: 20, height: 20);

  /// A chip's icon box and padding: 8 dp around, up to 8 dp each side of
  /// the label.
  static const _chipFrame = 20.0 + 16 + 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final matched = [
      for (final id in candidates)
        ?projects.where((p) => p.id == id).firstOrNull,
    ];
    final shown = [
      ?first,
      ...(matched.isNotEmpty ? matched : similarProjects(name, projects)).where(
        (p) => p.id != first?.id,
      ),
    ].take(similar).toList();
    final more = projects.any((p) => !shown.any((s) => s.id == p.id));
    return LayoutBuilder(
      builder: (context, box) {
        // A long name wraps to a second line rather than being cut, for
        // large text. A chip measures its label at its whole width before
        // taking off its icon and padding, so the label keeps to what is
        // left.
        Widget label(String text) => ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.max(0, box.maxWidth - _chipFrame),
          ),
          // A chip's own text style doesn't wrap.
          child: Text(
            text,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const ValueKey('project-choice-create'),
              avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
              avatarBoxConstraints: _avatarBox,
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
                avatarBoxConstraints: _avatarBox,
                label: label(project.name),
                onPressed: enabled ? () => onPick(project) : null,
              ),
            if (more)
              ActionChip(
                key: const ValueKey('project-choice-other'),
                avatar: const Icon(Icons.folder_open_outlined, size: 18),
                avatarBoxConstraints: _avatarBox,
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
                avatarBoxConstraints: _avatarBox,
                label: label(l.noList),
                onPressed: enabled ? onNone : null,
              ),
          ],
        );
      },
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
            // TalkBack hears the card by this line, as shown.
            child: Text(
              text,
              key: const ValueKey('command-headline'),
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
          // The chips span the card, for their room at large text.
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 4, bottom: 8),
            child: ProjectChoices(
              name: name,
              projects: editableProjects(projects),
              first: editableProjects(
                projects,
              ).where((p) => p.id == command.existingListId).firstOrNull,
              candidates: command.projectCandidates,
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
    final heading =
        _about(
          context,
          words: command.words,
          listId: command.listId,
          personId: command.personId,
          projects: projects,
          accountId: accountId,
        ) ??
        l.tasks;
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

/// What a search, or a set, is about in words: «Tareas con «médico»»,
/// «Tus tareas de «Física»», «Tareas para Paul». Null when only a period or
/// a status narrows it.
String? _about(
  BuildContext context, {
  required List<String> words,
  required String? listId,
  required int? personId,
  required List<TaskListInfo> projects,
  required int? accountId,
}) {
  final l = context.l10n;
  final project = projects.where((p) => p.id == listId).firstOrNull;
  final person = personId == null
      ? null
      : projects
            .expand((p) => p.people)
            .where((p) => p.id == personId)
            .firstOrNull;
  final mine = personId != null && personId == accountId;
  return words.isNotEmpty
      ? l.commandFindWords(_words(words))
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
      : null;
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
    // Read out as a button, as it opens the task.
    return Semantics(
      button: true,
      child: InkWell(
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
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
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
      ),
    );
  }
}

/// A task's day as a command's card lists it: its day and time, or its
/// deadline when it has only that.
String _dayOf(BuildContext context, Task task) =>
    task.displayDate == null && task.deadline != null
    ? taskDeadlineLabel(context, task)
    : taskDayLine(context, task);

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
          Semantics(
            button: true,
            child: InkWell(
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
                        _dayOf(context, task),
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
            removeLabel: l.commandDontChangeAny,
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
        // Moved by days, with no day to move: it stays.
        if (plan.noDay && plan.isEmpty)
          _Note(l.commandBulkLeftNoDay(1), icon: Icons.info_outline),
        // Nothing to change: already as asked (unless a line above says
        // why not), or nothing asked, and then it opens to edit.
        if (plan.isEmpty &&
            !plan.needsDay &&
            !plan.noDay &&
            plan.problem == null)
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
            removeLabel: l.commandDontDeleteAny,
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

/// `complete`: the task with its day, which the confirming tap marks done
/// («Marcar como hecha»), as ticking it does: a repeating task's repetition.
/// Or the list to choose it from, or that it wasn't found, or that it is
/// done already.
class CompleteCommandCard extends StatelessWidget {
  const CompleteCommandCard({
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

  static const _icon = Icons.task_alt_rounded;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (view.notFound) {
      return _Frame(
        children: [_Header(icon: _icon, text: _notFound(context, view))],
      );
    }
    if (view.choosing) {
      return _Frame(
        children: [
          _Header(
            icon: _icon,
            text: l.commandWhichToComplete,
            onRemove: onRemove,
            removeLabel: l.commandDontCompleteAny,
            enabled: enabled,
          ),
          _Choice(view: view, onChanged: onChanged, enabled: enabled),
        ],
      );
    }
    final shown = view.target!;
    return _Frame(
      children: [
        _Header(
          icon: _icon,
          text: shown.title,
          onRemove: onRemove,
          removeLabel: l.commandDontComplete(shown.title),
          enabled: enabled,
        ),
        _Note(_dayOf(context, shown)),
        if (view.alreadyDone) _Note(l.commandNothingToChange),
        if (view.matches.length > 1)
          _another(context, view, onChanged, enabled),
      ],
    );
  }
}

/// The person a bulk change assigns the tasks to, as projects name them.
String _assignee(CaptureCommand command, List<TaskListInfo> projects) {
  final changes = command.changes;
  final id = changes.assigneeId;
  final person = id == null
      ? null
      : projects.expand((p) => p.people).where((p) => p.id == id).firstOrNull;
  return person?.name ?? changes.assigneeName ?? '';
}

/// A bulk command's heading, with its live [BulkPlan.count]: «Mover 5 tareas
/// a mañana, jue 22», «Mover 3 tareas una semana después», «Asignar 4
/// tareas a Paul», «Cambiar 4 tareas», «Marcar 4 tareas como hechas»,
/// «Eliminar 6 tareas».
String bulkHeading(
  BuildContext context,
  CommandView view,
  List<TaskListInfo> projects,
) {
  final l = context.l10n;
  final bulk = view.bulk!;
  final count = bulk.count;
  final changes = view.command.changes;
  switch (bulk.action) {
    case BulkAction.move:
      final date = changes.date!;
      final today = DateUtils.dateOnly(DateTime.now());
      final day = Task.day(date);
      final when = day == today
          ? 'today'
          : day == DateTime(today.year, today.month, today.day + 1)
          ? 'tomorrow'
          : 'other';
      // Today and tomorrow need no month: «mañana, jue 22».
      final shown = when == 'other'
          ? context.weekdayDate(date)
          : DateFormat('E d', context.localeName).format(date);
      return l.commandBulkMoveTo(count, when, shown);
    case BulkAction.shift:
      final days = changes.shiftDays!;
      final weeks = days % 7 == 0;
      final span = l.commandBulkSpan(
        (weeks ? days ~/ 7 : days).abs(),
        weeks ? 'weeks' : 'days',
      );
      return l.commandBulkShift(count, span, days < 0 ? 'earlier' : 'later');
    case BulkAction.assign:
      return l.commandBulkAssignTo(count, _assignee(view.command, projects));
    case BulkAction.change:
      return l.commandBulkChange(count);
    case BulkAction.complete:
      return l.commandBulkComplete(count);
    case BulkAction.delete:
      return l.commandBulkDelete(count);
  }
}

/// The confirming button for a result whose one card is a bulk command: its
/// verb and live count, «Mover 5 tareas», «Eliminar 6 tareas».
String bulkButton(BuildContext context, BulkPlan bulk) {
  final l = context.l10n;
  final count = bulk.count;
  return switch (bulk.action) {
    BulkAction.move || BulkAction.shift => l.commandBulkMove(count),
    BulkAction.assign => l.commandBulkAssign(count),
    BulkAction.change => l.commandBulkChange(count),
    BulkAction.complete => l.commandBulkComplete(count),
    BulkAction.delete => l.commandBulkDelete(count),
  };
}

/// What a bulk change sets on each task, beyond what its heading says:
/// «Hora: 18:00 · Prioridad: Alta». Null when the heading says it all.
String? _bulkSets(
  BuildContext context,
  CommandView view,
  List<TaskListInfo> projects,
) {
  final l = context.l10n;
  final changes = view.command.changes;
  final action = view.bulk!.action;
  String clock(({int hour, int minute}) time) =>
      context.clockTime(DateTime(2000, 1, 1, time.hour, time.minute));
  String? deadline() {
    if (!changes.has('deadline_date') && !changes.has('deadline_time')) {
      return null;
    }
    if (changes.has('deadline_date')) {
      final date = changes.deadlineDate;
      if (date == null) return l.deadlineUnset;
      final time = changes.deadlineTime;
      return time == null
          ? context.weekdayDate(date)
          : '${context.weekdayDate(date)} · ${clock(time)}';
    }
    final time = changes.deadlineTime;
    return time == null ? l.anyTime : clock(time);
  }

  final due = deadline();
  final parts = [
    // A day taken away; a new day is the heading's.
    if (changes.has('date') && changes.date == null)
      l.commandBulkField(l.reviewSchedule, l.noDate),
    if (changes.has('time'))
      l.commandBulkField(
        l.time,
        changes.time == null ? l.anyTime : clock(changes.time!),
      ),
    if (due != null) l.commandBulkField(l.deadline, due),
    if (changes.priority case final priority?)
      l.commandBulkField(l.priority, context.priorityName(priority)),
    if (action != BulkAction.assign &&
        changes.assigns &&
        !changes.hasUnresolved)
      l.commandBulkField(
        l.commandAssignee,
        changes.assignsNobody
            ? l.assignedToGroup
            : _assignee(view.command, projects),
      ),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// What a bulk command left out, in one line: «2 tareas que se repiten no
/// cambian». Null when nothing was.
String? _bulkLeftOut(
  BuildContext context,
  CommandView view,
  List<TaskListInfo> projects,
) {
  final l = context.l10n;
  final bulk = view.bulk!;
  final parts = [
    if (bulk.repeating > 0)
      l.commandBulkLeftRepeating(bulk.repeating, switch (view.kind) {
        CommandKind.delete => 'delete',
        CommandKind.complete => 'complete',
        _ => 'change',
      }),
    if (bulk.unassignable > 0)
      l.commandBulkLeftUnassignable(
        bulk.unassignable,
        _assignee(view.command, projects),
      ),
    if (bulk.noDay > 0) l.commandBulkLeftNoDay(bulk.noDay),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// What a set that matched nothing looked for: «No hay tareas pendientes de
/// ayer».
String _bulkNone(BuildContext context, CommandTarget target) {
  final l = context.l10n;
  final from = target.from;
  final to = target.to;
  final today = DateUtils.dateOnly(DateTime.now());
  bool on(DateTime day, int days) => DateUtils.isSameDay(
    day,
    DateTime(today.year, today.month, today.day + days),
  );
  final kind = target.undated
      ? 'undated'
      : from != null && to != null
      ? !DateUtils.isSameDay(from, to)
            ? 'range'
            : on(from, 0)
            ? 'today'
            : on(from, -1)
            ? 'yesterday'
            : on(from, 1)
            ? 'tomorrow'
            : 'other'
      : to != null
      ? 'until'
      : from != null
      ? 'since'
      : null;
  final period = kind == null
      ? ''
      : l.commandBulkPeriod(
          kind,
          from == null ? '' : context.weekdayDate(from),
          to == null ? '' : context.weekdayDate(to),
        );
  return l.commandBulkNone(target.status, period).trim();
}

/// A bulk command (Backend/docs/VOICE_COMMANDS.md, «The card»): its action
/// and live count, what it sets, one line for what was left out, and the
/// tasks with their current day, each ticked; untick one to leave it out.
/// Nothing changes before the confirming tap. Or one line saying why there
/// is nothing to do: nothing matched, more than 200 did, or a project or a
/// person wasn't found.
class BulkCommandCard extends ConsumerStatefulWidget {
  const BulkCommandCard({
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
  ConsumerState<BulkCommandCard> createState() => _BulkCommandCardState();
}

class _BulkCommandCardState extends ConsumerState<BulkCommandCard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    final command = widget.view.command;
    final excluded = {...command.excluded};
    if (!excluded.remove(key)) excluded.add(key);
    widget.onChanged(command.copyWith(excluded: excluded.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final view = widget.view;
    final command = view.command;
    final target = command.target;
    final bulk = view.bulk!;
    final projects = ref.watch(taskListsProvider).valueOrNull ?? const [];
    final accountId = ref.watch(authProvider).account?.id;
    final delete = command.kind == CommandKind.delete;
    final icon = switch (command.kind) {
      CommandKind.delete => Icons.delete_outline_rounded,
      CommandKind.complete => Icons.task_alt_rounded,
      _ => Icons.edit_outlined,
    };
    Widget header(String text, {bool removable = false}) => _Header(
      icon: icon,
      text: text,
      color: delete && removable ? colors.error : null,
      onRemove: removable ? widget.onRemove : null,
      removeLabel: switch (command.kind) {
        CommandKind.delete => l.commandDontDeleteAny,
        CommandKind.complete => l.commandDontCompleteAny,
        _ => l.commandDontChangeAny,
      },
      enabled: widget.enabled,
    );
    String person(String name) => command.issues.contains('ambiguous_member')
        ? l.commandAmbiguousMember(name)
        : l.commandPersonNotFound(name);

    // A project or person said that wasn't found: nothing was searched.
    if (target.projectName case final name?) {
      return _Frame(children: [header(l.commandProjectNotFound(name))]);
    }
    if (target.personName case final name?) {
      return _Frame(children: [header(person(name))]);
    }
    if (bulk.tooMany) {
      return _Frame(children: [header(l.commandBulkTooMany(bulk.matched))]);
    }
    // Nothing said to change: the tasks, as a search lists them; each opens
    // to edit, as one task's card does.
    if (bulk.unasked case final found when found.isNotEmpty) {
      return _Frame(
        children: [
          header(
            _about(
                  context,
                  words: target.words,
                  listId: target.listId,
                  personId: target.personId,
                  projects: projects,
                  accountId: accountId,
                ) ??
                l.tasks,
          ),
          for (final task in found.take(FindCommandCard.shown))
            _FoundRow(task: task),
          if (found.length > FindCommandCard.shown)
            _Note(l.commandMore(found.length - FindCommandCard.shown)),
        ],
      );
    }
    final changes = command.changes;
    // Someone named for the tasks who wasn't found: said once.
    final problem = changes.hasUnresolved
        ? person(changes.assigneeName ?? '')
        : null;
    final leftOut = _bulkLeftOut(context, view, projects);
    if (bulk.items.isEmpty) {
      if (bulk.matched == 0 && bulk.repeating == 0) {
        if (bulk.viewOnly case final task?) {
          return _Frame(children: [header(l.commandViewOnly(task.title))]);
        }
        final about = _about(
          context,
          words: target.words,
          listId: target.listId,
          personId: target.personId,
          projects: projects,
          accountId: accountId,
        );
        return _Frame(
          children: [
            header(_bulkNone(context, target)),
            if (about != null) _Note(about),
          ],
        );
      }
      // Tasks matched, and none of them would change: why, in one line.
      return _Frame(
        children: [
          header(problem ?? leftOut ?? l.commandNothingToChange),
          if (problem != null && leftOut != null)
            _Note(leftOut, icon: Icons.info_outline),
        ],
      );
    }
    final sets = command.kind == CommandKind.update
        ? _bulkSets(context, view, projects)
        : null;
    Widget row(BulkItem item) {
      final task = item.shown;
      final day = [
        _dayOf(context, task),
        if (target.status != 'completed' && _completed(task))
          l.commandCompleted,
      ].join(' · ');
      return CheckboxListTile(
        key: ValueKey('bulk-${command.id}-${item.key}'),
        value: !bulk.excluded.contains(item.key),
        onChanged: widget.enabled ? (_) => _toggle(item.key) : null,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsetsDirectional.only(end: 8),
        activeColor: delete ? colors.error : null,
        checkColor: delete ? colors.onError : null,
        title: Text(task.title),
        subtitle: Text(day),
      );
    }

    // A long list scrolls inside the card, so a result's other cards stay
    // near. At large text a window that small would show one task at a
    // time, so the rows go in the sheet's own scroll instead.
    final large = MediaQuery.textScalerOf(context).scale(10) >= 15;
    final list = large
        ? Column(children: [for (final item in bulk.items) row(item)])
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                160.0,
                MediaQuery.sizeOf(context).height * 0.4,
              ),
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: bulk.items.length,
                itemBuilder: (context, index) => row(bulk.items[index]),
              ),
            ),
          );
    return _Frame(
      destructive: delete,
      children: [
        header(bulkHeading(context, view, projects), removable: true),
        if (sets != null) _Note(sets),
        if (problem != null) _Note(problem, icon: Icons.info_outline),
        // Apart from the ✕ above, so the first task isn't tapped for it.
        const SizedBox(height: 8),
        list,
        // What was left out, in one line, after the list.
        if (leftOut != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Note(leftOut, icon: Icons.info_outline),
          ),
      ],
    );
  }
}
