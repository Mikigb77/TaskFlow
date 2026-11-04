import 'dart:async';

import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/name_ask_sheet.dart';
import 'package:agenda/widgets/project_preferences.dart';
import 'package:flutter/material.dart';
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
    await _guard(() async {
      final result = await ref
          .read(apiClientProvider)
          .request(
            deleting ? 'DELETE' : 'POST',
            'lists/${widget.listId}/$action',
            data: data,
            accountId: account.id,
          );
      await _applied(
        account.id,
        action,
        result,
        deleting: deleting,
        leave: leave,
        done: done,
      );
    });
  }

  /// Runs [work] with the bar under the app bar; a failure comes as the
  /// floating message, as on Projects, and the page stays as it was.
  Future<void> _guard(Future<void> Function() work) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    setState(() => _busy = true);
    try {
      await work();
    } catch (error) {
      if (messenger.mounted) {
        showFeedback(
          messenger,
          requestProblemText(strings, error, keptNote: false),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What follows a request the server accepted: fresh data, an
  /// invitation's code, or closing the page.
  Future<void> _applied(
    int accountId,
    String action,
    Object? result, {
    bool deleting = false,
    bool leave = false,
    String? done,
  }) async {
    if (!mounted || ref.read(authProvider).account?.id != accountId) return;
    final synced = ref.read(taskProvider.notifier).loadTasks().then((_) {
      if (mounted && ref.read(authProvider).account?.id == accountId) {
        ref.invalidate(taskListsProvider);
      }
    });
    if (deleting || leave) {
      // The page closes once this phone has caught up.
      await synced;
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      final messenger = ScaffoldMessenger.of(context);
      // True tells the project page under this one to close as well.
      Navigator.pop(context, true);
      if (done != null) showFeedback(messenger, done);
      return;
    }
    // The page shows the change as soon as the server answers; the sync
    // runs behind it.
    unawaited(synced);
    final code =
        action == 'invite/' && result is Map && result['code'] is String
        ? result['code'] as String
        : null;
    ref.invalidate(listSharingProvider(widget.listId));
    if (code == null) {
      try {
        await ref.read(listSharingProvider(widget.listId).future);
      } catch (_) {
        // The page says it couldn't load, with Retry.
      }
      return;
    }
    // The work is done: no progress bar under “Invitation sent”.
    setState(() => _busy = false);
    await showInvitationSent(context, accountId: accountId, code: code);
    // An account without a name is asked for one, once.
    if (mounted) {
      await askForNameOnce(Navigator.of(context), accountId: accountId);
    }
  }

  /// Everyone joins as an editor; the owner can make them a viewer on
  /// their row.
  Future<void> _invite(String project) async {
    final account = ref.read(authProvider).account;
    if (_busy || account == null) return;
    var email = '';
    var sending = false;
    Object? error;
    Object? result;
    final form = GlobalKey<FormState>();
    // The dialog stays open until the invitation is sent, so a refused or
    // offline invite keeps the typed address and says why.
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> send() async {
            if (sending || !form.currentState!.validate()) return;
            setState(() {
              sending = true;
              error = null;
            });
            try {
              result = await ref
                  .read(apiClientProvider)
                  .request(
                    'POST',
                    'lists/${widget.listId}/invite/',
                    data: {'email': email, 'role': 'editor'},
                    accountId: account.id,
                  );
            } catch (failure) {
              if (context.mounted) {
                setState(() {
                  sending = false;
                  error = failure;
                });
              }
              return;
            }
            if (context.mounted) Navigator.pop(context, true);
          }

          return AlertDialog(
            scrollable: true,
            title: Text(context.l10n.inviteWho(project)),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MessageBanner(
                        requestProblemText(
                          context.l10n,
                          error!,
                          keptNote: false,
                        ),
                        isError: true,
                      ),
                    ),
                  TextFormField(
                    key: const ValueKey('invite-email'),
                    initialValue: email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      labelText: context.l10n.email,
                      // Room for the own-address line at large text.
                      errorMaxLines: 6,
                    ),
                    onChanged: (value) => email = value.trim(),
                    onFieldSubmitted: (_) => send(),
                    validator: (value) => value?.contains('@') != true
                        ? context.l10n.enterEmailAddress
                        : ownEmailProblem(context, account.email, value!),
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.shareProjectHelp(project)),
                  if (sending) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            // Stacked at large text, the buttons keep apart.
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: sending ? null : send,
                child: Text(context.l10n.sendInvitation),
              ),
            ],
          );
        },
      ),
    );
    if (sent == true && mounted) {
      await _guard(() => _applied(account.id, 'invite/', result));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A project this phone hasn't synced yet doesn't exist on the server.
    final local = (ref.watch(taskListsProvider).value ?? [])
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
    return _sharing(context, shared: local?.shared ?? true, local: local);
  }

  /// A person and their role, with nothing to manage; [you] marks the
  /// account's own row.
  Widget _personRow(
    BuildContext context,
    ProjectMember person, {
    required bool you,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(you ? context.l10n.personYou(person.name) : person.name),
    subtitle: Text(context.listRole(person.role)),
  );

  /// A person with access: their name first, when the project knows it,
  /// then their email and role.
  Widget _memberRow(BuildContext context, Map member, String? name) {
    final email = member['user__email'] as String;
    final role = member['role'] as String;
    final access = context.listRole(role);
    final danger = Theme.of(context).colorScheme.error;
    final unnamed = name == null || name == email;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: unnamed ? _address(email) : Text(name),
      subtitle: unnamed ? Text(access) : _address(email, after: ' · $access'),
      trailing: PopupMenuButton<String>(
        enabled: !_busy,
        tooltip: context.l10n.manageItem(name ?? email),
        // Only the role they don't have yet.
        itemBuilder: (_) => [
          if (role != 'editor')
            PopupMenuItem(
              value: 'editor',
              child: Text(context.l10n.makeEditor),
            ),
          if (role != 'viewer')
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
            await _run('member/', {'user_id': member['user_id'], 'role': role});
          }
        },
      ),
    );
  }

  /// [address], then [after], wrapping only after «@» or «.»; TalkBack
  /// reads the address whole.
  Widget _address(String address, {String after = ''}) => Text(
    '${breakableAddress(address)}$after',
    semanticsLabel: '$address$after',
  );

  /// A shared project's own update choice, as a labelled row. A group's
  /// projects keep it in Projects ⋮.
  Widget? _updates(BuildContext context, TaskListInfo? project) {
    if (project == null || !project.shared || project.groupId != null) {
      return null;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.projectNotifications),
      subtitle: Text(switch (project.notifications) {
        'all' => context.l10n.updatesAll,
        'muted' => context.l10n.updatesMuted,
        _ => context.l10n.updatesAssigned,
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: _busy ? null : () => showProjectPreferences(context, ref, project),
    );
  }

  Widget _sharing(
    BuildContext context, {
    required bool shared,
    TaskListInfo? local,
  }) => Scaffold(
    // «Miembros · N» opens this page: once shared, it lists them.
    appBar: CustomAppBar(
      title: shared ? context.l10n.people : context.l10n.listSharing,
    ),
    // While a change is on its way, a thin bar under the app bar, in view
    // at any scroll; it covers the page's margin, so nothing moves.
    body: Stack(
      children: [
        _page(context, shared: shared, local: local),
        if (_busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    ),
  );

  Widget _page(
    BuildContext context, {
    required bool shared,
    TaskListInfo? local,
  }) => ref
      .watch(listSharingProvider(widget.listId))
      .when(
        // The page stays on screen while it fetches a change.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            MessageBanner(
              requestProblemText(context.l10n, error, keptNote: false),
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
          final updates = _updates(context, local);
          // The sharing endpoint only knows emails; the project's people
          // know names.
          final people = local?.people ?? const <ProjectMember>[];
          final names = {for (final person in people) person.id: person.name};
          final account = ref.watch(authProvider).account;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                list['name'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
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
                // Once shared, the app bar already reads «Miembros».
                if (!shared) SectionLabel(context.l10n.people),
                if ((data['members'] as List).isEmpty)
                  Text(context.l10n.noOtherMembers)
                else if (account != null)
                  // The owner first, so «Miembros · 3» shows 3 rows.
                  _personRow(
                    context,
                    ProjectMember(
                      id: account.id,
                      name:
                          names[account.id] ??
                          (account.firstName.isEmpty
                              ? account.email
                              : account.firstName),
                      role: 'owner',
                    ),
                    you: true,
                  ),
                for (final member in data['members'] as List)
                  _memberRow(context, member as Map, names[member['user_id']]),
                if ((data['invitations'] as List).isNotEmpty)
                  SectionLabel(context.l10n.pendingInvitations),
                for (final invitation in data['invitations'] as List)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: _address(invitation['email'] as String),
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
                ?updates,
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
                // Deleting it for everyone ends the sharing, so it stays
                // here; a project of one's own is deleted from its ⋮.
                if (shared) ...[
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
                              context.l10n.deleteListHelp,
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
                    child: Text(context.l10n.deleteListForEveryone),
                  ),
                ],
              ] else ...[
                // Names and roles only: the server gives emails to the
                // owner alone. The owner comes first.
                for (final person in people)
                  _personRow(context, person, you: person.id == account?.id),
                const SizedBox(height: 16),
                if (updates != null) ...[updates, const SizedBox(height: 16)],
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
                              await _run('leave/', {}, leave: true, done: left);
                            }
                          }
                        },
                  child: Text(context.l10n.leaveList),
                ),
              ],
            ],
          );
        },
      );
}
