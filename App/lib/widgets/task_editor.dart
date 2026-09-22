import 'package:agenda/l10n/region.dart';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/services/quick_schedule_parser.dart';

/// One editor keeps manual creation, AI review and editing visually consistent.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor(
      {super.key,
      this.task,
      this.draft,
      this.calendarDate,
      this.onReview,
      this.initialListId});
  final Task? task;
  final TaskDraft? draft;
  final DateTime? calendarDate;
  final ValueChanged<Task>? onReview;
  final String? initialListId;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _labels;
  String? _listId;
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
  bool _pickingFile = false;
  late bool _detailsExpanded;
  final _referenceTime = DateTime.now();
  String? _ignoredSuggestion;
  late List<ChecklistItem> _checklist;

  @override
  void initState() {
    super.initState();
    _detailsExpanded =
        widget.task != null || widget.draft != null || widget.onReview != null;
    final day = widget.calendarDate;
    _dueDate = widget.task?.dueDate ??
        widget.draft?.dueDate ??
        (day == null ? null : DateTime(day.year, day.month, day.day));
    _title = TextEditingController(
        text: widget.task?.title ?? widget.draft?.title ?? '');
    _notes = TextEditingController(
        text: widget.task?.notes ?? widget.draft?.notes ?? '');
    _labels = TextEditingController(text: widget.task?.labels.join(', ') ?? '');
    _listId = widget.task?.listId ?? widget.initialListId;
    _hasTime = widget.task?.hasTime ?? widget.draft?.hasTime ?? false;
    _recurrence = widget.task?.recurrence ?? widget.draft?.recurrence ?? 'none';
    _repeatInterval =
        widget.task?.repeatInterval ?? widget.draft?.repeatInterval ?? 1;
    _repeatWeekdays = [
      ...(widget.task?.repeatWeekdays ?? widget.draft?.repeatWeekdays ?? [])
    ];
    _exceptions = [...?widget.task?.exceptions];
    _repeatUntil = widget.task?.repeatUntil ?? widget.draft?.repeatUntil;
    _priority = widget.task?.priority ?? widget.draft?.priority ?? 1;
    _reminderMinutes = widget.task?.reminderMinutes;
    _reminderTime = widget.task?.reminderTime;
    _attachments = [...?widget.task?.filePaths, ...?widget.task?.imagePaths];
    _checklist = [...(widget.task?.checklist ?? widget.draft?.checklist ?? [])];
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _labels.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _dueDate ?? DateTime.now(),
        firstDate: pickerFirstDate(_dueDate),
        lastDate: pickerLastDate(_dueDate));
    if (date == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(date.year, date.month, date.day,
          _hasTime ? _dueDate!.hour : 0, _hasTime ? _dueDate!.minute : 0);
      if (_repeatUntil != null && _repeatUntil!.isBefore(Task.day(date))) {
        _repeatUntil = null;
      }
    });
  }

  Future<void> _pickTime() async {
    if (_dueDate == null) await _pickDate();
    if (_dueDate == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: _hasTime
            ? TimeOfDay.fromDateTime(_dueDate!)
            : const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day,
          time.hour, time.minute);
      _hasTime = true;
    });
  }

  bool _isImage(String file) => ['.jpg', '.jpeg', '.png', '.gif', '.webp']
      .contains(path.extension(file).toLowerCase());

  void _quickDate(DateTime? date) => setState(() {
        if (date == null) {
          _dueDate = null;
          _hasTime = false;
          _recurrence = 'none';
          _repeatUntil = null;
        } else {
          _dueDate = DateTime(date.year, date.month, date.day,
              _hasTime ? _dueDate!.hour : 0, _hasTime ? _dueDate!.minute : 0);
          if (_repeatUntil != null && _repeatUntil!.isBefore(Task.day(date))) {
            _repeatUntil = null;
          }
        }
      });

  void _acceptSchedule(ScheduleSuggestion suggestion) {
    final previousTitle = _title.text;
    final previousDate = _dueDate;
    final previousHasTime = _hasTime;
    final previousRepeatUntil = _repeatUntil;
    setState(() {
      _title.text = suggestion.title;
      _dueDate = suggestion.date;
      _hasTime = suggestion.hasTime;
      if (_repeatUntil != null &&
          _repeatUntil!.isBefore(Task.day(suggestion.date))) {
        _repeatUntil = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.suggestionApplied),
        action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () {
              if (mounted) {
                setState(() {
                  _title.text = previousTitle;
                  _dueDate = previousDate;
                  _hasTime = previousHasTime;
                  _repeatUntil = previousRepeatUntil;
                });
              }
            })));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final before = widget.task;
    final ruleChanged = before != null &&
        (before.dueDate != _dueDate ||
            before.hasTime != _hasTime ||
            before.recurrence != _recurrence ||
            before.repeatInterval != _repeatInterval ||
            before.repeatUntil != _repeatUntil ||
            !const ListEquality<int>()
                .equals(before.repeatWeekdays, _repeatWeekdays));
    if (ruleChanged && _exceptions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(context.l10n.changeSeriesQuestion),
                  content: Text(context.l10n.changeSeriesHelp),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.keepEditing)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.resetSave))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final task = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      dueDate: _dueDate,
      hasTime: _hasTime,
      recurrence: _dueDate == null ? 'none' : _recurrence,
      repeatInterval: _recurrence == 'none' ? 1 : _repeatInterval,
      repeatWeekdays: _recurrence == 'weekly' ? _repeatWeekdays : [],
      exceptions: ruleChanged || _recurrence == 'none' ? [] : _exceptions,
      repeatUntil: _recurrence == 'none' ? null : _repeatUntil,
      completedDates: _recurrence == 'none' ? [] : widget.task?.completedDates,
      priority: _priority,
      reminderMinutes: _reminderMinutes,
      reminderTime: _reminderTime,
      isCompleted:
          _recurrence != 'none' ? false : widget.task?.isCompleted ?? false,
      notes: _notes.text.trim(),
      checklist: _checklist,
      listId: _listId,
      labels: _labels.text
          .split(',')
          .where((label) => label.trim().isNotEmpty)
          .toList(),
      imagePaths: _attachments.where(_isImage).toList(),
      filePaths: _attachments.where((file) => !_isImage(file)).toList(),
    );
    try {
      if (widget.onReview != null) {
        widget.onReview!(task);
        if (mounted) Navigator.pop(context);
        return;
      }
      final notifier = ref.read(taskProvider.notifier);
      if (widget.task == null) {
        await notifier.addTask(task);
      } else {
        await notifier.updateTask(task);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.task == null
              ? _dueDate == null
                  ? context.l10n.taskSavedInbox
                  : context.l10n.taskAddedCalendar
              : context.l10n.changesSaved)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.taskSaveError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attach() async {
    if (_pickingFile || _saving) return;
    if (_attachments.length >= 20) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.fileLimit)));
      return;
    }
    final local = ref.read(taskRepositoryProvider).ownerKey == 'local';
    final gallery = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(local
                          ? context.l10n.fileLocalHelp
                          : context.l10n.fileUploadHelp)),
                  ListTile(
                      leading: const Icon(Icons.photo_outlined),
                      title: Text(context.l10n.choosePhoto),
                      onTap: () => Navigator.pop(context, true)),
                  ListTile(
                      leading: const Icon(Icons.attach_file_rounded),
                      title: Text(context.l10n.attachFile),
                      onTap: () => Navigator.pop(context, false)),
                ]))));
    if (gallery == null || !mounted) return;
    setState(() => _pickingFile = true);
    try {
      final String? file;
      if (gallery) {
        file =
            (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
      } else {
        file = (await FilePicker.platform.pickFiles())?.files.single.path;
      }
      final selectedFile =
          file == null ? null : await AttachmentFiles().retain(file);
      if (selectedFile != null && mounted) {
        setState(() => _attachments.add(selectedFile));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is FormatException
                ? context.l10n.fileLimit
                : context.l10n.attachError)));
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final edit = widget.task != null && widget.onReview == null;
    final suggestion = widget.task == null &&
            widget.draft == null &&
            widget.onReview == null &&
            _ignoredSuggestion != _title.text
        ? QuickScheduleParser.parse(_title.text, _referenceTime)
        : null;
    return Scaffold(
      appBar: CustomAppBar(
          title: edit
              ? context.l10n.editTask
              : widget.draft == null
                  ? widget.onReview != null
                      ? context.l10n.reviewTask
                      : context.l10n.newTask
                  : context.l10n.reviewTask),
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
                                  edit
                                      ? context.l10n.fineTunePlan
                                      : widget.draft == null
                                          ? context.l10n.onYourMind
                                          : context.l10n.wordsPlan,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 8),
                              Text(
                                  widget.task?.isRecurring == true
                                      ? context.l10n.seriesEdits
                                      : widget.draft == null
                                          ? context.l10n.giveName
                                          : context.l10n.checkBeforeAdd,
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant)),
                              const SizedBox(height: 24),
                              if (widget.draft != null) ...[
                                AppSurface(
                                    color: colors.primaryContainer,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SectionLabel(
                                              context.l10n.capturedWords),
                                          Text(widget.draft!.transcript,
                                              style: TextStyle(
                                                  color: colors
                                                      .onPrimaryContainer)),
                                        ])),
                                const SizedBox(height: 16),
                                if (widget.draft!.questions.isNotEmpty) ...[
                                  MessageBanner(
                                      widget.draft!.questions.join('\n'),
                                      isError: true),
                                  const SizedBox(height: 16)
                                ],
                              ],
                              TextFormField(
                                  key: const ValueKey('task-title'),
                                  controller: _title,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _save(),
                                  onChanged: (_) => setState(() {}),
                                  maxLength: 160,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                      labelText: context.l10n.taskTitle,
                                      hintText: 'e.g. Doctor appointment',
                                      counterText: ''),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? context.l10n.titleRequiredField
                                          : null),
                              if (suggestion != null) ...[
                                const SizedBox(height: 10),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  ActionChip(
                                      key:
                                          const ValueKey('schedule-suggestion'),
                                      avatar: const Icon(
                                          Icons.auto_awesome_outlined,
                                          size: 16),
                                      label: Text(context.l10n.useSchedule(
                                          '${DateFormat.MMMEd(context.localeName).format(suggestion.date)} · ${suggestion.hasTime ? context.clockTime(suggestion.date) : context.l10n.anyTime}')),
                                      onPressed: () =>
                                          _acceptSchedule(suggestion)),
                                  TextButton(
                                      onPressed: () => setState(() =>
                                          _ignoredSuggestion = _title.text),
                                      child: Text(context.l10n.keepAsTitle)),
                                ]),
                                if (suggestion.ambiguousTime)
                                  Text(context.l10n.ambiguousTimeHelp),
                              ],
                              const SizedBox(height: 24),
                              SectionLabel(context.l10n.schedule),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                ActionChip(
                                    label: Text(context.l10n.today),
                                    onPressed: () =>
                                        _quickDate(DateTime.now())),
                                ActionChip(
                                    label: Text(context.l10n.tomorrow),
                                    onPressed: () {
                                      final now = DateTime.now();
                                      _quickDate(DateTime(
                                          now.year, now.month, now.day + 1));
                                    }),
                                if (_dueDate != null)
                                  ActionChip(
                                      label: Text(context.l10n.inbox),
                                      onPressed: () => _quickDate(null)),
                              ]),
                              const SizedBox(height: 8),
                              AppSurface(
                                  padding: EdgeInsets.zero,
                                  child: Column(children: [
                                    ListTile(
                                        key: const ValueKey('task-date'),
                                        leading: const Icon(
                                            Icons.calendar_today_outlined),
                                        title: Text(_dueDate == null
                                            ? context.l10n.inboxDate
                                            : DateFormat.yMMMEd(
                                                    context.localeName)
                                                .format(_dueDate!)),
                                        subtitle: Text(context.l10n.date),
                                        onTap: _pickDate,
                                        trailing: _dueDate == null
                                            ? const Icon(Icons.add_rounded)
                                            : IconButton(
                                                tooltip: context.l10n.clearDate,
                                                onPressed: () => setState(() {
                                                      _dueDate = null;
                                                      _hasTime = false;
                                                      _recurrence = 'none';
                                                      _repeatUntil = null;
                                                    }),
                                                icon: const Icon(
                                                    Icons.close_rounded))),
                                    if (_dueDate != null)
                                      ListTile(
                                          key: const ValueKey('task-time'),
                                          leading: const Icon(
                                              Icons.schedule_outlined),
                                          title: Text(_hasTime
                                              ? context.clockTime(_dueDate!)
                                              : context.l10n.anyTime),
                                          subtitle:
                                              Text(context.l10n.optionalTime),
                                          onTap: _pickTime,
                                          trailing: !_hasTime
                                              ? const Icon(Icons.add_rounded)
                                              : IconButton(
                                                  tooltip:
                                                      context.l10n.removeTime,
                                                  onPressed: () => setState(() {
                                                        _hasTime = false;
                                                        _dueDate =
                                                            Task.day(_dueDate!);
                                                      }),
                                                  icon: const Icon(
                                                      Icons.close_rounded))),
                                  ])),
                              const SizedBox(height: 12),
                              if (!_detailsExpanded && _dueDate != null)
                                ReminderChip(
                                    task: Task(
                                        title: _title.text,
                                        dueDate: _dueDate,
                                        hasTime: _hasTime,
                                        priority: _priority,
                                        reminderMinutes: _reminderMinutes,
                                        reminderTime: _reminderTime),
                                    onChanged: (task) => setState(() {
                                          _reminderMinutes =
                                              task.reminderMinutes;
                                          _reminderTime = task.reminderTime;
                                        })),
                              if (!edit &&
                                  widget.draft == null &&
                                  widget.onReview == null)
                                TextButton.icon(
                                    key: const ValueKey('task-more-details'),
                                    onPressed: () => setState(() =>
                                        _detailsExpanded = !_detailsExpanded),
                                    icon: Icon(_detailsExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.tune_rounded),
                                    label: Text(_detailsExpanded
                                        ? context.l10n.fewerDetails
                                        : context.l10n.moreDetails)),
                              if (_detailsExpanded) ...[
                                if (_dueDate != null) ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      key: ValueKey('repeat-$_recurrence'),
                                      initialValue: _recurrence,
                                      decoration: InputDecoration(
                                          labelText: context.l10n.repeat,
                                          prefixIcon:
                                              const Icon(Icons.repeat_rounded)),
                                      items: Task.repeats.entries
                                          .map((e) => DropdownMenuItem(
                                              value: e.key,
                                              child: Text(
                                                  context.repeatName(e.key),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: (value) => setState(() {
                                            _recurrence = value!;
                                            if (value == 'none') {
                                              _repeatUntil = null;
                                              _repeatInterval = 1;
                                            }
                                            if (value != 'weekly') {
                                              _repeatWeekdays = [];
                                            }
                                          })),
                                  if (_recurrence != 'none')
                                    RepeatRuleControl(
                                        recurrence: _recurrence,
                                        interval: _repeatInterval,
                                        weekdays: _repeatWeekdays,
                                        onChanged: (interval, days) =>
                                            setState(() {
                                              _repeatInterval = interval;
                                              _repeatWeekdays = days;
                                            })),
                                  if (_exceptions.isNotEmpty)
                                    ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(
                                            '${_exceptions.length} individual date changes'),
                                        subtitle:
                                            Text(context.l10n.resetDateHelp),
                                        children: [
                                          for (final exception in _exceptions)
                                            ListTile(
                                                title: Text(
                                                    exception.originalDate),
                                                subtitle: Text(exception.skipped
                                                    ? context.l10n.skipped
                                                    : 'Moved to ${Task.dateKey(exception.date!)}${exception.hasTime ? ' · ${TimeOfDay.fromDateTime(exception.date!).format(context)}' : ''}'),
                                                trailing: TextButton(
                                                    onPressed: () => setState(
                                                        () => _exceptions
                                                            .remove(exception)),
                                                    child: Text(
                                                        context.l10n.reset)))
                                        ]),
                                  if (_recurrence != 'none')
                                    Row(children: [
                                      Expanded(
                                          child: TextButton.icon(
                                              icon: const Icon(
                                                  Icons.event_outlined,
                                                  size: 18),
                                              label: Text(_repeatUntil == null
                                                  ? context.l10n.noEndDate
                                                  : context.l10n.untilDate(
                                                      context.shortDate(
                                                          _repeatUntil!))),
                                              onPressed: () async {
                                                final date =
                                                    await showDatePicker(
                                                        context: context,
                                                        initialDate:
                                                            _repeatUntil ??
                                                                _dueDate!,
                                                        firstDate:
                                                            Task.day(_dueDate!),
                                                        lastDate:
                                                            pickerLastDate(
                                                                _repeatUntil ??
                                                                    _dueDate));
                                                if (date != null && mounted) {
                                                  setState(() =>
                                                      _repeatUntil = date);
                                                }
                                              })),
                                      if (_repeatUntil != null)
                                        IconButton(
                                            tooltip: context.l10n.removeEndDate,
                                            onPressed: () => setState(
                                                () => _repeatUntil = null),
                                            icon: const Icon(
                                                Icons.close_rounded)),
                                    ]),
                                ],
                                const SizedBox(height: 24),
                                ReminderControl(
                                    hasDate: _dueDate != null,
                                    hasTime: _hasTime,
                                    minutes: _reminderMinutes,
                                    time: _reminderTime,
                                    onMinutes: (value) => setState(
                                        () => _reminderMinutes = value),
                                    onTime: (value) =>
                                        setState(() => _reminderTime = value)),
                                const SizedBox(height: 16),
                                SectionLabel(context.l10n.priority),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final value in [1, 2, 3])
                                    ChoiceChip(
                                        showCheckmark: false,
                                        label:
                                            Text(context.priorityName(value)),
                                        avatar: Icon(Icons.flag_outlined,
                                            size: 17,
                                            color: AppTheme.priorityColor(
                                                context, value)),
                                        selected: _priority == value,
                                        onSelected: (_) =>
                                            setState(() => _priority = value)),
                                ]),
                                const SizedBox(height: 24),
                                SectionLabel(context.l10n.theDetails),
                                TaskListPicker(
                                    listId: _listId,
                                    onChanged: (id) =>
                                        setState(() => _listId = id)),
                                const SizedBox(height: 12),
                                TextFormField(
                                    key: const ValueKey('task-labels'),
                                    controller: _labels,
                                    decoration: InputDecoration(
                                        labelText: context.l10n.labels,
                                        hintText: 'home, errands, calls'),
                                    validator: (text) {
                                      final labels = (text ?? '')
                                          .split(',')
                                          .map((label) => label.trim())
                                          .where((label) => label.isNotEmpty)
                                          .toSet();
                                      return labels.length > 10 ||
                                              labels.any(
                                                  (label) => label.length > 32)
                                          ? context.l10n.labelLimit
                                          : null;
                                    }),
                                const SizedBox(height: 16),
                                ChecklistEditor(
                                    items: _checklist,
                                    recurring: _recurrence != 'none',
                                    onChanged: (items) =>
                                        setState(() => _checklist = items)),
                                const SizedBox(height: 12),
                                TextFormField(
                                    key: const ValueKey('task-notes'),
                                    controller: _notes,
                                    maxLength: 8000,
                                    minLines: 3,
                                    maxLines: 6,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                        labelText: context.l10n.additionalNotes,
                                        hintText: context.l10n.notesHint,
                                        alignLabelWithHint: true,
                                        counterText: '')),
                                const SizedBox(height: 20),
                                if (_attachments.isNotEmpty) ...[
                                  SectionLabel(context.l10n.attachments),
                                  for (var i = 0; i < _attachments.length; i++)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: AppSurface(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 4, 4, 4),
                                            child: Row(children: [
                                              if (_isImage(_attachments[i]))
                                                ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.file(
                                                        File(_attachments[i]),
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Icon(Icons
                                                                .broken_image_outlined)))
                                              else
                                                Icon(
                                                    Icons
                                                        .insert_drive_file_outlined,
                                                    color: colors.primary),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Text(
                                                      path.basename(
                                                          _attachments[i]),
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              IconButton(
                                                  tooltip:
                                                      'Remove ${path.basename(_attachments[i])}',
                                                  onPressed: () => setState(
                                                      () => _attachments
                                                          .removeAt(i)),
                                                  icon: const Icon(
                                                      Icons.close_rounded,
                                                      size: 18)),
                                            ]))),
                                ],
                                TextButton.icon(
                                    onPressed: _pickingFile || _saving
                                        ? null
                                        : _attach,
                                    icon: const Icon(Icons.attach_file_rounded,
                                        size: 20),
                                    label: Text(context.l10n.addAttachment)),
                                Text(
                                    ref
                                                .watch(taskRepositoryProvider)
                                                .ownerKey ==
                                            'local'
                                        ? context.l10n.fileLocalHelp
                                        : context.l10n.fileUploadHelp,
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12)),
                                if (edit)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(context.l10n.fileManageHelp)),
                              ],
                            ])),
                  )))),
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
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(edit ? Icons.check_rounded : Icons.add_rounded,
                        size: 20),
                label: Text(_saving
                    ? context.l10n.saving
                    : widget.onReview != null
                        ? context.l10n.keepChanges
                        : edit
                            ? context.l10n.saveChangesSentence
                            : context.l10n.createTask),
              ))),
    );
  }
}
