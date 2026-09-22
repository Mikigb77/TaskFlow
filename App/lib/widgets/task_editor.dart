import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/services/quick_schedule_parser.dart';

/// One editor keeps manual creation, AI review and editing visually consistent.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor(
      {super.key, this.task, this.draft, this.calendarDate, this.onReview});
  final Task? task;
  final TaskDraft? draft;
  final DateTime? calendarDate;
  final ValueChanged<Task>? onReview;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime? _dueDate;
  late bool _hasTime;
  late String _recurrence;
  DateTime? _repeatUntil;
  late int _priority;
  int? _reminderMinutes;
  int? _reminderTime;
  late final List<String> _attachments;
  bool _saving = false;
  late bool _detailsExpanded;
  final _referenceTime = DateTime.now();
  String? _ignoredSuggestion;

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
    _hasTime = widget.task?.hasTime ?? widget.draft?.hasTime ?? false;
    _recurrence = widget.task?.recurrence ?? widget.draft?.recurrence ?? 'none';
    _repeatUntil = widget.task?.repeatUntil ?? widget.draft?.repeatUntil;
    _priority = widget.task?.priority ?? widget.draft?.priority ?? 1;
    _reminderMinutes = widget.task?.reminderMinutes;
    _reminderTime = widget.task?.reminderTime;
    _attachments = [...?widget.task?.filePaths, ...?widget.task?.imagePaths];
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _dueDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
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
        content: const Text('Schedule suggestion applied'),
        action: SnackBarAction(
            label: 'Undo',
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
    setState(() => _saving = true);
    final task = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      dueDate: _dueDate,
      hasTime: _hasTime,
      recurrence: _dueDate == null ? 'none' : _recurrence,
      repeatUntil: _recurrence == 'none' ? null : _repeatUntil,
      completedDates: _recurrence == 'none' ? [] : widget.task?.completedDates,
      priority: _priority,
      reminderMinutes: _reminderMinutes,
      reminderTime: _reminderTime,
      isCompleted:
          _recurrence != 'none' ? false : widget.task?.isCompleted ?? false,
      notes: _notes.text.trim(),
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
                  ? 'Task saved to Inbox'
                  : 'Task added to your calendar'
              : 'Changes saved')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your task. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attach() async {
    final gallery = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Attachments currently stay on this phone. Signing in restores your tasks, but these files will not appear on another device.')),
                  ListTile(
                      leading: const Icon(Icons.photo_outlined),
                      title: const Text('Choose a photo'),
                      onTap: () => Navigator.pop(context, true)),
                  ListTile(
                      leading: const Icon(Icons.attach_file_rounded),
                      title: const Text('Attach a file'),
                      onTap: () => Navigator.pop(context, false)),
                ]))));
    if (gallery == null || !mounted) return;
    try {
      final String? file;
      if (gallery) {
        file =
            (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
      } else {
        file = (await FilePicker.platform.pickFiles())?.files.single.path;
      }
      final selectedFile = file;
      if (selectedFile != null && mounted) {
        setState(() => _attachments.add(selectedFile));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not attach that file. Please try again.')));
      }
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
              ? 'Edit task'
              : widget.draft == null
                  ? widget.onReview != null
                      ? 'Review task'
                      : 'New task'
                  : 'Review task'),
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
                                      ? 'Fine-tune your plan.'
                                      : widget.draft == null
                                          ? 'What’s on your mind?'
                                          : 'Your words, a clear plan.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 8),
                              Text(
                                  widget.task?.isRecurring == true
                                      ? 'Edits apply to the whole repeating task.'
                                      : widget.draft == null
                                          ? 'Give it a name. Add a date whenever you’re ready.'
                                          : 'Check the details before adding it to your calendar.',
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
                                          const SectionLabel(
                                              'Captured from your words'),
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
                                  decoration: const InputDecoration(
                                      labelText: 'Task Title',
                                      hintText: 'e.g. Doctor appointment',
                                      counterText: ''),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Please enter a task title'
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
                                      label: Text(
                                          'Use ${DateFormat('EEE, d MMM').format(suggestion.date)}${suggestion.hasTime ? ' · ${TimeOfDay.fromDateTime(suggestion.date).format(context)}' : ' · no time'}'),
                                      onPressed: () =>
                                          _acceptSchedule(suggestion)),
                                  TextButton(
                                      onPressed: () => setState(() =>
                                          _ignoredSuggestion = _title.text),
                                      child: const Text('Keep as title')),
                                ]),
                                if (suggestion.ambiguousTime)
                                  const Text(
                                      'Choose AM/PM or add the time yourself. No hour has been inferred.'),
                              ],
                              const SizedBox(height: 24),
                              const SectionLabel('Schedule'),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                ActionChip(
                                    label: const Text('Today'),
                                    onPressed: () =>
                                        _quickDate(DateTime.now())),
                                ActionChip(
                                    label: const Text('Tomorrow'),
                                    onPressed: () {
                                      final now = DateTime.now();
                                      _quickDate(DateTime(
                                          now.year, now.month, now.day + 1));
                                    }),
                                if (_dueDate != null)
                                  ActionChip(
                                      label: const Text('Inbox'),
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
                                            ? 'No date · Inbox'
                                            : DateFormat('EEE, d MMM yyyy')
                                                .format(_dueDate!)),
                                        subtitle: const Text('Date'),
                                        onTap: _pickDate,
                                        trailing: _dueDate == null
                                            ? const Icon(Icons.add_rounded)
                                            : IconButton(
                                                tooltip: 'Clear date',
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
                                              ? DateFormat('HH:mm')
                                                  .format(_dueDate!)
                                              : 'Any time'),
                                          subtitle:
                                              const Text('Time (optional)'),
                                          onTap: _pickTime,
                                          trailing: !_hasTime
                                              ? const Icon(Icons.add_rounded)
                                              : IconButton(
                                                  tooltip: 'Remove time',
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
                                        ? 'Fewer details'
                                        : 'More details')),
                              if (_detailsExpanded) ...[
                                if (_dueDate != null) ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      key: ValueKey('repeat-$_recurrence'),
                                      initialValue: _recurrence,
                                      decoration: const InputDecoration(
                                          labelText: 'Repeat',
                                          prefixIcon:
                                              Icon(Icons.repeat_rounded)),
                                      items: Task.repeats.entries
                                          .map((e) => DropdownMenuItem(
                                              value: e.key,
                                              child: Text(e.value,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: (value) => setState(() {
                                            _recurrence = value!;
                                            if (value == 'none') {
                                              _repeatUntil = null;
                                            }
                                          })),
                                  if (_recurrence != 'none')
                                    Row(children: [
                                      Expanded(
                                          child: TextButton.icon(
                                              icon: const Icon(
                                                  Icons.event_outlined,
                                                  size: 18),
                                              label: Text(_repeatUntil == null
                                                  ? 'No end date'
                                                  : 'Until ${DateFormat('d MMM yyyy').format(_repeatUntil!)}'),
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
                                                            DateTime(2101));
                                                if (date != null && mounted) {
                                                  setState(() =>
                                                      _repeatUntil = date);
                                                }
                                              })),
                                      if (_repeatUntil != null)
                                        IconButton(
                                            tooltip: 'Remove end date',
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
                                const SectionLabel('Priority'),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final value in [1, 2, 3])
                                    ChoiceChip(
                                        showCheckmark: false,
                                        label:
                                            Text(AppTheme.priorityLabel(value)),
                                        avatar: Icon(Icons.flag_outlined,
                                            size: 17,
                                            color: AppTheme.priorityColor(
                                                context, value)),
                                        selected: _priority == value,
                                        onSelected: (_) =>
                                            setState(() => _priority = value)),
                                ]),
                                const SizedBox(height: 24),
                                const SectionLabel('The details'),
                                TextFormField(
                                    key: const ValueKey('task-notes'),
                                    controller: _notes,
                                    maxLength: 8000,
                                    minLines: 3,
                                    maxLines: 6,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                        labelText: 'Additional Notes',
                                        hintText:
                                            'Anything you’d like to remember…',
                                        alignLabelWithHint: true,
                                        counterText: '')),
                                const SizedBox(height: 20),
                                if (_attachments.isNotEmpty) ...[
                                  const SectionLabel('Attachments'),
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
                                    onPressed: _attach,
                                    icon: const Icon(Icons.attach_file_rounded,
                                        size: 20),
                                    label: const Text('Add attachment')),
                                Text('Attachments stay on this device.',
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ])),
                  )))),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(edit ? Icons.check_rounded : Icons.add_rounded,
                        size: 20),
                label: Text(_saving
                    ? 'Saving…'
                    : widget.onReview != null
                        ? 'Keep changes'
                        : edit
                            ? 'Save changes'
                            : 'Create Task'),
              ))),
    );
  }
}
