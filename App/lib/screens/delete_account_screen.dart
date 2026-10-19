import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/archive_locale.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/models/archive_diagnostic.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/services/account_deletion.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/site_links.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/google_login_button.dart';

/// Google Play's subscriptions page, for when billing knows of no purchase.
final playSubscriptions = Uri.parse(
  'https://play.google.com/store/account/subscriptions',
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
  final _confirmButton = GlobalKey();
  late final int? _accountId = ref.read(authProvider).account?.id;
  late final String _email = ref.read(authProvider).account?.email ?? '';
  late final bool _complimentary =
      ref.read(authProvider).account?.complimentaryPro == true;

  /// A password account with Google linked can confirm either way.
  late final bool _googleLinked =
      ref.read(authProvider).account?.googleLinked == true;
  DeletionPreview? _preview;
  bool _loading = true;
  bool _reloading = false;
  bool _showPassword = false;
  bool _confirmingGoogle = false;
  bool _deleting = false;
  bool _savingCopy = false;
  bool _copySaved = false;
  Object? _copyError;
  String? _googleToken;
  Object? _googleError;
  _Problem? _problem;

  /// Handovers that are new or changed since the page last showed them,
  /// after the server refused because the plan changed. Bold until the next
  /// tap on Delete my account.
  List<Handover> _changedHandovers = const [];

  /// How long the server said to wait, when it said.
  int? _waitMinutes;

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
    return _googleToken != null ||
        (!preview.google && _password.text.isNotEmpty);
  }

  Future<void> _confirmWithGoogle() async {
    setState(() {
      _confirmingGoogle = true;
      _googleError = null;
      _problem = null;
      _waitMinutes = null;
    });
    try {
      final token = await ref.read(googleSignInServiceProvider).authenticate();
      if (mounted && token != null) {
        setState(() => _googleToken = token);
        // At large text the button it enables can be below the screen.
        _reveal(_confirmButton);
      }
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
      _waitMinutes = null;
      _googleError = null;
      _changedHandovers = const [];
    });
    try {
      await api.request(
        'POST',
        'auth/delete-account/',
        accountId: account.id,
        data: {
          if (_googleToken != null)
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
        _waitMinutes = waitMinutesFor(error);
        // That Google confirmation can't be used again.
        if (problem == _Problem.otherGoogleAccount ||
            problem == _Problem.confirmAgain) {
          _googleToken = null;
        }
      });
      // What will happen, or the way to confirm, changed since the page
      // opened: show it as it is now. Only the person sends it again.
      if (problem == _Problem.planChanged || problem == _Problem.confirmAgain) {
        unawaited(
          _load().then((_) {
            if (!mounted) return;
            if (problem == _Problem.planChanged) {
              setState(
                () => _changedHandovers = _newOrChanged(
                  preview.handovers,
                  _preview?.handovers ?? const [],
                ),
              );
            }
            _reveal(problem == _Problem.planChanged ? _changed : _outcome);
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

  /// The handovers in [after] that nothing in [before] matched in kind, name
  /// and recipient: a project now going to someone else counts.
  static List<Handover> _newOrChanged(
    List<Handover> before,
    List<Handover> after,
  ) => [
    for (final handover in after)
      if (!before.any(
        (old) =>
            old.group == handover.group &&
            old.name == handover.name &&
            old.to == handover.to,
      ))
        handover,
  ];

  static String _handoverText(AppLocalizations strings, Handover handover) =>
      strings.deleteAccountHandover(
        handover.group ? 'group' : 'project',
        handover.name,
        handover.to,
      );

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

  /// Saves a TaskFlow file here, as Export & import does, through Android's
  /// save screen. Backing out of it changes nothing.
  Future<void> _saveCopy() async {
    setState(() {
      _savingCopy = true;
      _copyError = null;
    });
    try {
      final contents = await ref.read(archiveStoreProvider).export();
      if (!mounted) return;
      final saved = await ref.read(archiveFilesProvider).save(contents);
      if (mounted && saved) setState(() => _copySaved = true);
    } catch (error) {
      if (mounted) setState(() => _copyError = error);
    } finally {
      if (mounted) setState(() => _savingCopy = false);
    }
  }

  /// The Pro screen's Customer Center when billing knows of a purchase;
  /// otherwise Google Play's subscriptions page.
  Future<void> _manageSubscription(bool purchased) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    if (purchased) {
      final result = await ref
          .read(subscriptionProvider.notifier)
          .presentCustomerCenter(
            Localizations.localeOf(context).toLanguageTag(),
          );
      if (result != BillingResult.cancelled && messenger.mounted) {
        unawaited(showFeedback(messenger, strings.billingResult(result.name)));
      }
      return;
    }
    await openWebPage(context, ref, playSubscriptions);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final preview = _preview;
    final outcome = switch (_problem) {
      _Problem.offline => strings.deleteAccountOffline,
      _Problem.noAnswer => strings.deleteAccountNoAnswer,
      _Problem.throttled =>
        _waitMinutes == null
            ? strings.deleteAccountThrottled
            : strings.tooManyTriesWait(_waitMinutes!),
      _Problem.confirmAgain => strings.deleteAccountConfirmAgain,
      _Problem.failed => strings.deleteAccountFailed,
      _ => null,
    };
    return PopScope(
      // Leaving wouldn't stop a deletion already sent.
      canPop: !_deleting,
      child: Scaffold(
        appBar: CustomAppBar(
          title: strings.deleteAccount,
          canGoBack: !_deleting,
        ),
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
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Which account goes, as Account names it.
                  Text(
                    _email,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                Text(strings.deleteAccountIntro),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (preview == null)
                  LoadFailed(onRetry: _load)
                else ...[
                  ..._consequences(context, preview),
                  // Only what is the person's own can be copied.
                  if (preview.tasks > 0 || preview.notes > 0)
                    _copy(context, preview),
                  const SizedBox(height: 24),
                  if (preview.google)
                    _googleConfirmation(
                      context,
                      strings.deleteAccountGoogleHelp(_email),
                    )
                  else ...[
                    // Confirmed with Google, the password isn't needed.
                    if (_googleToken == null) _passwordConfirmation(context),
                    if (_googleLinked) ...[
                      if (_googleToken == null) const SizedBox(height: 16),
                      _googleConfirmation(
                        context,
                        _googleToken == null
                            ? strings.deleteAccountGoogleInstead(_email)
                            : null,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  // Above the button: read before confirming again.
                  if (_problem == _Problem.planChanged) ...[
                    _changedBanner(strings),
                    const SizedBox(height: 16),
                  ],
                  if (_reloading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  KeyedSubtree(
                    key: _confirmButton,
                    child: FilledButton(
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
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                _deleting
                                    ? strings.deleteAccountDeleting
                                    : strings.deleteAccountButton,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
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
        _bullet(strings.deleteAccountKeptShared(preview.keptInShared)),
      if (preview.keptFilesInShared > 0)
        _bullet(strings.deleteAccountKeptFiles(preview.keptFilesInShared)),
      for (final handover in preview.handovers)
        _bullet(
          _handoverText(strings, handover),
          bold: _changedHandovers.contains(handover),
        ),
    ];
    final heading = Theme.of(context).textTheme.titleMedium;
    return [
      if (counts.isNotEmpty) ...[
        Text(strings.deleteAccountWhatGoes, style: heading),
        const SizedBox(height: 8),
        for (final line in counts) _bullet(line),
        const SizedBox(height: 16),
      ],
      if (stays.isNotEmpty) ...[
        Text(strings.deleteAccountWhatStays, style: heading),
        const SizedBox(height: 8),
        ...stays,
        const SizedBox(height: 16),
      ],
      if (preview.pro && !_complimentary) ...[
        Text(strings.deleteAccountSubscription),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _manageLink(strings),
        ),
      ],
      const SizedBox(height: 8),
    ];
  }

  /// Gestionar suscripción, as on the Pro screen: its Customer Center when
  /// billing is ready and knows of a purchase, else Google Play's page.
  Widget _manageLink(AppLocalizations strings) {
    final billing = ref.watch(subscriptionProvider);
    final purchased =
        billing.ready &&
        billing.customerInfo?.allPurchasedProductIdentifiers.isNotEmpty == true;
    return TextButton.icon(
      key: const ValueKey('delete-account-manage-subscription'),
      onPressed: purchased && billing.busy
          ? null
          : () => _manageSubscription(purchased),
      icon: const Icon(Icons.manage_accounts_outlined),
      label: Text(strings.billingManage),
    );
  }

  /// What changed, one line each once the reload knows. Silent while it
  /// reloads, then read once with its final text, without the bullets.
  Widget _changedBanner(AppLocalizations strings) {
    final lines = _reloading || _changedHandovers.isEmpty
        ? [strings.deleteAccountPlanChanged]
        : [
            strings.deleteAccountChangedIntro,
            for (final handover in _changedHandovers)
              _handoverText(strings, handover),
            strings.deleteAccountChangedCheck,
          ];
    // Between the intro and the check, every line is a handover.
    final visible = [
      for (var i = 0; i < lines.length; i++)
        i > 0 && i < lines.length - 1 ? '• ${lines[i]}' : lines[i],
    ];
    return Semantics(
      container: true,
      liveRegion: !_reloading,
      label: lines.join('\n'),
      child: ExcludeSemantics(
        child: MessageBanner(
          visible.join('\n'),
          key: _changed,
          icon: Icons.info_outline,
        ),
      ),
    );
  }

  /// One line of a list on this page, after a bullet TalkBack doesn't read.
  Widget _bullet(String line, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(child: Text('•')),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            line,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ),
      ],
    ),
  );

  /// The link that saves a copy, then the check that it was saved, and what
  /// the copy leaves out.
  Widget _copy(BuildContext context, DeletionPreview preview) {
    final strings = context.l10n;
    final colors = Theme.of(context).colorScheme;
    // Where TextButton.icon puts its icon: 12 dp in, less at large text.
    final inset = ButtonStyleButton.scaledPadding(
      const EdgeInsetsDirectional.only(start: 12),
      const EdgeInsetsDirectional.only(start: 4),
      const EdgeInsetsDirectional.only(start: 4),
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final error = _copyError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_copySaved)
          Semantics(
            key: const ValueKey('delete-account-copy-saved'),
            liveRegion: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: inset,
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(strings.deleteAccountCopySaved)),
                  ],
                ),
              ),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('delete-account-export'),
              onPressed: _deleting || _savingCopy ? null : _saveCopy,
              icon: const Icon(Icons.download_outlined, size: 20),
              label: Text(strings.deleteAccountSaveCopy),
            ),
          ),
        if (error != null)
          Padding(
            padding: inset.add(const EdgeInsets.only(bottom: 4)),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error is ArchiveDiagnostic
                    ? context.archiveDiagnostic(error)
                    : strings.transferError,
                style: TextStyle(color: colors.error),
              ),
            ),
          ),
        if (preview.files > 0)
          Padding(
            padding: inset,
            child: Text(
              strings.deleteAccountCopyNoFiles,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
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
              errorText: _problem != _Problem.wrongPassword
                  ? null
                  : _googleLinked
                  ? strings.deleteAccountWrongPasswordGoogle
                  : strings.deleteAccountWrongPassword,
              errorMaxLines: 10,
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

  /// [help] says which Google account to choose; null once confirmed in
  /// place of the password.
  Widget _googleConfirmation(BuildContext context, String? help) {
    final strings = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final error = _problem == _Problem.otherGoogleAccount
        ? strings.deleteAccountOtherGoogle(_email)
        : _googleError == null
        ? null
        : requestProblemText(strings, _googleError!, onSignIn: true);
    return KeyedSubtree(
      key: _googleArea,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (help != null) ...[Text(help), const SizedBox(height: 12)],
          if (_googleToken == null)
            GoogleLoginButton(
              key: const ValueKey('delete-account-google'),
              label: strings.deleteAccountConfirmGoogle,
              onPressed: _deleting || _confirmingGoogle
                  ? null
                  : _confirmWithGoogle,
            )
          else
            // TalkBack's focus was on the button this replaces.
            Semantics(
              liveRegion: true,
              child: Row(
                key: const ValueKey('delete-account-google-confirmed'),
                children: [
                  Icon(Icons.check_circle_outline, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(strings.deleteAccountGoogleConfirmed)),
                ],
              ),
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
