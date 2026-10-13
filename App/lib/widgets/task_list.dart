import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/task_tile.dart';

class TaskList extends StatelessWidget {
  const TaskList({super.key, required this.tasks, this.newestFirst = false});
  final List<Task> tasks;

  /// Latest date first, undated last: what was just done is on top.
  final bool newestFirst;
  @override
  Widget build(BuildContext context) {
    final sorted = [...tasks]
      ..sort(
        newestFirst
            ? (a, b) => a.displayDate == null || b.displayDate == null
                  ? Task.compareBySchedule(a, b)
                  : b.displayDate!.compareTo(a.displayDate!)
            : Task.compareBySchedule,
      );
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => TaskTile(task: sorted[index], showDate: true),
    );
  }
}
