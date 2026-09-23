import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_schedule_label.dart';

class ReviewTasksScreen extends ConsumerStatefulWidget {
  const ReviewTasksScreen(
      {super.key, this.drafts = const [], this.transcript = '', this.session});
  final List<TaskDraft> drafts;
  final String transcript;
  final CaptureSession? session;
  @override
  ConsumerState<ReviewTasksScreen> createState() => _ReviewTasksScreenState();
}

class _ReviewTasksScreenState extends ConsumerState<ReviewTasksScreen> {
  late CaptureSession? _session = widget.session;
  late List<CaptureDraft> _items = [
    ...?_session?.drafts,
    if (_session == null) ...widget.drafts.map(CaptureDraft.fromAI)
  ];
  late final CaptureStore _store;
  Future<void> _writes = Future.value();
  bool _saving = false;
  String? _error;
  final _reviewWatch = Stopwatch()..start();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(captureStoreProvider);
    unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.reviewOpened));
  }

  Future<void> _measureCorrection(Future<void> Function() change) async {
    final watch = Stopwatch()..start();
    try {
      await change();
    } finally {
      unawaited(CaptureDiagnostics(_store.database).record(
          CaptureEvent.correction,
          elapsedMs: watch.elapsedMilliseconds));
    }
  }

  @override
  void dispose() {
    if (!_finished && _items.any((d) => d.pending)) {
      unawaited(CaptureDiagnostics(_store.database)
          .record(CaptureEvent.leftReviewPending));
      unawaited(CaptureDiagnostics(_store.database).record(
          CaptureEvent.reviewTime,
          elapsedMs: _reviewWatch.elapsedMilliseconds));
    }
    super.dispose();
  }

  Future<void> _change(CaptureDraft draft) async {
    setState(() {
      _items = _items.map((d) => d.id == draft.id ? draft : d).toList();
      _error = null;
    });
    if (_session == null) return;
    final snapshot = _session!.copyWith(drafts: _items, status: 'ready');
    _session = snapshot;
    _writes =
        _writes.catchError((Object _) {}).then((_) => _store.update(snapshot));
    try {
      await _writes;
      await CaptureDiagnostics(_store.database).record(CaptureEvent.edited);
      if (mounted) ref.invalidate(pendingCapturesProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.reviewWriteFailed);
      }
    }
  }

  Future<void> _save() async {
    final ready = _items.where((d) => d.ready).toList();
    if (_saving || ready.isEmpty) return;
    final saveWatch = Stopwatch()..start();
    unawaited(CaptureDiagnostics(_store.database).record(
        CaptureEvent.reviewTime,
        elapsedMs: _reviewWatch.elapsedMilliseconds));
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(taskProvider.notifier);
    try {
      await _writes;
      if (_session != null) {
        final result = await _store.saveReady(
            _session!.id, _session!.ownerKey, ready.map((d) => d.id).toSet());
        _session = result;
        _items = result.drafts;
        await CaptureDiagnostics(_store.database).record(CaptureEvent.saved,
            elapsedMs: saveWatch.elapsedMilliseconds, count: ready.length);
        _reviewWatch.reset();
        _finished = !_items.any((d) => d.pending);
        await notifier.loadTasks();
      } else {
        await notifier.addTasks(ready.map((d) => d.task).toList());
        final ids = ready.map((d) => d.id).toSet();
        _items = _items
            .map((d) => ids.contains(d.id) ? d.copyWith(savedTaskId: -1) : d)
            .toList();
      }
      if (!mounted) return;
      ref.invalidate(pendingCapturesProvider);
      final remaining = _items.where((d) => d.pending).length;
      _finished = remaining == 0;
      final messenger = ScaffoldMessenger.of(context);
      final message = ready.every((item) => item.task.isNote)
          ? context.l10n.noteSaved
          : '${context.l10n.captureTasksSaved(ready.length)}${remaining > 0 ? ' · ${context.l10n.captureKeptForReview(remaining)}' : ''}';
      if (remaining == 0) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        setState(() => _error = CaptureProblem.saveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editWords(CaptureDraft item, {bool notes = false}) async {
    await _measureCorrection(() => _editWordsImpl(item, notes: notes));
  }

  Future<void> _editWordsImpl(CaptureDraft item, {bool notes = false}) async {
    var text = (notes ? item.task.notes : item.task.title) ?? '';
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(notes
                    ? context.l10n.noteBody
                    : item.task.isNote
                        ? context.l10n.noteTitle
                        : context.l10n.taskTitle),
                content: TextFormField(
                    key: notes
                        ? const ValueKey('draft-notes')
                        : const ValueKey('task-title'),
                    initialValue: text,
                    onChanged: (value) => text = value,
                    autofocus: true,
                    minLines: notes ? 3 : 1,
                    maxLines: notes ? 6 : 2,
                    maxLength: notes ? 8000 : 160,
                    decoration: InputDecoration(
                        labelText: notes
                            ? context.l10n.notes
                            : context.l10n.taskTitle)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel)),
                  FilledButton(
                      onPressed: () {
                        if (notes || text.trim().isNotEmpty) {
                          Navigator.pop(context, text.trim());
                        }
                      },
                      child: Text(context.l10n.keepChanges))
                ]));
    if (result == null || !mounted) return;
    await _change(item.copyWith(
        task: notes
            ? item.task.copyWith(notes: result)
            : item.task.copyWith(title: result)));
  }

  Future<void> _date(CaptureDraft item) async {
    await _measureCorrection(() => _dateImpl(item));
  }

  Future<void> _dateImpl(CaptureDraft item) async {
    final now = DateTime.now();
    final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in [
                ('today', context.l10n.today),
                ('tomorrow', context.l10n.tomorrow),
                ('pick', context.l10n.pickDate),
                ('inbox', context.l10n.noDate)
              ])
                ListTile(
                    title: Text(option.$2),
                    onTap: () => Navigator.pop(context, option.$1))
            ])));
    if (selected == null || !mounted) return;
    if (selected == 'inbox') {
      await _change(item.copyWith(
          task: item.task.copyWith(
              dueDate: null,
              hasTime: false,
              recurrence: 'none',
              repeatInterval: 1,
              repeatWeekdays: [],
              exceptions: [],
              repeatUntil: null)));
      return;
    }
    final day = selected == 'pick'
        ? await showDatePicker(
            context: context,
            initialDate: item.task.dueDate ?? now,
            firstDate: pickerFirstDate(item.task.dueDate),
            lastDate: pickerLastDate(item.task.dueDate))
        : DateTime(
            now.year, now.month, now.day + (selected == 'tomorrow' ? 1 : 0));
    if (day == null || !mounted) return;
    final old = item.task.dueDate;
    final date = DateTime(day.year, day.month, day.day,
        item.task.hasTime ? old!.hour : 0, item.task.hasTime ? old!.minute : 0);
    await _change(item.copyWith(
        task: item.task.copyWith(
            dueDate: date,
            repeatUntil: item.task.repeatUntil?.isBefore(Task.day(date)) == true
                ? null
                : item.task.repeatUntil)));
  }

  Future<void> _time(CaptureDraft item) async {
    await _measureCorrection(() => _timeImpl(item));
  }

  Future<void> _timeImpl(CaptureDraft item) async {
    if (item.task.dueDate == null) {
      await _dateImpl(item);
      if (!mounted) return;
      item = _items.firstWhere((d) => d.id == item.id);
    }
    if (item.task.dueDate == null) return;
    final result = await showTimePicker(
        context: context,
        initialTime: item.task.hasTime
            ? TimeOfDay.fromDateTime(item.task.dueDate!)
            : TimeOfDay.now());
    if (result == null || !mounted) return;
    final date = item.task.dueDate!;
    await _change(item.copyWith(
        task: item.task.copyWith(
            dueDate: DateTime(
                date.year, date.month, date.day, result.hour, result.minute),
            hasTime: true)));
  }

  Future<void> _finishEmpty() async {
    if (_session != null) {
      await _writes;
      await _store.discard(_session!.id, _session!.ownerKey);
    }
    _finished = true;
    unawaited(
        CaptureDiagnostics(_store.database).record(CaptureEvent.discarded));
    if (mounted) {
      ref.invalidate(pendingCapturesProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((d) => d.pending).toList();
    final ready = pending.where((d) => d.ready).length;
    final uncertain = pending.length - ready;
    final colors = Theme.of(context).colorScheme;
    final note = _session?.kind == 'note' ||
        (_items.isNotEmpty && _items.every((item) => item.task.isNote));
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: CustomAppBar(
              title: note ? context.l10n.reviewNote : context.l10n.checkTasks),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        Text(
                            pending.length == 1
                                ? context.l10n.lookRight
                                : context.l10n.readyCount(ready),
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                            uncertain > 0
                                ? context.l10n.needsCheckCount(uncertain)
                                : context.l10n.finalSay,
                            style: TextStyle(color: colors.onSurfaceVariant)),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: MessageBanner(
                                  captureProblemText(context.l10n, _error!),
                                  isError: true)),
                        const SizedBox(height: 16),
                        for (final item in pending)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(item.task.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium)),
                                      IconButton(
                                          tooltip: context.l10n
                                              .editCaptureItem(item.task.title),
                                          onPressed: _saving
                                              ? null
                                              : () => _editWords(item),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20)),
                                      IconButton(
                                          tooltip: context.l10n
                                              .removeCaptureItem(
                                                  item.task.title),
                                          onPressed: _saving
                                              ? null
                                              : () => _change(
                                                  item.copyWith(removed: true)),
                                          icon: const Icon(Icons.close_rounded,
                                              size: 20))
                                    ]),
                                    if (!item.task.isNote)
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            ActionChip(
                                                avatar: const Icon(
                                                    Icons
                                                        .calendar_today_outlined,
                                                    size: 16),
                                                label: Text(taskScheduleLabel(
                                                    item.task,
                                                    context: context)),
                                                onPressed: _saving
                                                    ? null
                                                    : () => _date(item)),
                                            InputChip(
                                                avatar: const Icon(
                                                    Icons.schedule_outlined,
                                                    size: 16),
                                                label: Text(item.task.hasTime
                                                    ? TimeOfDay.fromDateTime(
                                                            item.task.dueDate!)
                                                        .format(context)
                                                    : context.l10n.addTime),
                                                onPressed: _saving
                                                    ? null
                                                    : () => _time(item),
                                                onDeleted: item.task.hasTime &&
                                                        !_saving
                                                    ? () => _change(item.copyWith(
                                                        task: item.task.copyWith(
                                                            hasTime: false)))
                                                    : null),
                                            PopupMenuButton<int>(
                                                enabled: !_saving,
                                                tooltip:
                                                    context.l10n.changePriority,
                                                onSelected: (p) => _change(
                                                    item.copyWith(
                                                        task: item.task
                                                            .copyWith(
                                                                priority: p))),
                                                itemBuilder: (_) => [
                                                      for (final p in [1, 2, 3])
                                                        PopupMenuItem(
                                                            value: p,
                                                            child: Text(context
                                                                .l10n
                                                                .priorityValue(
                                                                    context
                                                                        .priorityName(
                                                                            p))))
                                                    ],
                                                child: Chip(
                                                    label: Text(context.l10n
                                                        .priorityValue(context
                                                            .priorityName(item
                                                                .task
                                                                .priority))))),
                                            ActionChip(
                                                tooltip:
                                                    context.l10n.changeRepeat,
                                                label: Text(context
                                                    .repeatLabel(item.task)),
                                                onPressed: _saving ||
                                                        item.task.dueDate ==
                                                            null
                                                    ? null
                                                    : () => _measureCorrection(
                                                            () async {
                                                          final task =
                                                              await editTaskRepeat(
                                                                  context,
                                                                  item.task);
                                                          if (task != null &&
                                                              mounted) {
                                                            await _change(
                                                                item.copyWith(
                                                                    task:
                                                                        task));
                                                          }
                                                        })),
                                          ]),
                                    TextButton.icon(
                                        onPressed: _saving
                                            ? null
                                            : () =>
                                                _editWords(item, notes: true),
                                        icon: const Icon(Icons.notes_rounded,
                                            size: 18),
                                        label: Text(
                                            item.task.notes?.isNotEmpty == true
                                                ? item.task.notes!
                                                : context.l10n.addNotes,
                                            textAlign: TextAlign.start)),
                                    TaskListPicker(
                                        listId: item.task.listId,
                                        onChanged: _saving
                                            ? null
                                            : (id) => _change(item.copyWith(
                                                task: item.task
                                                    .copyWith(listId: id)))),
                                    ChecklistEditor(
                                        items: item.task.checklist,
                                        recurring: item.task.isRecurring,
                                        onChanged: _saving
                                            ? null
                                            : (items) => _change(item.copyWith(
                                                task: item.task.copyWith(
                                                    checklist: items)))),
                                    if (!item.task.isNote)
                                      ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(context.l10n.planning),
                                          initiallyExpanded:
                                              item.task.deadline != null ||
                                                  item.task.durationMinutes !=
                                                      null,
                                          children: [
                                            TaskPlanningControl(
                                                task: item.task,
                                                onChanged: _saving
                                                    ? null
                                                    : (task) => _change(item
                                                        .copyWith(task: task)))
                                          ]),
                                    if (item.task.reminderDate != null)
                                      ReminderChip(
                                          task: item.task,
                                          onChanged: _saving
                                              ? null
                                              : (task) => _change(
                                                  item.copyWith(task: task))),
                                    if (item.questions.isNotEmpty &&
                                        !item.confirmed) ...[
                                      MessageBanner(item.questions.join('\n')),
                                      CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(context
                                              .l10n.captureConfirmDetails),
                                          value: item.confirmed,
                                          onChanged: _saving
                                              ? null
                                              : (v) => _change(item.copyWith(
                                                  confirmed: v == true))),
                                    ],
                                  ]))),
                        if (pending.isEmpty) ...[
                          EmptyState(
                              title: context.l10n.captureNothingToReview,
                              message: context.l10n.captureRemovedDraftsHelp),
                          TextButton(
                              onPressed: _finishEmpty,
                              child: Text(context.l10n.captureFinish))
                        ],
                        ExpansionTile(
                            title: Text(context.l10n.captureYourWords),
                            children: [
                              Text(_session?.transcript ?? widget.transcript)
                            ]),
                        if (_session != null)
                          Text(context.l10n.captureReviewRetainedHelp,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12)),
                      ]))),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: FilledButton.icon(
                      key: const ValueKey('save-drafts'),
                      onPressed: _saving || ready == 0 ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.done_all_rounded),
                      label: Text(_saving
                          ? context.l10n.saving
                          : ready == 0
                              ? context.l10n.captureCheckDetails
                              : note
                                  ? context.l10n.saveNote
                                  : context.l10n.captureSaveTasks(ready))))),
        ));
  }
}
