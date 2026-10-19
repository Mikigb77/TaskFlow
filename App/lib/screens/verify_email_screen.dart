import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/pending_verification.dart';

/// Why the confirm screen sends the person back to creating the account.
enum VerifyEmailReturn {
  /// «Usar otro correo»: the email is kept, to correct it.
  otherAddress,

  /// The address was registered again, with another password, before it was
  /// confirmed: the account must be created again.
  replaced,
}

/// A code the server no longer takes, too old or tried too often, once
/// signing in has shown that the address still waits for one.
enum _Spent {
  /// A minute or more after the last code: that sign-in emailed a new one.
  sentNew,

  /// Within the minute: no new code could go yet.
  wait,
}

/// Asks for the 6-digit code the server emailed to [email]: after creating
/// an account, or after signing in to one whose address isn't confirmed
/// yet. The right code signs in, so the app opens where any sign-in does.
/// Pops with a [VerifyEmailReturn] when it sends the person back to
/// creating the account.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.password,
    this.sentAt,
  });

  /// Where the code went, as the server wrote it.
  final String email;

  /// The password just typed to create the account, or to sign in to it,
  /// sent with the code. Only in memory: it goes when this screen closes.
  /// Without it, as when the app reopens on this screen after Android closed
  /// it, the screen asks for it.
  final String? password;

  /// When the code went, if before this screen opened, as when the app
  /// reopens on it: «Reenviar código» waits only what is left of its minute.
  final DateTime? sentAt;

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
  // What [_reveal] brings into view: each field with the line under it.
  final _codeBox = GlobalKey();
  final _passwordBox = GlobalKey();
  bool _confirming = false;
  bool _resending = false;
  // When this screen's last code was sent: just before it opened, or at
  // [VerifyEmailScreen.sentAt], then at each new one.
  late DateTime _sentAt;
  // When «Reenviar código» can be tapped again, by the clock.
  late DateTime _readyAt;
  // Seconds until then, as shown.
  int _wait = 0;
  Timer? _timer;
  // The last answer: from the server or the connection.
  Object? _error;
  // The last code was spent, as signing in confirmed.
  _Spent? _spent;
  // The last digits refused, and what was said: sent again, they would only
  // use up a try.
  ({String code, Object? error, _Spent? spent})? _refused;
  // Confirmar with fewer than 6 digits.
  bool _short = false;
  // Confirmar with no password to send.
  bool _noPassword = false;
  // The password typed here isn't the account's.
  bool _wrongPassword = false;
  // A new code went out, and nothing was confirmed or sent since.
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    // The server sent a code just before this screen opened, or at [sentAt].
    _sentAt = widget.sentAt ?? _now();
    _countDown(
      math.max(
        0,
        VerifyEmailScreen.resendWait - _now().difference(_sentAt).inSeconds,
      ),
    );
  }

  DateTime _now() => ref.read(calendarClockProvider)();

  /// While it confirms, what is typed is ignored. Neither field turns
  /// read-only: that would close Android's keyboard, which on an answer
  /// would come back over it.
  late final _steady = TextInputFormatter.withFunction(
    (old, typed) => _confirming ? old : typed,
  );

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _field.dispose();
    _password.dispose();
    _passwordField.dispose();
    super.dispose();
  }

  /// «Reenviar código» waits [seconds], counting down each second. What is
  /// left is read from the clock, not counted: Android freezes the app while
  /// the person reads the email, and the timer then fires once on return.
  /// Never longer than the seconds the timer saw pass, should the phone's
  /// clock be set back.
  void _countDown([int seconds = VerifyEmailScreen.resendWait]) {
    _timer?.cancel();
    _readyAt = _now().add(Duration(seconds: seconds));
    _wait = math.max(0, seconds);
    if (_wait == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (_readyAt.difference(_now()).inMilliseconds / 1000).ceil();
      setState(() => _wait = math.max(0, math.min(left, seconds - timer.tick)));
      if (_wait == 0) timer.cancel();
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
    switch (_spent) {
      case _Spent.sentNew:
        return l.verifyEmailCodeSpentNew;
      case _Spent.wait:
        return l.verifyEmailCodeSpentWait;
      case null:
        break;
    }
    if (error == null) return null;
    return switch (_refusal(error)) {
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

  /// Brings the field and the line under it into view, above the keyboard,
  /// as sign-in does with its answers.
  void _reveal([GlobalKey? box]) {
    final key = box ?? _codeBox;
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

  /// Shows [message] under its field: read out, and in view.
  void _show(String message, [GlobalKey? box]) {
    _announce(message);
    _reveal(box);
  }

  void _changed(String code) {
    if (_error != null || _short || _spent != null) {
      setState(() {
        _error = null;
        _short = false;
        _spent = null;
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
        _spent = null;
        _resent = false;
      });
      _show(l.verifyEmailCodeLength);
      return;
    }
    // Refused already: said again, and nothing is sent.
    final refused = _refused;
    if (refused != null && refused.code == code) {
      setState(() {
        _short = false;
        _error = refused.error;
        _spent = refused.spent;
        _resent = false;
      });
      _show(_problem(l)!);
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _noPassword = true;
        _short = false;
        _error = null;
        _spent = null;
        _resent = false;
      });
      _show(l.enterPassword, _passwordBox);
      _passwordField.requestFocus();
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
      _short = false;
      _spent = null;
      _resent = false;
      _wrongPassword = false;
    });
    try {
      // Signed in: the app opens where any sign-in does, and this screen
      // goes with the sign-in screens.
      await ref
          .read(authProvider.notifier)
          .verifyEmail(widget.email, code, password);
    } catch (error) {
      if (!mounted) return;
      switch (_refusal(error)) {
        case 'signup_replaced':
          // The password is checked before the code: typed here, it is most
          // likely mistyped.
          if (widget.password == null) {
            _showWrongPassword(l);
            return;
          }
          // Sign-up says why, with the email kept.
          unawaited(ref.read(pendingVerificationProvider).forget());
          Navigator.pop(context, VerifyEmailReturn.replaced);
          return;
        case 'code_expired':
          await _signInInstead(l, code, password);
          return;
        case 'code_invalid':
          _refused = (code: code, error: error, spent: null);
      }
      setState(() {
        _confirming = false;
        _error = error;
      });
      _show(_problem(l)!);
    }
  }

  /// The server says `code_expired` for a spent code, and also for an
  /// address already confirmed: by this very code, if its answer was lost,
  /// or by Google. Signing in tells them apart; for a spent code it emails a
  /// new one, at most one a minute. The screen stays confirming meanwhile.
  Future<void> _signInInstead(
    AppLocalizations l,
    String code,
    String password,
  ) async {
    final auth = ref.read(authProvider.notifier);
    try {
      // Signed in: the app opens, as after the right code.
      await auth.signIn(widget.email, password);
    } on EmailVerificationRequired {
      if (mounted) _codeSpent(l, code);
      return;
    }
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error == null) return;
    // This screen's answer, not one for sign-in behind it.
    auth.clearError();
    if (widget.password == null && requestProblem(error) == 'credentials') {
      _showWrongPassword(l);
      return;
    }
    setState(() {
      _confirming = false;
      _error = error;
    });
    _show(_problem(l)!);
  }

  /// The password typed here isn't the account's: said under it, which takes
  /// the keyboard to correct it.
  void _showWrongPassword(AppLocalizations l) {
    setState(() {
      _confirming = false;
      _error = null;
      _wrongPassword = true;
    });
    _show(l.verifyEmailWrongPassword, _passwordBox);
    _passwordField.requestFocus();
  }

  /// The code really is spent. A minute or more after the last code, the
  /// sign-in that checked it emailed a new one: the field is emptied for it
  /// and the countdown starts again. Within the minute, it keeps running.
  void _codeSpent(AppLocalizations l, String code) {
    final now = _now();
    final elapsed = now.difference(_sentAt).inSeconds;
    final sentNew = elapsed >= VerifyEmailScreen.resendWait;
    if (sentNew) {
      _sentAt = now;
      _code.clear();
      unawaited(ref.read(pendingVerificationProvider).remember(widget.email));
    }
    setState(() {
      _confirming = false;
      _error = null;
      _spent = sentNew ? _Spent.sentNew : _Spent.wait;
      _refused = sentNew ? null : (code: code, error: null, spent: _spent);
      // A new code waits a minute again; otherwise the wait goes on, never
      // longer than the clock says.
      _countDown(
        sentNew
            ? VerifyEmailScreen.resendWait
            : math.min(_wait, VerifyEmailScreen.resendWait - elapsed),
      );
    });
    if (sentNew) _field.requestFocus();
    _show(_problem(l)!);
  }

  Future<void> _resend() async {
    if (_resending || _confirming || _wait > 0) return;
    final l = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _resending = true;
      _error = null;
      _short = false;
      _spent = null;
      _resent = false;
    });
    try {
      await ref
          .read(apiClientProvider)
          .resendVerificationCode(widget.email, language: language);
      if (!mounted) return;
      // The code that was typed no longer works.
      _code.clear();
      _sentAt = _now();
      unawaited(ref.read(pendingVerificationProvider).remember(widget.email));
      setState(() {
        _resending = false;
        _resent = true;
        _refused = null;
        _countDown();
      });
      _show(l.verifyEmailResent);
      _field.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = error;
        // Too many requests: the next one waits too.
        if (error is ApiException && error.status == 429) _countDown();
      });
      _show(_problem(l)!);
    }
  }

  /// [VerifyEmailScreen.email] stands out in its sentence: a mistyped
  /// address is the usual reason the email never comes.
  TextSpan _help(AppLocalizations l, ColorScheme colors) {
    final email = widget.email;
    final help = l.verifyEmailHelp(email);
    final at = help.indexOf(email);
    if (email.isEmpty || at < 0) return TextSpan(text: help);
    return TextSpan(
      children: [
        TextSpan(text: help.substring(0, at)),
        TextSpan(
          text: email,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: help.substring(at + email.length)),
      ],
    );
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
                            AuthHeading(l.verifyEmailHeading),
                            const SizedBox(height: 10),
                            Semantics(
                              container: true,
                              child: Text.rich(
                                _help(l, colors),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Semantics(
                              key: _codeBox,
                              container: true,
                              child: TextField(
                                key: const ValueKey('verify-email-code'),
                                controller: _code,
                                focusNode: _field,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                inputFormatters: [
                                  _steady,
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
                                key: _passwordBox,
                                container: true,
                                child: TextField(
                                  key: const ValueKey('verify-email-password'),
                                  controller: _password,
                                  focusNode: _passwordField,
                                  inputFormatters: [_steady],
                                  obscureText: true,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) {
                                    if (_noPassword || _wrongPassword) {
                                      setState(() {
                                        _noPassword = false;
                                        _wrongPassword = false;
                                      });
                                    }
                                  },
                                  onSubmitted: (_) => unawaited(_confirm()),
                                  decoration: InputDecoration(
                                    labelText: l.password,
                                    errorText: _noPassword
                                        ? l.enterPassword
                                        : _wrongPassword
                                        ? l.verifyEmailWrongPassword
                                        : null,
                                    // The wrong-password line names the way
                                    // out: over 8 lines in English and
                                    // Catalan at 2× on 320 dp.
                                    errorMaxLines: 12,
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
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          semanticsLabel:
                                              l.verifyEmailConfirming,
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
                              // The countdown is the screen's only "when":
                              // read as easily as the help above.
                              style: waiting
                                  ? TextButton.styleFrom(
                                      disabledForegroundColor:
                                          colors.onSurfaceVariant,
                                    )
                                  : null,
                              child: Text(
                                waiting
                                    ? l.verifyEmailResendIn(_wait)
                                    : l.verifyEmailResend,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Apart, so a tap on the countdown doesn't leave.
                            const SizedBox(height: 8),
                            TextButton(
                              key: const ValueKey('verify-email-other-address'),
                              onPressed: _confirming
                                  ? null
                                  : () {
                                      unawaited(
                                        ref
                                            .read(pendingVerificationProvider)
                                            .forget(),
                                      );
                                      Navigator.pop(
                                        context,
                                        VerifyEmailReturn.otherAddress,
                                      );
                                    },
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
