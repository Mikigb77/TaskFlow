import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

String activityLabel(BuildContext context, String action) => switch (action) {
  'created' => context.l10n.activityCreated,
  'assigned' => context.l10n.activityAssigned,
  'unassigned' => context.l10n.assignmentNeeded,
  'completed' => context.l10n.activityCompleted,
  'reopened' => context.l10n.activityReopened,
  'deleted' => context.l10n.activityDeleted,
  _ => context.l10n.activityUpdated,
};

class ActivityButton extends ConsumerWidget {
  const ActivityButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only people who share something have group activity: the same
    // condition shows the `Para mí` / `Todas` chips.
    final shares = (ref.watch(taskListsProvider).valueOrNull ?? []).any(
      (project) => project.shared && !project.inactive,
    );
    if (!shares) return const SizedBox.shrink();
    final count = ref.watch(collaborationUnreadProvider).valueOrNull ?? 0;
    return IconButton(
      tooltip: context.l10n.groupActivity,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.groups_outlined),
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ActivityScreen()),
        );
        ref.invalidate(collaborationUnreadProvider);
      },
    );
  }
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _busy = false;
  Future<void> _read([Map<String, dynamic>? item]) async {
    final accountId = ref.read(authProvider).account?.id;
    final owner = ref.read(taskRepositoryProvider).ownerKey;
    if (_busy || accountId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .request(
            'POST',
            item == null
                ? 'notifications/read_all/'
                : 'notifications/${item['id']}/read/',
            accountId: accountId,
          );
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      ref.invalidate(collaborationActivityProvider);
      ref.invalidate(collaborationUnreadProvider);
      if (item == null) return;
      await ref.read(taskProvider.notifier).loadTasks();
      final rows = await (await TaskDatabase().database).query(
        'tasks',
        columns: ['id'],
        where: 'owner_key = ? AND sync_id = ? AND is_deleted = 0',
        whereArgs: [owner, item['task_id']],
      );
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      if (rows.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(taskId: rows.single['id'] as int),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          requestProblemText(context.l10n, error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(title: context.l10n.groupActivity),
    body: ref
        .watch(collaborationActivityProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              LoadFailed(
                onRetry: () => ref.invalidate(collaborationActivityProvider),
              ),
            ],
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(collaborationActivityProvider);
              await ref.read(collaborationActivityProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (items.any((i) => i['read_at'] == null))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _read,
                      child: Text(context.l10n.activityMarkRead),
                    ),
                  ),
                if (items.isEmpty)
                  EmptyState(
                    title: context.l10n.activityEmpty,
                    message: context.l10n.activityHelp,
                  ),
                for (final item in items)
                  _ActivityRow(
                    item: item,
                    onTap: _busy ? null : () => _read(item),
                  ),
              ],
            ),
          ),
        ),
  );
}

/// Who did what first, then where and when. Unread rows are bold and say so
/// to TalkBack.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final date = context.shortDate(
      DateTime.parse(item['created_at'] as String).toLocal(),
    );
    final project = item['project_name'] as String?;
    return MergeSemantics(
      child: Semantics(
        label: unread ? context.l10n.activityUnread : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          title: Text(
            context.l10n.activityEntry(
              item['action'] as String? ?? '',
              item['actor_name'] as String? ?? context.l10n.activitySystem,
              item['task_title'] as String? ?? '',
            ),
            style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
          subtitle: Text(project == null ? date : '$project · $date'),
          onTap: onTap,
        ),
      ),
    );
  }
}

final taskHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, id) async {
      final accountId = ref.watch(
        authProvider.select((state) => state.account?.id),
      );
      if (accountId == null) return [];
      final owner = ref.watch(taskRepositoryProvider).ownerKey;
      final rows = await (await TaskDatabase().database).query(
        'tasks',
        columns: ['sync_id', 'remote_version'],
        where: 'owner_key = ? AND id = ?',
        whereArgs: [owner, id],
      );
      if (rows.isEmpty || rows.single['remote_version'] == 0) return [];
      final response =
          await ref
                  .watch(apiClientProvider)
                  .request(
                    'GET',
                    'tasks/${rows.single['sync_id']}/history/',
                    accountId: accountId,
                  )
              as List;
      return response.reversed
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });

class TaskActivity extends ConsumerStatefulWidget {
  const TaskActivity({super.key, required this.taskId});
  final int taskId;
  @override
  ConsumerState<TaskActivity> createState() => _TaskActivityState();
}

class _TaskActivityState extends ConsumerState<TaskActivity> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(context.l10n.activity),
    leading: const Icon(Icons.history),
    onExpansionChanged: (open) {
      setState(() => _open = open);
      if (open) ref.invalidate(taskHistoryProvider(widget.taskId));
    },
    children: [
      if (_open)
        ref
            .watch(taskHistoryProvider(widget.taskId))
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => TextButton(
                onPressed: () =>
                    ref.invalidate(taskHistoryProvider(widget.taskId)),
                child: Text(context.l10n.retry),
              ),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(activityLabel(context, item['action'])),
                      subtitle: Text(
                        '${item['actor_name'] ?? context.l10n.activitySystem} · ${context.shortDate(DateTime.parse(item['created_at']).toLocal())}',
                      ),
                    ),
                ],
              ),
            ),
    ],
  );
}
