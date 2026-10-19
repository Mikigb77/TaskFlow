import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/services/text_encoding_repair.dart';
import 'package:agenda/widgets/capture_command_cards.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/widgets/schedule_editor.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The same draft stays mounted as a compact card or a direct editor. All
/// changes go immediately to the parent's durable capture journal.
class CaptureReviewEditor extends StatefulWidget {
  const CaptureReviewEditor({
    super.key,
    required this.draft,
    required this.compact,
    required this.expanded,
    required this.onExpand,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
    this.onRenameProject,
  });
  final CaptureDraft draft;
  final bool compact;
  final bool expanded;
  final bool enabled;
  final VoidCallback onExpand;
  final ValueChanged<CaptureDraft> onChanged;
  final VoidCallback onRemove;

  /// The project this task's confirming tap creates, renamed from its chip:
  /// the name it had, and the one typed. Nothing is created yet.
  final void Function(String from, String to)? onRenameProject;
  @override
  State<CaptureReviewEditor> createState() => _CaptureReviewEditorState();
}

class _CaptureReviewEditorState extends State<CaptureReviewEditor> {
  late final _title = TextEditingController(text: widget.draft.task.title);
  late final _notes = TextEditingController(
    text: widget.draft.task.notes ?? '',
  );
  final _notesFocus = FocusNode();
  // The steps move up out of Opciones once there is one; one key keeps the
  // add-step field focused across the move.
  final _steps = GlobalKey();
  bool _options = false;
  // The notes field shows once the task has notes, or once `Añadir notas`
  // opened it; then it stays for this card even if emptied again.
  late bool _notesOpen = _hasNotes;
  Task get task => widget.draft.task;
  bool get expanded => !widget.compact || widget.expanded;
  bool get _hasNotes => task.notes?.trim().isNotEmpty ?? false;

  @override
  void didUpdateWidget(CaptureReviewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_title.text != task.title) _title.text = task.title;
    if (_notes.text != (task.notes ?? '')) _notes.text = task.notes ?? '';
    if (_hasNotes) _notesOpen = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _openNotes() {
    setState(() => _notesOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notesFocus.requestFocus();
    });
  }

  void _change(Task value) =>
      widget.onChanged(widget.draft.copyWith(task: value));
  void _resolve(CaptureClarification question, {Task? value}) {
    final resolved = {...widget.draft.resolvedQuestions, question.id};
    widget.onChanged(
      widget.draft.copyWith(
        task: value,
        resolvedQuestions: resolved.toList(),
        confirmed: widget.draft.reviewQuestions.every(
          (q) => resolved.contains(q.id),
        ),
      ),
    );
  }

  Future<void> _schedule({
    CaptureClarification? question,
    bool deadline = false,
  }) async {
    final result = await editSchedule(
      context,
      date: deadline ? task.deadline : task.dueDate,
      hasTime: deadline ? task.deadlineHasTime : task.hasTime,
      title: deadline ? context.l10n.deadline : null,
      // Fixing a day on the result is one tap: Hoy, Mañana and Sin fecha
      // apply at once.
      applyDays: true,
    );
    if (result == null || !mounted) return;
    final changed = deadline
        ? task.copyWith(
            deadline: result.date,
            deadlineHasTime: result.hasTime,
            reminderAnchor: result.date == null
                ? 'planned'
                : task.dueDate == null
                ? 'deadline'
                : task.reminderAnchor,
          )
        : task.copyWith(
            dueDate: result.date,
            hasTime: result.hasTime,
            recurrence: result.date == null ? 'none' : task.recurrence,
            repeatInterval: result.date == null ? 1 : task.repeatInterval,
            repeatWeekdays: result.date == null ? [] : task.repeatWeekdays,
            exceptions: result.date == null ? [] : task.exceptions,
            repeatUntil:
                result.date == null ||
                    (task.repeatUntil?.isBefore(Task.day(result.date!)) ??
                        false)
                ? null
                : task.repeatUntil,
          );
    if (question == null) {
      // A date chosen here is no longer the one read from the words.
      widget.onChanged(
        widget.draft.copyWith(task: changed, clearAsTyped: true),
      );
    } else {
      _resolve(question, value: changed);
    }
  }

  List<CaptureClarification> _openQuestions(String field) =>
      widget.draft.confirmed
      ? <CaptureClarification>[]
      : widget.draft.reviewQuestions
            .where(
              (q) =>
                  q.field == field &&
                  !widget.draft.resolvedQuestions.contains(q.id),
            )
            .toList();

  Widget _questions(String field) {
    final questions = _openQuestions(field);
    final l = context.l10n;
    final timed = field == 'schedule' || field == 'deadline';
    final day = field == 'deadline' ? task.deadline : task.dueDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final question in questions)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: QuestionBox(
              question: question.question.isEmpty
                  ? l.captureWhatTime
                  : question.question,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // A question that offers times is answered by picking
                  // one of them or saying there is no time.
                  if (timed && day != null && question.times.isNotEmpty) ...[
                    for (final clock in question.times)
                      ActionChip(
                        label: Text(
                          TimeOfDay(
                            hour: int.parse(clock.split(':')[0]),
                            minute: int.parse(clock.split(':')[1]),
                          ).format(context),
                        ),
                        onPressed: !widget.enabled
                            ? null
                            : () {
                                final date = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                  int.parse(clock.split(':')[0]),
                                  int.parse(clock.split(':')[1]),
                                );
                                _resolve(
                                  question,
                                  value: field == 'deadline'
                                      ? task.copyWith(
                                          deadline: date,
                                          deadlineHasTime: true,
                                        )
                                      : task.copyWith(
                                          dueDate: date,
                                          hasTime: true,
                                        ),
                                );
                              },
                      ),
                    ActionChip(
                      label: Text(l.reviewNoTime),
                      onPressed: !widget.enabled
                          ? null
                          : () => _resolve(
                              question,
                              value: field == 'deadline'
                                  ? task.copyWith(
                                      deadline: Task.day(day),
                                      deadlineHasTime: false,
                                    )
                                  : task.copyWith(
                                      dueDate: Task.day(day),
                                      hasTime: false,
                                    ),
                            ),
                    ),
                  ] else ...[
                    if (timed)
                      TextButton(
                        onPressed: !widget.enabled
                            ? null
                            : () => _schedule(
                                question: question,
                                deadline: field == 'deadline',
                              ),
                        child: Text(l.reviewEditDetail),
                      ),
                    TextButton.icon(
                      onPressed: !widget.enabled
                          ? null
                          : () => _resolve(question),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l.reviewConfirmDetail),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    Key? key,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: widget.enabled ? onTap : null,
  );

  /// A project said that doesn't exist: where the task goes. Create it, or
  /// take an existing one or none instead, one tap each. Never created
  /// without that tap. A person named for a shared project chosen is then
  /// checked as before.
  Widget _projectChoice(String said) => Consumer(
    builder: (context, ref, _) {
      final name = spokenProjectName(said);
      final member =
          widget.draft.assignmentHints['member']?.trim().isNotEmpty == true;
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: QuestionBox(
          question: context.l10n.commandWhichProject,
          child: ProjectChoices(
            name: name,
            enabled: widget.enabled,
            projects: editableProjects(
              ref.watch(taskListsProvider).valueOrNull ?? const [],
            ),
            onCreate: () => widget.onChanged(
              widget.draft.copyWith(
                newProject: name,
                clearProjectSuggestion: true,
                assignmentReviewed: true,
              ),
            ),
            onPick: (project) => widget.onChanged(
              widget.draft.copyWith(
                task: taskWithProject(task, project),
                clearProjectSuggestion: true,
                assignmentReviewed: !(project.shared && member),
              ),
            ),
            onNone: () => widget.onChanged(
              widget.draft.copyWith(
                task: taskWithProject(task, null),
                clearProjectSuggestion: true,
                assignmentReviewed: true,
              ),
            ),
          ),
        ),
      );
    },
  );

  /// `Dejar como está`: the typed words become the title again, with the
  /// date the task would have had without them.
  void _keepAsTyped() {
    final typed = widget.draft.asTyped;
    if (typed == null) return;
    widget.onChanged(
      widget.draft.copyWith(
        task: typed,
        clearAsTyped: true,
        confirmed: true,
        resolvedQuestions: [
          for (final question in widget.draft.reviewQuestions) question.id,
        ],
      ),
    );
  }

  /// Under a date read from typed words: where it came from, and the way
  /// back to the words as typed.
  Widget _fromWords() {
    final l = context.l10n;
    final text = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.fromYourWords, style: text),
        ExcludeSemantics(child: Text(' · ', style: text)),
        TextButton(
          onPressed: widget.enabled ? _keepAsTyped : null,
          child: Text(l.keepAsTyped),
        ),
      ],
    );
  }

  /// The date is the result's main line; a collapsed row shows it smaller.
  /// Tapping it opens the date sheet. TalkBack says what the line is:
  /// `Fecha y hora: Hoy`. A collapsed row for a task with only a deadline
  /// shows the deadline (`Vence jue, 12 nov`) instead of `Sin fecha`; the
  /// opened card keeps `Sin fecha` with its deadline row under it.
  Widget _dateLine({required bool main}) {
    final text = Theme.of(context).textTheme;
    final due = !main && task.dueDate == null && task.deadline != null;
    final day = due
        ? taskDeadlineLabel(context, task)
        : taskDayLine(context, task);
    return Semantics(
      label: '${context.l10n.reviewSchedule}: $day',
      button: true,
      enabled: widget.enabled,
      excludeSemantics: true,
      onTap: widget.enabled ? _schedule : null,
      child: ListTile(
        key: ValueKey('draft-schedule-${widget.draft.id}'),
        contentPadding: EdgeInsets.zero,
        dense: !main,
        visualDensity: main ? null : VisualDensity.compact,
        horizontalTitleGap: main ? 12 : 8,
        minLeadingWidth: 0,
        leading: Icon(
          due ? Icons.flag_outlined : Icons.calendar_today_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: main ? 24 : 18,
        ),
        title: Text(day),
        titleTextStyle: main ? text.titleLarge : text.bodyMedium,
        trailing: main
            ? const Icon(Icons.chevron_right_rounded, size: 20)
            : null,
        onTap: widget.enabled ? _schedule : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final repairTitle = suggestTextEncodingRepair(task.title);
    final repairNotes = suggestTextEncodingRepair(task.notes ?? '');
    final showPlanning =
        task.deadline != null ||
        task.durationMinutes != null ||
        (!widget.draft.confirmed &&
            widget.draft.reviewQuestions.any(
              (q) => ['deadline', 'duration'].contains(q.field),
            ));
    // The project and the person show only when they are set: by the
    // assistant, or because capture opened inside a project. The personal
    // inbox is the default, so it stays behind `Más opciones`. A project
    // the dictation creates, or one said that doesn't exist, shows too.
    final newProject = widget.draft.newProject;
    final suggestion = widget.draft.projectSuggestion;
    final showAssignment =
        task.listId != null ||
        newProject != null ||
        suggestion != null ||
        !widget.draft.assignmentReviewed;
    // The date was read from typed words: say so under it.
    final fromWords = widget.draft.asTyped != null;
    Widget assignment({bool asRow = false}) => suggestion != null
        ? _projectChoice(suggestion)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaskAssignmentPicker(
                task: task,
                compact: true,
                asRow: asRow,
                needsReview: !widget.draft.assignmentReviewed,
                hints: widget.draft.assignmentHints,
                newProjectName: newProject == null
                    ? null
                    : spokenProjectName(newProject),
                onRenameProject:
                    !widget.enabled ||
                        newProject == null ||
                        widget.onRenameProject == null
                    ? null
                    : (name) => widget.onRenameProject!(newProject, name),
                // Another project chosen: none is created for this task.
                onChanged: !widget.enabled
                    ? null
                    : newProject == null
                    ? _change
                    : (value) => widget.onChanged(
                        widget.draft.copyWith(
                          task: value,
                          clearNewProject: true,
                        ),
                      ),
                onReviewed: !widget.enabled
                    ? null
                    : () => widget.onChanged(
                        widget.draft.copyWith(assignmentReviewed: true),
                      ),
              ),
              // Nobody is in a new project yet: whoever was named waits
              // for an invitation, sent from the project's Compartir.
              if (newProject != null && task.listId == null)
                if (widget.draft.assignmentHints['member']?.trim()
                    case final member? when member.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l.commandMemberNotInNew(
                        member,
                        spokenProjectName(newProject),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
            ],
          );
    // A note's body is its notes, so it always shows.
    final showNotes = task.isNote || _notesOpen;
    // An underline says the field can be tapped and corrected, and keeps
    // the title's heading look.
    final fieldBorders = (
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabled: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.outline),
      ),
      focused: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    );
    final optionsSummary = [
      if (task.priority > 1)
        l.priorityValue(context.priorityName(task.priority)),
      if (task.isRecurring) context.repeatLabel(task),
    ];
    final repair = [
      if (repairTitle != null || repairNotes != null) ...[
        Text(l.reviewRepairHelp, style: Theme.of(context).textTheme.bodySmall),
        TextButton.icon(
          onPressed: !widget.enabled
              ? null
              : () => _change(
                  task.copyWith(
                    title: repairTitle ?? task.title,
                    notes: repairNotes ?? task.notes,
                  ),
                ),
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(l.reviewRepair),
        ),
      ],
    ];
    bool openQuestion(String field) => _openQuestions(field).isNotEmpty;
    final belowNotes =
        repair.isNotEmpty ||
        showAssignment ||
        (!task.isNote &&
            (task.deadline != null ||
                task.durationMinutes != null ||
                openQuestion('deadline') ||
                openQuestion('duration'))) ||
        task.checklist.isNotEmpty ||
        task.priority > 1 ||
        task.isRecurring ||
        openQuestion('recurrence') ||
        openQuestion('details');
    final notesLast = showNotes && !belowNotes;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An opened card keeps only ✕ here; its title is in the field.
        if (widget.compact && expanded)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              tooltip: l.removeCaptureItem(task.title),
              onPressed: widget.enabled ? widget.onRemove : null,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          )
        else if (widget.compact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: widget.enabled ? widget.onExpand : null,
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.removeCaptureItem(task.title),
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        if (expanded) ...[
          if (widget.compact) const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('task-title'),
            controller: _title,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: null,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: task.isNote ? l.noteTitle : l.taskTitle,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: fieldBorders.border,
              disabledBorder: fieldBorders.border,
              enabledBorder: fieldBorders.enabled,
              focusedBorder: fieldBorders.focused,
              counterText: '',
              errorText: task.title.trim().isEmpty
                  ? l.titleRequiredField
                  : null,
            ),
            onChanged: (value) => _change(task.copyWith(title: value)),
          ),
          _questions('title'),
          // The date is the main line, with an open time question under it.
          if (!task.isNote) ...[
            _dateLine(main: true),
            if (fromWords && task.dueDate != null) _fromWords(),
            _questions('schedule'),
          ],
          if (showNotes) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('draft-notes'),
              controller: _notes,
              focusNode: _notesFocus,
              enabled: widget.enabled,
              minLines: 2,
              maxLines: null,
              maxLength: 8000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.notes,
                hintText: l.addNotes,
                filled: false,
                border: fieldBorders.border,
                disabledBorder: fieldBorders.border,
                enabledBorder: fieldBorders.enabled,
                focusedBorder: fieldBorders.focused,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) => _change(task.copyWith(notes: value)),
            ),
          ],
          const SizedBox(height: 8),
          ...repair,
          if (showAssignment) assignment(),
          if (showPlanning && !task.isNote) ...[
            if (task.deadline != null)
              _row(
                Icons.flag_outlined,
                taskDeadlineLabel(context, task),
                onTap: () => _schedule(deadline: true),
              ),
            if (fromWords && task.dueDate == null && task.deadline != null)
              _fromWords(),
            _questions('deadline'),
            if (task.durationMinutes != null)
              Text(
                l.durationMinutes(task.durationMinutes!),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            _questions('duration'),
          ],
          if (task.checklist.isNotEmpty)
            ChecklistEditor(
              key: _steps,
              items: task.checklist,
              recurring: task.isRecurring,
              onChanged: !widget.enabled
                  ? null
                  : (items) => _change(task.copyWith(checklist: items)),
            ),
          if (task.priority > 1 || task.isRecurring)
            Wrap(
              spacing: 8,
              children: [
                if (task.priority > 1)
                  Chip(
                    label: Text(
                      l.priorityValue(context.priorityName(task.priority)),
                    ),
                  ),
                if (task.isRecurring)
                  ActionChip(
                    label: Text(context.repeatLabel(task)),
                    tooltip: l.changeRepeat,
                    onPressed: !widget.enabled
                        ? null
                        : () async {
                            final result = await editTaskRepeat(context, task);
                            if (result != null && mounted) _change(result);
                          },
                  ),
              ],
            ),
          _questions('recurrence'),
          _questions('details'),
          // The notes field's underline already separates it from the row,
          // when nothing else sits between them.
          if (!notesLast) const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            key: ValueKey('draft-options-${widget.draft.id}'),
            leading: const Icon(Icons.tune_rounded, size: 22),
            title: Text(l.reviewOptions),
            // Only what differs from the defaults; nothing when all are.
            subtitle: optionsSummary.isEmpty
                ? null
                : Text(optionsSummary.join(' · ')),
            trailing: Icon(
              _options ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: () => setState(() => _options = !_options),
          ),
          if (_options) ...[
            if (!showNotes)
              _row(
                Icons.notes_rounded,
                l.addNotes,
                key: ValueKey('draft-add-notes-${widget.draft.id}'),
                onTap: _openNotes,
              ),
            if (!showAssignment) assignment(asRow: true),
            if (!task.isNote) ...[
              DropdownButtonFormField<int>(
                initialValue: task.priority,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.priority),
                items: [
                  for (final p in [1, 2, 3])
                    DropdownMenuItem(
                      value: p,
                      child: Text(context.priorityName(p)),
                    ),
                ],
                onChanged: !widget.enabled
                    ? null
                    : (p) => _change(task.copyWith(priority: p)),
              ),
              _row(
                Icons.repeat_rounded,
                context.repeatLabel(task),
                onTap: task.dueDate == null
                    ? null
                    : () async {
                        final result = await editTaskRepeat(context, task);
                        if (result != null && mounted) _change(result);
                      },
              ),
              TaskPlanningControl(
                task: task,
                onChanged: widget.enabled ? _change : null,
              ),
              ReminderControl(
                hasDate: task.reminderDate != null,
                hasTime: task.reminderHasTime,
                minutes: task.reminderMinutes,
                time: task.reminderTime,
                onMinutes: (value) {
                  if (widget.enabled) {
                    _change(task.copyWith(reminderMinutes: value));
                  }
                },
                onTime: (value) {
                  if (widget.enabled) {
                    _change(task.copyWith(reminderTime: value));
                  }
                },
              ),
            ],
            if (task.checklist.isEmpty)
              ChecklistEditor(
                key: _steps,
                items: task.checklist,
                recurring: task.isRecurring,
                onChanged: !widget.enabled
                    ? null
                    : (items) => _change(task.copyWith(checklist: items)),
              ),
            TextButton.icon(
              onPressed: widget.enabled ? widget.onRemove : null,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: Text(l.reviewRemove),
            ),
          ],
        ] else ...[
          // A collapsed row: its title, its date line and ✕, with every open
          // question in view, so `Revisa los datos de arriba` always points
          // at something.
          _questions('title'),
          if (!task.isNote) ...[_dateLine(main: false), _questions('schedule')],
          ...repair,
          if (!widget.draft.assignmentReviewed || newProject != null)
            assignment(),
          if (!task.isNote) ...[_questions('deadline'), _questions('duration')],
          _questions('recurrence'),
          _questions('details'),
        ],
      ],
    );
    return widget.compact
        ? Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 12),
              child: body,
            ),
          )
        : body;
  }
}
