// Delete my account (`/deleteAccount`): what goes and what stays with
// others, the confirm step, deleting, its errors, and the end.
import 'dart:async';

import 'package:agenda/screens/delete_account_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const deleteAccount = Screen(
  'delete',
  'delete-account',
  'Delete my account (`/deleteAccount`), from Cuenta',
  sources: [
    'lib/screens/delete_account_screen.dart',
    'lib/services/account_deletion.dart',
    'lib/l10n/request_locale.dart',
    'lib/screens/groups_screen.dart',
  ],
);

const signedOut = Screen(
  'delete',
  'after-deletion',
  'Sign-in right after the account was deleted',
  sources: ['lib/screens/login_screen.dart', 'lib/screens/delete_account_screen.dart'],
);

/// What deleting would do: the account's own things go; what it added to
/// shared projects stays, and what it owns that others use passes to them.
Map<String, dynamic> _plan({
  bool pro = false,
  String reauth = 'password',
  bool handovers = true,
}) => {
  'personal': {
    'tasks': 24,
    'notes': 4,
    'files': 3,
    'projects': 2,
    'groups': 1,
  },
  'kept_in_shared': 6,
  'kept_files_in_shared': 2,
  'handovers': [
    if (handovers) ...[
      {'kind': 'project', 'name': 'Excursión de fin de curso', 'to': 'Ana'},
      {'kind': 'group', 'name': 'Familia López', 'to': 'Paul'},
    ],
  ],
  'pro': pro,
  'reauth': reauth,
  'plan': 'plan-1',
};

/// Google sign-in that confirms as the account's Google account.
class _ConfirmingGoogle extends PreviewGoogle {
  @override
  Future<String?> authenticate() async => 'google-id-token';
}

Future<PreviewApp> _open(
  Preview p, {
  Map<String, dynamic>? plan,
  bool load = true,
  bool googleLinked = false,
}) async {
  final app = await PreviewApp.open(
    p,
    user: googleLinked ? account(google: true) : null,
    tasks: [...normalDay(), ...sharedProjectTasks()],
    projects: allProjects,
    overrides: [
      if (googleLinked)
        googleSignInServiceProvider.overrideWithValue(_ConfirmingGoogle()),
    ],
  );
  if (load) {
    app.api.handlers['GET auth/delete-account/'] = (_) => plan ?? _plan();
  }
  return app;
}

/// Scrolls the page until [target] shows.
Future<void> _scrollTo(Preview p, Finder target) => p.tester.scrollUntilVisible(
  target,
  200,
  scrollable: find
      .descendant(
        of: find.byType(DeleteAccountScreen),
        matching: find.byType(Scrollable),
      )
      .first,
);

/// Types the password at the end of the page.
Future<void> _password(Preview p) async {
  final field = find.byKey(const ValueKey('delete-account-password'));
  await _scrollTo(p, field);
  await p.tester.enterText(field, 'contraseña de María');
  await p.tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await p.tester.pumpAndSettle();
}

Future<void> _confirm(Preview p, {bool settle = true}) async {
  final confirm = find.byKey(const ValueKey('delete-account-confirm'));
  await p.tester.ensureVisible(confirm);
  await p.tester.pumpAndSettle();
  await p.tester.tap(confirm);
  if (settle) {
    await p.tester.pumpAndSettle();
  } else {
    await p.frames();
  }
}

void deletePreviews() {
  previewArea('delete', 'Delete account', () {
    preview(
      deleteAccount,
      'loading',
      'Opened: working out what deleting would do.',
      [es1],
      (p) async {
        final app = await _open(p, load: false);
        app.api.handlers['GET auth/delete-account/'] =
            (_) => Completer<dynamic>().future;
        app.navigator.pushNamed('/deleteAccount');
        await p.frames(10);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'preview',
      'What goes, and what stays for others: tasks kept in shared projects, a project and a group handed to Ana and Paul.',
      [es1, es2, ca2],
      (p) async {
        final app = await _open(p);
        await app.push('/deleteAccount');
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'confirm',
      'The password typed at the end of the page: Eliminar mi cuenta is on.',
      [es2],
      (p) async {
        final app = await _open(p);
        await app.push('/deleteAccount');
        await _password(p);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'deleting',
      'Eliminar mi cuenta tapped: deleting, with Back held.',
      [es1],
      (p) async {
        final app = await _open(p);
        app.api.handlers['POST auth/delete-account/'] =
            (_) => Completer<dynamic>().future;
        await app.push('/deleteAccount');
        await _password(p);
        await _confirm(p, settle: false);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'error-offline',
      'No connection when confirming: nothing was deleted.',
      everywhere,
      (p) async {
        final app = await _open(p);
        app.api.handlers['POST auth/delete-account/'] =
            (_) => throw ApiException(0, ApiClient.offlineMessage);
        await app.push('/deleteAccount');
        await _password(p);
        await _confirm(p);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'error-too-many',
      'Too many attempts: wait 15 minutes.',
      [es1],
      (p) async {
        final app = await _open(p);
        app.api.handlers['POST auth/delete-account/'] = (_) => throw ApiException(
          429,
          'Request was throttled.',
          null,
          const Duration(seconds: 900),
        );
        await app.push('/deleteAccount');
        await _password(p);
        await _confirm(p);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'wrong-password',
      'A wrong password: the error under the field.',
      [es1],
      (p) async {
        final app = await _open(p);
        app.api.handlers['POST auth/delete-account/'] = (_) => throw ApiException(
          400,
          'Wrong password.',
          {'code': 'wrong_password'},
        );
        await app.push('/deleteAccount');
        await _password(p);
        await _confirm(p);
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'load-failed',
      'Opened with no connection: the page can\'t say what deleting would do.',
      [es1],
      (p) async {
        final app = await _open(p, load: false);
        await app.push('/deleteAccount');
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'google',
      'An account that signs in with Google: it confirms with Google, not a password.',
      [es1],
      (p) async {
        final app = await _open(p, plan: _plan(reauth: 'google'));
        await app.push('/deleteAccount');
        final google = find.byKey(const ValueKey('delete-account-google'));
        await p.tester.ensureVisible(google);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'password-or-google',
      'An account with a password and Google linked: the password, or Confirmar con Google instead.',
      [es2, ca2],
      (p) async {
        final app = await _open(p, googleLinked: true);
        await app.push('/deleteAccount');
        final google = find.byKey(const ValueKey('delete-account-google'));
        await _scrollTo(p, google);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'google-instead-confirmed',
      'That account confirmed with Google: the password field and the Or-confirm-with-Google line are gone, and Eliminar mi cuenta is on.',
      [es2],
      (p) async {
        final app = await _open(p, googleLinked: true);
        await app.push('/deleteAccount');
        final google = find.byKey(const ValueKey('delete-account-google'));
        await _scrollTo(p, google);
        await p.tester.pumpAndSettle();
        await p.tester.tap(google);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      deleteAccount,
      'pro',
      'An account paying for Pro: deleting doesn\'t cancel the subscription, with the way to manage it.',
      [es1],
      (p) async {
        final app = await _open(p, plan: _plan(pro: true, handovers: false));
        await app.push('/deleteAccount');
        await p.shoot();
      },
    );

    preview(
      signedOut,
      'deleted',
      'Deleted: back on sign-in, which says the account is gone.',
      [es1],
      (p) async {
        FlutterSecureStorage.setMockInitialValues({});
        final app = await _open(p);
        app.api.handlers['POST auth/delete-account/'] = (_) => null;
        await app.push('/deleteAccount');
        await _password(p);
        await _confirm(p);
        await p.shoot();
      },
    );
  });
}
