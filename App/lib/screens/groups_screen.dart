import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
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
import 'package:agenda/widgets/name_ask_sheet.dart';

String groupRoleLabel(BuildContext context, String role) =>
    role == 'admin' ? context.l10n.groupAdmin : context.listRole(role);

/// The line under an invite's email field when [typed] is the account's own
/// address ([own]); null otherwise.
String? ownEmailProblem(BuildContext context, String? own, String typed) =>
    own != null && typed.trim().toLowerCase() == own.trim().toLowerCase()
    ? context.l10n.inviteOwnEmail
    : null;

/// What follows an invitation to a project or a group: the code to send
/// if the email doesn't arrive.
Future<void> showInvitationSent(
  BuildContext context, {
  required int accountId,
  required String code,
}) => showDialog<void>(
  context: context,
  builder: (context) => Consumer(
    builder: (context, dialogRef, _) {
      final sameAccount =
          dialogRef.watch(authProvider).account?.id == accountId;
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
                  SelectableText(code, key: const ValueKey('invitation-code')),
                ],
              )
            : Text(context.l10n.accountChanged),
        actionsOverflowButtonSpacing: 8,
        actions: [
          if (sameAccount)
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
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

/// One text step of a group flow. [title] heads the dialog and, without a
/// [label], names the field. [action] names the button: what the step does
/// (`Crear grupo`); `Guardar` by default. [check] can refuse a valid value
/// with a line under the field. With [submit], the dialog stays open while
/// it runs and shows its error inside, so a failed request keeps what was
/// typed. It closes once [submit] returns true; false leaves it open
/// without an error.
Future<String?> groupTextDialog(
  BuildContext context,
  String title, {
  String? label,
  String value = '',
  String? help,
  bool email = false,
  bool allowEmpty = false,
  int maxLength = 80,
  String? action,
  String? Function(String value)? check,
  Future<bool> Function(String value)? submit,
}) async {
  final form = GlobalKey<FormState>();
  var busy = false;
  Object? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> send() async {
          if (busy || !form.currentState!.validate()) return;
          final text = value.trim();
          if (submit == null) {
            Navigator.pop(context, text);
            return;
          }
          setState(() {
            busy = true;
            error = null;
          });
          var done = false;
          try {
            done = await submit(text);
          } catch (failure) {
            error = failure;
          }
          if (!context.mounted) return;
          if (done) {
            Navigator.pop(context, text);
          } else {
            setState(() => busy = false);
          }
        }

        return AlertDialog(
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
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MessageBanner(
                      requestProblemText(context.l10n, error!, keptNote: false),
                      isError: true,
                    ),
                  ),
                TextFormField(
                  initialValue: value,
                  autofocus: true,
                  maxLength: maxLength,
                  keyboardType: email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: label ?? title,
                    counterText: '',
                    // Room for the own-address line at large text.
                    errorMaxLines: 6,
                  ),
                  onChanged: (s) => value = s,
                  onFieldSubmitted: (_) => send(),
                  validator: (s) {
                    final text = s?.trim() ?? '';
                    if (email &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                      return context.l10n.enterEmailAddress;
                    }
                    if (!email && !allowEmpty && text.isEmpty) {
                      return context.l10n.enterName;
                    }
                    return check?.call(text);
                  },
                ),
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
          // Stacked at large text, the buttons keep apart.
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: busy ? null : send,
              child: Text(action ?? context.l10n.save),
            ),
          ],
        );
      },
    ),
  );
}

/// What a page says when its data couldn't be fetched, with Retry.
class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MessageBanner(context.l10n.loadFailed, isError: true),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
    ],
  );
}

Future<bool> groupConfirm(
  BuildContext context,
  String title,
  String message, {
  bool destructive = false,
  String? action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actionsOverflowButtonSpacing: 8,
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
            child: Text(action ?? title),
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
  /// The name dialog stays open until the server has the group, so a
  /// failure (offline, say) keeps the typed name and says why.
  Future<void> _create() async {
    final accountId = ref.read(authProvider).account?.id;
    if (accountId == null) return;
    final api = ref.read(apiClientProvider);
    String? id;
    final name = await groupTextDialog(
      context,
      context.l10n.groupName,
      action: context.l10n.createGroup,
      submit: (name) async {
        final result =
            await api.request(
                  'POST',
                  'groups/',
                  data: {'name': name, 'version': 0},
                  accountId: accountId,
                )
                as Map;
        id = result['id'] as String;
        return true;
      },
    );
    if (id == null) return;
    ref.invalidate(groupsProvider);
    if (name == null ||
        !mounted ||
        ref.read(authProvider).account?.id != accountId) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GroupScreen(groupId: id!)),
    );
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
                error: (_, _) =>
                    LoadFailed(onRetry: () => ref.invalidate(groupsProvider)),
              ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton.icon(
          onPressed: _create,
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

  /// Runs [work] with the bar under the app bar; a failure comes as the
  /// floating message, as on Projects, with the server's reason (already a
  /// member, the member limit), and the page fetches the group again. The
  /// page keeps what it shows if that fails too.
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
      if (mounted) ref.invalidate(groupDetailsProvider(widget.groupId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Object?> _request(
    int accountId,
    String action,
    Map<String, dynamic> data, {
    String method = 'POST',
  }) => ref
      .read(apiClientProvider)
      .request(
        method,
        'groups/${widget.groupId}/$action',
        data: data,
        accountId: accountId,
      );

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
    await _guard(() async {
      final result = await _request(accountId, action, data, method: method);
      await _applied(accountId, result, leave: leave, done: done, undo: undo);
    });
  }

  /// What follows a request the server accepted: fresh data, the message,
  /// and an invitation's code.
  Future<void> _applied(
    int accountId,
    Object? result, {
    bool leave = false,
    String? done,
    void Function(Object? result)? undo,
  }) async {
    if (!mounted || ref.read(authProvider).account?.id != accountId) return;
    ref.invalidate(groupsProvider);
    final synced = ref.read(taskProvider.notifier).loadTasks().then((_) {
      if (mounted && ref.read(authProvider).account?.id == accountId) {
        ref.invalidate(taskListsProvider);
      }
    });
    if (leave) {
      // The page closes once this phone has caught up.
      await synced;
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (done != null) showFeedback(messenger, done);
      return;
    }
    // The page shows the change as soon as the server answers; the sync
    // runs behind it.
    unawaited(synced);
    final code = result is Map && result['code'] is String
        ? result['code'] as String
        : null;
    ref.invalidate(groupDetailsProvider(widget.groupId));
    if (code == null) {
      try {
        await ref.read(groupDetailsProvider(widget.groupId).future);
      } catch (_) {
        // The page keeps what it shows.
      }
      if (!mounted || ref.read(authProvider).account?.id != accountId) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (done != null) {
      showFeedback(
        messenger,
        done,
        actionLabel: undo == null ? null : context.l10n.undo,
        onAction: undo == null ? null : () => undo(result),
      );
    }
    if (code != null) {
      // The work is done: no progress bar under “Invitation sent”.
      setState(() => _busy = false);
      await showInvitationSent(context, accountId: accountId, code: code);
      // An account without a name is asked for one, once.
      if (mounted) {
        await askForNameOnce(Navigator.of(context), accountId: accountId);
      }
    }
  }

  /// Everyone joins as an editor; the role changes on the person's row. The
  /// email dialog stays open until the invitation is sent, so a refused or
  /// offline invite keeps the typed address.
  Future<void> _invite(TaskGroupInfo group) async {
    final account = ref.read(authProvider).account;
    if (_busy || account == null) return;
    Object? result;
    final email = await groupTextDialog(
      context,
      context.l10n.inviteWho(group.name),
      label: context.l10n.email,
      email: true,
      maxLength: 254,
      help: context.l10n.groupInviteHelp,
      action: context.l10n.sendInvitation,
      check: (email) => ownEmailProblem(context, account.email, email),
      submit: (email) async {
        result = await _request(account.id, 'invite/', {
          'email': email,
          'role': 'editor',
        });
        return true;
      },
    );
    if (email == null || !mounted) return;
    await _guard(() => _applied(account.id, result));
  }

  /// Asks what [name] can do, with their [current] role marked.
  Future<String?> _chooseRole(
    TaskGroupInfo group, {
    required String name,
    String? current,
  }) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  context.l10n.groupRoleQuestion(name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final role in [
              'editor',
              'viewer',
              if (group.role == 'owner') 'admin',
            ])
              ListTile(
                selected: role == current,
                title: Text(groupRoleLabel(context, role)),
                trailing: role == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, role),
              ),
            ListTile(
              textColor: Theme.of(context).colorScheme.error,
              title: Text(context.l10n.removeAccess),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _member(TaskGroupInfo group, ProjectMember person) async {
    final role = await _chooseRole(
      group,
      name: person.name,
      current: person.role,
    );
    if (role == null || role == person.role || !mounted) return;
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
            ListTile(title: Text(context.l10n.groupTransfer)),
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
          context.l10n.groupTransferConfirm(group.name, person.name),
          context.l10n.groupTransferHelp,
          action: context.l10n.groupTransferAction(person.name),
        ) &&
        mounted) {
      await _run('transfer/', {'user_id': person.id, 'version': group.version});
    }
  }

  /// This member's own name for voice assignments. The owner's account name
  /// serves for them, so the server refuses one for the owner.
  Future<void> _voiceName(ProjectMember me) => _sendTyped(
    context.l10n.groupVoiceName,
    help: context.l10n.groupVoiceHelp,
    value: me.voiceName,
    allowEmpty: true,
    maxLength: 60,
    send: (name) => ('profile/', {'voice_name': name}, 'POST'),
  );

  Future<void> _rename(TaskGroupInfo group) => _sendTyped(
    context.l10n.groupName,
    value: group.name,
    send: (name) => (
      '',
      {'name': name, 'archived': group.archived, 'version': group.version},
      'PUT',
    ),
  );

  /// A text step whose dialog sends [send]'s request itself, as `_invite`
  /// does: it stays open until the server answers, so a failure keeps what
  /// was typed and says why. Then the page refreshes.
  Future<void> _sendTyped(
    String title, {
    required (String, Map<String, dynamic>, String) Function(String value) send,
    String? help,
    String value = '',
    bool allowEmpty = false,
    int maxLength = 80,
  }) async {
    final accountId = ref.read(authProvider).account?.id;
    if (_busy || accountId == null) return;
    Object? result;
    final typed = await groupTextDialog(
      context,
      title,
      help: help,
      value: value,
      allowEmpty: allowEmpty,
      maxLength: maxLength,
      submit: (text) async {
        final (action, data, method) = send(text);
        result = await _request(accountId, action, data, method: method);
        return true;
      },
    );
    if (typed == null || !mounted) return;
    await _guard(() => _applied(accountId, result));
  }

  /// The group's name: from its page or, while that loads, from the list.
  String _title(BuildContext context) =>
      (ref.watch(groupDetailsProvider(widget.groupId)).value?['group']
              as Map?)?['name']
          as String? ??
      ref
          .watch(groupsProvider)
          .value
          ?.where((group) => group.id == widget.groupId)
          .firstOrNull
          ?.name ??
      context.l10n.groups;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(title: _title(context)),
    // While a change is on its way, a thin bar under the app bar, in view
    // at any scroll; it covers the page's margin, so nothing moves.
    body: Stack(
      children: [
        _page(context),
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

  Widget _page(BuildContext context) => ref
      .watch(groupDetailsProvider(widget.groupId))
      .when(
        // A fetch that fails after a failed change keeps the page as it
        // was; only a page that never loaded says so.
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LoadFailed(
              onRetry: () =>
                  ref.invalidate(groupDetailsProvider(widget.groupId)),
            ),
          ],
        ),
        data: (details) {
          final group = TaskGroupInfo.fromJson(
            Map<String, dynamic>.from(details['group']),
          );
          final me = ref.watch(authProvider).account?.id;
          final projects = (ref.watch(taskListsProvider).value ?? [])
              .where((p) => p.groupId == group.id);
          final invitations = details['invitations'] as List? ?? [];
          return RefreshIndicator(
            // Offline, the page keeps what it shows and says why, as an
            // action's failure does.
            onRefresh: () async {
              final messenger = ScaffoldMessenger.of(context);
              final strings = context.l10n;
              ref.invalidate(groupDetailsProvider(widget.groupId));
              try {
                await ref.read(groupDetailsProvider(widget.groupId).future);
              } catch (error) {
                if (mounted) {
                  showFeedback(
                    messenger,
                    requestProblemText(strings, error, keptNote: false),
                  );
                }
              }
              await ref.read(taskProvider.notifier).loadTasks();
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // The page's main action first, as on a project's Miembros.
                if (group.canManage) ...[
                  FilledButton.icon(
                    key: const ValueKey('invite-person'),
                    onPressed: _busy ? null : () => _invite(group),
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(context.l10n.invitePerson),
                  ),
                  const SizedBox(height: 24),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.groupMembers,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final person in group.people)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      person.id == me
                          ? context.l10n.personYou(person.name)
                          : person.name,
                    ),
                    subtitle: Text(groupRoleLabel(context, person.role)),
                    trailing: person.id == me && person.id != group.ownerId
                        ? PopupMenuButton<String>(
                            enabled: !_busy,
                            tooltip: context.l10n.manageItem(person.name),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'voice',
                                child: Text(context.l10n.groupVoiceName),
                              ),
                            ],
                            onSelected: (_) => _voiceName(person),
                          )
                        : group.canManage &&
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
                if (invitations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.groupInvited,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final invitation in invitations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_send_outlined),
                      title: Text(
                        breakableAddress(invitation['email'] as String),
                        semanticsLabel: invitation['email'] as String,
                      ),
                      subtitle: Text(context.l10n.invitationPending),
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        onSelected: (action) => action == 'again'
                            ? _run('invite/', {
                                'email': invitation['email'],
                                'role': invitation['role'] ?? 'editor',
                              })
                            : _run('revoke_invite/', {
                                'invitation_id': invitation['id'],
                              }),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.groupProjects,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                    onPressed: () async {
                      try {
                        await ref.read(groupsProvider.future);
                      } catch (_) {
                        // The form says when the group can't be reached.
                      }
                      if (context.mounted) {
                        await createProject(context, ref, groupId: group.id);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.newList),
                  ),
                const Divider(height: 40),
                if (group.canManage) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.groupRename),
                    leading: const Icon(Icons.edit_outlined),
                    onTap: _busy ? null : () => _rename(group),
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
                      context.l10n.groupDeleteAction,
                      style: group.projectCount == 0
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                    // Why the row is off; an empty group needs no reason.
                    subtitle: group.projectCount == 0
                        ? null
                        : Text(context.l10n.groupDeleteHelp),
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
                                  context.l10n.groupDeleteAction,
                                  context.l10n.groupDeleteConfirm(group.name),
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
                              await _run('leave/', {}, leave: true, done: left);
                            }
                          },
                  ),
              ],
            ),
          );
        },
      );
}
