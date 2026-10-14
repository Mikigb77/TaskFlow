import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task_group.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/invitation_cards.dart';

String groupRoleLabel(BuildContext context, String role) =>
    role == 'admin' ? context.l10n.groupAdmin : context.listRole(role);

Future<String?> groupTextDialog(
  BuildContext context,
  String title, {
  String value = '',
  String? help,
  bool email = false,
  bool allowEmpty = false,
  int maxLength = 80,
}) async {
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(help),
              ),
            TextFormField(
              initialValue: value,
              autofocus: true,
              maxLength: maxLength,
              keyboardType: email
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              decoration: InputDecoration(labelText: title),
              onChanged: (s) => value = s,
              validator: (s) =>
                  (allowEmpty || s?.trim().isNotEmpty == true) &&
                      (!email ||
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(s!.trim()))
                  ? null
                  : context.l10n.checkBeforeAdd,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, value.trim());
            }
          },
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}

Future<bool> groupConfirm(
  BuildContext context,
  String title,
  String message, {
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(title),
          ),
        ],
      ),
    ) ==
    true;

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  bool _busy = false;
  Future<void> _create() async {
    final accountId = ref.read(authProvider).account?.id;
    if (_busy || accountId == null) return;
    final name = await groupTextDialog(context, context.l10n.groupName);
    if (name == null ||
        !mounted ||
        ref.read(authProvider).account?.id != accountId) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result =
          await ref
                  .read(apiClientProvider)
                  .request(
                    'POST',
                    'groups/',
                    data: {'name': name, 'version': 0},
                    accountId: accountId,
                  )
              as Map;
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      ref.invalidate(groupsProvider);
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GroupScreen(groupId: result['id']),
        ),
      );
    } catch (_) {
      if (mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.groupActionError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(title: context.l10n.groups),
    body: RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(groupsProvider);
        ref.invalidate(pendingInvitationsProvider);
        await ref.read(groupsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.groupHelp,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          const PendingInvitations(kind: 'group'),
          ref
              .watch(groupsProvider)
              .when(
                data: (groups) => Column(
                  children: [
                    for (final group in groups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          group.archived
                              ? Icons.inventory_2_outlined
                              : Icons.groups_outlined,
                        ),
                        title: Text(group.name),
                        subtitle: Text(groupRoleLabel(context, group.role)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GroupScreen(groupId: group.id),
                          ),
                        ),
                      ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Column(
                  children: [
                    Text(context.l10n.groupOnline),
                    TextButton(
                      onPressed: () => ref.invalidate(groupsProvider),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton.icon(
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.group_add_outlined),
          label: Text(context.l10n.newGroup),
        ),
      ),
    ),
  );
}

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _run(
    String action,
    Map<String, dynamic> data, {
    String method = 'POST',
    bool leave = false,
    String? done,
    void Function(Object? result)? undo,
  }) async {
    final accountId = ref.read(authProvider).account?.id;
    if (_busy || accountId == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .request(
            method,
            'groups/${widget.groupId}/$action',
            data: data,
            accountId: accountId,
          );
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailsProvider(widget.groupId));
      await ref.read(taskProvider.notifier).loadTasks();
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      ref.invalidate(taskListsProvider);
      final messenger = ScaffoldMessenger.of(context);
      if (leave) {
        Navigator.pop(context);
        if (done != null) showFeedback(messenger, done);
        return;
      }
      if (done != null) {
        showFeedback(
          messenger,
          done,
          actionLabel: undo == null ? null : context.l10n.undo,
          onAction: undo == null ? null : () => undo(result),
        );
      }
      if (result is Map && result['code'] is String) {
        final code = result['code'] as String;
        await showDialog<void>(
          context: context,
          builder: (context) => Consumer(
            builder: (context, dialogRef, _) {
              final sameAccount =
                  dialogRef.watch(authProvider).account?.id == accountId;
              return AlertDialog(
                scrollable: true,
                title: Text(context.l10n.invitationCode),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result['email_status'] != null) ...[
                      Text(
                        result['email_status'] == 'sent'
                            ? context.l10n.invitationEmailSent
                            : context.l10n.invitationEmailPending,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(context.l10n.invitationCodeHelp),
                    const SizedBox(height: 16),
                    SelectableText(
                      sameAccount ? code : context.l10n.accountChanged,
                      key: const ValueKey('group-invitation-code'),
                    ),
                  ],
                ),
                actions: [
                  if (sameAccount)
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code)),
                      child: Text(context.l10n.copyCode),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.done),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
        ref.invalidate(groupDetailsProvider(widget.groupId));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(TaskGroupInfo group) async {
    final email = await groupTextDialog(
      context,
      context.l10n.inviteeEmail,
      email: true,
      maxLength: 254,
      help: context.l10n.groupInviteHelp,
    );
    if (email == null || !mounted) return;
    final role = await _chooseRole(group, canRemove: false);
    if (role != null && mounted) {
      await _run('invite/', {'email': email, 'role': role});
    }
  }

  Future<String?> _chooseRole(TaskGroupInfo group, {required bool canRemove}) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in [
                'editor',
                'viewer',
                if (group.role == 'owner') 'admin',
              ])
                ListTile(
                  title: Text(groupRoleLabel(context, role)),
                  onTap: () => Navigator.pop(context, role),
                ),
              if (canRemove)
                ListTile(
                  textColor: Theme.of(context).colorScheme.error,
                  title: Text(context.l10n.removeAccess),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      );

  Future<void> _member(TaskGroupInfo group, ProjectMember person) async {
    final role = await _chooseRole(group, canRemove: true);
    if (role == null || !mounted) return;
    if (role == 'remove' &&
        !await groupConfirm(
          context,
          context.l10n.removeAccess,
          context.l10n.groupRemoveHelp,
          destructive: true,
        )) {
      return;
    }
    if (mounted) await _run('member/', {'user_id': person.id, 'role': role});
  }

  Future<void> _transfer(TaskGroupInfo group) async {
    final person = await showModalBottomSheet<ProjectMember>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.l10n.groupTransfer),
              subtitle: Text(context.l10n.groupTransferHelp),
            ),
            for (final member in group.people.where(
              (p) => p.id != group.ownerId,
            ))
              ListTile(
                title: Text(member.name),
                onTap: () => Navigator.pop(context, member),
              ),
          ],
        ),
      ),
    );
    if (person == null || !mounted) return;
    if (await groupConfirm(
          context,
          '${context.l10n.groupTransfer}: ${person.name}',
          context.l10n.groupTransferHelp,
        ) &&
        mounted) {
      await _run('transfer/', {'user_id': person.id, 'version': group.version});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(title: context.l10n.groups),
    body: ref
        .watch(groupDetailsProvider(widget.groupId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EmptyState(
            title: context.l10n.groupOnline,
            message: context.l10n.groupActionError,
            action: TextButton(
              onPressed: () =>
                  ref.invalidate(groupDetailsProvider(widget.groupId)),
              child: Text(context.l10n.retry),
            ),
          ),
          data: (details) {
            final group = TaskGroupInfo.fromJson(
              Map<String, dynamic>.from(details['group']),
            );
            final me = ref.watch(authProvider).account?.id;
            final projects = (ref.watch(taskListsProvider).valueOrNull ?? [])
                .where((p) => p.groupId == group.id);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupDetailsProvider(widget.groupId));
                await ref.read(taskProvider.notifier).loadTasks();
              },
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(groupRoleLabel(context, group.role)),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MessageBanner(
                        context.l10n.groupActionError,
                        isError: true,
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.groupMembers,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final person in group.people)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(person.name),
                      subtitle: Text(groupRoleLabel(context, person.role)),
                      trailing:
                          group.canManage &&
                              person.id != group.ownerId &&
                              (group.role == 'owner' || person.role != 'admin')
                          ? IconButton(
                              tooltip: context.l10n.manageItem(person.name),
                              icon: const Icon(Icons.manage_accounts_outlined),
                              onPressed: _busy
                                  ? null
                                  : () => _member(group, person),
                            )
                          : null,
                    ),
                  if (group.canManage)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _invite(group),
                      icon: const Icon(Icons.person_add_outlined),
                      label: Text(context.l10n.invitePerson),
                    ),
                  if (group.role != 'owner')
                    TextButton.icon(
                      icon: const Icon(Icons.record_voice_over_outlined),
                      label: Text(context.l10n.groupVoiceName),
                      onPressed: _busy
                          ? null
                          : () async {
                              final name = await groupTextDialog(
                                context,
                                context.l10n.groupVoiceName,
                                help: context.l10n.groupVoiceHelp,
                                value:
                                    group.people
                                        .where((p) => p.id == me)
                                        .firstOrNull
                                        ?.voiceName ??
                                    '',
                                allowEmpty: true,
                                maxLength: 60,
                              );
                              if (name != null && mounted) {
                                await _run('profile/', {'voice_name': name});
                              }
                            },
                    ),
                  for (final invitation
                      in (details['invitations'] as List? ?? []))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(invitation['email']),
                      subtitle: Text(
                        groupRoleLabel(context, invitation['role']),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        color: Theme.of(context).colorScheme.error,
                        tooltip: context.l10n.revokeInvitation,
                        onPressed: _busy
                            ? null
                            : () => _run('revoke_invite/', {
                                'invitation_id': invitation['id'],
                              }),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.groupProjects,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final project in projects)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(project.name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HomeScreen(isRoot: false, listId: project.id),
                        ),
                      ),
                    ),
                  if (group.canManage && !group.archived)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TaskListsScreen(
                            groupId: group.id,
                            createOnOpen: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.newList),
                    ),
                  const Divider(height: 40),
                  if (group.canManage) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.groupRename),
                      leading: const Icon(Icons.edit_outlined),
                      onTap: _busy
                          ? null
                          : () async {
                              final name = await groupTextDialog(
                                context,
                                context.l10n.groupName,
                                value: group.name,
                              );
                              if (name != null && mounted) {
                                await _run('', {
                                  'name': name,
                                  'archived': group.archived,
                                  'version': group.version,
                                }, method: 'PUT');
                              }
                            },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        group.archived
                            ? context.l10n.groupRestore
                            : context.l10n.groupArchive,
                      ),
                      leading: const Icon(Icons.inventory_2_outlined),
                      onTap: _busy
                          ? null
                          : () => _run(
                              '',
                              {
                                'name': group.name,
                                'archived': !group.archived,
                                'version': group.version,
                              },
                              method: 'PUT',
                              done: group.archived
                                  ? null
                                  : context.l10n.groupArchivedForEveryone(
                                      group.name,
                                    ),
                              undo: (result) {
                                if (!mounted || result is! Map) return;
                                _run('', {
                                  'name': group.name,
                                  'archived': false,
                                  'version': result['version'],
                                }, method: 'PUT');
                              },
                            ),
                    ),
                  ],
                  if (group.role == 'owner') ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.groupTransfer),
                      leading: const Icon(Icons.swap_horiz),
                      onTap: _busy ? null : () => _transfer(group),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.delete,
                        style: group.projectCount == 0
                            ? TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              )
                            : null,
                      ),
                      subtitle: Text(context.l10n.groupDeleteHelp),
                      leading: Icon(
                        Icons.delete_outline,
                        color: group.projectCount == 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      onTap: _busy || group.projectCount != 0
                          ? null
                          : () async {
                              final deleted = context.l10n.groupDeleted;
                              if (await groupConfirm(
                                    context,
                                    context.l10n.delete,
                                    context.l10n.groupDeleteHelp,
                                    destructive: true,
                                  ) &&
                                  mounted) {
                                await _run(
                                  '',
                                  {'version': group.version},
                                  method: 'DELETE',
                                  leave: true,
                                  done: deleted,
                                );
                              }
                            },
                    ),
                  ] else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      textColor: Theme.of(context).colorScheme.error,
                      iconColor: Theme.of(context).colorScheme.error,
                      title: Text(context.l10n.groupLeave),
                      leading: const Icon(Icons.logout),
                      onTap: _busy
                          ? null
                          : () async {
                              final left = context.l10n.youLeft(group.name);
                              if (await groupConfirm(
                                    context,
                                    context.l10n.groupLeave,
                                    context.l10n.groupLeaveHelp,
                                    destructive: true,
                                  ) &&
                                  mounted) {
                                await _run(
                                  'leave/',
                                  {},
                                  leave: true,
                                  done: left,
                                );
                              }
                            },
                    ),
                ],
              ),
            );
          },
        ),
  );
}
