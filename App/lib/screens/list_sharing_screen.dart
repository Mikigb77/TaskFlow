import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
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
      return Map<String, dynamic>.from(
        await ref
            .watch(apiClientProvider)
            .request('GET', 'lists/$id/sharing/', accountId: account.id),
      );
    });

final invitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final account = ref.watch(authProvider).account;
      if (account == null) return [];
      final response =
          await ref
                  .watch(apiClientProvider)
                  .request('GET', 'invitations/', accountId: account.id)
              as Map;
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
  Object? _error;
  Future<void> _run(
    String action,
    Map<String, dynamic> data, {
    bool deleting = false,
    bool leave = false,
  }) async {
    if (_busy) return;
    final account = ref.read(authProvider).account;
    if (account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .request(
            deleting ? 'DELETE' : 'POST',
            'lists/${widget.listId}/$action',
            data: data,
            accountId: account.id,
          );
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      await ref.read(taskProvider.notifier).loadTasks();
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      ref.invalidate(taskListsProvider);
      ref.invalidate(listSharingProvider(widget.listId));
      if (action == 'invite/' && result is Map && result['code'] is String) {
        final code = result['code'] as String;
        await showDialog<void>(
          context: context,
          builder: (context) => Consumer(
            builder: (context, dialogRef, _) {
              final sameAccount =
                  dialogRef.watch(authProvider).account?.id == account.id;
              return AlertDialog(
                scrollable: true,
                title: Text(context.l10n.invitationCode),
                content: sameAccount
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            code,
                            key: const ValueKey('invitation-code'),
                          ),
                        ],
                      )
                    : Text(context.l10n.accountChanged),
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
      if (mounted && (deleting || leave)) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
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
          title: Text(context.l10n.inviteToList),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.inviteHelp),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('invite-email'),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.l10n.inviteeEmail,
                    errorMaxLines: 3,
                  ),
                  onChanged: (value) => email = value.trim(),
                  validator: (value) => value?.contains('@') == true
                      ? null
                      : context.l10n.enterEmailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.l10n.access),
                  items: [
                    DropdownMenuItem(
                      value: 'editor',
                      child: Text(context.l10n.roleEditor),
                    ),
                    DropdownMenuItem(
                      value: 'viewer',
                      child: Text(context.l10n.roleViewer),
                    ),
                  ],
                  onChanged: (value) => update(() => role = value!),
                ),
                const SizedBox(height: 12),
                Text(context.l10n.sharingRolesHelp),
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
                  Navigator.pop(context, true);
                }
              },
              child: Text(context.l10n.createInvitation),
            ),
          ],
        ),
      ),
    );
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
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(title: context.l10n.listSharing),
    body: ref
        .watch(listSharingProvider(widget.listId))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              MessageBanner(
                requestProblemText(context.l10n, error),
                isError: true,
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(listSharingProvider(widget.listId)),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
          data: (data) {
            final list = data['list'] as Map;
            final owner = list['role'] == 'owner';
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  list['name'] as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.yourRole(
                    context.listRole(list['role'] as String),
                  ),
                ),
                const SizedBox(height: 16),
                Text(context.l10n.sharingHelp),
                if (_error != null)
                  MessageBanner(
                    requestProblemText(context.l10n, _error!),
                    isError: true,
                  ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 20),
                if (owner) ...[
                  FilledButton.icon(
                    key: const ValueKey('invite-person'),
                    onPressed: _busy ? null : _invite,
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(context.l10n.invitePerson),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(context.l10n.people),
                  if ((data['members'] as List).isEmpty)
                    Text(context.l10n.noOtherMembers),
                  for (final member in data['members'] as List)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member['user__email'] as String),
                      subtitle: Text(
                        context.listRole(member['role'] as String),
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        tooltip: context.l10n.manageItem(
                          member['user__email'] as String,
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'editor',
                            child: Text(context.l10n.makeEditor),
                          ),
                          PopupMenuItem(
                            value: 'viewer',
                            child: Text(context.l10n.makeViewer),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(context.l10n.removeAccess),
                          ),
                        ],
                        onSelected: (role) async {
                          if (role == 'remove' &&
                              !await _confirm(
                                context.l10n.removeAccess,
                                context.l10n.removeAccessHelp,
                              )) {
                            return;
                          }
                          if (mounted) {
                            await _run('member/', {
                              'user_id': member['user_id'],
                              'role': role,
                            });
                          }
                        },
                      ),
                    ),
                  SectionLabel(context.l10n.pendingInvitations),
                  for (final invitation in data['invitations'] as List)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(invitation['email'] as String),
                      subtitle: Text(
                        context.l10n.pendingRole(
                          context.listRole(invitation['role'] as String),
                        ),
                      ),
                      onTap: _busy
                          ? null
                          : () => _run('invite/', {
                              'email': invitation['email'],
                              'role': invitation['role'],
                            }),
                      trailing: IconButton(
                        tooltip: context.l10n.revokeInvitation,
                        onPressed: _busy
                            ? null
                            : () => _run('revoke_invite/', {
                                'invitation_id': invitation['id'],
                              }),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  if ((data['invitations'] as List).isNotEmpty)
                    Text(context.l10n.replaceInvitationHelp),
                  ExpansionTile(
                    title: Text(context.l10n.howSharingWorks),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      Text(context.l10n.sharedDataHelp),
                      const SizedBox(height: 12),
                      Text(context.l10n.sharingRemovalHelp),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm(
                              context.l10n.deleteList,
                              context.l10n.deleteListHelp,
                            )) {
                              if (mounted) {
                                await _run('', {
                                  'version': list['version'],
                                }, deleting: true);
                              }
                            }
                          },
                    child: Text(context.l10n.deleteListForEveryone),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm(
                              context.l10n.leaveList,
                              context.l10n.leaveListHelp,
                            )) {
                              if (mounted) {
                                await _run('leave/', {}, leave: true);
                              }
                            }
                          },
                    child: Text(context.l10n.leaveList),
                  ),
              ],
            );
          },
        ),
  );
}

class ListInvitations extends ConsumerStatefulWidget {
  const ListInvitations({super.key});
  @override
  ConsumerState<ListInvitations> createState() => _ListInvitationsState();
}

class _ListInvitationsState extends ConsumerState<ListInvitations> {
  bool _busy = false;
  Object? _error;
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
          title: Text(context.l10n.enterInvitationCode),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.requestInvitationCodeHelp),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('accept-invitation-code'),
                  maxLength: 128,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.invitationCode,
                    errorMaxLines: 3,
                  ),
                  onChanged: (value) => entered = value.trim(),
                  validator: (_) => entered.length >= 16
                      ? null
                      : context.l10n.invitationCodeRequired,
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
                  Navigator.pop(context, entered);
                }
              },
              child: Text(context.l10n.joinList),
            ),
          ],
        ),
      );
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
      await ref
          .read(apiClientProvider)
          .request(
            'POST',
            'invitations/$id/respond/',
            data: {'decision': decision, if (code != null) 'code': code},
            accountId: account.id,
          );
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      ref.invalidate(invitationsProvider);
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) ref.invalidate(taskListsProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(invitationsProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(invitationsProvider),
          child: Text(context.l10n.retryInvitations),
        ),
        data: (invitations) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              MessageBanner(
                requestProblemText(context.l10n, _error!),
                isError: true,
              ),
            if (invitations.isNotEmpty) SectionLabel(context.l10n.invitations),
            for (final invitation in invitations)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['list_name'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.l10n.joinListHelp(
                          context.listRole(invitation['role'] as String),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(invitation['id'], 'accept'),
                            child: Text(context.l10n.acceptInvitation),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(invitation['id'], 'decline'),
                            child: Text(context.l10n.decline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
