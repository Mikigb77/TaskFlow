import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/task_tile.dart';

class TaskList extends StatelessWidget {
  const TaskList({
    super.key,
    required this.tasks,
    this.newestFirst = false,
    this.landedIds = const {},
    this.lit = false,
    this.landedRow,
    this.bottomPadding = 100,
    this.project,
    this.showUndated = true,
  });
  final List<Task> tasks;

  /// Latest date first, undated last: what was just done is on top.
  final bool newestFirst;

  /// Just-saved tasks, highlighted while [lit]. The first one's row carries
  /// [landedRow], so it can be scrolled into view.
  final Set<int> landedIds;
  final bool lit;
  final Key? landedRow;

  /// Empty space after the last row.
  final double bottomPadding;

  /// The page's project, which its rows don't repeat.
  final String? project;

  /// Whether a row with no date says so; the Sin fecha page's rows don't.
  final bool showUndated;

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
    final first = sorted.indexWhere((task) => landedIds.contains(task.id));
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final task = sorted[index];
        return landedIds.contains(task.id)
            ? LandedTaskTile(
                key: index == first ? landedRow : null,
                task: task,
                lit: lit,
                showDate: true,
                project: project,
                showUndated: showUndated,
                markOverdue: true,
              )
            : TaskTile(
                task: task,
                showDate: true,
                project: project,
                showUndated: showUndated,
                markOverdue: true,
              );
      },
    );
  }
}
