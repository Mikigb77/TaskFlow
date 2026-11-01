// Sign-in and accounts: sign in, create an account, recover the password,
// their errors, the session ending, the first loading screen, and confirming
// the email with its code.
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/verify_email_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const login = Screen(
  'auth',
  'sign-in',
  'Sign-in, signed out: sign in, create an account or recover the password',
  sources: [
    'lib/screens/login_screen.dart',
    'lib/widgets/google_login_button.dart',
    'lib/widgets/language_selector.dart',
    'lib/l10n/request_locale.dart',
  ],
);

const loading = Screen(
  'auth',
  'opening',
  'Opening the app while the saved session is read',
  sources: ['lib/screens/login_screen.dart', 'lib/main.dart'],
);

const verify = Screen(
  'auth',
  'verify-email',
  'Confirm the email with its 6-digit code, after creating an account',
  sources: ['lib/screens/verify_email_screen.dart', 'lib/l10n/request_locale.dart'],
);

const _email = 'maria.lopez@example.com';
const _password = 'una frase larga y segura';

Future<PreviewApp> _signedOut(Preview p) => PreviewApp.open(p, signedIn: false);

/// Signed out, after «Continuar con mi correo»: the email form, which a
/// fresh sign-in folds behind Google.
Future<PreviewApp> _emailForm(Preview p) async {
  final app = await _signedOut(p);
  final open = find.byKey(const ValueKey('continue-with-email'));
  await p.tester.ensureVisible(open);
  await p.tester.pumpAndSettle();
  await p.tester.tap(open);
  await p.tester.pumpAndSettle();
  return app;
}

Future<void> _tapText(Preview p, String text) async {
  final finder = find.text(text);
  await p.tester.ensureVisible(finder.first);
  await p.tester.pumpAndSettle();
  await p.tester.tap(finder.first);
  await p.tester.pumpAndSettle();
}

Future<void> _fill(Preview p, {String email = _email, String? password = _password}) async {
  await p.tester.enterText(find.byKey(const ValueKey('account-email')), email);
  if (password != null) {
    await p.tester.enterText(find.byKey(const ValueKey('account-password')), password);
  }
  await p.tester.pumpAndSettle();
}

Future<void> _submit(Preview p) async {
  final submit = find.byKey(const ValueKey('account-submit'));
  FocusManager.instance.primaryFocus?.unfocus();
  await p.tester.pumpAndSettle();
  await p.tester.ensureVisible(submit);
  await p.tester.pumpAndSettle();
  await p.tester.tap(submit);
  await p.tester.pumpAndSettle();
}

Future<PreviewApp> _verify(Preview p) async {
  final app = await _signedOut(p);
  await app.pushPage(const VerifyEmailScreen(email: _email, password: _password));
  return app;
}

Future<void> _code(Preview p, String code) async {
  await p.tester.enterText(find.byKey(const ValueKey('verify-email-code')), code);
  await p.tester.pumpAndSettle();
}

void authPreviews() {
  previewArea('auth', 'Sign-in and accounts', () {
    preview(
      login,
      'sign-in',
      'The first screen signed out, headed Entra o crea tu cuenta: Continuar con Google, and under it Continuar con mi correo, with the email form folded; the Privacy Policy and Terms links under the card.',
      [...mainScreen, ...longText],
      (p) async {
        await _signedOut(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'email-open',
      'After Continuar con mi correo: the email and password form in place under Google and «o», the focus in Correo.',
      [es1, es2, esDark, ca2],
      (p) async {
        await _emailForm(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'sign-up',
      'Crear una cuenta: the same card for a new account, with the password rule; the Privacy Policy and Terms links under the card.',
      [es1, ca2],
      (p) async {
        await _emailForm(p);
        await _tapText(p, p.l.createAnAccount);
        await p.shoot();
      },
    );

    preview(
      login,
      'recovery',
      '¿Has olvidado tu contraseña?: the email to send a recovery code to; under Enviar código, Ya tengo un código and Volver a iniciar sesión, 8 dp apart.',
      everywhere,
      (p) async {
        await _emailForm(p);
        await _tapText(p, p.l.forgotPassword);
        await p.shoot();
      },
    );

    preview(
      login,
      'recovery-sent',
      'Recovery code sent: where it went, above the code and a new password.',
      [es1, es2, ca2],
      (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/password-reset/'] = (_) => <String, dynamic>{};
        await _tapText(p, p.l.forgotPassword);
        await _fill(p, password: null);
        await _submit(p);
        await p.shoot();
      },
    );

    // The recovery code refused: wrong (said under the code, the new password
    // kept) or expired (a new one asked for at once, the line above says so).
    for (final (name, refusal, note) in [
      (
        'recovery-code-wrong',
        'code_invalid',
        'Recovery code refused as wrong: said under the code, the new password kept.',
      ),
      (
        'recovery-code-renewed',
        'code_expired',
        'Recovery code expired: a new one asked for, the line above the emptied code says so.',
      ),
    ]) {
      preview(login, name, note, [es2, ca2], (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/password-reset/'] = (_) => <String, dynamic>{};
        app.api.handlers['POST auth/password-reset/confirm/'] =
            (_) => throw ApiException(400, 'Refused.', {'code': refusal});
        await _tapText(p, p.l.forgotPassword);
        await _fill(p, password: null);
        await _submit(p);
        await p.tester.enterText(find.byKey(const ValueKey('account-recovery-code')), '123456');
        await p.tester.enterText(find.byKey(const ValueKey('account-password')), _password);
        await _submit(p);
        await p.shoot();
      });
    }

    preview(
      login,
      'invitation',
      'An invitation link opened while signed out: which address to sign in with, above Google.',
      [es1, ca2, en2],
      (p) async {
        final app = await _signedOut(p);
        app.container.read(invitationLinkProvider.notifier).receive(
              Uri.parse(
                'taskflow://invite?kind=list'
                '&id=6f1c2a4e-8b3d-4c5e-9f7a-1b2c3d4e5f60'
                '&code=preview-invitation-code',
              ),
            );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      login,
      'wrong-password',
      'An email and password that don\'t match an account.',
      [es1, ca2],
      (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/login/'] = (_) => throw ApiException(
          401,
          'Email or password is incorrect.',
          {'detail': 'Email or password is incorrect.'},
        );
        await _fill(p);
        await _submit(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'offline',
      'Signing in with no connection.',
      [es1],
      (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/login/'] =
            (_) => throw ApiException(0, ApiClient.offlineMessage);
        await _fill(p);
        await _submit(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'too-many',
      'Too many attempts: wait 15 minutes.',
      [es1],
      (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/login/'] = (_) => throw ApiException(
          429,
          'Request was throttled.',
          {'detail': 'Request was throttled.'},
          const Duration(seconds: 900),
        );
        await _fill(p);
        await _submit(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'email-in-use',
      'Creating an account with an email that already has one: sign in or recover instead.',
      [es2],
      (p) async {
        final app = await _emailForm(p);
        app.api.handlers['POST auth/register/'] = (_) => throw ApiException(
          400,
          'email: An account with this email already exists.',
          {
            'email': ['An account with this email already exists.'],
          },
        );
        await _tapText(p, p.l.createAnAccount);
        await _fill(p);
        await _submit(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'empty',
      'Iniciar sesión tapped with nothing typed: what each field needs.',
      [es2],
      (p) async {
        await _emailForm(p);
        await _submit(p);
        await p.shoot();
      },
    );

    preview(
      login,
      'sign-in-again',
      'The session ended while the app was open: sign-in over the open screens, the email kept.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        (app.container.read(authProvider.notifier) as PreviewAuth).expire();
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      loading,
      'restoring',
      'Opening: the saved session is still being read.',
      everywhere,
      (p) async {
        await PreviewApp.open(p, restoring: true, settle: false);
        await p.shoot();
      },
    );

    // ------------------------------------------------------- verify email
    preview(
      verify,
      'code-entry',
      'Just created: the code to type, sent to the address shown; Reenviar código waits 55 s.',
      [es1, es2, ca2],
      (p) async {
        await _verify(p);
        await p.tester.pump(const Duration(seconds: 5));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      verify,
      'wrong-code',
      'A code that isn\'t right.',
      [es2],
      (p) async {
        final app = await _verify(p);
        app.api.handlers['POST auth/verify-email/'] = (_) =>
            throw ApiException(400, 'Invalid code.', {'code': 'code_invalid'});
        await _code(p, '482915');
        await p.shoot();
      },
    );

    preview(
      verify,
      'expired',
      'A code that has expired: ask for a new one, at once.',
      everywhere,
      (p) async {
        final app = await _verify(p);
        app.api.handlers['POST auth/verify-email/'] = (_) =>
            throw ApiException(400, 'Code expired.', {'code': 'code_expired'});
        await _code(p, '482915');
        await p.shoot();
      },
    );

    preview(
      verify,
      'resend-ready',
      'A minute later: Reenviar código is on.',
      [es1],
      (p) async {
        await _verify(p);
        await p.tester.pump(const Duration(seconds: 61));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      verify,
      'resent',
      'Reenviar código tapped: a new code is on its way, and the wait starts again.',
      [es2],
      (p) async {
        final app = await _verify(p);
        app.api.handlers['POST auth/verify-email/resend/'] = (_) => null;
        await p.tester.pump(const Duration(seconds: 61));
        await p.tester.pumpAndSettle();
        final resend = find.byKey(const ValueKey('verify-email-resend'));
        await p.tester.ensureVisible(resend);
        await p.tester.pumpAndSettle();
        await p.tester.tap(resend);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      verify,
      'resend-limited',
      'Reenviar código refused for 30 minutes, too many codes asked for: the wait is said, nothing was sent, the digits typed stay.',
      [es2, ca2],
      (p) async {
        final app = await _verify(p);
        app.api.handlers['POST auth/verify-email/resend/'] = (_) => throw ApiException(
          429,
          'Too many codes requested. Try again later.',
          {'code': 'resend_limited', 'retry_after': 1800},
          const Duration(seconds: 1800),
        );
        await p.tester.pump(const Duration(seconds: 61));
        await p.tester.pumpAndSettle();
        await _code(p, '4829');
        final resend = find.byKey(const ValueKey('verify-email-resend'));
        await p.tester.ensureVisible(resend);
        await p.tester.pumpAndSettle();
        await p.tester.tap(resend);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      verify,
      'offline',
      'Confirming the code with no connection.',
      [es1],
      (p) async {
        final app = await _verify(p);
        app.api.handlers['POST auth/verify-email/'] =
            (_) => throw ApiException(0, ApiClient.offlineMessage);
        await _code(p, '482915');
        await p.shoot();
      },
    );
  });
}
