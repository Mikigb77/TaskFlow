import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/theme/app_theme.dart';

class ReviewTasksScreen extends ConsumerStatefulWidget {
  const ReviewTasksScreen(
      {super.key, required this.drafts, required this.transcript});
  final List<TaskDraft> drafts;
  final String transcript;
  @override
  ConsumerState<ReviewTasksScreen> createState() => _ReviewTasksScreenState();
}

class _ReviewedTask {
  _ReviewedTask(TaskDraft draft)
      : task = Task(
            title: draft.title,
            dueDate: draft.dueDate,
            hasTime: draft.hasTime,
            recurrence: draft.recurrence,
            repeatUntil: draft.repeatUntil,
            priority: draft.priority,
            notes: draft.notes),
        questions = draft.questions,
        confirmed = draft.questions.isEmpty;
  Task task;
  final List<String> questions;
  bool confirmed;
}

class _ReviewTasksScreenState extends ConsumerState<ReviewTasksScreen> {
  late final _items = widget.drafts.map(_ReviewedTask.new).toList();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _items.isEmpty) return;
    if (_items.any((item) => !item.confirmed)) {
      setState(() => _error =
          'Check the highlighted details: edit the task or confirm the details shown.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(taskProvider.notifier)
          .addTasks(_items.map((item) => item.task).toList());
      if (!mounted) return;
      final count = _items.length;
      final inbox = _items.where((item) => item.task.dueDate == null).length;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(
              '$count ${count == 1 ? 'task' : 'tasks'} saved${inbox > 0 ? ' · $inbox in Inbox' : ''}')));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nothing was saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: const CustomAppBar(title: 'Review your tasks'),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      children: [
                        Text('A little clearer already.',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                            'Edit anything, remove what you don’t need, then save together.',
                            style: TextStyle(color: colors.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Your words'),
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(widget.transcript))
                            ]),
                        if (ref.watch(authProvider).account == null)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  'These tasks stay on this phone. You can sign in and import them later.')),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: MessageBanner(_error!, isError: true)),
                        if (_items.isEmpty)
                          const EmptyState(
                              title: 'Nothing to save',
                              message: 'Go back to capture another thought.'),
                        for (final item in _items)
                          Padding(
                              key: ObjectKey(item),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: Text(item.task.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium)),
                                          IconButton(
                                              tooltip:
                                                  'Edit ${item.task.title}',
                                              onPressed: _saving
                                                  ? null
                                                  : () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                          builder: (_) =>
                                                              TaskEditor(
                                                                  task:
                                                                      item.task,
                                                                  onReview:
                                                                      (task) {
                                                                    setState(
                                                                        () {
                                                                      item.task =
                                                                          task;
                                                                      item.confirmed =
                                                                          true;
                                                                      _error =
                                                                          null;
                                                                    });
                                                                  }))),
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 20)),
                                          IconButton(
                                              tooltip:
                                                  'Remove ${item.task.title}',
                                              onPressed: _saving
                                                  ? null
                                                  : () => setState(() =>
                                                      _items.remove(item)),
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 20)),
                                        ]),
                                    Text(taskScheduleLabel(item.task),
                                        style:
                                            TextStyle(color: colors.primary)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${AppTheme.priorityLabel(item.task.priority)} priority${item.task.isRecurring ? ' · ${Task.repeats[item.task.recurrence]}' : ''}',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12)),
                                    if (item.task.notes?.isNotEmpty ?? false)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(item.task.notes!)),
                                    if (item.questions.isNotEmpty &&
                                        !item.confirmed) ...[
                                      const SizedBox(height: 12),
                                      MessageBanner(item.questions.join('\n'),
                                          isError: true),
                                      CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          value: item.confirmed,
                                          title: const Text(
                                              'Use the details shown'),
                                          onChanged: _saving
                                              ? null
                                              : (value) => setState(() =>
                                                  item.confirmed = value!)),
                                    ],
                                  ]))),
                      ]))),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: FilledButton.icon(
                      key: const ValueKey('save-drafts'),
                      onPressed: _saving || _items.isEmpty ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.done_all_rounded),
                      label: Text(_saving
                          ? 'Saving…'
                          : 'Save ${_items.length} ${_items.length == 1 ? 'task' : 'tasks'}')))),
        ));
  }
}
