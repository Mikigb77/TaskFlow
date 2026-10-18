import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/services/api_client.dart';

/// Why the confirm screen sends the person back to creating the account.
enum VerifyEmailReturn {
  /// «Usar otro correo»: the email is kept, to correct it.
  otherAddress,

  /// The address was registered again, with another password, before it was
  /// confirmed: the account must be created again.
  replaced,
}

/// Asks for the 6-digit code the server emailed to [email]: after creating
/// an account, or after signing in to one whose address isn't confirmed
/// yet. The right code signs in, so the app opens where any sign-in does.
/// Pops with a [VerifyEmailReturn] when it sends the person back to
/// creating the account.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.password});

  /// Where the code went, as the server wrote it.
  final String email;

  /// The password just typed to create the account, or to sign in to it,
  /// sent with the code. Only in memory: it goes when this screen closes.
  /// Without it, the screen asks for it.
  final String? password;

  /// Digits in a code.
  static const codeLength = 6;

  /// Seconds «Reenviar código» waits after each code is sent.
  static const resendWait = 60;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  final _field = FocusNode();
  // Typed here only when the screen opened without the password.
  final _password = TextEditingController();
  final _passwordField = FocusNode();
  bool _confirming = false;
  bool _resending = false;
  // Seconds until «Reenviar código» can be tapped. The server sent a code
  // just before this screen opened.
  int _wait = 0;
  Timer? _timer;
  // The last answer: from the server or the connection.
  Object? _error;
  // Confirmar with fewer than 6 digits.
  bool _short = false;
  // Confirmar with no password to send.
  bool _noPassword = false;
  // A new code went out, and nothing was confirmed or sent since.
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _countDown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _field.dispose();
    _password.dispose();
    _passwordField.dispose();
    super.dispose();
  }

  /// «Reenviar código» waits, counting down each second.
  void _countDown() {
    _timer?.cancel();
    _wait = VerifyEmailScreen.resendWait;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  /// How the server refused the code: `code_expired` (too old, or tried too
  /// often), `signup_replaced`, or `code_invalid` for a wrong one and any
  /// other answer about the code. Null for every other problem: no
  /// connection, too many requests…
  static String? _refusal(Object error) {
    if (error is! ApiException || error.status != 400) return null;
    return switch (error.body?['code']) {
      'code_expired' => 'code_expired',
      'signup_replaced' => 'signup_replaced',
      _ when error.body?.containsKey('code') == true => 'code_invalid',
      _ => null,
    };
  }

  /// What shows under the code field, if anything is wrong.
  String? _problem(AppLocalizations l) {
    final error = _error;
    if (_short) return l.verifyEmailCodeLength;
    if (error == null) return null;
    return switch (_refusal(error)) {
      'code_expired' => l.verifyEmailCodeExpired,
      'code_invalid' => l.verifyEmailCodeInvalid,
      _ => requestProblemText(l, error, onSignIn: true),
    };
  }

  /// The answer under a field is read out as it appears. On Android it is a
  /// live region (the field makes its errors one), so only where the
  /// platform prefers announcements (iOS) is it said here.
  void _announce(String message) {
    if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  void _changed(String code) {
    if (_error != null || _short) {
      setState(() {
        _error = null;
        _short = false;
      });
    }
    // Six digits, typed or pasted, confirm by themselves.
    if (code.length == VerifyEmailScreen.codeLength) unawaited(_confirm());
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    final l = context.l10n;
    final code = _code.text;
    final password = widget.password ?? _password.text;
    if (code.length != VerifyEmailScreen.codeLength) {
      setState(() {
        _short = true;
        _error = null;
        _resent = false;
      });
      _announce(l.verifyEmailCodeLength);
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _noPassword = true;
        _short = false;
        _error = null;
        _resent = false;
      });
      _announce(l.enterPassword);
      _passwordField.requestFocus();
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
      _short = false;
      _resent = false;
    });
    try {
      // Signed in: the app opens where any sign-in does, and this screen
      // goes with the sign-in screens.
      await ref
          .read(authProvider.notifier)
          .verifyEmail(widget.email, code, password);
    } catch (error) {
      if (!mounted) return;
      if (_refusal(error) == 'signup_replaced') {
        // Sign-up says why, with the email kept.
        Navigator.pop(context, VerifyEmailReturn.replaced);
        return;
      }
      setState(() {
        _confirming = false;
        _error = error;
        // Only a new code can be confirmed now: offered at once.
        if (_refusal(error) == 'code_expired') {
          _timer?.cancel();
          _wait = 0;
        }
      });
      _announce(_problem(l)!);
    }
  }

  Future<void> _resend() async {
    if (_resending || _confirming || _wait > 0) return;
    final l = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _resending = true;
      _error = null;
      _short = false;
      _resent = false;
    });
    try {
      await ref
          .read(apiClientProvider)
          .resendVerificationCode(widget.email, language: language);
      if (!mounted) return;
      // The code that was typed no longer works.
      _code.clear();
      setState(() {
        _resending = false;
        _resent = true;
        _countDown();
      });
      _announce(l.verifyEmailResent);
      _field.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = error;
        // Too many requests: the next one waits too.
        if (error is ApiException && error.status == 429) _countDown();
      });
      _announce(_problem(l)!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final waiting = _wait > 0;
    return PopScope(
      canPop: !_confirming,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.appBarTheme.systemOverlayStyle!,
        child: Scaffold(
          key: const ValueKey('verify-email-screen'),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 488),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Where sign-in shows it, beside its language button.
                    const SizedBox(
                      height: 48,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AuthBrand(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    DecoratedBox(
                      decoration: authCardDecoration(colors),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Each its own node for TalkBack: otherwise the
                            // field takes the heading and the help as its name.
                            Semantics(
                              container: true,
                              header: true,
                              child: Text(
                                l.verifyEmailHeading,
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontSize: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Semantics(
                              container: true,
                              child: Text(
                                l.verifyEmailHelp(widget.email),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Semantics(
                              container: true,
                              child: TextField(
                                key: const ValueKey('verify-email-code'),
                                controller: _code,
                                focusNode: _field,
                                autofocus: true,
                                // Read-only, not disabled, while it
                                // confirms: the keyboard stays up to fix
                                // a wrong digit.
                                readOnly: _confirming,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    VerifyEmailScreen.codeLength,
                                  ),
                                ],
                                onChanged: _changed,
                                onSubmitted: (_) => unawaited(_confirm()),
                                decoration: InputDecoration(
                                  labelText: l.verifyEmailCode,
                                  errorText: _problem(l),
                                  errorMaxLines: 8,
                                  // Read out as it appears, as errors are.
                                  helper: _resent
                                      ? Semantics(
                                          liveRegion:
                                              !MediaQuery.supportsAnnounceOf(
                                                context,
                                              ),
                                          child: Text(
                                            l.verifyEmailResent,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            // Never needed after sign-up or sign-in, which
                            // pass the password they were given.
                            if (widget.password == null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                container: true,
                                child: TextField(
                                  key: const ValueKey('verify-email-password'),
                                  controller: _password,
                                  focusNode: _passwordField,
                                  readOnly: _confirming,
                                  obscureText: true,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) {
                                    if (_noPassword) {
                                      setState(() => _noPassword = false);
                                    }
                                  },
                                  onSubmitted: (_) => unawaited(_confirm()),
                                  decoration: InputDecoration(
                                    labelText: l.password,
                                    errorText: _noPassword
                                        ? l.enterPassword
                                        : null,
                                    errorMaxLines: 4,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              key: const ValueKey('verify-email-confirm'),
                              onPressed: _confirming
                                  ? null
                                  : () => unawaited(_confirm()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_confirming) ...[
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
                                        l.verifyEmailConfirm,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              key: const ValueKey('verify-email-resend'),
                              onPressed: _confirming || _resending || waiting
                                  ? null
                                  : () => unawaited(_resend()),
                              child: Text(
                                waiting
                                    ? l.verifyEmailResendIn(_wait)
                                    : l.verifyEmailResend,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('verify-email-other-address'),
                              onPressed: _confirming
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      VerifyEmailReturn.otherAddress,
                                    ),
                              child: Text(
                                l.verifyEmailOtherAddress,
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
          ),
        ),
      ),
    );
  }
}
