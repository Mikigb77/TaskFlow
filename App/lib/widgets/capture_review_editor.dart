import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/text_encoding_repair.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/widgets/schedule_editor.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter/material.dart';

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
  });
  final CaptureDraft draft;
  final bool compact;
  final bool expanded;
  final bool enabled;
  final VoidCallback onExpand;
  final ValueChanged<CaptureDraft> onChanged;
  final VoidCallback onRemove;
  @override
  State<CaptureReviewEditor> createState() => _CaptureReviewEditorState();
}

class _CaptureReviewEditorState extends State<CaptureReviewEditor> {
  late final _title = TextEditingController(text: widget.draft.task.title);
  late final _notes = TextEditingController(
    text: widget.draft.task.notes ?? '',
  );
  bool _options = false;
  Task get task => widget.draft.task;
  bool get expanded => !widget.compact || widget.expanded;

  @override
  void didUpdateWidget(CaptureReviewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_title.text != task.title) _title.text = task.title;
    if (_notes.text != (task.notes ?? '')) _notes.text = task.notes ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
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
      _change(changed);
    } else {
      _resolve(question, value: changed);
    }
  }

  Widget _questions(String field) {
    final questions = widget.draft.confirmed
        ? <CaptureClarification>[]
        : widget.draft.reviewQuestions
              .where(
                (q) =>
                    q.field == field &&
                    !widget.draft.resolvedQuestions.contains(q.id),
              )
              .toList();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final question in questions)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (field == 'schedule' || field == 'deadline') ...[
                          for (final clock in question.times)
                            if ((field == 'deadline'
                                    ? task.deadline
                                    : task.dueDate) !=
                                null)
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
                                        final day = (field == 'deadline'
                                            ? task.deadline
                                            : task.dueDate)!;
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
                          TextButton(
                            onPressed: !widget.enabled
                                ? null
                                : () => _schedule(
                                    question: question,
                                    deadline: field == 'deadline',
                                  ),
                            child: Text(l.reviewEditDetail),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: !widget.enabled
                              ? null
                              : () => _resolve(question),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(l.reviewConfirmDetail),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.compact)
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
                tooltip: l.editCaptureItem(task.title),
                onPressed: widget.enabled ? widget.onExpand : null,
                icon: Icon(
                  expanded ? Icons.expand_less_rounded : Icons.edit_outlined,
                  size: 20,
                ),
              ),
              if (expanded)
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
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              counterText: '',
              errorText: task.title.trim().isEmpty
                  ? l.titleRequiredField
                  : null,
            ),
            onChanged: (value) => _change(task.copyWith(title: value)),
          ),
          if (task.title.length > 80)
            Text(
              l.reviewShortTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _questions('title'),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('draft-notes'),
            controller: _notes,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: null,
            maxLength: 8000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.notes,
              hintText: l.addNotes,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (value) => _change(task.copyWith(notes: value)),
          ),
          const SizedBox(height: 16),
        ] else if (task.notes?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              task.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        if (repairTitle != null || repairNotes != null) ...[
          Text(
            l.reviewRepairHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
        if (!task.isNote) ...[
          if (expanded) const Divider(height: 1),
          if (expanded)
            _row(
              Icons.calendar_today_outlined,
              l.reviewSchedule,
              subtitle: taskScheduleLabel(task, context: context),
              onTap: _schedule,
              key: ValueKey('draft-schedule-${widget.draft.id}'),
            )
          else
            ActionChip(
              key: ValueKey('draft-schedule-${widget.draft.id}'),
              avatar: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(taskScheduleLabel(task, context: context)),
              onPressed: widget.enabled ? _schedule : null,
            ),
          _questions('schedule'),
        ],
        if (expanded) const Divider(height: 1),
        TaskAssignmentPicker(
          task: task,
          compact: true,
          asRow: expanded,
          needsReview: !widget.draft.assignmentReviewed,
          hints: widget.draft.assignmentHints,
          onChanged: widget.enabled ? _change : null,
          onReviewed: !widget.enabled
              ? null
              : () => widget.onChanged(
                  widget.draft.copyWith(assignmentReviewed: true),
                ),
        ),
        if (showPlanning && !task.isNote) ...[
          if (task.deadline != null)
            _row(
              Icons.flag_outlined,
              taskDeadlineLabel(context, task),
              onTap: () => _schedule(deadline: true),
            ),
          _questions('deadline'),
          if (task.durationMinutes != null)
            Text(
              l.durationMinutes(task.durationMinutes!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          _questions('duration'),
        ],
        if (task.checklist.isNotEmpty && expanded)
          ChecklistEditor(
            items: task.checklist,
            recurring: task.isRecurring,
            onChanged: !widget.enabled
                ? null
                : (items) => _change(task.copyWith(checklist: items)),
          ),
        if (task.checklist.isNotEmpty && !expanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.checklistCount(task.checklistDone, task.checklist.length),
            ),
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
        if (expanded) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            key: ValueKey('draft-options-${widget.draft.id}'),
            leading: const Icon(Icons.tune_rounded, size: 22),
            title: Text(l.reviewOptions),
            subtitle: Text(
              '${l.priorityValue(context.priorityName(task.priority))} · ${context.repeatLabel(task)}',
            ),
            trailing: Icon(
              _options ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: () => setState(() => _options = !_options),
          ),
          if (_options) ...[
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
            child: Padding(padding: const EdgeInsets.all(18), child: body),
          )
        : body;
  }
}
