import 'package:flutter/material.dart';
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
import 'package:agenda/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _store = ref.read(captureStoreProvider);
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
        setState(() => _error =
            'Could not keep these changes. Please try again before leaving.');
      }
    }
  }

  Future<void> _save() async {
    final ready = _items.where((d) => d.ready).toList();
    if (_saving || ready.isEmpty) return;
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
        await CaptureDiagnostics(_store.database)
            .record(CaptureEvent.saved, count: ready.length);
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
      final messenger = ScaffoldMessenger.of(context);
      if (remaining == 0) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(
              '${ready.length} ${ready.length == 1 ? 'task' : 'tasks'} saved${remaining > 0 ? ' · $remaining kept for review' : ''}')));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not finish saving. Your capture is kept; retry will not duplicate saved tasks.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editWords(CaptureDraft item, {bool notes = false}) async {
    var text = (notes ? item.task.notes : item.task.title) ?? '';
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(notes ? 'Task notes' : 'Task title'),
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
                    decoration:
                        InputDecoration(labelText: notes ? 'Notes' : 'Title')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (notes || text.trim().isNotEmpty) {
                          Navigator.pop(context, text.trim());
                        }
                      },
                      child: const Text('Keep changes'))
                ]));
    if (result == null || !mounted) return;
    await _change(item.copyWith(
        task: notes
            ? item.task.copyWith(notes: result)
            : item.task.copyWith(title: result)));
  }

  Future<void> _date(CaptureDraft item) async {
    final now = DateTime.now();
    final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in [
                'Today',
                'Tomorrow',
                'Pick a date',
                'No date'
              ])
                ListTile(
                    title: Text(option),
                    onTap: () => Navigator.pop(context, option))
            ])));
    if (selected == null || !mounted) return;
    if (selected == 'No date') {
      await _change(item.copyWith(
          task: item.task.copyWith(
              dueDate: null,
              hasTime: false,
              recurrence: 'none',
              repeatUntil: null)));
      return;
    }
    final day = selected == 'Pick a date'
        ? await showDatePicker(
            context: context,
            initialDate: item.task.dueDate ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2101))
        : DateTime(
            now.year, now.month, now.day + (selected == 'Tomorrow' ? 1 : 0));
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
    if (item.task.dueDate == null) {
      await _date(item);
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
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: const CustomAppBar(title: 'Check your tasks'),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        Text(
                            pending.length == 1
                                ? 'Look right?'
                                : '$ready ready to save',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                            uncertain > 0
                                ? '$uncertain ${uncertain == 1 ? 'task needs' : 'tasks need'} a quick check. Save the ready ones whenever you like.'
                                : 'Tap a detail to change it. You have the final say.',
                            style: TextStyle(color: colors.onSurfaceVariant)),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: MessageBanner(_error!, isError: true)),
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
                                          tooltip: 'Edit ${item.task.title}',
                                          onPressed: _saving
                                              ? null
                                              : () => _editWords(item),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20)),
                                      IconButton(
                                          tooltip: 'Remove ${item.task.title}',
                                          onPressed: _saving
                                              ? null
                                              : () => _change(
                                                  item.copyWith(removed: true)),
                                          icon: const Icon(Icons.close_rounded,
                                              size: 20))
                                    ]),
                                    Wrap(spacing: 8, runSpacing: 4, children: [
                                      ActionChip(
                                          avatar: const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16),
                                          label: Text(
                                              taskScheduleLabel(item.task)),
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
                                              : 'Add time'),
                                          onPressed: _saving
                                              ? null
                                              : () => _time(item),
                                          onDeleted:
                                              item.task.hasTime && !_saving
                                                  ? () => _change(item.copyWith(
                                                      task: item.task.copyWith(
                                                          hasTime: false)))
                                                  : null),
                                      PopupMenuButton<int>(
                                          enabled: !_saving,
                                          tooltip: 'Change priority',
                                          onSelected: (p) => _change(
                                              item.copyWith(
                                                  task: item.task
                                                      .copyWith(priority: p))),
                                          itemBuilder: (_) => [
                                                for (final p in [1, 2, 3])
                                                  PopupMenuItem(
                                                      value: p,
                                                      child: Text(
                                                          '${AppTheme.priorityLabel(p)} priority'))
                                              ],
                                          child: Chip(
                                              label: Text(
                                                  '${AppTheme.priorityLabel(item.task.priority)} priority'))),
                                      PopupMenuButton<String>(
                                          enabled: !_saving &&
                                              item.task.dueDate != null,
                                          tooltip: 'Change repeat',
                                          onSelected: (r) => _change(
                                              item.copyWith(
                                                  task: item.task.copyWith(
                                                      recurrence: r))),
                                          itemBuilder: (_) => [
                                                for (final r
                                                    in Task.repeats.entries)
                                                  PopupMenuItem(
                                                      value: r.key,
                                                      child: Text(r.value))
                                              ],
                                          child: Chip(
                                              label: Text(Task.repeats[
                                                  item.task.recurrence]!))),
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
                                                : 'Add notes',
                                            textAlign: TextAlign.start)),
                                    if (item.questions.isNotEmpty &&
                                        !item.confirmed) ...[
                                      MessageBanner(item.questions.join('\n')),
                                      CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                              'Use the details shown'),
                                          value: item.confirmed,
                                          onChanged: _saving
                                              ? null
                                              : (v) => _change(item.copyWith(
                                                  confirmed: v == true))),
                                    ],
                                  ]))),
                        if (pending.isEmpty) ...[
                          const EmptyState(
                              title: 'Nothing left to review',
                              message: 'Removed drafts will not become tasks.'),
                          TextButton(
                              onPressed: _finishEmpty,
                              child: const Text('Finish'))
                        ],
                        ExpansionTile(
                            title: const Text('Your words'),
                            children: [
                              Text(_session?.transcript ?? widget.transcript)
                            ]),
                        if (_session != null)
                          Text(
                              'Unfinished drafts are kept on this phone. You can return from Unfinished captures.',
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
                          ? 'Saving…'
                          : ready == 0
                              ? 'Check the details above'
                              : 'Save $ready ${ready == 1 ? 'task' : 'tasks'}')))),
        ));
  }
}
