import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/widgets/app_components.dart';

/// One pending invitation. Tapping it opens the join dialog; [more] counts
/// the invitations waiting behind it.
class InvitationCard extends StatelessWidget {
  const InvitationCard({super.key, required this.invitation, this.more = 0});
  final PendingInvitation invitation;
  final int more;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      key: ValueKey('invitation-${invitation.id}'),
      leading: const Icon(Icons.mail_outline),
      title: Text(context.l10n.invitedTo(invitation.name)),
      trailing: more > 0 ? Text(context.l10n.invitationsMore(more)) : null,
      onTap: () => openInvitation(context, invitation),
    ),
  );
}

/// Every pending invitation, one card each; [kind] keeps only that kind.
class PendingInvitations extends ConsumerWidget {
  const PendingInvitations({super.key, this.kind});
  final String? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(pendingInvitationsProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(pendingInvitationsProvider),
          child: Text(context.l10n.retryInvitations),
        ),
        data: (invitations) => Column(
          children: [
            for (final invitation in invitations.where(
              (invitation) => kind == null || invitation.kind == kind,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InvitationCard(invitation: invitation),
              ),
          ],
        ),
      );
}

bool _responding = false;

/// Asks for the code to join [invitation], or declines it after one
/// confirmation. Joining waits in the dialog, then opens what was joined.
Future<void> openInvitation(
  BuildContext context,
  PendingInvitation invitation,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final account = container.read(authProvider).account;
  if (_responding || account == null) return;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final strings = context.l10n;
  // An invitation link opened earlier already holds the code.
  final link = container.read(invitationLinkProvider);
  final answer = await showDialog<({bool declining, Object? result})>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _JoinDialog(
      container: container,
      invitation: invitation,
      accountId: account.id,
      code: link != null && link.id == invitation.id ? link.code : '',
    ),
  );
  if (answer == null ||
      container.read(authProvider).account?.id != account.id) {
    return;
  }
  if (!answer.declining) {
    showJoined(
      navigator: navigator,
      messenger: messenger,
      strings: strings,
      group: invitation.group,
      targetId: joinedId(answer.result) ?? invitation.targetId,
      name: invitation.name,
    );
    return;
  }
  if (!context.mounted ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              scrollable: true,
              content: Text(
                context.l10n.declineInvitationConfirm(invitation.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  key: const ValueKey('confirm-decline'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.decline),
                ),
              ],
            ),
          ) !=
          true) {
    return;
  }
  if (_responding || container.read(authProvider).account?.id != account.id) {
    return;
  }
  _responding = true;
  try {
    await container
        .read(apiClientProvider)
        .request(
          'POST',
          '${invitation.endpoint}/${invitation.id}/respond/',
          data: {'decision': 'decline'},
          accountId: account.id,
        );
    if (container.read(authProvider).account?.id != account.id) return;
    await refreshAfterInvitation(container, invitation.id);
  } catch (error) {
    if (messenger.mounted) {
      showFeedback(messenger, requestProblemText(strings, error));
    }
  } finally {
    _responding = false;
  }
}

/// The join dialog. Unirme sends the code from here and waits, so a wrong
/// code stays in the field with the problem under it.
class _JoinDialog extends StatefulWidget {
  const _JoinDialog({
    required this.container,
    required this.invitation,
    required this.accountId,
    required this.code,
  });
  final ProviderContainer container;
  final PendingInvitation invitation;
  final int accountId;
  final String code;

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _form = GlobalKey<FormState>();
  late var _entered = widget.code;
  var _sending = false;
  String? _problem;

  bool get _switched =>
      widget.container.read(authProvider).account?.id != widget.accountId;

  Future<void> _join() async {
    if (_sending || _responding || !_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final strings = context.l10n;
    if (_switched) {
      navigator.pop();
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    _responding = true;
    try {
      final result = await widget.container
          .read(apiClientProvider)
          .request(
            'POST',
            '${widget.invitation.endpoint}/${widget.invitation.id}/respond/',
            data: {'decision': 'accept', 'code': _entered},
            accountId: widget.accountId,
          );
      if (_switched) {
        if (mounted) navigator.pop();
        return;
      }
      // Joined: a refresh that fails doesn't undo that.
      try {
        await refreshAfterInvitation(widget.container, widget.invitation.id);
      } catch (_) {}
      if (mounted) navigator.pop((declining: false, result: result));
    } catch (error) {
      if (!mounted) return;
      if (_switched) {
        navigator.pop();
        return;
      }
      setState(
        () => _problem = sharingProblemReason(error) == 'code'
            ? strings.invitationCodeWrong
            : requestProblemText(strings, error),
      );
    } finally {
      _responding = false;
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      scrollable: true,
      title: Text(context.l10n.joinInvitationTitle(widget.invitation.name)),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.joinInvitationHelp),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('accept-invitation-code'),
              initialValue: _entered,
              enabled: !_sending,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.l10n.invitationCode,
                errorText: _problem,
                // Room for the longest problem at 2× text in 320 dp.
                errorMaxLines: 12,
              ),
              onChanged: (value) => setState(() {
                _entered = value.trim();
                _problem = null;
              }),
              onFieldSubmitted: (_) => _join(),
              validator: (_) => _entered.length >= 16
                  ? null
                  : context.l10n.invitationCodeRequired,
            ),
          ],
        ),
      ),
      // Decline can't be undone: it sits away from Join.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          key: const ValueKey('decline-invitation'),
          onPressed: _sending
              ? null
              : () => Navigator.pop(context, (declining: true, result: null)),
          child: Text(context.l10n.decline),
        ),
        OverflowBar(
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: _sending ? null : _join,
              child: _sending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: context.l10n.joinInvitation,
                      ),
                    )
                  : Text(context.l10n.joinInvitation),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The project or group a successful answer names.
String? joinedId(Object? result) => result is Map
    ? (result['list_id'] ?? result['group_id']) as String?
    : null;

/// Brings everything an answered invitation changes up to date, and forgets
/// its link.
Future<void> refreshAfterInvitation(
  ProviderContainer container,
  String invitationId,
) async {
  final link = container.read(invitationLinkProvider);
  if (link != null && link.id == invitationId) {
    container.read(invitationLinkProvider.notifier).clear(link);
  }
  container.invalidate(pendingInvitationsProvider);
  container.invalidate(groupsProvider);
  await container.read(taskProvider.notifier).loadTasks();
  container.invalidate(taskListsProvider);
}

/// Opens the joined project's or group's page and says so. [replace] puts
/// it in place of the current screen, which closes as handled.
void showJoined({
  required NavigatorState navigator,
  required ScaffoldMessengerState messenger,
  required AppLocalizations strings,
  required bool group,
  required String? targetId,
  required String name,
  bool replace = false,
}) {
  if (!navigator.mounted) return;
  if (targetId != null) {
    final page = MaterialPageRoute<void>(
      builder: (_) => group
          ? GroupScreen(groupId: targetId)
          : HomeScreen(isRoot: false, listId: targetId),
    );
    replace
        ? navigator.pushReplacement(page, result: true)
        : navigator.push(page);
  } else if (replace) {
    navigator.pop(true);
  }
  if (messenger.mounted) showFeedback(messenger, strings.joinedInvitation(name));
}
