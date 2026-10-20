import 'dart:async';

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
  'unassigned' => context.l10n.activityUnassigned,
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

  /// Marks everything read.
  Future<void> _readAll() async {
    final accountId = ref.read(authProvider).account?.id;
    if (_busy || accountId == null) return;
    setState(() => _busy = true);
    try {
      await _markRead(accountId);
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

  Future<void> _markRead(int accountId, [Map<String, dynamic>? item]) async {
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
  }

  /// The entry waiting for the sync to bring its task; its row shows a bar.
  Object? _waiting;

  /// Opens the entry's task as this phone has it, at once; marking it read
  /// and the sync run behind. A task the phone hasn't got yet waits for that
  /// sync; only a task still missing after it may have been deleted.
  Future<void> _open(Map<String, dynamic> item) async {
    final accountId = ref.read(authProvider).account?.id;
    final owner = ref.read(taskRepositoryProvider).ownerKey;
    if (_busy || accountId == null) return;
    unawaited(_markRead(accountId, item).catchError((_) {}));
    final synced = ref.read(taskProvider.notifier).loadTasks();
    Future<int?> local() async {
      final rows = await (await TaskDatabase().database).query(
        'tasks',
        columns: ['id'],
        where: 'owner_key = ? AND sync_id = ? AND is_deleted = 0',
        whereArgs: [owner, item['task_id']],
      );
      return rows.isEmpty ? null : rows.single['id'] as int;
    }

    bool moved() => ref.read(authProvider).account?.id != accountId;
    final id = await local();
    if (!mounted || moved()) return;
    if (id != null) return _show(id);
    if (item['action'] == 'deleted') {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.taskRemoved);
      return;
    }
    final waiting = item['id'];
    setState(() => _waiting = waiting);
    // Acts only while this row is still the one waiting and Activity is on
    // top; otherwise the person has moved on and the answer is dropped.
    bool still() =>
        !moved() &&
        _waiting == waiting &&
        ModalRoute.of(context)?.isCurrent == true;
    try {
      try {
        await synced;
      } catch (_) {}
      if (!mounted || !still()) return;
      final found = await local();
      if (!mounted || !still()) return;
      if (found != null) return _show(found);
      showFeedback(ScaffoldMessenger.of(context), context.l10n.taskRemoved);
    } finally {
      if (mounted && _waiting == waiting) setState(() => _waiting = null);
    }
  }

  /// Opens task [id]; a row still waiting for the sync no longer will.
  void _show(int id) {
    if (_waiting != null) setState(() => _waiting = null);
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)),
      ),
    );
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
                      onPressed: _busy ? null : _readAll,
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
                    waiting: _waiting != null && _waiting == item['id'],
                    onTap: _busy ? null : () => _open(item),
                  ),
              ],
            ),
          ),
        ),
  );
}

/// Who did what to which task. An assignment says who has it now, when the
/// server says so; older entries keep the general sentence.
String activityEntry(BuildContext context, Map<String, dynamic> item) {
  final action = item['action'] as String? ?? '';
  final actor = item['actor_name'] as String? ?? context.l10n.activitySystem;
  final title = item['task_title'] as String? ?? '';
  final assignee = item['assignee_name'] as String?;
  if (action == 'assigned' && item['assignee_is_you'] == true) {
    return context.l10n.activityAssignedYou(actor, title);
  }
  if (action == 'assigned' && assignee != null) {
    return context.l10n.activityAssignedTo(actor, assignee, title);
  }
  return context.l10n.activityEntry(action, actor, title);
}

/// Who did what first, then where and when. Unread rows are bold and say so
/// to TalkBack.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.onTap,
    this.waiting = false,
  });
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  /// Waiting for the sync to bring its task: a thin bar along the bottom
  /// that TalkBack announces once, and no second tap. The text keeps its
  /// width, so nothing moves under the finger.
  final bool waiting;
  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final date = context.shortDate(
      DateTime.parse(item['created_at'] as String).toLocal(),
    );
    final project = item['project_name'] as String?;
    return MergeSemantics(
      child: Semantics(
        // A waiting row drops «unread» as its wait starts, so marking it
        // read mid-wait doesn't change what TalkBack hears.
        label: unread && !waiting ? context.l10n.activityUnread : null,
        child: Stack(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              title: Text(
                activityEntry(context, item),
                style: unread
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
              subtitle: Text(project == null ? date : '$project · $date'),
              onTap: waiting ? null : onTap,
            ),
            if (waiting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Semantics(
                  liveRegion: true,
                  label: context.l10n.activityFindingTask,
                  child: const ExcludeSemantics(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),
              ),
          ],
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
