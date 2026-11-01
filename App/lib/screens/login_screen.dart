import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/verify_email_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/development_login.dart';
import 'package:agenda/services/pending_verification.dart';
import 'package:agenda/services/site_links.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:agenda/widgets/language_selector.dart';

/// The form field a server answer belongs on.
enum _Field { email, password }

/// A page that opens with no slide, as if the app had opened on it; closing
/// it plays the theme's usual Back transition.
class _ShownAtOnce<T> extends MaterialPageRoute<T> {
  _ShownAtOnce({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.signInAgain = false});

  /// Shown over the open screens after the server ended the session: says why,
  /// and keeps the account's email.
  final bool signInAgain;

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
  // Where recovery just sent its code: said above the code field.
  String? _sentTo;
  // The code typed had expired, so a new one was asked for: the line above
  // the code field says so.
  bool _codeRenewed = false;
  // The server said the code typed is wrong: said under the code field
  // until it changes.
  bool _codeWrong = false;
  bool _busy = false;
  bool _showPassword = false;
  // The email form shows, rather than only Google and «Continuar con mi
  // correo». Once open, it stays open until Back folds it.
  bool _emailOpen = false;
  // Reached sign-in from create's email-in-use answer, so this email has an
  // account: wrong credentials mean a forgotten password, not a new account.
  bool _accountExists = false;
  String? _message;
  // [_message] says the account must be created again, back from the
  // confirm screen: TalkBack reads it as it appears.
  bool _replaced = false;
  Object? _error;
  final _emailField = GlobalKey();
  final _emailFocus = FocusNode();
  final _passwordField = GlobalKey();
  final _outcome = GlobalKey();
  final _sent = GlobalKey();
  final _codeField = GlobalKey();
  final _codeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ref.read(apiClientProvider).baseUrl);
    if (widget.signInAgain) {
      _emailOpen = true;
      _email.text = ref.read(authProvider).account?.email ?? '';
    } else {
      unawaited(_resumeConfirming());
    }
  }

  /// Android closed the app while the person read the email: the address
  /// still waits for that code, so its screen opens again, asking for the
  /// password. Nothing is sent, so the code in the inbox still works, and
  /// «Reenviar código» waits only what is left of that code's minute.
  Future<void> _resumeConfirming() async {
    final pending = await ref.read(pendingVerificationProvider).resume();
    if (pending == null || !mounted || _busy) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _email.text = pending.email;
    await _confirmEmail(pending.email, resumedFrom: pending.sentAt);
  }

  @override
  void dispose() {
    for (final controller in [_email, _password, _code, _server]) {
      controller.dispose();
    }
    _emailFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _mode({
    bool register = false,
    bool recover = false,
    bool accountExists = false,
  }) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      // Sign-in and create share the typed password; recovery sets a new one.
      if (recover || _recover) _password.clear();
      _register = register;
      _recover = recover;
      _accountExists = accountExists;
      // Create and recovery come back to the open form.
      _emailOpen = true;
      _hasRecoveryCode = false;
      _sentTo = null;
      _codeRenewed = false;
      _codeWrong = false;
      _code.clear();
      _message = null;
      _replaced = false;
      _error = null;
      _form = GlobalKey<FormState>();
    });
  }

  /// Google can sign in here, so the email form can wait behind «Continuar
  /// con mi correo». Sign-in again keeps it open: it has the email filled.
  bool get _canFold {
    final google = ref.read(googleSignInServiceProvider);
    return !widget.signInAgain && google.supported && google.configured;
  }

  /// Only Google and «Continuar con mi correo» show: the first screen.
  bool get _folded => !_emailOpen && !_register && !_recover && _canFold;

  /// «Continuar con mi correo»: today's form in place, ready to type.
  void _openEmail() {
    setState(() => _emailOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  /// Back from the open form folds it again, as create and recovery go back
  /// to sign-in.
  void _fold() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _emailOpen = false;
      _accountExists = false;
      _message = null;
      _replaced = false;
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
      _replaced = false;
      _codeWrong = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _reveal();
  }

  // With a code but none asked for here («Ya tengo un código»), the email
  // shows too: the code is checked against its address.
  bool get _showsEmail => !_recover || !_hasRecoveryCode || _sentTo == null;
  bool get _showsPassword => !_recover || _hasRecoveryCode;

  /// The visible field a server answer is about, so it shows on that field.
  _Field? _fieldFor(Object? error) {
    if (error == null || error is GoogleSignInProblem || _folded) return null;
    return switch (requestProblem(error)) {
      'email' || 'emailUsed' when _showsEmail => _Field.email,
      'password' when _showsPassword => _Field.password,
      _ => null,
    };
  }

  void _clearProblem() {
    ref.read(authProvider.notifier).clearError();
    setState(() => _error = null);
  }

  /// Brings the answer into view: the field it concerns, or the banner and its
  /// action, which sit below the submit button and can be off-screen at large
  /// text.
  void _reveal() {
    final error = _error ?? ref.read(authProvider).error;
    if (error == null && _message == null && _sentTo == null && !_codeWrong) {
      return;
    }
    final key = _codeWrong
        ? _codeField
        : switch (_fieldFor(error)) {
            _Field.email => _emailField,
            _Field.password => _passwordField,
            null => error == null && _message == null ? _sent : _outcome,
          };
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

  /// Signs in, or creates the account, with the app's language for its
  /// emails. Returns the address that must be confirmed first, if any.
  Future<String?> _signIn(
    String email,
    String password, {
    bool register = false,
  }) async {
    final language = Localizations.localeOf(context).languageCode;
    await ref.read(regionalProvider.notifier).ready;
    final zone = await CaptureTimezone.resolve(ref.read(regionalProvider));
    if (!mounted) return null;
    try {
      await ref
          .read(authProvider.notifier)
          .signIn(
            email,
            password,
            register: register,
            timezone: zone.identifier,
            language: language,
          );
    } on EmailVerificationRequired catch (pending) {
      return pending.email;
    }
    return null;
  }

  /// The address waits for the code the server just emailed: ask for it,
  /// sending the [password] just typed along with it; without one, the
  /// screen asks for it. Coming back lands on creating the account, with the
  /// email kept. When it must be created again, the password is cleared and
  /// sign-up says why. Reopened after a restart, with [resumedFrom] the time
  /// its code went, the screen shows at once, with no slide in.
  Future<void> _confirmEmail(
    String email, {
    String? password,
    DateTime? resumedFrom,
  }) async {
    // Kept across a restart while its code works; never the password.
    if (password != null) {
      unawaited(ref.read(pendingVerificationProvider).remember(email));
    }
    Widget screen(BuildContext _) => VerifyEmailScreen(
      email: email,
      password: password,
      sentAt: resumedFrom,
    );
    final back = await Navigator.of(context).push<VerifyEmailReturn>(
      resumedFrom == null
          ? MaterialPageRoute(builder: screen)
          : _ShownAtOnce(builder: screen),
    );
    if (back == null || !mounted) return;
    _mode(register: true);
    if (back == VerifyEmailReturn.otherAddress) {
      // Ready to correct the address: the cursor at its end.
      _email.selection = TextSelection.collapsed(offset: _email.text.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFocus.requestFocus();
      });
    }
    if (back == VerifyEmailReturn.replaced) {
      _password.clear();
      setState(() {
        _message = context.l10n.verifyEmailReplaced;
        _replaced = true;
      });
      _reveal();
    }
  }

  /// How the server refused a recovery code: `code_expired` (unknown,
  /// expired, or tried too often) or `code_invalid` for a wrong one and any
  /// other answer about the code, as on the verify screen. Null for every
  /// other problem.
  static String? _codeRefusal(ApiException error) {
    if (error.status != 400) return null;
    return switch (error.body?['code']) {
      'code_expired' => 'code_expired',
      _ when error.body?.containsKey('code') == true => 'code_invalid',
      _ => null,
    };
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final password = _password.text;
    // Recovery's email in the app's language, as sign-in's.
    final language = Localizations.localeOf(context).languageCode;
    String? unconfirmed;
    var renewed = false;
    await _run(() async {
      final api = ref.read(apiClientProvider);
      await api.setServer(_server.text);
      if (_recover) {
        // The address the code went to, or the one typed with it.
        final email = _sentTo ?? _email.text.trim();
        Future<void> requestCode() => api.request(
          'POST',
          'auth/password-reset/',
          authenticated: false,
          data: {'email': email, 'language': language},
        );
        if (!_hasRecoveryCode) {
          await requestCode();
          if (!mounted) return;
          setState(() {
            _hasRecoveryCode = true;
            _sentTo = email;
          });
          return;
        }
        try {
          await api.request(
            'POST',
            'auth/password-reset/confirm/',
            authenticated: false,
            data: {
              'email': email,
              'code': _code.text,
              'password': _password.text,
            },
          );
        } on ApiException catch (error) {
          switch (_codeRefusal(error)) {
            case 'code_invalid':
              // The new password typed stays.
              if (mounted) setState(() => _codeWrong = true);
              return;
            case 'code_expired':
              // A new code at once, as sign-up does for a spent one; if
              // asking fails, its own answer shows instead.
              _code.clear();
              if (mounted) setState(() => _codeRenewed = false);
              await requestCode();
              if (!mounted) return;
              setState(() {
                _sentTo = email;
                _codeRenewed = true;
              });
              renewed = true;
              return;
          }
          rethrow;
        }
        if (!mounted) return;
        // Back to sign-in, ready to use the new password.
        final password = _password.text;
        _mode();
        _password.text = password;
        setState(() => _message = context.l10n.passwordResetComplete);
        return;
      }
      unconfirmed = await _signIn(_email.text, password, register: _register);
    });
    // Ready for the new code, once the field is enabled again.
    if (renewed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    }
    if (unconfirmed != null && mounted) {
      await _confirmEmail(unconfirmed!, password: password);
    }
  }

  Future<void> _testSignIn() async {
    if (!DevelopmentLogin.enabled) return;
    String? unconfirmed;
    await _run(() async {
      await ref.read(apiClientProvider).setServer(_server.text);
      unconfirmed = await _signIn(
        DevelopmentLogin.email,
        DevelopmentLogin.password,
      );
    });
    if (unconfirmed != null && mounted) {
      await _confirmEmail(unconfirmed!, password: DevelopmentLogin.password);
    }
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
    // An invitation link opened while signed out waits for its address.
    final invitation =
        !widget.signInAgain && ref.watch(invitationLinkProvider) != null;
    final colors = Theme.of(context).colorScheme;
    final busy = _busy || auth.loading;
    // Sign-in again already says why it appeared; the expiry's own error
    // would say it twice.
    final expiry =
        widget.signInAgain &&
        _error == null &&
        auth.error != null &&
        requestProblem(auth.error!) == 'session';
    final error = _error ?? (expiry ? null : auth.error);
    final field = _fieldFor(error);
    final problem = error == null
        ? null
        : requestProblemText(strings, error, onSignIn: true);
    final emailError = field == _Field.email ? problem : null;
    final passwordError = field == _Field.password ? problem : null;
    final unknownAccount =
        !_register &&
        !_recover &&
        error != null &&
        error is! GoogleSignInProblem &&
        requestProblem(error) == 'credentials';
    // The mirror of [unknownAccount]: the email has an account, so offer
    // sign-in with it kept.
    final emailUsed =
        _register &&
        field == _Field.email &&
        requestProblem(error!) == 'emailUsed';
    final submitLabel = _recover
        ? _hasRecoveryCode
              ? strings.saveNewPassword
              : strings.sendRecoveryCode
        : _register
        ? strings.createAccount
        : strings.signIn;
    final folded = _folded;
    // Create and recover behave like screens on top of sign-in: Back returns.
    // The open email form folds back behind «Continuar con mi correo».
    return PopScope(
      canPop: !_register && !_recover && (!_emailOpen || !_canFold),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy) return;
        if (_register || _recover) {
          _mode();
        } else if (_emailOpen && _canFold) {
          _fold();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Right after deleting the account; gone on the next try.
                    if (auth.deleted) ...[
                      MessageBanner(
                        strings.accountDeleted,
                        key: const ValueKey('account-deleted'),
                        liveRegion: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    DecoratedBox(
                      decoration: authCardDecoration(colors),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthHeading(
                              _recover
                                  ? strings.recoveryHeading
                                  : _register
                                  ? strings.registerHeading
                                  : folded
                                  // New and returning people alike start here.
                                  ? strings.signInOrUpHeading
                                  : strings.signInHeading,
                            ),
                            const SizedBox(height: 10),
                            // Its own node, read after the heading.
                            Semantics(
                              container: true,
                              child: Text(
                                _recover
                                    ? strings.recoveryHelp
                                    : widget.signInAgain
                                    ? strings.signInAgainReason
                                    : strings.authPitch,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (invitation && !_recover) ...[
                              MessageBanner(
                                strings.invitationWaitingSignIn,
                                key: const ValueKey('invitation-waiting'),
                                icon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!_recover && google.supported) ...[
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
                              if (folded) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  key: const ValueKey('continue-with-email'),
                                  onPressed: busy ? null : _openEmail,
                                  child: Text(
                                    strings.continueWithEmail,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 20),
                                // Seen, not read: «o» alone means nothing.
                                ExcludeSemantics(
                                  child: Row(
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
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],
                            if (!folded)
                              Form(
                                key: _form,
                                child: AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_showsEmail) ...[
                                        KeyedSubtree(
                                          key: _emailField,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              TextFormField(
                                                key: const ValueKey(
                                                  'account-email',
                                                ),
                                                controller: _email,
                                                focusNode: _emailFocus,
                                                enabled: !busy,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                autocorrect: false,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                ],
                                                textInputAction:
                                                    _recover &&
                                                        !_hasRecoveryCode
                                                    ? TextInputAction.done
                                                    : TextInputAction.next,
                                                onFieldSubmitted:
                                                    _recover &&
                                                        !_hasRecoveryCode
                                                    ? (_) => _submit()
                                                    : null,
                                                onChanged: (_) {
                                                  if (_accountExists) {
                                                    setState(
                                                      () => _accountExists =
                                                          false,
                                                    );
                                                  }
                                                  if (emailError != null) {
                                                    _clearProblem();
                                                  }
                                                },
                                                decoration: InputDecoration(
                                                  labelText: strings.email,
                                                  // Above the field, at its
                                                  // smaller size: whole at 2×.
                                                  floatingLabelBehavior:
                                                      FloatingLabelBehavior
                                                          .always,
                                                  errorText: emailError,
                                                  errorMaxLines: 4,
                                                ),
                                                validator: (value) =>
                                                    value == null ||
                                                        !value.contains('@')
                                                    ? strings.enterEmail
                                                    : null,
                                              ),
                                              if (emailUsed) ...[
                                                const SizedBox(height: 12),
                                                OutlinedButton(
                                                  key: const ValueKey(
                                                    'sign-in-with-email',
                                                  ),
                                                  onPressed: busy
                                                      ? null
                                                      : () => _mode(
                                                          accountExists: true,
                                                        ),
                                                  child: Text(
                                                    strings.signInWithEmail,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_recover && _hasRecoveryCode) ...[
                                        if (_sentTo case final sentTo?) ...[
                                          MessageBanner(
                                            _codeRenewed
                                                ? strings.recoveryCodeRenewed(
                                                    breakableAddress(sentTo),
                                                  )
                                                : strings
                                                      .recoveryEmailRequested(
                                                        breakableAddress(
                                                          sentTo,
                                                        ),
                                                      ),
                                            key: _sent,
                                            icon: Icons.mail_outline_rounded,
                                            // The answer to the code typed:
                                            // read out as it appears.
                                            liveRegion: _codeRenewed,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        KeyedSubtree(
                                          key: _codeField,
                                          child: TextFormField(
                                            key: const ValueKey(
                                              'account-recovery-code',
                                            ),
                                            controller: _code,
                                            focusNode: _codeFocus,
                                            enabled: !busy,
                                            // The verify screen's setup: the
                                            // number pad, the code autofilled.
                                            keyboardType: TextInputType.number,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode,
                                            ],
                                            autocorrect: false,
                                            enableSuggestions: false,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                VerifyEmailScreen.codeLength,
                                              ),
                                            ],
                                            onChanged: (_) {
                                              if (_codeWrong) {
                                                setState(
                                                  () => _codeWrong = false,
                                                );
                                              }
                                            },
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: InputDecoration(
                                              // On the border like the other
                                              // fields. At large text it is the
                                              // longest label: it shrinks to
                                              // stay whole rather than cut.
                                              label: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: AlignmentDirectional
                                                    .centerStart,
                                                child: Text(
                                                  strings.recoveryCode,
                                                ),
                                              ),
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              errorText: _codeWrong
                                                  ? strings
                                                        .verifyEmailCodeInvalid
                                                  : null,
                                              errorMaxLines: 4,
                                            ),
                                            validator: (value) =>
                                                value == null ||
                                                    value.length !=
                                                        VerifyEmailScreen
                                                            .codeLength
                                                ? strings.verifyEmailCodeLength
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_showsPassword)
                                        KeyedSubtree(
                                          key: _passwordField,
                                          child: TextFormField(
                                            key: const ValueKey(
                                              'account-password',
                                            ),
                                            controller: _password,
                                            enabled: !busy,
                                            obscureText: !_showPassword,
                                            enableSuggestions: false,
                                            autocorrect: false,
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) => _submit(),
                                            onChanged: (_) {
                                              if (passwordError != null) {
                                                _clearProblem();
                                              }
                                            },
                                            autofillHints: [
                                              _register || _recover
                                                  ? AutofillHints.newPassword
                                                  : AutofillHints.password,
                                            ],
                                            decoration: InputDecoration(
                                              labelText: _recover
                                                  ? strings.newPassword
                                                  : strings.password,
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              errorText: passwordError,
                                              errorMaxLines: 6,
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
                                                      ? Icons
                                                            .visibility_off_outlined
                                                      : Icons
                                                            .visibility_outlined,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            // Length rules are for new passwords;
                                            // signing in only needs one typed.
                                            validator: (value) =>
                                                !_register && !_recover
                                                ? value == null || value.isEmpty
                                                      ? strings.enterPassword
                                                      : null
                                                : value == null ||
                                                      value.length < 12
                                                ? strings.passwordTooShort
                                                : null,
                                          ),
                                        ),
                                      // Hidden while the banner offers the same
                                      // recovery as a button (UX-495).
                                      if (!_recover &&
                                          !_register &&
                                          !(unknownAccount && _accountExists))
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Align(
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
                                                  child:
                                                      CircularProgressIndicator(
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
                            if (_message != null ||
                                (error != null && field == null))
                              Padding(
                                key: _outcome,
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_replaced && error == null)
                                      MessageBanner(
                                        _message!,
                                        key: const ValueKey('signup-replaced'),
                                        liveRegion: true,
                                      )
                                    else
                                      MessageBanner(
                                        problem ?? _message!,
                                        isError: error != null,
                                      ),
                                    if (unknownAccount && _accountExists) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        key: const ValueKey(
                                          'recover-with-email',
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => _mode(recover: true),
                                        child: Text(
                                          strings.forgotPassword,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ] else if (unknownAccount) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        key: const ValueKey(
                                          'create-account-with-email',
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => _mode(register: true),
                                        child: Text(
                                          strings.createAccountWithEmail,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ],
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
                              // Apart, so a tap on one doesn't land on the
                              // other.
                              if (!_hasRecoveryCode) const SizedBox(height: 8),
                              TextButton(
                                onPressed: busy ? null : () => _mode(),
                                child: Text(strings.backToSignIn),
                              ),
                            ] else if (!folded &&
                                (!unknownAccount || _accountExists))
                              // Hidden while the banner offers the same
                              // create as a button.
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
                          ],
                        ),
                      ),
                    ),
                    // Before an account is created, Google's included: the
                    // terms must be available beforehand.
                    if (!_recover && !widget.signInAgain)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (page, label) in [
                              (SitePage.privacy, strings.privacyPolicy),
                              (SitePage.terms, strings.termsAndConditions),
                            ])
                              TextButton(
                                key: ValueKey('site-${page.path}'),
                                onPressed: () =>
                                    openSitePage(context, ref, page),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.onSurfaceVariant,
                                  // Narrow enough that both fit on one line
                                  // of a 360 dp phone, 8 dp apart.
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                                child: Text(label, textAlign: TextAlign.center),
                              ),
                          ],
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
                              icon: const Icon(
                                Icons.science_outlined,
                                size: 20,
                              ),
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
      ),
    );
  }
}

/// The card around sign-in's form, and the confirm screen's.
BoxDecoration authCardDecoration(ColorScheme colors) => BoxDecoration(
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
);

/// The heading of sign-in's card and the confirm screen's: it names the
/// screen, so TalkBack says it as the screen opens. It grows with the text
/// size up to 1.2×, so at 2× its longest words still fit on a 320 dp phone
/// and it stays larger than the text under it.
class AuthHeading extends StatelessWidget {
  const AuthHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    header: true,
    namesRoute: true,
    child: Text(
      text,
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 30),
    ),
  );
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
