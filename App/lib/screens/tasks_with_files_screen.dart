import 'dart:math' as math;

import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The tasks and notes whose files use this account's file space: those with
/// no project, and those in projects it owns (storage is charged to the
/// project's owner). Largest total first.
final tasksWithFilesProvider =
    FutureProvider.autoDispose<List<(Task, TaskFileUsage)>>((ref) async {
      final repository = ref.watch(taskRepositoryProvider);
      final tasks =
          ref.watch(taskProvider).value ?? await repository.getAllTasks();
      final owned = {
        for (final list in await ref.watch(taskListsProvider.future))
          if (list.role == 'owner') list.id,
      };
      final usage = await repository.attachments.usageByTask();
      final rows = <int, (Task, TaskFileUsage)>{
        for (final task in tasks)
          if (usage[task.id] != null &&
              (task.listId == null || owned.contains(task.listId)))
            task.id!: (task, usage[task.id]!),
      }.values.toList()..sort((a, b) => b.$2.bytes.compareTo(a.$2.bytes));
      return rows;
    });

class TasksWithFilesScreen extends ConsumerWidget {
  const TasksWithFilesScreen({super.key});

  static const _megabyte = 1024 * 1024;

  /// Opens the list, from a full file space's message.
  static Future<void> open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/tasksWithFiles'),
      builder: (_) => const TasksWithFilesScreen(),
    ),
  );

  /// Megabytes to one decimal in the app's locale; a file under 0.05 MB
  /// still reads 0.1, never 0.0.
  static String _size(BuildContext context, int bytes) => NumberFormat(
    '0.0',
    context.l10n.localeName,
  ).format(bytes <= 0 ? 0 : math.max(bytes / _megabyte, 0.1));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: CustomAppBar(title: l10n.tasksWithFiles),
      body: ref
          .watch(tasksWithFilesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => SingleChildScrollView(
              child: EmptyState(
                title: l10n.fileLoadError,
                message: l10n.tryLater,
                icon: null,
              ),
            ),
            data: (rows) => ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                if (rows.isEmpty)
                  Text(l10n.tasksWithFilesEmpty)
                else ...[
                  Text(
                    l10n.tasksWithFilesHelp,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  for (final (task, usage) in rows) ...[
                    _FileRow(
                      task: task,
                      files: l10n.tasksWithFilesRow(
                        usage.count,
                        _size(context, usage.bytes),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(name: '/taskDetails'),
                            builder: (_) => TaskDetailScreen(
                              taskId: task.id!,
                              showFiles: true,
                            ),
                          ),
                        );
                        // Files may have been removed there.
                        if (context.mounted) {
                          ref.invalidate(tasksWithFilesProvider);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.task,
    required this.files,
    required this.onTap,
  });
  final Task task;
  final String files;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      files,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
