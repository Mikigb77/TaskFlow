import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/task_tile.dart';

class TaskList extends StatelessWidget {
  const TaskList({super.key, required this.tasks, this.footer});
  final List<Task> tasks;

  /// Shown after the last task.
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final sorted = [...tasks]..sort(Task.compareBySchedule);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: sorted.length + (footer == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => index == sorted.length
          ? footer!
          : TaskTile(task: sorted[index], showDate: true),
    );
  }
}
