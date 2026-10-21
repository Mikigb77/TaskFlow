import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:agenda/widgets/name_ask_sheet.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/screens/login_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.debug = kDebugMode});

  /// Only debug builds show the server address here; staging builds reach it
  /// from the version line in Other settings.
  final bool debug;
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

enum _Action { sync, import, google, signOut }

class _AccountScreenState extends ConsumerState<AccountScreen> {
  _Action? _running;
  bool _failed = false;
  String? _message;
  Object? _failure;
  late Future<int> _localItems = ref
      .read(taskRepositoryProvider)
      .localTaskCount();

  Future<void> _run(_Action kind, Future<void> Function() action) async {
    setState(() {
      _running = kind;
      _message = null;
      _failure = null;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _sync() => _run(
    _Action.sync,
    () => ref.read(taskProvider.notifier).loadTasks(),
  );

  Future<void> _import() async {
    final count = await _localItems;
    if (count == 0 || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.importLocalItemsQuestion),
        content: Text(context.l10n.importLocalItemsHelp(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.importItems),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(_Action.import, () async {
      final repository = ref.read(taskRepositoryProvider);
      final imported = await repository.importLocalTasks();
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) {
        setState(() {
          _message = context.l10n.itemsImported(imported);
          _localItems = repository.localTaskCount();
        });
      }
    });
  }

  Future<void> _signOut() async {
    // Signing out cancels every reminder on this phone, so ask first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        content: Text(context.l10n.signOutQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      _Action.signOut,
      () => ref.read(authProvider.notifier).signOut(),
    );
  }

  Future<void> _linkGoogle() async {
    final current = ref.read(authProvider).account;
    if (current == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _GoogleLinkDialog(),
    );
    if (password == null || !mounted) return;
    await _run(_Action.google, () async {
      final token = await ref.read(googleSignInServiceProvider).authenticate();
      if (token == null || !mounted) return;
      if (ref.read(authProvider).account?.id != current.id) return;
      await ref.read(authProvider.notifier).linkGoogle(token, password);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.account == null) return const LoginScreen();
    final busy = _running != null || auth.loading;
    final colors = Theme.of(context).colorScheme;
    final google = ref.watch(googleSignInServiceProvider);
    ref.watch(taskProvider);
    final syncError = ref.read(taskRepositoryProvider).syncError;
    final name = auth.account!.firstName.trim();
    final email = auth.account!.email;
    // In-button progress names what is happening, so TalkBack says it.
    Widget progress(String label, {Color? color}) => SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
        semanticsLabel: label,
      ),
    );
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.yourAccount),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // The person's name, when the account has one; then the email.
              if (name.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text(name,
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                breakableAddress(email),
                semanticsLabel: email,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              // Sets or fixes the name people see on shared projects.
              ListTile(
                key: const ValueKey('account-name'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(
                  name.isEmpty
                      ? context.l10n.accountAddName
                      : context.l10n.nameAskField,
                ),
                subtitle: name.isEmpty ? null : Text(name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => editName(context),
              ),
              const SizedBox(height: 12),
              if (auth.account!.googleLinked) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(context.l10n.googleAccountLinked),
                ),
                const SizedBox(height: 12),
              ] else if (google.configured) ...[
                GoogleLoginButton(
                  label: context.l10n.linkGoogleAccount,
                  onPressed: busy ? null : _linkGoogle,
                ),
                if (_running == _Action.google) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
              ],
              // The sync state in one line; a failed sync says so here, once.
              if (syncError == null)
                ListTile(
                  key: const ValueKey('account-sync-status'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.cloud_done_outlined,
                    color: colors.primary,
                  ),
                  title: Text(context.l10n.accountSaved),
                )
              else
                MessageBanner(
                  requestProblemText(context.l10n, syncError),
                  key: const ValueKey('account-sync-status'),
                  isError: true,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: busy ? null : _sync,
                  icon: _running == _Action.sync
                      ? progress(context.l10n.accountSyncing)
                      : const Icon(Icons.sync_rounded, size: 20),
                  label: Text(context.l10n.syncNow),
                ),
              ),
              FutureBuilder<int>(
                future: _localItems,
                builder: (context, snapshot) {
                  if ((snapshot.data ?? 0) == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _import,
                      icon: _running == _Action.import
                          ? progress(context.l10n.accountImporting)
                          : const Icon(Icons.file_upload_outlined, size: 20),
                      label: Text(context.l10n.importLocalItems),
                    ),
                  );
                },
              ),
              if (_message != null || _failure != null || auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: MessageBanner(
                    _message ??
                        requestProblemText(
                          context.l10n,
                          _failure ?? auth.error!,
                        ),
                    isError: auth.error != null || _failed,
                  ),
                ),
              if (widget.debug) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(context.l10n.connectionDetails),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SelectableText(
                        ref.read(apiClientProvider).baseUrl,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                // Sign-out can wait on the server; show progress in the button,
                // and nothing at rest.
                child: TextButton.icon(
                  onPressed: busy ? null : _signOut,
                  icon: _running == _Action.signOut
                      ? progress(
                          context.l10n.accountSigningOut,
                          color: colors.error,
                        )
                      : null,
                  label: Text(
                    context.l10n.signOut,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
              // Deleting the account is its own group, kept apart from
              // signing out.
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('account-delete'),
                  onPressed: busy
                      ? null
                      : () => Navigator.pushNamed(context, '/deleteAccount'),
                  child: Text(
                    context.l10n.deleteAccount,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLinkDialog extends StatefulWidget {
  const _GoogleLinkDialog();
  @override
  State<_GoogleLinkDialog> createState() => _GoogleLinkDialogState();
}

class _GoogleLinkDialogState extends State<_GoogleLinkDialog> {
  final password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.linkGoogleAccount),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.googleLinkHelp),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('google-link-password'),
          controller: password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: context.l10n.password),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: password.text.isEmpty
            ? null
            : () => Navigator.pop(context, password.text),
        child: Text(context.l10n.continueWithGoogle),
      ),
    ],
  );
}
