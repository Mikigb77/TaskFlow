import 'dart:async';
import 'dart:convert';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/development_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/design_fixtures.dart';

class _EmptyTasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async => state = const AsyncData([]);
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) respond, {
  String language = 'en',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(transport: MockClient(respond));
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => _EmptyTasks()),
      taskListsProvider.overrideWith((ref) async => []),
      pendingCapturesProvider.overrideWith((ref) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(RegionalPreferences(language: language)),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(api.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final button = find.byKey(const ValueKey('development-sign-in'));

  if (!DevelopmentLogin.enabled) {
    testWidgets('ordinary builds cannot offer the development shortcut', (
      tester,
    ) async {
      await _open(tester, (_) async => throw StateError('Must not log in'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(button, findsNothing);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
    });
    return;
  }

  for (final language in ['en', 'es', 'ca']) {
    testWidgets('one tap logs in normally with an empty account: $language', (
      tester,
    ) async {
      var calls = 0;
      final response = Completer<http.Response>();
      final container = await _open(tester, (request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/login/');
        expect(request.headers['Authorization'], isNull);
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], DevelopmentLogin.email);
        expect(body['password'], DevelopmentLogin.password);
        return response.future;
      }, language: language);
      final strings = await AppLocalizations.delegate.load(Locale(language));
      await tester.scrollUntilVisible(
        button,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(strings.useTestAccount), findsOneWidget);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(find.text(strings.enterEmail), findsNothing);
      expect(find.byType(CalendarScreen), findsNothing);
      response.complete(
        http.Response(
          jsonEncode({
            'access': 'fixture-access',
            'refresh': 'fixture-refresh',
            'user': {
              'id': 42,
              'email': DevelopmentLogin.email,
              'timezone': 'Europe/Madrid',
              'billing_id': 'fixture-billing-id',
            },
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        container.read(authProvider).account!.email,
        DevelopmentLogin.email,
      );
      expect(container.read(taskProvider).requireValue, isEmpty);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'taskflow.session'))!,
      );
      expect(saved['access'], 'fixture-access');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('server refusal keeps the login gate and displays the error', (
    tester,
  ) async {
    final container = await _open(
      tester,
      (_) async => http.Response('{"detail":"Invalid credentials"}', 401),
    );
    await tester.scrollUntilVisible(
      button,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).account, isNull);
    expect(container.read(authProvider).error, isA<ApiException>());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(
      await const FlutterSecureStorage().read(key: 'taskflow.session'),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
