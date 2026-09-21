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

/// One editor keeps manual creation, AI review and editing visually consistent.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({super.key, this.task, this.draft, this.calendarDate});
  final Task? task;
  final TaskDraft? draft;
  final DateTime? calendarDate;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _due;
  late DateTime? _dueDate;
  late int _priority;
  late final List<String> _attachments;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final day = widget.calendarDate;
    _dueDate = widget.task?.dueDate ??
        widget.draft?.dueDate ??
        (day == null ? null : DateTime(day.year, day.month, day.day));
    _title = TextEditingController(
        text: widget.task?.title ?? widget.draft?.title ?? '');
    _notes = TextEditingController(
        text: widget.task?.notes ?? widget.draft?.notes ?? '');
    _due = TextEditingController(text: _dateLabel);
    _priority = widget.task?.priority ?? widget.draft?.priority ?? 1;
    _attachments = [...?widget.task?.filePaths, ...?widget.task?.imagePaths];
  }

  String get _dateLabel => _dueDate == null
      ? ''
      : DateFormat('EEE, d MMM yyyy · HH:mm').format(_dueDate!);
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _dueDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()));
    if (time == null || !mounted) return;
    setState(() {
      _dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _due.text = _dateLabel;
    });
  }

  bool _isImage(String file) => ['.jpg', '.jpeg', '.png', '.gif', '.webp']
      .contains(path.extension(file).toLowerCase());

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final task = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      dueDate: _dueDate!,
      priority: _priority,
      isCompleted: widget.task?.isCompleted ?? false,
      notes: _notes.text.trim(),
      imagePaths: _attachments.where(_isImage).toList(),
      filePaths: _attachments.where((file) => !_isImage(file)).toList(),
    );
    try {
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
              ? 'Task added to your calendar'
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
    final edit = widget.task != null;
    return Scaffold(
      appBar: CustomAppBar(
          title: edit
              ? 'Edit task'
              : widget.draft == null
                  ? 'New task'
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
                                  widget.draft == null
                                      ? 'Give it a name. Make a little time for it.'
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
                              const SizedBox(height: 24),
                              const SectionLabel('Schedule'),
                              Semantics(
                                  button: true,
                                  label: 'Choose due date and time',
                                  child: GestureDetector(
                                      onTap: _pickDateTime,
                                      child: AbsorbPointer(
                                          child: TextFormField(
                                        key: const ValueKey('task-due'),
                                        controller: _due,
                                        decoration: InputDecoration(
                                            labelText: _dueDate == null
                                                ? 'Select Due Date & Time'
                                                : 'Due Date & Time',
                                            prefixIcon: const Icon(
                                                Icons.calendar_today_outlined),
                                            suffixIcon: const Icon(
                                                Icons.expand_more_rounded)),
                                        validator: (_) => _dueDate == null
                                            ? 'Please pick a due date and time'
                                            : null,
                                      )))),
                              const SizedBox(height: 24),
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
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AppSurface(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 4, 4, 4),
                                          child: Row(children: [
                                            if (_isImage(_attachments[i]))
                                              ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            IconButton(
                                                tooltip:
                                                    'Remove ${path.basename(_attachments[i])}',
                                                onPressed: () => setState(() =>
                                                    _attachments.removeAt(i)),
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
                    : edit
                        ? 'Save changes'
                        : 'Create Task'),
              ))),
    );
  }
}
