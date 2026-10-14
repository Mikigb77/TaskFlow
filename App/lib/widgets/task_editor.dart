import 'package:agenda/widgets/schedule_editor.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/services/text_encoding_repair.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/reminder_ask_sheet.dart';

/// Edits a saved task or note. New ones come from the capture sheet.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({super.key, required this.task});
  final Task task;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _labels;
  String? _listId;
  String? _assignment;
  int? _assigneeId;
  String? _assigneeName;
  Task get _responsibility => Task(
    title: _title.text,
    priority: _priority,
    kind: _isNote ? 'note' : 'task',
    listId: _listId,
    assignment: _isNote
        ? 'personal'
        : _assignment ??
              ((ref.read(taskListsProvider).valueOrNull ?? []).any(
                    (p) => p.id == _listId && p.shared,
                  )
                  ? 'group'
                  : 'personal'),
    assigneeId: _isNote ? null : _assigneeId,
    assigneeName: _isNote ? null : _assigneeName,
  );

  late DateTime? _dueDate;
  late bool _hasTime;
  late String _recurrence;
  late int _repeatInterval;
  late List<int> _repeatWeekdays;
  late List<OccurrenceException> _exceptions;
  DateTime? _repeatUntil;
  late int _priority;
  int? _reminderMinutes;
  int? _reminderTime;
  late final List<String> _attachments;
  bool _saving = false;
  late final Map<String, dynamic> _unchanged;
  bool _pickingFile = false;
  late bool _detailsExpanded;
  late List<ChecklistItem> _checklist;
  late bool _isNote;
  DateTime? _deadline;
  bool _deadlineHasTime = false;
  int? _durationMinutes;
  String _reminderAnchor = 'planned';
  Task get _planningTask => Task(
    title: _title.text,
    priority: _priority,
    dueDate: _dueDate,
    hasTime: _hasTime,
    deadline: _deadline,
    deadlineHasTime: _deadlineHasTime,
    durationMinutes: _durationMinutes,
    recurrence: _dueDate == null ? 'none' : _recurrence,
    reminderAnchor: _reminderAnchor,
    reminderMinutes: _reminderMinutes,
    reminderTime: _reminderTime,
  );

  Task get _repeatTask => _planningTask.copyWith(
    repeatInterval: _repeatInterval,
    repeatWeekdays: _repeatWeekdays,
    repeatUntil: _repeatUntil,
  );

  /// The same repeat sheet as the capture result.
  Future<void> _editRepeat() async {
    final result = await editTaskRepeat(context, _repeatTask);
    if (result == null || !mounted) return;
    setState(() {
      _recurrence = result.recurrence;
      _repeatInterval = result.repeatInterval;
      _repeatWeekdays = [...result.repeatWeekdays];
      _repeatUntil = result.repeatUntil;
    });
  }

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _isNote = task.isNote;
    _detailsExpanded = false;
    _dueDate = task.dueDate;
    _title = TextEditingController(text: task.title);
    _notes = TextEditingController(text: task.notes ?? '');
    _labels = TextEditingController(text: task.labels.join(', '));
    _listId = task.listId;
    _assignment = task.assignment;
    _assigneeId = task.assigneeId;
    _assigneeName = task.assigneeName;
    _hasTime = task.hasTime;
    _deadline = task.deadline;
    _deadlineHasTime = task.deadlineHasTime;
    _durationMinutes = task.durationMinutes;
    _reminderAnchor = task.reminderAnchor;
    _recurrence = task.recurrence;
    _repeatInterval = task.repeatInterval;
    _repeatWeekdays = [...task.repeatWeekdays];
    _exceptions = [...task.exceptions];
    _repeatUntil = task.repeatUntil;
    _priority = task.priority;
    _reminderMinutes = task.reminderMinutes;
    _reminderTime = task.reminderTime;
    _attachments = [...task.filePaths, ...task.imagePaths];
    _checklist = [...task.checklist];
    _unchanged = _edited().toMap();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _labels.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await editSchedule(
      context,
      date: _dueDate,
      hasTime: _hasTime,
    );
    if (result == null || !mounted) return;
    setState(() {
      _dueDate = result.date;
      _hasTime = result.hasTime;
      if (_dueDate == null) {
        _recurrence = 'none';
        _repeatInterval = 1;
        _repeatWeekdays = [];
        _repeatUntil = null;
      } else if (_repeatUntil?.isBefore(Task.day(_dueDate!)) ?? false) {
        _repeatUntil = null;
      }
    });
  }

  bool _isImage(String file) => [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
  ].contains(path.extension(file).toLowerCase());

  void _quickDate(DateTime? date) => setState(() {
    if (date == null) {
      _dueDate = null;
      _hasTime = false;
      _recurrence = 'none';
      _repeatUntil = null;
    } else {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        _hasTime ? _dueDate!.hour : 0,
        _hasTime ? _dueDate!.minute : 0,
      );
      if (_repeatUntil != null && _repeatUntil!.isBefore(Task.day(date))) {
        _repeatUntil = null;
      }
    }
  });

  bool get _ruleChanged {
    final before = widget.task;
    return before.dueDate != _dueDate ||
        before.hasTime != _hasTime ||
        before.recurrence != _recurrence ||
        before.repeatInterval != _repeatInterval ||
        before.repeatUntil != _repeatUntil ||
        !const ListEquality<int>().equals(
          before.repeatWeekdays,
          _repeatWeekdays,
        );
  }

  /// The task as the form would save it.
  Task _edited() {
    final before = widget.task;
    final ruleChanged = _ruleChanged;
    return Task(
      kind: _isNote ? 'note' : 'task',
      id: before.id,
      title: _title.text.trim(),
      dueDate: _isNote ? null : _dueDate,
      hasTime: !_isNote && _hasTime,
      deadline: _isNote ? null : _deadline,
      deadlineHasTime: !_isNote && _deadlineHasTime,
      durationMinutes: _isNote ? null : _durationMinutes,
      reminderAnchor: _isNote ? 'planned' : _reminderAnchor,
      recurrence: _isNote || _dueDate == null ? 'none' : _recurrence,
      repeatInterval: _isNote || _recurrence == 'none' ? 1 : _repeatInterval,
      repeatWeekdays: !_isNote && _recurrence == 'weekly'
          ? _repeatWeekdays
          : [],
      exceptions: _isNote || ruleChanged || _recurrence == 'none'
          ? []
          : _exceptions,
      repeatUntil: _isNote || _recurrence == 'none' ? null : _repeatUntil,
      completedDates: _isNote || _recurrence == 'none'
          ? []
          : before.completedDates,
      priority: _isNote ? 1 : _priority,
      reminderMinutes: _isNote ? -1 : _reminderMinutes,
      reminderTime: _isNote ? null : _reminderTime,
      isCompleted: _isNote || _recurrence != 'none'
          ? false
          : before.isCompleted,
      notes: _notes.text.trim(),
      checklist: _isNote
          ? _checklist.map((item) => item.copyWith(completedDates: [])).toList()
          : _checklist,
      listId: _listId,
      assignment: _responsibility.assignment,
      assigneeId: _responsibility.assigneeId,
      assigneeName: _responsibility.assigneeName,
      createdBy: before.createdBy,
      labels: _labels.text
          .split(',')
          .where((label) => label.trim().isNotEmpty)
          .toList(),
      imagePaths: _attachments.where(_isImage).toList(),
      filePaths: _attachments.where((file) => !_isImage(file)).toList(),
    );
  }

  /// Back and Save behave the same: an unchanged form just closes, and
  /// changes are saved, with Undo.
  Future<void> _back() async {
    if (_saving) return;
    await _save();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (const DeepCollectionEquality().equals(_edited().toMap(), _unchanged)) {
      Navigator.pop(context);
      return;
    }
    FocusScope.of(context).unfocus();
    final before = widget.task;
    if (_ruleChanged && _exceptions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.changeSeriesQuestion),
          content: Text(context.l10n.changeSeriesHelp),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.keepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.resetSave),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final task = _edited();
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final notifier = ref.read(taskProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);
      final strings = context.l10n;
      await notifier.updateTask(task);
      if (!mounted) return;
      Navigator.pop(context);
      final feedback = showFeedback(
        messenger,
        strings.changesSaved,
        actionLabel: strings.undo,
        onAction: () async {
          if (!messenger.mounted ||
              !identical(container.read(taskProvider.notifier), notifier)) {
            return;
          }
          try {
            await notifier.updateTask(before);
          } catch (_) {
            if (messenger.mounted) {
              unawaited(showFeedback(messenger, strings.undoError));
            }
          }
        },
      );
      unawaited(feedback);
      askAboutRemindersAfterSave(context, [task], feedback: feedback);
    } catch (_) {
      if (mounted) {
        unawaited(
          showFeedback(
            ScaffoldMessenger.of(context),
            context.l10n.taskSaveError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attach() async {
    if (_pickingFile || _saving) return;
    if (_attachments.length >= 20) {
      unawaited(
        showFeedback(ScaffoldMessenger.of(context), context.l10n.fileLimit),
      );
      return;
    }
    final local = ref.read(taskRepositoryProvider).ownerKey == 'local';
    final gallery = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  local
                      ? context.l10n.fileLocalHelp
                      : context.l10n.fileUploadHelp,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(context.l10n.choosePhoto),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(context.l10n.attachFile),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (gallery == null || !mounted) return;
    setState(() => _pickingFile = true);
    try {
      final String? file;
      if (gallery) {
        file = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
        ))?.path;
      } else {
        file = (await FilePicker.platform.pickFiles())?.files.single.path;
      }
      final selectedFile = file == null
          ? null
          : await AttachmentFiles().retain(file);
      if (selectedFile != null && mounted) {
        setState(() => _attachments.add(selectedFile));
      }
    } catch (error) {
      if (mounted) {
        unawaited(
          showFeedback(
            ScaffoldMessenger.of(context),
            error is FormatException
                ? context.l10n.fileLimit
                : context.l10n.attachError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: _isNote ? context.l10n.editNote : context.l10n.editTask,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNote
                            ? context.l10n.noteTitle
                            : context.l10n.fineTunePlan,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isNote
                            ? context.l10n.notesHelp
                            : widget.task.isRecurring
                            ? context.l10n.seriesEdits
                            : context.l10n.giveName,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TaskAssignmentPicker(
                        compact: true,
                        task: _responsibility,
                        lockShared: true,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _listId = value.listId;
                                _assignment = value.assignment;
                                _assigneeId = value.assigneeId;
                                _assigneeName = value.assigneeName;
                              }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('task-title'),
                        controller: _title,
                        textInputAction: _isNote
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: _isNote ? null : (_) => _save(),
                        onChanged: (_) => setState(() {}),
                        maxLength: 160,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: _isNote
                              ? context.l10n.noteTitle
                              : context.l10n.taskTitle,
                          hintText: _isNote
                              ? context.l10n.noteTitleHint
                              : context.l10n.taskTitleHint,
                          counterText: '',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? _isNote
                                  ? context.l10n.noteTitleRequired
                                  : context.l10n.titleRequiredField
                            : null,
                      ),
                      const SizedBox(height: 24),
                      if (_isNote) ...[
                        TextFormField(
                          key: const ValueKey('note-body'),
                          controller: _notes,
                          minLines: 5,
                          maxLines: 12,
                          maxLength: 8000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: context.l10n.noteBody,
                            hintText: context.l10n.noteHint,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_isNote) ...[
                        TextFormField(
                          key: const ValueKey('task-notes'),
                          controller: _notes,
                          maxLength: 8000,
                          minLines: 2,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: context.l10n.notes,
                            hintText: context.l10n.notesHint,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          key: const ValueKey('task-date'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(context.l10n.reviewSchedule),
                          subtitle: Text(
                            taskScheduleLabel(_planningTask, context: context),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _pickDate,
                        ),
                        if (_dueDate != null)
                          TextButton(
                            onPressed: () => _quickDate(null),
                            child: Text(context.l10n.clearDate),
                          ),
                      ],
                      if (suggestTextEncodingRepair(_title.text) != null ||
                          suggestTextEncodingRepair(_notes.text) != null) ...[
                        Text(context.l10n.reviewRepairHelp),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _title.text =
                                suggestTextEncodingRepair(_title.text) ??
                                _title.text;
                            _notes.text =
                                suggestTextEncodingRepair(_notes.text) ??
                                _notes.text;
                          }),
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: Text(context.l10n.reviewRepair),
                        ),
                      ],
                      TextButton.icon(
                        key: const ValueKey('task-more-details'),
                        onPressed: () => setState(
                          () => _detailsExpanded = !_detailsExpanded,
                        ),
                        icon: Icon(
                          _detailsExpanded
                              ? Icons.expand_less_rounded
                              : Icons.tune_rounded,
                        ),
                        label: Text(
                          _detailsExpanded
                              ? context.l10n.fewerDetails
                              : context.l10n.moreDetails,
                        ),
                      ),
                      if (!_detailsExpanded) ...[
                        if (_deadline != null)
                          Text(taskDeadlineLabel(context, _planningTask)),
                        if (_priority > 1 ||
                            _recurrence != 'none' ||
                            _durationMinutes != null)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_priority > 1)
                                Chip(
                                  label: Text(
                                    context.l10n.priorityValue(
                                      context.priorityName(_priority),
                                    ),
                                  ),
                                ),
                              if (_recurrence != 'none')
                                Chip(
                                  label: Text(
                                    context.repeatLabel(_planningTask),
                                  ),
                                ),
                              if (_durationMinutes != null)
                                Chip(
                                  label: Text(
                                    context.l10n.durationMinutes(
                                      _durationMinutes!,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (_checklist.isNotEmpty)
                          ChecklistEditor(
                            items: _checklist,
                            recurring: !_isNote && _recurrence != 'none',
                            onChanged: (items) =>
                                setState(() => _checklist = items),
                          ),
                      ],
                      if (_detailsExpanded) ...[
                        if (!_isNote) ...[
                          TaskPlanningControl(
                            task: _planningTask,
                            onChanged: (task) => setState(() {
                              _deadline = task.deadline;
                              _deadlineHasTime = task.deadlineHasTime;
                              _durationMinutes = task.durationMinutes;
                              _reminderAnchor = task.reminderAnchor;
                            }),
                          ),
                          if (_dueDate != null) ...[
                            const SizedBox(height: 16),
                            ListTile(
                              key: const ValueKey('task-repeat'),
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.repeat_rounded),
                              title: Text(context.l10n.repeat),
                              subtitle: Text(
                                [
                                  _recurrence == 'none'
                                      ? context.repeatName(_recurrence)
                                      : context.repeatLabel(_repeatTask),
                                  if (_recurrence != 'none' &&
                                      _repeatUntil != null)
                                    context.l10n.untilDate(
                                      context.shortDate(_repeatUntil!),
                                    ),
                                ].join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _editRepeat,
                            ),
                            if (_exceptions.isNotEmpty)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  context.l10n.individualDateChanges(
                                    _exceptions.length,
                                  ),
                                ),
                                subtitle: Text(context.l10n.resetDateHelp),
                                children: [
                                  for (final exception in _exceptions)
                                    ListTile(
                                      title: Text(
                                        context.fullDate(
                                          DateTime.parse(
                                            exception.originalDate,
                                          ),
                                        ),
                                      ),
                                      subtitle: Text(
                                        exception.skipped
                                            ? context.l10n.skipped
                                            : '${context.l10n.movedOccurrenceDate(context.fullDate(exception.date!))}${exception.hasTime ? ' · ${context.clockTime(exception.date!)}' : ''}',
                                      ),
                                      trailing: TextButton(
                                        onPressed: () => setState(
                                          () => _exceptions.remove(exception),
                                        ),
                                        child: Text(context.l10n.reset),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                          const SizedBox(height: 24),
                          ReminderControl(
                            hasDate: _planningTask.reminderDate != null,
                            hasTime: _planningTask.reminderHasTime,
                            minutes: _reminderMinutes,
                            time: _reminderTime,
                            onMinutes: (value) =>
                                setState(() => _reminderMinutes = value),
                            onTime: (value) =>
                                setState(() => _reminderTime = value),
                          ),
                          const SizedBox(height: 16),
                          SectionLabel(context.l10n.priority),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in [1, 2, 3])
                                ChoiceChip(
                                  showCheckmark: false,
                                  label: Text(context.priorityName(value)),
                                  avatar: Icon(
                                    Icons.flag_outlined,
                                    size: 17,
                                    color: AppTheme.priorityColor(
                                      context,
                                      value,
                                    ),
                                  ),
                                  selected: _priority == value,
                                  onSelected: (_) =>
                                      setState(() => _priority = value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SectionLabel(context.l10n.theDetails),
                        ],
                        TextFormField(
                          key: const ValueKey('task-labels'),
                          controller: _labels,
                          decoration: InputDecoration(
                            labelText: context.l10n.labels,
                            hintText: context.l10n.labelsExample,
                          ),
                          validator: (text) {
                            final labels = (text ?? '')
                                .split(',')
                                .map((label) => label.trim())
                                .where((label) => label.isNotEmpty)
                                .toSet();
                            return labels.length > 10 ||
                                    labels.any((label) => label.length > 32)
                                ? context.l10n.labelLimit
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ChecklistEditor(
                          items: _checklist,
                          recurring: !_isNote && _recurrence != 'none',
                          onChanged: (items) =>
                              setState(() => _checklist = items),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 20),
                        if (_attachments.isNotEmpty) ...[
                          SectionLabel(context.l10n.attachments),
                          for (var i = 0; i < _attachments.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppSurface(
                                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                                child: Row(
                                  children: [
                                    if (_isImage(_attachments[i]))
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_attachments[i]),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.insert_drive_file_outlined,
                                        color: colors.primary,
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        path.basename(_attachments[i]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Remove ${path.basename(_attachments[i])}',
                                      onPressed: () => setState(
                                        () => _attachments.removeAt(i),
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        TextButton.icon(
                          onPressed: _pickingFile || _saving ? null : _attach,
                          icon: const Icon(Icons.attach_file_rounded, size: 20),
                          label: Text(context.l10n.addAttachment),
                        ),
                        Text(
                          ref.watch(taskRepositoryProvider).ownerKey == 'local'
                              ? context.l10n.fileLocalHelp
                              : context.l10n.fileUploadHelp,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(context.l10n.fileManageHelp),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: ElevatedButton.icon(
              onPressed: _saving || _pickingFile ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _saving
                    ? context.l10n.saving
                    : context.l10n.saveChangesSentence,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
