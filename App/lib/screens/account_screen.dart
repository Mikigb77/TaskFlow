import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late final TextEditingController _server;
  bool _register = false;
  bool _recover = false;
  bool _busy = false;
  bool _showPassword = false;
  bool _failed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ref.read(apiClientProvider).baseUrl);
  }

  @override
  void dispose() {
    for (final controller in [_email, _password, _code, _server]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final api = ref.read(apiClientProvider);
      await api.setServer(_server.text);
      if (_recover) {
        final result = await api.request(
            'POST',
            _code.text.trim().isEmpty
                ? 'auth/password-reset/'
                : 'auth/password-reset/confirm/',
            authenticated: false,
            data: _code.text.trim().isEmpty
                ? {'email': _email.text.trim()}
                : {'code': _code.text.trim(), 'password': _password.text});
        if (mounted) setState(() => _message = result['detail'] as String);
        return;
      }
      await ref.read(regionalProvider.notifier).ready;
      final zone = await CaptureTimezone.resolve(ref.read(regionalProvider));
      await ref.read(authProvider.notifier).signIn(_email.text, _password.text,
          register: _register, timezone: zone.identifier);
    });
  }

  Future<void> _import() async {
    final local = await TaskDatabase().getTasks();
    if (!mounted) return;
    if (local.isEmpty) {
      setState(() => _message = 'There are no local tasks to import.');
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Import local tasks?'),
              content: Text(
                  'Move ${local.length} tasks from this phone into your account and back up their titles, dates, priorities and notes. Attachments stay on this phone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Import'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final count = await ref.read(taskRepositoryProvider).importLocalTasks();
      await ref.read(taskProvider.notifier).loadTasks();
      if (mounted) setState(() => _message = '$count tasks imported.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final busy = _busy || auth.loading;
    final colors = Theme.of(context).colorScheme;
    ref.watch(taskProvider);
    return Scaffold(
      appBar: const CustomAppBar(title: 'Your account'),
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
                                  borderRadius: BorderRadius.circular(24)),
                              child: Icon(Icons.person_outline_rounded,
                                  size: 32, color: colors.primary))),
                      const SizedBox(height: 24),
                      Text('Your own little space.',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(auth.account!.email,
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 28),
                      AppSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Icon(Icons.cloud_done_outlined,
                                color: colors.primary, size: 28),
                            const SizedBox(height: 12),
                            Text('Your plans, kept close.',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                                'Tasks are saved on this phone and backed up when connected. New attachments upload after saving; check their status in task details. Older device-only files need an explicit Upload.',
                                style:
                                    TextStyle(color: colors.onSurfaceVariant)),
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
                                                setState(() => _message = ref
                                                        .read(
                                                            taskRepositoryProvider)
                                                        .syncError ??
                                                    'Your tasks are up to date.');
                                              }
                                            }),
                                    icon: const Icon(Icons.sync_rounded,
                                        size: 20),
                                    label: const Text('Sync now'))),
                          ])),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed: busy ? null : _import,
                          icon:
                              const Icon(Icons.file_upload_outlined, size: 20),
                          label: const Text('Import local tasks')),
                      const SizedBox(height: 12),
                      if (ref.read(taskRepositoryProvider).syncError != null)
                        MessageBanner(
                            ref.read(taskRepositoryProvider).syncError!,
                            isError: true),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Connection details'),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SelectableText(
                                    ref.read(apiClientProvider).baseUrl)),
                          ]),
                      const SizedBox(height: 20),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(() =>
                                  ref.read(authProvider.notifier).signOut()),
                          child: Text('Sign out',
                              style: TextStyle(color: colors.error))),
                    ] else ...[
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(22)),
                              child: Icon(
                                  _recover
                                      ? Icons.lock_reset_rounded
                                      : Icons.waving_hand_outlined,
                                  color: colors.primary,
                                  size: 28))),
                      const SizedBox(height: 24),
                      Text(
                          _recover
                              ? 'Let’s get you back in.'
                              : _register
                                  ? 'A space for your plans.'
                                  : 'Welcome back.',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 10),
                      Text(
                          _recover
                              ? 'Request a recovery email, then use the code to set a new password.'
                              : 'Sign in to back up your tasks and get a larger voice allowance.',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 28),
                      Form(
                          key: _form,
                          child: AutofillGroup(
                              child: Column(children: [
                            TextFormField(
                                key: const ValueKey('account-email'),
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(
                                        Icons.alternate_email_rounded,
                                        size: 20)),
                                validator: (value) =>
                                    value == null || !value.contains('@')
                                        ? 'Enter your email'
                                        : null),
                            const SizedBox(height: 16),
                            if (_recover) ...[
                              TextFormField(
                                  controller: _code,
                                  decoration: const InputDecoration(
                                      labelText: 'Recovery code',
                                      helperText:
                                          'Leave empty to request an email.')),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                                key: const ValueKey('account-password'),
                                controller: _password,
                                obscureText: !_showPassword,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: [
                                  _register || _recover
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password
                                ],
                                decoration: InputDecoration(
                                    labelText:
                                        _recover ? 'New password' : 'Password',
                                    helperText: _register || _recover
                                        ? 'At least 12 characters'
                                        : null,
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20),
                                    suffixIcon: IconButton(
                                        tooltip: _showPassword
                                            ? 'Hide password'
                                            : 'Show password',
                                        onPressed: () => setState(() =>
                                            _showPassword = !_showPassword),
                                        icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20))),
                                validator: (value) =>
                                    _recover && _code.text.trim().isEmpty
                                        ? null
                                        : value == null || value.length < 12
                                            ? 'Use at least 12 characters'
                                            : null),
                            const SizedBox(height: 24),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                    onPressed: busy ? null : _submit,
                                    child: Text(_recover
                                        ? 'Continue recovery'
                                        : _register
                                            ? 'Create account'
                                            : 'Sign in'))),
                          ]))),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _register = !_register;
                                    _recover = false;
                                    _message = null;
                                  }),
                          child: Text(_register
                              ? 'Already have an account? Sign in'
                              : 'Create an account')),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _recover = !_recover;
                                    _message = null;
                                  }),
                          child: Text(_recover
                              ? 'Back to sign in'
                              : 'Forgot password?')),
                      const SizedBox(height: 16),
                      Text(
                          'You can also use TaskFlow without an account. Your local tasks stay on this phone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 20),
                      ExpansionTile(
                          title: const Text('Connection settings'),
                          tilePadding: EdgeInsets.zero,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: [
                            TextFormField(
                                controller: _server,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                    labelText: 'Backend address',
                                    helperText:
                                        'Emulator: http://10.0.2.2:8088\nPhone: your computer’s LAN IP on the same Wi-Fi.')),
                          ]),
                    ],
                    if (busy)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator())),
                    if (_message != null || auth.error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: MessageBanner(_message ?? auth.error!,
                              isError: auth.error != null || _failed)),
                  ]))),
    );
  }
}
