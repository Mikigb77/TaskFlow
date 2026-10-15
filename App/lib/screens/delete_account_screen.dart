import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/services/account_deletion.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/google_login_button.dart';

/// Google Play's help page on cancelling a subscription.
final playCancelHelp = Uri.parse(
  'https://support.google.com/googleplay/answer/7018481',
);

/// Opens a web page outside the app; false when nothing could open it.
final openWebPageProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Why the account wasn't deleted.
enum _Problem {
  wrongPassword,
  otherGoogleAccount,
  confirmAgain,
  planChanged,
  offline,
  noAnswer,
  throttled,
  failed,
}

/// One plain page: what goes, what stays for others and who receives what
/// the person owns, then the password or Google, then one destructive button.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _passwordArea = GlobalKey();
  final _googleArea = GlobalKey();
  final _changed = GlobalKey();
  final _outcome = GlobalKey();
  late final int? _accountId = ref.read(authProvider).account?.id;
  DeletionPreview? _preview;
  bool _loading = true;
  bool _reloading = false;
  bool _showPassword = false;
  bool _confirmingGoogle = false;
  bool _deleting = false;
  String? _googleToken;
  Object? _googleError;
  _Problem? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// The first load shows a spinner. A reload keeps the page as it is,
  /// what was typed included, until the new answer replaces it.
  Future<void> _load() async {
    final accountId = _accountId;
    if (accountId == null) return;
    if (_preview != null) {
      setState(() => _reloading = true);
    } else if (!_loading) {
      setState(() => _loading = true);
    }
    DeletionPreview? preview;
    try {
      preview = DeletionPreview.parse(
        await ref
            .read(apiClientProvider)
            .request('GET', 'auth/delete-account/', accountId: accountId),
      );
    } catch (_) {
      preview = null;
    }
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _loading = false;
      _reloading = false;
    });
  }

  bool get _ready {
    final preview = _preview;
    if (preview == null || _deleting || _reloading) return false;
    return preview.google ? _googleToken != null : _password.text.isNotEmpty;
  }

  Future<void> _confirmWithGoogle() async {
    setState(() {
      _confirmingGoogle = true;
      _googleError = null;
      _problem = null;
    });
    try {
      final token = await ref.read(googleSignInServiceProvider).authenticate();
      if (mounted && token != null) setState(() => _googleToken = token);
    } catch (error) {
      if (mounted) setState(() => _googleError = error);
    } finally {
      if (mounted) setState(() => _confirmingGoogle = false);
    }
  }

  static _Problem _problemFor(Object error) {
    if (error is! ApiException) return _Problem.failed;
    if (error.status == 400) {
      switch (error.body?['code']) {
        case 'wrong_password':
          return _Problem.wrongPassword;
        case 'google_reauth_failed':
          return _Problem.otherGoogleAccount;
        case 'reauth_required':
          return _Problem.confirmAgain;
      }
    }
    if (error.status == 409 && error.body?['code'] == 'plan_changed') {
      return _Problem.planChanged;
    }
    if (error.status == 429) return _Problem.throttled;
    // Without a network the request never left the phone. Any other lost
    // answer may have arrived, so it isn't called "nothing deleted".
    if (error.status == 0) {
      return error.message == ApiClient.offlineMessage
          ? _Problem.offline
          : _Problem.noAnswer;
    }
    return _Problem.failed;
  }

  Future<void> _delete() async {
    final preview = _preview;
    final account = ref.read(authProvider).account;
    if (!_ready ||
        preview == null ||
        account == null ||
        account.id != _accountId) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final api = ref.read(apiClientProvider);
    final auth = ref.read(authProvider.notifier);
    setState(() {
      _deleting = true;
      _problem = null;
      _googleError = null;
    });
    try {
      await api.request(
        'POST',
        'auth/delete-account/',
        accountId: account.id,
        data: {
          if (preview.google)
            'google_id_token': _googleToken
          else
            'password': _password.text,
          // Deletes only as previewed: if anything changed, nothing is.
          'plan': preview.plan,
        },
      );
    } catch (error) {
      // Already gone, deleted elsewhere or by an answer that was lost: the
      // app is on its way to sign-in, saying so.
      if (!mounted ||
          (error is ApiException &&
              error.status == 401 &&
              error.body?['code'] == 'user_not_found')) {
        return;
      }
      final problem = _problemFor(error);
      setState(() {
        _deleting = false;
        _problem = problem;
        // That Google confirmation can't be used again.
        if (problem == _Problem.otherGoogleAccount ||
            problem == _Problem.confirmAgain) {
          _googleToken = null;
        }
      });
      // What will happen, or the way to confirm, changed since the page
      // opened: show it as it is now. Only the person sends it again.
      if (problem == _Problem.planChanged ||
          problem == _Problem.confirmAgain) {
        unawaited(
          _load().then((_) {
            if (mounted) {
              _reveal(problem == _Problem.planChanged ? _changed : _outcome);
            }
          }),
        );
        return;
      }
      _reveal(switch (problem) {
        _Problem.wrongPassword => _passwordArea,
        _Problem.otherGoogleAccount => _googleArea,
        _ => _outcome,
      });
      return;
    }
    try {
      await auth.forgetDeletedAccount();
    } catch (_) {
      // Sign-in shows by now; nothing left behind belongs to any account.
    }
  }

  /// Brings an answer into view: at large text it can be below the screen.
  void _reveal(GlobalKey key) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        final target = key.currentContext;
        if (target == null || !target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          duration: duration,
          alignmentPolicy: policy,
        );
      }
    });
  }

  Future<void> _openPlayHelp() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.deleteAccountLinkError;
    var opened = false;
    try {
      opened = await ref.read(openWebPageProvider)(playCancelHelp);
    } catch (_) {
      opened = false;
    }
    if (!opened && messenger.mounted) {
      unawaited(showFeedback(messenger, failed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final preview = _preview;
    final outcome = switch (_problem) {
      _Problem.offline => strings.deleteAccountOffline,
      _Problem.noAnswer => strings.deleteAccountNoAnswer,
      _Problem.throttled => strings.deleteAccountThrottled,
      _Problem.confirmAgain => strings.deleteAccountConfirmAgain,
      _Problem.failed => strings.deleteAccountFailed,
      _ => null,
    };
    return PopScope(
      // Leaving wouldn't stop a deletion already sent.
      canPop: !_deleting,
      child: Scaffold(
        appBar: CustomAppBar(title: strings.deleteAccount),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  strings.deleteAccountQuestion,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(strings.deleteAccountIntro),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (preview == null)
                  LoadFailed(onRetry: _load)
                else ...[
                  ..._consequences(context, preview),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('delete-account-export'),
                      onPressed: _deleting
                          ? null
                          : () => Navigator.pushNamed(context, '/dataTransfer'),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      label: Text(strings.deleteAccountSaveCopy),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (preview.google)
                    _googleConfirmation(context)
                  else
                    _passwordConfirmation(context),
                  const SizedBox(height: 24),
                  // Above the button: read before confirming again.
                  if (_problem == _Problem.planChanged) ...[
                    Semantics(
                      liveRegion: true,
                      child: MessageBanner(
                        strings.deleteAccountPlanChanged,
                        key: _changed,
                        icon: Icons.info_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_reloading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    key: const ValueKey('delete-account-confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: _ready ? _delete : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_deleting) ...[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: strings.deleteAccountDeleting,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              strings.deleteAccountButton,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (outcome != null)
                    Padding(
                      key: _outcome,
                      padding: const EdgeInsets.only(top: 16),
                      child: MessageBanner(outcome, isError: true),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What goes, what stays for the others, and who receives what.
  List<Widget> _consequences(BuildContext context, DeletionPreview preview) {
    final strings = context.l10n;
    final counts = [
      if (preview.tasks > 0) strings.deleteAccountTasks(preview.tasks),
      if (preview.notes > 0) strings.deleteAccountNotes(preview.notes),
      if (preview.files > 0) strings.deleteAccountFiles(preview.files),
      if (preview.projects > 0) strings.deleteAccountProjects(preview.projects),
      if (preview.groups > 0) strings.deleteAccountGroups(preview.groups),
    ];
    final stays = [
      if (preview.keptInShared > 0)
        strings.deleteAccountKeptShared(preview.keptInShared),
      for (final handover in preview.handovers)
        strings.deleteAccountHandover(
          handover.group ? 'group' : 'project',
          handover.name,
          handover.to,
        ),
    ];
    return [
      if (counts.isNotEmpty) ...[
        Text(
          strings.deleteAccountWhatGoes,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final line in counts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(child: Text('•')),
                const SizedBox(width: 10),
                Expanded(child: Text(line)),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
      for (final line in stays)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(line),
        ),
      if (preview.pro) ...[
        if (stays.isNotEmpty) const SizedBox(height: 4),
        Text(
          strings.deleteAccountSubscription,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('delete-account-play-help'),
            onPressed: _openPlayHelp,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(strings.deleteAccountSubscriptionHelp),
          ),
        ),
      ],
      const SizedBox(height: 8),
    ];
  }

  Widget _passwordConfirmation(BuildContext context) {
    final strings = context.l10n;
    return KeyedSubtree(
      key: _passwordArea,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.deleteAccountPasswordHelp),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('delete-account-password'),
            controller: _password,
            enabled: !_deleting,
            obscureText: !_showPassword,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              if (_problem == _Problem.wrongPassword) _problem = null;
            }),
            decoration: InputDecoration(
              labelText: strings.password,
              errorText: _problem == _Problem.wrongPassword
                  ? strings.deleteAccountWrongPassword
                  : null,
              errorMaxLines: 4,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? strings.hidePassword
                    : strings.showPassword,
                onPressed: _deleting
                    ? null
                    : () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleConfirmation(BuildContext context) {
    final strings = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final error = _problem == _Problem.otherGoogleAccount
        ? strings.deleteAccountOtherGoogle
        : _googleError == null
        ? null
        : requestProblemText(strings, _googleError!, onSignIn: true);
    return KeyedSubtree(
      key: _googleArea,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.deleteAccountGoogleHelp),
          const SizedBox(height: 12),
          if (_googleToken == null)
            GoogleLoginButton(
              key: const ValueKey('delete-account-google'),
              label: strings.deleteAccountConfirmGoogle,
              onPressed: _deleting || _confirmingGoogle
                  ? null
                  : _confirmWithGoogle,
            )
          else
            Row(
              key: const ValueKey('delete-account-google-confirmed'),
              children: [
                Icon(Icons.check_circle_outline, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.deleteAccountGoogleConfirmed)),
              ],
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(error, style: TextStyle(color: colors.error)),
              ),
            ),
        ],
      ),
    );
  }
}
