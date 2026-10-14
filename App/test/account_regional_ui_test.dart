import 'package:agenda/l10n/generated/app_localizations.dart';
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
      expect(api.requests.single.$2, {'email': 'recovery@example.invalid'});
      await reveal(find.text(
          'Si la cuenta existe, se ha enviado un correo de recuperación.'));
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
