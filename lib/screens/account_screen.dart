import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';

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
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
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
      String zone = 'Europe/Madrid';
      try {
        zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {/* Editable in voice form. */}
      await ref.read(authProvider.notifier).signIn(_email.text, _password.text,
          register: _register, timezone: zone);
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
    ref.watch(taskProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (auth.account != null) ...[
          const Icon(Icons.account_circle, size: 64),
          const SizedBox(height: 16),
          Text(auth.account!.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          const Text(
              'Your tasks are saved on this phone and backed up to your account when connected. Attachments stay on the device where you added them.'),
          const SizedBox(height: 16),
          Text('Server: ${ref.read(apiClientProvider).baseUrl}'),
          if (ref.read(taskRepositoryProvider).syncError != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(ref.read(taskRepositoryProvider).syncError!,
                    style: const TextStyle(color: Colors.amber))),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                        await ref.read(taskProvider.notifier).loadTasks();
                        if (mounted) {
                          setState(() => _message =
                              ref.read(taskRepositoryProvider).syncError ??
                                  'Your tasks are up to date.');
                        }
                      }),
              icon: const Icon(Icons.sync),
              label: const Text('Sync now')),
          OutlinedButton.icon(
              onPressed: busy ? null : _import,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import local tasks')),
          TextButton(
              onPressed: busy
                  ? null
                  : () => _run(() => ref.read(authProvider.notifier).signOut()),
              child: const Text('Sign out')),
        ] else ...[
          Text(
              _recover
                  ? 'Recover your account'
                  : (_register ? 'Create your account' : 'Welcome back'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
              'Sign in for task backup and voice creation. You can also keep using local tasks without an account.'),
          const SizedBox(height: 20),
          Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                    key: const ValueKey('account-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter your email'
                        : null),
                const SizedBox(height: 16),
                if (_recover)
                  TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                          labelText: 'Recovery code',
                          helperText:
                              'Leave empty to request an email. Paste the code to reset.')),
                TextFormField(
                    key: const ValueKey('account-password'),
                    controller: _password,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: [
                      _register || _recover
                          ? AutofillHints.newPassword
                          : AutofillHints.password
                    ],
                    decoration: InputDecoration(
                        labelText: _recover ? 'New password' : 'Password',
                        helperText: 'At least 12 characters'),
                    validator: (value) => _recover && _code.text.trim().isEmpty
                        ? null
                        : (value == null || value.length < 12
                            ? 'Use at least 12 characters'
                            : null)),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(_recover
                        ? 'Continue recovery'
                        : (_register ? 'Create account' : 'Sign in'))),
              ])),
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
              child: Text(_recover ? 'Back to sign in' : 'Forgot password?')),
          ExpansionTile(title: const Text('Connection settings'), children: [
            TextFormField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Backend address',
                    helperText:
                        'Emulator: http://10.0.2.2:8088\nPhone: use your computer’s LAN IP on the same Wi-Fi.')),
          ]),
        ],
        if (busy)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
        if (_message != null || auth.error != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message ?? auth.error!,
                  style: const TextStyle(color: Colors.amber))),
      ]),
    );
  }
}
