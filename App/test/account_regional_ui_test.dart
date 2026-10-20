// P44 (UX-408), round 1 of 2026-10-13-app: Account in one line, sign-out
// asked first, connection details only in debug builds.
// P96 (UX-508), round 2: sign-out shows progress in its button.
import 'dart:async';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Spanish account recovery at 2x text, dark=$dark',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _RecoveryApi();
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _GuestAuth(api)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      addTearDown(container.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: const Locale('es'),
              theme: dark ? AppTheme.dark : AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const AccountScreen())));
      await tester.pumpAndSettle();

      Future<void> reveal(Finder target) async {
        final scroll = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(target, 180, scrollable: scroll);
        await tester.pumpAndSettle();
      }

      await reveal(find.text('¿Has olvidado tu contraseña?'));
      await tester.tap(find.text('¿Has olvidado tu contraseña?'));
      await tester.pumpAndSettle();
      final email = find.byKey(const ValueKey('account-email'));
      await reveal(email);
      await tester.enterText(email, 'recovery@example.invalid');
      await reveal(find.text('Enviar código'));
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      // Requesting a recovery email must not require a password or a code.
      expect(api.requests.single.$1, 'auth/password-reset/');
      expect(api.requests.single.$2,
          {'email': 'recovery@example.invalid', 'language': 'es'});
      await reveal(find.text('Si recovery@example.invalid tiene cuenta, te '
          'llegará un correo con un código. Escríbelo aquí.'));
      expect(tester.takeException(), isNull);

      final code = find.byKey(const ValueKey('account-recovery-code'));
      await reveal(code);
      await tester.enterText(code, '  Fixture:Case-Sensitive-Code  ');
      final password = find.byKey(const ValueKey('account-password'));
      await reveal(password);
      await tester.enterText(password, 'short');
      await reveal(find.text('Guardar contraseña nueva'));
      await tester.tap(find.text('Guardar contraseña nueva'));
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      await reveal(find.text('Usa al menos 12 caracteres'));
      expect(tester.takeException(), isNull);
      await reveal(password);
      await tester.enterText(password, 'Synthetic-only-password!');
      await reveal(find.text('Guardar contraseña nueva'));
      await tester.tap(find.text('Guardar contraseña nueva'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1, 'auth/password-reset/confirm/');
      expect(api.requests.last.$2, {
        'code': 'Fixture:Case-Sensitive-Code',
        'password': 'Synthetic-only-password!'
      });
      await reveal(find.text(
          'Contraseña actualizada. Inicia sesión con tu nueva contraseña.'));
      expect(tester.takeException(), isNull);
    });
  }

  // ---- P44 · UX-408: Account in one line, fewer buttons ----

  Future<(_SignOutAuth, _LocalItems)> openAccount(WidgetTester tester,
      {String language = 'es',
      int localItems = 0,
      String? syncError,
      bool debug = false,
      bool dark = false,
      double textScale = 1,
      DesignTaskNotifier Function()? tasks}) async {
    final api = OfflineApiClient();
    late _SignOutAuth auth;
    final repository = _LocalItems(localItems)..syncError = syncError;
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => auth = _SignOutAuth(api)),
      taskRepositoryProvider.overrideWithValue(repository),
      taskProvider.overrideWith((ref) => tasks?.call() ?? DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: Locale(language),
            theme: dark ? AppTheme.dark : AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: AccountScreen(debug: debug))));
    await tester.pumpAndSettle();
    container.read(authProvider);
    return (auth, repository);
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-408: Account says Guardado en tu cuenta with Sincronizar ahora, and no import row without local items ($language, 2x text at 320 dp)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l = lookupAppLocalizations(Locale(language));
      await openAccount(tester, language: language, textScale: 2);
      for (final text in [l.accountSaved, l.syncNow]) {
        await tester.scrollUntilVisible(find.text(text), 120,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.text(text));
        expect(rect.left, greaterThanOrEqualTo(0), reason: text);
        expect(rect.right, lessThanOrEqualTo(320.5), reason: text);
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      // The whole screen at once: no import row without local items.
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await openAccount(tester, language: language);
      expect(find.text(l.accountSaved), findsOneWidget);
      expect(find.text(l.signOut), findsOneWidget, reason: 'all built');
      expect(find.text(l.importLocalItems), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('UX-408: with local items, Importar tareas y notas locales shows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openAccount(tester, localItems: 3);
    expect(find.text(es.importLocalItems), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UX-408: a failed sync says so once, in place of the saved line',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const error = 'Saved on this phone. Cannot reach the server.';
    await openAccount(tester, syncError: error);
    final message = requestProblemText(es, error);
    expect(find.text(message), findsOneWidget);
    expect(find.text(es.accountSaved), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-408 (D13): outside debug builds there is no Detalles de conexión; a debug build keeps it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openAccount(tester);
    expect(find.text(es.signOut), findsOneWidget, reason: 'all built');
    expect(find.text(es.connectionDetails), findsNothing);
    await openAccount(tester, debug: true);
    expect(find.text(es.connectionDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-408: Cerrar sesión asks first, saying reminders stop; Cancelar keeps the account, Cerrar sesión in the question signs out',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (auth, _) = await openAccount(tester);
    Finder signOutButton() => find.widgetWithText(TextButton, es.signOut);
    await tester.tap(signOutButton());
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text(es.signOutQuestion)),
        findsOneWidget);
    await tester.tap(
        find.descendant(of: dialog, matching: find.text(es.cancel)));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(signOutButton());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.signOut)));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(tester.takeException(), isNull);
  });

  // ---- Round 2 · P96 · UX-508: sign-out shows progress in its button ----

  for (final dark in [false, true]) {
    testWidgets(
        'UX-508: while a confirmed sign-out waits on the server, a progress indicator sits inside Cerrar sesión; before confirming there is none (dark=$dark)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (auth, _) = await openAccount(tester, dark: dark);
      auth.hold = Completer<void>();
      Finder signOutButton() => find.ancestor(
          of: find.text(es.signOut), matching: find.byType(TextButton));
      Finder spinnerInButton() => find.descendant(
          of: signOutButton(), matching: find.byType(CircularProgressIndicator));
      expect(signOutButton(), findsOneWidget);
      expect(spinnerInButton(), findsNothing, reason: 'nothing at rest');
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(signOutButton());
      await tester.pumpAndSettle();
      // The question is open: still no indicator in the button.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
          find.descendant(
              of: find.ancestor(
                  of: find.text(es.signOut).first,
                  matching: find.byType(TextButton)),
              matching: find.byType(CircularProgressIndicator)),
          findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, es.signOut)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.signOuts, 1);
      expect(spinnerInButton(), findsOneWidget,
          reason: 'progress shows in the button');
      final colors = Theme.of(tester.element(signOutButton())).colorScheme;
      expect(
          tester
              .widget<CircularProgressIndicator>(spinnerInButton())
              .color,
          colors.error);
      expect(
          tester.widget<TextButton>(signOutButton()).onPressed, isNull,
          reason: 'it can’t be pressed twice');
      expect(tester.takeException(), isNull);

      auth.hold!.complete();
      await tester.pumpAndSettle();
      expect(spinnerInButton(), findsNothing);
    });
  }

  // ---- Round 1 · P100 · UX-513: in-button spinners say what is happening ----

  /// What TalkBack hears on [button]: its own label merged with its children.
  String spoken(WidgetTester tester, Finder button) =>
      tester.getSemantics(button).label;

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-513: while syncing, the spinner in Sincronizar ahora is labelled with what is happening ($language)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final l = lookupAppLocalizations(Locale(language));
      late _HeldTasks tasks;
      await openAccount(tester,
          language: language, tasks: () => tasks = _HeldTasks());
      final button = find.ancestor(
          of: find.text(l.syncNow), matching: find.byType(TextButton));
      expect(spoken(tester, button), isNot(contains(l.accountSyncing)),
          reason: 'nothing is announced at rest');

      tasks.hold = Completer<void>();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final spinner = find.descendant(
          of: button, matching: find.byType(CircularProgressIndicator));
      expect(spinner, findsOneWidget);
      expect(tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
          l.accountSyncing);
      expect(spoken(tester, button), contains(l.accountSyncing));
      expect(l.accountSyncing.trim(), isNotEmpty);
      expect(tester.takeException(), isNull);

      tasks.hold!.complete();
      await tester.pumpAndSettle();
      expect(spinner, findsNothing);
      semantics.dispose();
    });
  }

  testWidgets(
      'UX-513: while importing, the spinner in Importar tareas y notas locales is labelled Importando tareas y notas',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final (_, repository) = await openAccount(tester, localItems: 3);
    repository.hold = Completer<void>();
    final button = find.ancestor(
        of: find.text(es.importLocalItems),
        matching: find.byType(OutlinedButton));
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.importItems)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final spinner = find.descendant(
        of: button, matching: find.byType(CircularProgressIndicator));
    expect(spinner, findsOneWidget);
    expect(tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
        es.accountImporting);
    expect(spoken(tester, button), contains(es.accountImporting));
    expect(tester.takeException(), isNull);

    repository.hold!.complete();
    await tester.pumpAndSettle();
    expect(spinner, findsNothing);
    semantics.dispose();
  });

  testWidgets(
      'UX-513: while signing out, the spinner in Cerrar sesión is labelled Cerrando sesión',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final (auth, _) = await openAccount(tester);
    auth.hold = Completer<void>();
    final button = find.ancestor(
        of: find.text(es.signOut), matching: find.byType(TextButton));
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.signOut)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final spinner = find.descendant(
        of: button, matching: find.byType(CircularProgressIndicator));
    expect(spinner, findsOneWidget);
    expect(tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
        es.accountSigningOut);
    expect(spoken(tester, button), contains(es.accountSigningOut));
    expect(tester.takeException(), isNull);

    auth.hold!.complete();
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  test('UX-513: each in-button progress label is written in EN, ES and CA', () {
    for (final language in ['en', 'es', 'ca']) {
      final l = lookupAppLocalizations(Locale(language));
      final labels = [l.accountSyncing, l.accountImporting, l.accountSigningOut];
      for (final label in labels) {
        expect(label.trim(), isNotEmpty, reason: language);
      }
      expect(labels.toSet(), hasLength(3), reason: 'each names its action');
    }
  });

  test('UX-408: the sign-out question names the reminders in EN, ES and CA',
      () {
    for (final (language, word) in [
      ('en', 'Reminders'),
      ('es', 'recordatorios'),
      ('ca', 'recordatoris'),
    ]) {
      final l = lookupAppLocalizations(Locale(language));
      expect(l.signOutQuestion, contains(word));
    }
  });
}

final es = lookupAppLocalizations(const Locale('es'));

class _SignOutAuth extends SignedInFixtureAuth {
  _SignOutAuth(super.api);
  int signOuts = 0;

  /// When set, sign-out waits for it, as on a slow server.
  Completer<void>? hold;
  @override
  Future<void> signOut() async {
    signOuts++;
    await hold?.future;
  }
}

/// Tasks and notes kept on this phone before signing in.
class _LocalItems extends MemoryTasks {
  _LocalItems(this.count);
  final int count;

  /// When set, importing waits for it, as on a slow server.
  Completer<void>? hold;
  @override
  Future<int> localTaskCount() async => count;
  @override
  Future<int> importLocalTasks() async {
    await hold?.future;
    return count;
  }
}

/// Sync waits for [hold] once it is set, as on a slow server.
class _HeldTasks extends DesignTaskNotifier {
  Completer<void>? hold;
  @override
  Future<void> loadTasks() async {
    await hold?.future;
    await super.loadTasks();
  }
}

class _GuestAuth extends AuthNotifier {
  _GuestAuth(super.api);
  @override
  Future<void> restore() async {
    state = const AuthState();
  }
}

class _RecoveryApi extends OfflineApiClient {
  final requests = <(String, Map<String, dynamic>?)>[];
  @override
  Future<void> setServer(String value) async {
    baseUrl = value;
  }

  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (method != 'POST' ||
        authenticated ||
        !path.startsWith('auth/password-reset/')) {
      throw StateError('Unexpected fixture request');
    }
    requests.add((path, data));
    // Server response copy must not force the UI back into English.
    return {'detail': 'Server success in English'};
  }
}
