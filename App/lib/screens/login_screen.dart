import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/development_login.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:agenda/widgets/language_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  var _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late final TextEditingController _server;
  bool _register = false;
  bool _recover = false;
  bool _hasRecoveryCode = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  Object? _error;

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

  void _mode({bool register = false, bool recover = false}) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _register = register;
      _recover = recover;
      _hasRecoveryCode = false;
      _password.clear();
      _code.clear();
      _message = null;
      _error = null;
      _form = GlobalKey<FormState>();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
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
        final confirming = _hasRecoveryCode;
        await api.request(
          'POST',
          confirming ? 'auth/password-reset/confirm/' : 'auth/password-reset/',
          authenticated: false,
          data: confirming
              ? {'code': _code.text.trim(), 'password': _password.text}
              : {'email': _email.text.trim()},
        );
        if (mounted) {
          setState(() {
            _hasRecoveryCode = true;
            _message = confirming
                ? context.l10n.passwordResetComplete
                : context.l10n.recoveryEmailRequested;
          });
        }
        return;
      }
      await ref.read(regionalProvider.notifier).ready;
      final zone = await CaptureTimezone.resolve(ref.read(regionalProvider));
      if (!mounted) return;
      await ref
          .read(authProvider.notifier)
          .signIn(
            _email.text,
            _password.text,
            register: _register,
            timezone: zone.identifier,
          );
    });
  }

  Future<void> _testSignIn() async {
    if (!DevelopmentLogin.enabled) return;
    await _run(() async {
      await ref.read(apiClientProvider).setServer(_server.text);
      await ref.read(regionalProvider.notifier).ready;
      final zone = await CaptureTimezone.resolve(ref.read(regionalProvider));
      if (!mounted) return;
      await ref
          .read(authProvider.notifier)
          .signIn(
            DevelopmentLogin.email,
            DevelopmentLogin.password,
            timezone: zone.identifier,
          );
    });
  }

  Future<void> _googleSignIn() => _run(() async {
    await ref.read(apiClientProvider).setServer(_server.text);
    final token = await ref.read(googleSignInServiceProvider).authenticate();
    if (token == null || !mounted) return;
    await ref.read(regionalProvider.notifier).ready;
    final zone = await CaptureTimezone.resolve(ref.read(regionalProvider));
    if (!mounted) return;
    await ref
        .read(authProvider.notifier)
        .signInWithGoogle(token, timezone: zone.identifier);
  });

  Future<void> _connectionSettings() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(context.l10n.connectionSettings),
      content: TextField(
        controller: _server,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: context.l10n.backendAddress,
          helperText: context.l10n.backendAddressHelp,
          helperMaxLines: 8,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final auth = ref.watch(authProvider);
    final google = ref.watch(googleSignInServiceProvider);
    final colors = Theme.of(context).colorScheme;
    final busy = _busy || auth.loading;
    final error = _error ?? auth.error;
    final submitLabel = _recover
        ? strings.continueRecovery
        : _register
        ? strings.createAccount
        : strings.signIn;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
        key: const ValueKey('login-screen'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 488),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Row(
                    children: [
                      const Expanded(child: AuthBrand()),
                      IconButton(
                        tooltip: strings.language,
                        onPressed: () => showLanguageSelector(context),
                        icon: const Icon(Icons.translate_rounded, size: 21),
                      ),
                      const ThemeToggle(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: .025),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _recover
                                ? strings.recoveryHeading
                                : _register
                                ? strings.registerHeading
                                : strings.authWelcome,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge?.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _recover
                                ? strings.recoveryHelp
                                : _register
                                ? strings.authRegisterHelp
                                : strings.accountSignInHelp,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Form(
                            key: _form,
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!_recover || !_hasRecoveryCode) ...[
                                    TextFormField(
                                      key: const ValueKey('account-email'),
                                      controller: _email,
                                      enabled: !busy,
                                      keyboardType: TextInputType.emailAddress,
                                      autocorrect: false,
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      textInputAction: _recover
                                          ? TextInputAction.done
                                          : TextInputAction.next,
                                      onFieldSubmitted: _recover
                                          ? (_) => _submit()
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: strings.email,
                                        errorMaxLines: 3,
                                      ),
                                      validator: (value) =>
                                          value == null || !value.contains('@')
                                          ? strings.enterEmail
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_recover && _hasRecoveryCode) ...[
                                    TextFormField(
                                      key: const ValueKey(
                                        'account-recovery-code',
                                      ),
                                      controller: _code,
                                      enabled: !busy,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: strings.recoveryCode,
                                        errorMaxLines: 3,
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? strings.authEnterRecoveryCode
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (!_recover || _hasRecoveryCode)
                                    TextFormField(
                                      key: const ValueKey('account-password'),
                                      controller: _password,
                                      enabled: !busy,
                                      obscureText: !_showPassword,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      autofillHints: [
                                        _register || _recover
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: _recover
                                            ? strings.newPassword
                                            : strings.password,
                                        errorMaxLines: 3,
                                        helperMaxLines: 3,
                                        helperText: _register || _recover
                                            ? strings.passwordHelp
                                            : null,
                                        suffixIcon: IconButton(
                                          tooltip: _showPassword
                                              ? strings.hidePassword
                                              : strings.showPassword,
                                          onPressed: busy
                                              ? null
                                              : () => setState(
                                                  () => _showPassword =
                                                      !_showPassword,
                                                ),
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.length < 12
                                          ? strings.passwordTooShort
                                          : null,
                                    ),
                                  if (!_recover && !_register)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => _mode(recover: true),
                                        child: Text(
                                          strings.forgotPassword,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 20),
                                  FilledButton(
                                    key: const ValueKey('account-submit'),
                                    onPressed: busy ? null : _submit,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (busy) ...[
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
                                              submitLabel,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_message != null || error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: MessageBanner(
                                  _message ??
                                      requestProblemText(strings, error!),
                                  isError: error != null,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (_recover) ...[
                            if (!_hasRecoveryCode)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => _hasRecoveryCode = true,
                                      ),
                                child: Text(
                                  strings.authHaveRecoveryCode,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            TextButton(
                              onPressed: busy ? null : () => _mode(),
                              child: Text(strings.backToSignIn),
                            ),
                          ] else ...[
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _mode(register: !_register),
                              child: Text(
                                _register
                                    ? strings.alreadyHaveAccount
                                    : strings.createAnAccount,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (google.supported) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      strings.authOr,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 24),
                              GoogleLoginButton(
                                key: const ValueKey('google-sign-in'),
                                label: strings.continueWithGoogle,
                                onPressed: busy || !google.configured
                                    ? null
                                    : _googleSignIn,
                              ),
                              if (!google.configured)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    strings.googleSignInSetupPending,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (DevelopmentLogin.enabled && !_register && !_recover)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('development-sign-in'),
                            onPressed: busy ? null : _testSignIn,
                            icon: const Icon(Icons.science_outlined, size: 20),
                            label: Text(
                              strings.useTestAccount,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.developmentOnly,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: busy ? null : _connectionSettings,
                        child: Text(
                          strings.connectionSettings,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.done_all_rounded,
            color: colors.onPrimary,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'taskflow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 21),
          ),
        ),
      ],
    );
  }
}

class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: Theme.of(context).appBarTheme.systemOverlayStyle!,
    child: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrand(),
            const SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: context.l10n.authRestoring,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
