import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/widgets/invitation_cards.dart';

class InvitationReviewScreen extends ConsumerStatefulWidget {
  const InvitationReviewScreen({super.key, required this.invitation});
  final InvitationLink invitation;
  @override
  ConsumerState<InvitationReviewScreen> createState() =>
      _InvitationReviewScreenState();
}

class _InvitationReviewScreenState
    extends ConsumerState<InvitationReviewScreen> {
  Map? _details;
  Object? _error;
  bool _loading = true, _accepting = false;
  int? _accountId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = ref.read(authProvider).account;
    if (account == null) return;
    _accountId = account.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref
                  .read(apiClientProvider)
                  .request(
                    'GET',
                    '${widget.invitation.endpoint}/',
                    accountId: account.id,
                  )
              as Map;
      final matching = (data['invitations'] as List)
          .whereType<Map>()
          .where((row) => row['id'] == widget.invitation.id)
          .firstOrNull;
      if (!mounted || ref.read(authProvider).account?.id != account.id) return;
      if (matching == null) {
        throw ApiException(404, 'Invitation unavailable for this account.');
      }
      setState(() => _details = matching);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (_accepting || _accountId != ref.read(authProvider).account?.id) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    final details = _details!;
    final group = widget.invitation.kind == 'group';
    try {
      final result = await ref
          .read(apiClientProvider)
          .request(
            'POST',
            '${widget.invitation.endpoint}/${widget.invitation.id}/respond/',
            data: {'decision': 'accept', 'code': widget.invitation.code},
            accountId: _accountId,
          );
      if (!mounted || _accountId != ref.read(authProvider).account?.id) return;
      await refreshAfterInvitation(
        ProviderScope.containerOf(context, listen: false),
        widget.invitation.id,
      );
      if (mounted && _accountId == ref.read(authProvider).account?.id) {
        // Land on what was joined, in place of this screen.
        showJoined(
          navigator: navigator,
          messenger: messenger,
          strings: strings,
          group: group,
          targetId:
              joinedId(result) ??
              (group ? details['group_id'] : details['list_id']) as String?,
          name: (details['group_name'] ?? details['list_name']) as String,
          replace: true,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  bool get _unavailable =>
      _details == null &&
      _error is ApiException &&
      (_error as ApiException).status == 404;

  /// What a role other than editor lets the person do, in plain words.
  String? _accessLine(Object? role) => switch (role) {
    'viewer' => context.l10n.invitationViewerAccess,
    'admin' => context.l10n.invitationAdminAccess,
    _ => null,
  };

  /// The first line: who invited you to what, or just what when the
  /// server doesn't say who.
  String _headline(Map details) {
    final name = (details['group_name'] ?? details['list_name']) as String;
    final sender = invitationSender(details);
    return sender == null ? name : context.l10n.invitationFrom(sender, name);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final account = ref.watch(authProvider).account;
    return Scaffold(
      appBar: AppBar(title: Text(strings.invitationReview)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (_details != null) ...[
                      Text(
                        _headline(_details!),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(strings.invitationReviewHelp),
                      const SizedBox(height: 24),
                      // Editor, the usual role, goes without saying.
                      if (_accessLine(_details!['role']) case final line?) ...[
                        Text(line),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (account != null)
                      Text(
                        strings.signedInAs(account.email),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _error is ApiException &&
                                  (_error as ApiException).status == 404
                              ? strings.invitationUnavailable
                              : requestProblemText(strings, _error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_details != null)
                      FilledButton.icon(
                        onPressed: _accepting ? null : _accept,
                        icon: _accepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(strings.acceptInvitation),
                      )
                    else if (_unavailable)
                      // Asking again gets the same answer: the link is
                      // dropped.
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(strings.close),
                      )
                    else
                      OutlinedButton(
                        onPressed: _load,
                        child: Text(strings.tryAgain),
                      ),
                    // Keeps the link: Calendar's card offers the
                    // invitation again.
                    if (!_unavailable)
                      TextButton(
                        onPressed: _accepting
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text(strings.invitationNotNow),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
