import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
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
    String? done,
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
        // The work is done: no progress bar under “Invitation sent”.
        setState(() => _busy = false);
        await showDialog<void>(
          context: context,
          builder: (context) => Consumer(
            builder: (context, dialogRef, _) {
              final sameAccount =
                  dialogRef.watch(authProvider).account?.id == account.id;
              return AlertDialog(
                scrollable: true,
                title: Text(context.l10n.invitationSent),
                content: sameAccount
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.invitationCodeFallback),
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
      if (mounted && (deleting || leave)) {
        final messenger = ScaffoldMessenger.of(context);
        // True tells the project page under this one to close as well.
        Navigator.pop(context, true);
        if (done != null) showFeedback(messenger, done);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Everyone joins as an editor; the owner can make them a viewer on
  /// their row.
  Future<void> _invite(String project) async {
    var email = '';
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        void send() {
          if (form.currentState!.validate()) Navigator.pop(context, true);
        }

        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.shareProjectTitle(project)),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('invite-email'),
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    labelText: context.l10n.theirEmail,
                    errorMaxLines: 3,
                  ),
                  onChanged: (value) => email = value.trim(),
                  onFieldSubmitted: (_) => send(),
                  validator: (value) => value?.contains('@') == true
                      ? null
                      : context.l10n.enterEmailAddress,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.shareProjectHelp(project)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: send,
              child: Text(context.l10n.sendInvitation),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await _run('invite/', {'email': email, 'role': 'editor'});
    }
  }

  @override
  Widget build(BuildContext context) {
    // A project this phone hasn't synced yet doesn't exist on the server.
    final local = (ref.watch(taskListsProvider).valueOrNull ?? [])
        .where((project) => project.id == widget.listId)
        .firstOrNull;
    if (local != null && local.version == 0) {
      return Scaffold(
        appBar: CustomAppBar(title: context.l10n.listSharing),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(local.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(context.l10n.connectToShare),
          ],
        ),
      );
    }
    // Same flag as Projects ⋮, so both doors use the same words. A project
    // missing from the provider gets the cautious, shared wording.
    return _sharing(context, shared: local?.shared ?? true);
  }

  Widget _sharing(BuildContext context, {required bool shared}) => Scaffold(
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
            final danger = Theme.of(context).colorScheme.error;
            final dangerButton = OutlinedButton.styleFrom(
              foregroundColor: danger,
              side: BorderSide(color: danger),
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  list['name'] as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (!owner) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.yourRole(
                      context.listRole(list['role'] as String),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.sharingHelp),
                ],
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
                    onPressed: _busy
                        ? null
                        : () => _invite(list['name'] as String),
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
                            child: Text(
                              context.l10n.removeAccess,
                              style: TextStyle(color: danger),
                            ),
                          ),
                        ],
                        onSelected: (role) async {
                          if (role == 'remove' &&
                              !await groupConfirm(
                                context,
                                context.l10n.removeAccess,
                                context.l10n.removeAccessHelp,
                                destructive: true,
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
                  if ((data['invitations'] as List).isNotEmpty)
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
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        tooltip: context.l10n.manageItem(
                          invitation['email'] as String,
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'again',
                            child: Text(context.l10n.sendInvitationAgain),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text(
                              context.l10n.cancelInvitation,
                              style: TextStyle(color: danger),
                            ),
                          ),
                        ],
                        onSelected: (action) => action == 'again'
                            ? _run('invite/', {
                                'email': invitation['email'],
                                'role': invitation['role'],
                              })
                            : _run('revoke_invite/', {
                                'invitation_id': invitation['id'],
                              }),
                      ),
                    ),
                  ExpansionTile(
                    title: Text(context.l10n.howSharingWorks),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      Text(context.l10n.sharingRolesHelp),
                      const SizedBox(height: 12),
                      Text(context.l10n.sharedDataHelp),
                      const SizedBox(height: 12),
                      Text(context.l10n.sharingRemovalHelp),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    style: dangerButton,
                    onPressed: _busy
                        ? null
                        : () async {
                            final deleted = context.l10n.projectDeleted;
                            if (await groupConfirm(
                              context,
                              context.l10n.deleteList,
                              shared
                                  ? context.l10n.deleteListHelp
                                  : context.l10n.deleteListPrivateHelp(
                                      list['name'] as String,
                                    ),
                              destructive: true,
                            )) {
                              if (mounted) {
                                await _run(
                                  '',
                                  {'version': list['version']},
                                  deleting: true,
                                  done: deleted,
                                );
                              }
                            }
                          },
                    child: Text(
                      shared
                          ? context.l10n.deleteListForEveryone
                          : context.l10n.deleteList,
                    ),
                  ),
                ] else
                  OutlinedButton(
                    style: dangerButton,
                    onPressed: _busy
                        ? null
                        : () async {
                            final left = context.l10n.youLeft(
                              list['name'] as String,
                            );
                            if (await groupConfirm(
                              context,
                              context.l10n.leaveList,
                              context.l10n.leaveListHelp,
                              destructive: true,
                            )) {
                              if (mounted) {
                                await _run(
                                  'leave/',
                                  {},
                                  leave: true,
                                  done: left,
                                );
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
