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
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/reminder_ask_sheet.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/reminder_plans.dart';

/// Edits a saved task or note, or fills in a new task: a [task] with no id
/// is new. That is how an account without Pro creates tasks (DECISIONS.md,
/// 2026-10-18 later): the title first, then the day and an optional time,
/// and the rest under `Más detalles`. A new task is saved on the phone first
/// and lands as a capture's does: on [page], the task page the form was
/// opened from, or else on Calendar, which [showCalendar] brings forward.
///
/// Until a new task is saved, its title and notes wait in the capture store,
/// as a capture's words do, so they survive Android closing the app: in
/// [captureId], the capture its words came from, or in a new one from the
/// first character typed.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    required this.task,
    this.page,
    this.showCalendar = false,
    this.captureId,
    this.askedToSpeak = false,
  });
  final Task task;
  final Object? page;
  final bool showCalendar;
  final String? captureId;

  /// A new task opened by a way in that asks to speak (the widget, the voice
  /// shortcut): without the mic, the form says why above the title.
  final bool askedToSpeak;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final _form = GlobalKey<FormState>();
  // The steps show in both the short and the full form; one key keeps a
  // half-typed step across `Más detalles`.
  final _steps = GlobalKey();
  late final TextEditingController _title;
  // Caps the title at three lines only while typing in it.
  final _titleFocus = FocusNode();
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
  ReminderPlan? _reminderPlan;
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
    reminderPlan: _isNote ? null : _reminderPlan,
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

  /// A new task, not saved yet: the form for accounts without Pro.
  bool get _creating => widget.task.id == null;

  /// A new task opened inside a project shows its project by the day, so it
  /// is clear where the task goes; otherwise the project waits in `Más
  /// detalles`. Decided once, so the row never jumps.
  late final bool _projectUpFront = _creating && widget.task.listId != null;

  /// Words carried into a new task beyond its title show at once.
  late final bool _notesUpFront =
      _creating && (widget.task.notes?.trim().isNotEmpty ?? false);

  // A new task's words, kept in the capture store until it is saved.
  late final CaptureStore _captures;
  late final String _owner;
  late final ProviderContainer _container;
  CaptureSession? _capture;
  String? _captureId;
  String _kept = '';
  bool _letGo = false;
  Future<void> _keeping = Future.value();

  /// The capture's text: the title, then a line break and the notes when
  /// there are any, so a resumed capture opens with both again.
  String get _words {
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    return notes.isEmpty ? title : '$title\n$notes';
  }

  void _keepWords() {
    final text = _words;
    if (_letGo || text == _kept) return;
    _kept = text;
    _keeping = _keeping.then((_) => _writeWords(text));
  }

  Future<void> _writeWords(String text) async {
    try {
      final id = _captureId;
      if (id == null) {
        // Created at the first character typed, never before.
        if (text.trim().isEmpty) return;
        _capture = await _captures.create(
          _owner,
          _zone(),
          text: text,
          source: 'typed',
        );
        _captureId = _capture!.id;
        _container.invalidate(pendingCapturesProvider);
        return;
      }
      final session = _capture ??= await _captures.read(id, _owner);
      if (session == null || session.terminal) {
        // Gone meanwhile: the next words start a new one.
        _capture = null;
        _captureId = null;
        return _writeWords(text);
      }
      final next = session.copyWith(text: text);
      if (CaptureStore.isEmpty(next)) {
        // Every word gone: nothing is kept.
        await _captures.discard(id, _owner);
        _capture = null;
        _captureId = null;
        _container.invalidate(pendingCapturesProvider);
        return;
      }
      await _captures.update(next);
      _capture = next;
    } catch (_) {
      // The words stay in the form; the next change writes them again.
      _kept = '';
    }
  }

  /// The zone a new capture is stored in: the one chosen in Ajustes, or
  /// the account's. Its words are typed, so it matters only if the
  /// assistant reads them later.
  String _zone() {
    final chosen = _container.read(regionalProvider).captureTimezone;
    if (CaptureTimezone.valid(chosen)) return chosen!;
    final account = _container.read(authProvider).account?.timezone;
    return CaptureTimezone.valid(account) ? account! : 'UTC';
  }

  /// The task is saved, or the form closes with no title: its words no
  /// longer wait under `Sin guardar`.
  void _letGoOfWords() {
    if (!_creating || _letGo) return;
    _letGo = true;
    _keeping = _keeping.then((_) async {
      final id = _captureId;
      if (id == null) return;
      _captureId = null;
      try {
        await _captures.discard(id, _owner);
      } catch (_) {
        // It waits under `Sin guardar`, where it can be dropped.
      }
      _container.invalidate(pendingCapturesProvider);
    });
  }

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_titleFocusChanged);
    final task = widget.task;
    _isNote = task.isNote;
    _detailsExpanded = false;
    _dueDate = task.dueDate;
    _title = TextEditingController(text: task.title);
    _notes = TextEditingController(text: task.notes ?? '');
    _labels = TextEditingController(text: task.labels.join(', '));
    _listId = task.listId;
    // A new task follows its project: everyone in a shared one, until a
    // person is chosen. One given a person (opened under their chip)
    // keeps them.
    _assignment = _creating && task.assignment != 'member'
        ? null
        : task.assignment;
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
    _reminderPlan = task.reminderPlan;
    _attachments = [...task.filePaths, ...task.imagePaths];
    _checklist = [...task.checklist];
    _unchanged = _edited().toMap();
    if (_creating) {
      _captures = ref.read(captureStoreProvider);
      _owner = ref.read(captureOwnerProvider);
      _container = ProviderScope.containerOf(context, listen: false);
      _captureId = widget.captureId;
      _kept = _words;
      _title.addListener(_keepWords);
      _notes.addListener(_keepWords);
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _title.dispose();
    _notes.dispose();
    _labels.dispose();
    super.dispose();
  }

  /// The edit form's date sheet.
  Future<void> _pickDate() async {
    final result = await editSchedule(
      context,
      date: _dueDate,
      hasTime: _hasTime,
    );
    if (result == null || !mounted) return;
    _schedule(result.date, result.hasTime);
  }

  /// A new task's «Elegir día»: a sheet with only days, where the day
  /// tapped applies at once and a time already chosen stays.
  Future<void> _pickDay() async {
    _dropKeyboard();
    final result = await editSchedule(
      context,
      date: _dueDate,
      hasTime: false,
      dayOnly: true,
    );
    if (result == null || !mounted) return;
    _setDay(result.date);
  }

  /// A new task's day and time chips first put the keyboard away, so the
  /// rest of the form shows. Unfocusing the field itself, not the form's
  /// scope, keeps a sheet or picker from giving it the focus back when it
  /// closes; tapping the title brings the keyboard back.
  void _titleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _dropKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _schedule(DateTime? date, bool hasTime) => setState(() {
    _dueDate = date;
    _hasTime = hasTime && date != null;
    if (_dueDate == null) {
      _recurrence = 'none';
      _repeatInterval = 1;
      _repeatWeekdays = [];
      _repeatUntil = null;
    } else if (_repeatUntil?.isBefore(Task.day(_dueDate!)) ?? false) {
      _repeatUntil = null;
    }
  });

  /// A new task's day chip: [day], keeping a time already chosen; null
  /// takes the date away.
  void _setDay(DateTime? day) {
    final time = _hasTime ? _dueDate : null;
    _schedule(
      day == null || time == null
          ? day
          : DateTime(day.year, day.month, day.day, time.hour, time.minute),
      time != null,
    );
  }

  /// A new task's time, on its day: the phone's time picker, opened on its
  /// number boxes, so the hour and minutes go in on the number keys. It
  /// starts on the next full hour.
  Future<void> _pickTime() async {
    final day = _dueDate;
    if (day == null) return;
    _dropKeyboard();
    final next = (TimeOfDay.now().hour + 1) % 24;
    final picked = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      initialTime: _hasTime
          ? TimeOfDay.fromDateTime(day)
          : TimeOfDay(hour: next, minute: 0),
    );
    if (picked == null || !mounted || _dueDate == null) return;
    final on = _dueDate!;
    _schedule(
      DateTime(on.year, on.month, on.day, picked.hour, picked.minute),
      true,
    );
  }

  bool _isImage(String file) => [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
  ].contains(path.extension(file).toLowerCase());

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

  /// The task as the form would save it. Its plan stays only while it
  /// applies: with a deadline or a day, and not repeating. The form keeps it
  /// meanwhile, so a day taken away and put back brings it back.
  Task _edited() {
    final task = _withoutPlan();
    return ReminderPlans.plannable(task)
        ? task.copyWith(reminderPlan: _isNote ? null : _reminderPlan)
        : task;
  }

  Task _withoutPlan() {
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
      createdByName: before.createdByName,
      labels: _labels.text
          .split(',')
          .where((label) => label.trim().isNotEmpty)
          .toList(),
      imagePaths: _attachments.where(_isImage).toList(),
      filePaths: _attachments.where((file) => !_isImage(file)).toList(),
    );
  }

  /// Back and Save behave the same: an unchanged form just closes, and
  /// changes are saved, with Undo (D12). A new task with no title just
  /// closes; with one, Back saves it too.
  Future<void> _back() async {
    if (_saving) return;
    if (_creating && _title.text.trim().isEmpty) {
      _letGoOfWords();
      Navigator.pop(context);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    // Leaving the step field keeps a step typed without Enter; focus
    // changes land in a microtask, so wait for that one first.
    _saving = true;
    FocusScope.of(context).unfocus();
    await Future<void>.microtask(() {});
    _saving = false;
    if (!mounted) return;
    if (_creating) {
      await _add();
      return;
    }
    if (const DeepCollectionEquality().equals(_edited().toMap(), _unchanged)) {
      Navigator.pop(context);
      return;
    }
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

  /// Saves a new task on the phone (it syncs behind, so it works offline),
  /// then lands as a capture does: Calendar, or the page the form came
  /// from, shows it lit, with Deshacer. The message says the day it went
  /// to, or its deadline's, after Back too (D6). A task with only a
  /// deadline lands on its deadline's day, as a capture does.
  Future<void> _add() async {
    setState(() => _saving = true);
    final task = _edited();
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final notifier = ref.read(taskProvider.notifier);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final strings = context.l10n;
      final day = task.dueDate == null ? null : Task.day(task.dueDate!);
      final due = task.deadline == null ? null : Task.day(task.deadline!);
      final message = day != null
          ? strings.taskAddedOn(context.weekdayDate(day))
          : due != null
          ? strings.taskAddedDue(context.weekdayDate(due))
          : strings.taskSavedInbox;
      final id = await notifier.addTask(task);
      _letGoOfWords();
      // Shown from the phone at once, even while a sync is under way.
      await notifier.showLocal();
      if (!mounted) return;
      if (widget.showCalendar) {
        navigator.popUntil((route) => route.isFirst);
      } else {
        navigator.pop();
      }
      final focus = CalendarFocus(
        day ?? due,
        {id},
        page: widget.page,
        showCalendar: widget.showCalendar,
        undated: day == null && due == null,
      );
      container.read(calendarFocusProvider.notifier).state = focus;
      final feedback = showFeedback(
        messenger,
        message,
        actionLabel: strings.undo,
        onAction: () async {
          if (!messenger.mounted ||
              !identical(container.read(taskProvider.notifier), notifier)) {
            return;
          }
          try {
            await notifier.deleteTask(id);
            // The filter the landing widened comes back with the task gone.
            narrowAfterUndo(container, focus);
          } catch (_) {
            if (messenger.mounted) {
              unawaited(showFeedback(messenger, strings.undoError));
            }
          }
        },
      );
      unawaited(feedback);
      askAboutRemindersAfterSave(context, [
        task.copyWith(id: id),
      ], feedback: feedback);
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
              // A new task has no older files to explain: its two rows
              // speak for themselves.
              if (!_creating)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    local
                        ? context.l10n.fileLocalHelp
                        : context.l10n.fileUploadHelp,
                  ),
                )
              else
                const SizedBox(height: 12),
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
          title: _creating
              ? context.l10n.newTask
              : _isNote
              ? context.l10n.editNote
              : context.l10n.editTask,
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
                      // The title comes first. Only a repeating task says
                      // that an edit changes the whole series.
                      if (widget.task.isRecurring) ...[
                        Text(
                          context.l10n.seriesEdits,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Projects show once there is one to choose. A new
                      // task starts with its title instead.
                      if (!_creating &&
                          (_listId != null ||
                              (ref.watch(taskListsProvider).valueOrNull ??
                                      const [])
                                  .isNotEmpty)) ...[
                        _project(),
                        const SizedBox(height: 16),
                      ],
                      if (_creating &&
                          widget.askedToSpeak &&
                          !ref.watch(voiceAvailableProvider))
                        ..._noMic(),
                      TextFormField(
                        key: const ValueKey('task-title'),
                        controller: _title,
                        // A new task opens with the keyboard up. Its Done key
                        // only closes the keyboard: the day comes next. While
                        // typing, a long title wraps up to three lines so the
                        // days still show; without the focus it shows whole.
                        focusNode: _titleFocus,
                        autofocus: _creating,
                        minLines: 1,
                        maxLines: _titleFocus.hasFocus ? 3 : null,
                        keyboardType: TextInputType.text,
                        textInputAction: _isNote
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: _isNote || _creating
                            ? null
                            : (_) => _save(),
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
                      // A new task: its day and time come right after the
                      // title, then words carried over and its project.
                      if (_creating) ...[
                        _dayAndTime(),
                        const SizedBox(height: 12),
                        if (_notesUpFront) ...[
                          _notesField(),
                          const SizedBox(height: 12),
                        ],
                        if (_projectUpFront) ...[
                          _project(),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (!_isNote && !_creating) ...[
                        _notesField(),
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
                        onPressed: () async {
                          final expand = !_detailsExpanded;
                          if (!expand) {
                            // Keeps a step typed without Enter, as in _save.
                            FocusScope.of(context).unfocus();
                            await Future<void>.microtask(() {});
                            if (!mounted) return;
                          }
                          setState(() => _detailsExpanded = expand);
                        },
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
                        // A new task keeps showing the details that hold
                        // something: notes with text, its files, a chosen
                        // project. Empty ones wait in Más detalles.
                        if (_creating &&
                            !_notesUpFront &&
                            _notes.text.trim().isNotEmpty) ...[
                          _notesField(),
                          const SizedBox(height: 16),
                        ],
                        if (_creating && _attachments.isNotEmpty) ...[
                          ..._files(colors, add: false),
                          const SizedBox(height: 8),
                        ],
                        // What Más detalles holds, as plain text.
                        if (_deadline != null ||
                            _priority > 1 ||
                            _recurrence != 'none' ||
                            _durationMinutes != null)
                          Text(
                            [
                              if (_recurrence != 'none')
                                context.repeatLabel(_repeatTask),
                              if (_durationMinutes != null)
                                context.l10n.durationMinutes(_durationMinutes!),
                              if (_deadline != null)
                                taskDeadlineLabel(context, _planningTask),
                              if (_priority > 1)
                                context.l10n.priorityValue(
                                  context.priorityName(_priority),
                                ),
                            ].join(' · '),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        // A plan shows, as its one line, once it's set.
                        if (ReminderPlans.active(_planningTask) != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              reminderPlanText(context, ref, _planningTask),
                              key: const ValueKey('task-reminder-plan'),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        if (_checklist.isNotEmpty)
                          ChecklistEditor(
                            key: _steps,
                            items: _checklist,
                            recurring: !_isNote && _recurrence != 'none',
                            onChanged: (items) =>
                                setState(() => _checklist = items),
                          ),
                        if (_creating &&
                            !_projectUpFront &&
                            _listId != null) ...[
                          const SizedBox(height: 8),
                          _project(),
                        ],
                      ],
                      // A new task's details: notes and files first, as the
                      // owner listed them, then reminder, repeat, steps and
                      // the project. The rest waits for editing.
                      if (_detailsExpanded && _creating) ...[
                        if (!_notesUpFront) ...[
                          _notesField(),
                          const SizedBox(height: 16),
                        ],
                        ..._files(colors),
                        const SizedBox(height: 8),
                        _reminder(),
                        _repeat(),
                        const SizedBox(height: 8),
                        _stepsEditor(),
                        if (!_projectUpFront &&
                            (ref.watch(taskListsProvider).valueOrNull ??
                                    const [])
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _project(),
                        ],
                      ],
                      // Most used first: reminder, repeat and steps; then
                      // duration, deadline, priority, labels and files.
                      if (_detailsExpanded && !_creating) ...[
                        if (!_isNote) ...[
                          _reminder(),
                          _repeat(),
                          if (_dueDate != null && _exceptions.isNotEmpty)
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
                                        DateTime.parse(exception.originalDate),
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
                          const SizedBox(height: 8),
                        ],
                        _stepsEditor(),
                        if (!_isNote) ...[
                          const SizedBox(height: 16),
                          TaskPlanningControl(
                            task: _planningTask,
                            onChanged: (task) => setState(() {
                              _deadline = task.deadline;
                              _deadlineHasTime = task.deadlineHasTime;
                              _durationMinutes = task.durationMinutes;
                              _reminderAnchor = task.reminderAnchor;
                            }),
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
                        ],
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 24),
                        ..._files(colors),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // A new task's button stays above the keyboard: title, day, add.
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: _creating ? MediaQuery.viewInsetsOf(context).bottom : 0,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: ElevatedButton.icon(
                key: const ValueKey('task-save'),
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
                      // As on a capture's result: where the task goes.
                      : !_creating
                      ? context.l10n.saveChangesSentence
                      : _dueDate != null
                      ? context.l10n.captureAddToCalendar
                      : context.l10n.captureAddTask,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The project, and who in a shared one the task is for: a row, as the
  /// edit form has always shown it.
  Widget _project() => TaskAssignmentPicker(
    compact: true,
    task: _responsibility,
    // A new task may go to any project; a saved shared one stays put.
    lockShared: !_creating,
    onChanged: _saving
        ? null
        : (value) => setState(() {
            _listId = value.listId;
            _assignment = value.assignment;
            _assigneeId = value.assigneeId;
            _assigneeName = value.assigneeName;
          }),
  );

  /// Opened to speak without the mic: when free dictations come back, or,
  /// with no count from the server, that speaking comes with Pro; and where
  /// Pro is. As the capture sheet said it.
  List<Widget> _noMic() {
    final l = context.l10n;
    final theme = Theme.of(context);
    final usedUp = ref.watch(freeVoiceUsedUpProvider);
    return [
      Semantics(
        liveRegion: usedUp,
        child: Text(
          usedUp
              ? freeVoiceUsedUpText(l, ref.watch(freeVoiceResetsProvider))
              : l.captureSpeakingIsPro,
          key: usedUp ? const ValueKey('free-voice-used-up') : null,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => Navigator.pushNamed(context, '/subscription'),
          child: Text(l.voiceProAction),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _notesField() => TextFormField(
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
  );

  /// A new task's day, with Hoy and Mañana one tap away, and its optional
  /// time once it has a day. Tapping the chosen day again takes it away.
  Widget _dayAndTime() {
    final l = context.l10n;
    final now = ref.watch(calendarClockProvider)();
    final today = Task.day(now);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final day = _dueDate == null ? null : Task.day(_dueDate!);
    final other = day != null && day != today && day != tomorrow;
    const icon = 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              key: const ValueKey('new-task-today'),
              label: Text(l.today),
              selected: day == today,
              onSelected: _saving
                  ? null
                  : (selected) {
                      _dropKeyboard();
                      _setDay(selected ? today : null);
                    },
            ),
            ChoiceChip(
              key: const ValueKey('new-task-tomorrow'),
              label: Text(l.tomorrow),
              selected: day == tomorrow,
              onSelected: _saving
                  ? null
                  : (selected) {
                      _dropKeyboard();
                      _setDay(selected ? tomorrow : null);
                    },
            ),
            ChoiceChip(
              key: const ValueKey('new-task-pick-day'),
              avatar: const Icon(Icons.calendar_today_outlined, size: icon),
              label: Text(other ? context.weekdayDate(day) : l.pickDay),
              selected: other,
              onSelected: _saving ? null : (_) => unawaited(_pickDay()),
            ),
          ],
        ),
        if (_dueDate != null) ...[
          const SizedBox(height: 8),
          if (_hasTime)
            InputChip(
              key: const ValueKey('new-task-time'),
              avatar: const Icon(Icons.schedule_rounded, size: icon),
              label: Text(context.clockTime(_dueDate!)),
              onPressed: _saving ? null : () => unawaited(_pickTime()),
              onDeleted: _saving
                  ? null
                  : () {
                      _dropKeyboard();
                      _schedule(Task.day(_dueDate!), false);
                    },
              deleteButtonTooltipMessage: l.removeTime,
            )
          else
            ActionChip(
              key: const ValueKey('new-task-time'),
              avatar: const Icon(Icons.schedule_rounded, size: icon),
              label: Text(l.addTime),
              onPressed: _saving ? null : () => unawaited(_pickTime()),
            ),
        ],
      ],
    );
  }

  Widget _reminder() => ReminderControl(
    hasDate: _planningTask.reminderDate != null,
    hasTime: _planningTask.reminderHasTime,
    minutes: _reminderMinutes,
    time: _reminderTime,
    plan: _reminderPlan,
    task: _responsibility,
    schedule: _repeatTask.copyWith(
      exceptions: _exceptions,
      completedDates: widget.task.completedDates,
      isCompleted: widget.task.isCompleted,
    ),
    onMinutes: (value) => setState(() => _reminderMinutes = value),
    onTime: (value) => setState(() => _reminderTime = value),
    // One choice of the exclusive ones: a plan, or the single reminder.
    onChanged: (minutes, time, plan) => setState(() {
      _reminderMinutes = minutes;
      _reminderTime = time;
      _reminderPlan = plan;
    }),
  );

  Widget _repeat() => ListTile(
    key: const ValueKey('task-repeat'),
    contentPadding: EdgeInsets.zero,
    enabled: _dueDate != null,
    leading: const Icon(Icons.repeat_rounded),
    title: Text(context.l10n.repeat),
    subtitle: Text(
      _dueDate == null
          ? context.l10n.repeatNeedsDate
          : [
              _recurrence == 'none'
                  ? context.repeatName(_recurrence)
                  : context.repeatLabel(_repeatTask),
              if (_recurrence != 'none' && _repeatUntil != null)
                context.l10n.untilDate(context.shortDate(_repeatUntil!)),
            ].join(' · '),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: _editRepeat,
  );

  Widget _stepsEditor() => ChecklistEditor(
    key: _steps,
    items: _checklist,
    recurring: !_isNote && _recurrence != 'none',
    onChanged: (items) => setState(() => _checklist = items),
  );

  /// The files, and, unless [add] is false, the button that adds one. A new
  /// task's file is kept on the phone with the task, and goes up once the
  /// task reaches the server.
  List<Widget> _files(ColorScheme colors, {bool add = true}) => [
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
                          const Icon(Icons.broken_image_outlined),
                    ),
                  )
                else
                  Icon(Icons.insert_drive_file_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    path.basename(_attachments[i]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.removeFileNamed(
                    path.basename(_attachments[i]),
                  ),
                  onPressed: () => setState(() => _attachments.removeAt(i)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
    ],
    if (add)
      TextButton.icon(
        onPressed: _pickingFile || _saving ? null : _attach,
        icon: const Icon(Icons.attach_file_rounded, size: 20),
        label: Text(context.l10n.addAttachment),
      ),
  ];
}
