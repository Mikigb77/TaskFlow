import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'support/design_fixtures.dart';

class FakeGoogleSignIn extends GoogleSignInService {
  int calls = 0;
  @override
  bool get supported => true;
  @override
  bool get configured => true;
  @override
  Future<String?> authenticate() async {
    calls++;
    return null;
  }
}

class GoogleGuestAuth extends AuthNotifier {
  GoogleGuestAuth(super.api);
  @override
  Future<void> restore() async {
    state = const AuthState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
      'Google cancellation needs no email or password and fits $language at 2x text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = ApiClient(url: 'http://10.0.2.2:8088');
        final google = FakeGoogleSignIn();
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            googleSignInServiceProvider.overrideWithValue(google),
            authProvider.overrideWith((ref) => GoogleGuestAuth(api)),
            taskRepositoryProvider.overrideWithValue(MemoryTasks()),
            taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(api.close);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(language),
              theme: AppTheme.dark,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const AccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = await AppLocalizations.delegate.load(Locale(language));
        final button = find.text(strings.continueWithGoogle);
        await tester.scrollUntilVisible(button, 120,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(google.calls, 1);
        expect(container.read(authProvider).account, isNull);
        expect(container.read(authProvider).error, isNull);
        expect(find.text(strings.enterEmail), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
