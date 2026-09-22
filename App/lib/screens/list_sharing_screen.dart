import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listSharingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final account = ref.watch(authProvider).account;
  if (account == null) throw ApiException(401, 'Sign in to share lists.');
  return Map<String, dynamic>.from(await ref
      .watch(apiClientProvider)
      .request('GET', 'lists/$id/sharing/', accountId: account.id));
});

final invitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final account = ref.watch(authProvider).account;
  if (account == null) return [];
  final response = await ref
      .watch(apiClientProvider)
      .request('GET', 'invitations/', accountId: account.id) as Map;
  return (response['invitations'] as List)
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

class ListSharingScreen extends ConsumerStatefulWidget {
  const ListSharingScreen({super.key, required this.listId});
  final String listId;
  @override
  ConsumerState<ListSharingScreen> createState() => _ListSharingScreenState();
}

class _ListSharingScreenState extends ConsumerState<ListSharingScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _run(String action, Map<String, dynamic> data,
      {bool deleting = false, bool leave = false}) async {
    if (_busy) return;
    final account = ref.read(authProvider).account;
    if (account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiClientProvider).request(
          deleting ? 'DELETE' : 'POST', 'lists/${widget.listId}/$action',
          data: data, accountId: account.id);
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      await ref.read(taskProvider.notifier).loadTasks();
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      ref.invalidate(taskListsProvider);
      ref.invalidate(listSharingProvider(widget.listId));
      if (action == 'invite/' && result is Map && result['code'] is String) {
        final code = result['code'] as String;
        await showDialog<void>(
            context: context,
            builder: (context) => Consumer(builder: (context, dialogRef, _) {
                  final sameAccount =
                      dialogRef.watch(authProvider).account?.id == account.id;
                  return AlertDialog(
                      scrollable: true,
                      title: const Text('Invitation code'),
                      content: sameAccount
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text(
                                      'Give this code to the intended person through a channel you trust. They need it and the invited TaskFlow account to accept. The code is shown only now; replacing an invitation invalidates its previous code.'),
                                  const SizedBox(height: 16),
                                  SelectableText(code,
                                      key: const ValueKey('invitation-code')),
                                ])
                          : const Text('The account changed.'),
                      actions: [
                        if (sameAccount)
                          TextButton(
                              onPressed: () =>
                                  Clipboard.setData(ClipboardData(text: code)),
                              child: const Text('Copy code')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'))
                      ]);
                }));
      }
      if (mounted && (deleting || leave)) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Could not update sharing. Check the connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    var email = '';
    var role = 'editor';
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  scrollable: true,
                  title: const Text('Invite to this list'),
                  content: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'All tasks, notes and uploaded files in this list will be visible after they accept. The invitation appears in their TaskFlow account; no email is sent. Give them the code shown next. It expires in 7 days.'),
                        const SizedBox(height: 16),
                        TextFormField(
                            key: const ValueKey('invite-email'),
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Their account email'),
                            onChanged: (value) => email = value.trim(),
                            validator: (value) => value?.contains('@') == true
                                ? null
                                : 'Enter an email address.'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: role,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Access'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'editor', child: Text('Editor')),
                              DropdownMenuItem(
                                  value: 'viewer', child: Text('Viewer'))
                            ],
                            onChanged: (value) => update(() => role = value!)),
                        const SizedBox(height: 12),
                        const Text(
                            'Editors can add, change, complete and delete tasks and files. Only the owner manages the list and people. Shared tasks stay in this list; exporting creates a personal copy.'),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text('Create invitation'))
                  ],
                )));
    if (confirmed == true && mounted) {
      await _run('invite/', {'email': email, 'role': role});
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: Text(title),
                  content: Text(message),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(title))
                  ])) ==
      true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CustomAppBar(title: 'List sharing'),
        body: ref.watch(listSharingProvider(widget.listId)).when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ListView(padding: const EdgeInsets.all(24), children: [
                  MessageBanner(
                      error is ApiException
                          ? error.message
                          : 'Could not load sharing.',
                      isError: true),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(listSharingProvider(widget.listId)),
                      child: const Text('Retry'))
                ]),
            data: (data) {
              final list = data['list'] as Map;
              final owner = list['role'] == 'owner';
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text(list['name'] as String,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Your role: ${list['role']}'),
                const SizedBox(height: 16),
                const Text(
                    'Share shopping and chores. Changes sync when the app connects or you refresh.'),
                if (_error != null) MessageBanner(_error!, isError: true),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 20),
                if (owner) ...[
                  FilledButton.icon(
                      key: const ValueKey('invite-person'),
                      onPressed: _busy ? null : _invite,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Invite a person')),
                  const SizedBox(height: 16),
                  const SectionLabel('People'),
                  if ((data['members'] as List).isEmpty)
                    const Text('Only you have accepted access so far.'),
                  for (final member in data['members'] as List)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(member['user__email'] as String),
                        subtitle: Text(member['role'] as String),
                        trailing: PopupMenuButton<String>(
                            enabled: !_busy,
                            tooltip: 'Manage ${member['user__email']}',
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'editor',
                                      child: Text('Make editor')),
                                  PopupMenuItem(
                                      value: 'viewer',
                                      child: Text('Make viewer')),
                                  PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove access'))
                                ],
                            onSelected: (role) async {
                              if (role == 'remove' &&
                                  !await _confirm('Remove access',
                                      'This person will lose access to this list and its tasks and files. Their unsent shared edits will be removed on the next successful sync.')) {
                                return;
                              }
                              if (mounted) {
                                await _run('member/', {
                                  'user_id': member['user_id'],
                                  'role': role
                                });
                              }
                            })),
                  const SectionLabel('Pending invitations'),
                  for (final invitation in data['invitations'] as List)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(invitation['email'] as String),
                        subtitle: Text('${invitation['role']} · pending'),
                        onTap: _busy
                            ? null
                            : () => _run('invite/', {
                                  'email': invitation['email'],
                                  'role': invitation['role']
                                }),
                        trailing: IconButton(
                            tooltip: 'Revoke invitation',
                            onPressed: _busy
                                ? null
                                : () => _run('revoke_invite/',
                                    {'invitation_id': invitation['id']}),
                            icon: const Icon(Icons.close))),
                  if ((data['invitations'] as List).isNotEmpty)
                    const Text('Tap a pending invitation to replace its code.'),
                  const ExpansionTile(
                      title: Text('How sharing works'),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        Text(
                            'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Task reminder choices are shared, but each phone must enable its own notifications.'),
                        SizedBox(height: 12),
                        Text(
                            'Leaving or losing access removes this phone’s shared tasks, pending edits and downloaded copies at the next successful sync. Offline devices and copies already exported cannot be remotely erased.'),
                      ]),
                  const SizedBox(height: 24),
                  OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Delete list',
                                  'Delete this list and all its tasks and uploaded files for everyone? This cannot be undone.')) {
                                if (mounted) {
                                  await _run('', {'version': list['version']},
                                      deleting: true);
                                }
                              }
                            },
                      child: const Text('Delete list for everyone')),
                ] else
                  OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Leave list',
                                  'Shared tasks, files and any unsent edits will be removed from this phone. Other members keep the list.')) {
                                if (mounted) {
                                  await _run('leave/', {}, leave: true);
                                }
                              }
                            },
                      child: const Text('Leave list')),
              ]);
            }),
      );
}

class ListInvitations extends ConsumerStatefulWidget {
  const ListInvitations({super.key});
  @override
  ConsumerState<ListInvitations> createState() => _ListInvitationsState();
}

class _ListInvitationsState extends ConsumerState<ListInvitations> {
  bool _busy = false;
  String? _error;
  Future<void> _respond(String id, String decision) async {
    final account = ref.read(authProvider).account;
    if (account == null || _busy) return;
    String? code;
    if (decision == 'accept') {
      var entered = '';
      final form = GlobalKey<FormState>();
      code = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Enter invitation code'),
                  content: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Ask the list owner for the code they received when inviting you.'),
                        const SizedBox(height: 12),
                        TextFormField(
                            key: const ValueKey('accept-invitation-code'),
                            maxLength: 128,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                                labelText: 'Invitation code'),
                            onChanged: (value) => entered = value.trim(),
                            validator: (_) => entered.length >= 16
                                ? null
                                : 'Paste the full invitation code.'),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(context, entered);
                          }
                        },
                        child: const Text('Join list'))
                  ]));
      if (code == null ||
          !mounted ||
          ref.read(authProvider).account?.id != account.id) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).request(
          'POST', 'invitations/$id/respond/',
          data: {'decision': decision, if (code != null) 'code': code},
          accountId: account.id);
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      ref.invalidate(invitationsProvider);
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) ref.invalidate(taskListsProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Could not respond. Retry when connected.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref.watch(invitationsProvider).when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(invitationsProvider),
          child: const Text('Retry invitations')),
      data: (invitations) =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_error != null) MessageBanner(_error!, isError: true),
            if (invitations.isNotEmpty) const SectionLabel('Invitations'),
            for (final invitation in invitations)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(invitation['list_name'] as String,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                'Join as ${invitation['role']}. Shared tasks, notes and uploaded files will sync to your account.'),
                            Wrap(spacing: 8, children: [
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _respond(invitation['id'], 'accept'),
                                  child: const Text('Accept invitation')),
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _respond(invitation['id'], 'decline'),
                                  child: const Text('Decline'))
                            ]),
                          ]))),
          ]));
}
