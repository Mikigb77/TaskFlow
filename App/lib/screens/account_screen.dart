import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/screens/login_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  bool _failed = false;
  String? _message;
  Object? _failure;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final local = await TaskDatabase().getTasks();
    if (!mounted) return;
    if (local.isEmpty) {
      setState(() => _message = context.l10n.noLocalItems);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.importLocalItemsQuestion),
        content: Text(context.l10n.importLocalItemsHelp(local.length)),
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
    await _run(() async {
      final count = await ref.read(taskRepositoryProvider).importLocalTasks();
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) setState(() => _message = context.l10n.itemsImported(count));
    });
  }

  Future<void> _linkGoogle() async {
    final current = ref.read(authProvider).account;
    if (current == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _GoogleLinkDialog(),
    );
    if (password == null || !mounted) return;
    await _run(() async {
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
    final busy = _busy || auth.loading;
    final colors = Theme.of(context).colorScheme;
    final google = ref.watch(googleSignInServiceProvider);
    ref.watch(taskProvider);
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.yourAccount),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              if (auth.account != null) ...[
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
                Text(
                  context.l10n.accountHeading,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  auth.account!.email,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
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
                  const SizedBox(height: 20),
                ],
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        color: colors.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.backupHeading,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.accountBackupHelp,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _run(() async {
                                  await ref
                                      .read(taskProvider.notifier)
                                      .loadTasks();
                                  if (mounted) {
                                    setState(() {
                                      _failure = ref
                                          .read(taskRepositoryProvider)
                                          .syncError;
                                      _failed = _failure != null;
                                      _message = _failure == null
                                          ? context.l10n.accountUpToDate
                                          : null;
                                    });
                                  }
                                }),
                          icon: const Icon(Icons.sync_rounded, size: 20),
                          label: Text(context.l10n.syncNow),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : _import,
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: Text(context.l10n.importLocalItems),
                ),
                const SizedBox(height: 12),
                if (ref.read(taskRepositoryProvider).syncError != null)
                  MessageBanner(
                    requestProblemText(
                      context.l10n,
                      ref.read(taskRepositoryProvider).syncError!,
                    ),
                    isError: true,
                  ),
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
                const SizedBox(height: 20),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(
                          () => ref.read(authProvider.notifier).signOut(),
                        ),
                  child: Text(
                    context.l10n.signOut,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
