import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {} // The test controls when restoration finishes.
  void finish({bool signedIn = false}) {
    state = AuthState(
      account: signedIn
          ? Account.fromJson({
              'id': 1,
              'email': 'fixture@example.invalid',
              'timezone': 'Europe/Madrid',
            })
          : null,
    );
  }

  @override
  Future<void> signOut() async => finish();
}

class _Google extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
}

Future<(ProviderContainer, _Auth)> _open(
  WidgetTester tester, {
  ThemeMode theme = ThemeMode.light,
  Key? previewKey,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = OfflineApiClient();
  final auth = _Auth(api);
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => auth),
      googleSignInServiceProvider.overrideWithValue(_Google()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      pendingCapturesProvider.overrideWith((ref) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore(theme.name)),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(api.close);
  await container.read(themeModeProvider.notifier).ready;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: previewKey, child: const MyApp()),
    ),
  );
  await tester.pump();
  return (container, auth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('restoration exposes neither login nor tasks until it finishes', (
    tester,
  ) async {
    final (_, auth) = await _open(tester);
    expect(find.byType(SessionLoadingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
    auth.finish();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('signed-out named routes cannot open protected screens', (
    tester,
  ) async {
    final (_, auth) = await _open(tester);
    auth.finish();
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in [
      '/calendar',
      '/createTask',
      '/taskDetails',
      '/voiceTask',
      '/settings',
      '/subscription',
    ]) {
      navigator.pushNamed(route, arguments: 1);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget, reason: route);
      expect(find.byType(MainShell), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'a restored account opens Calendar; logout clears protected back history',
    (tester) async {
      final (_, auth) = await _open(tester);
      auth.finish(signedIn: true);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      final previous = tester.state<NavigatorState>(find.byType(Navigator));
      previous.pushNamed('/createTask');
      await tester.pumpAndSettle();
      expect(previous.canPop(), isTrue);
      await auth.signOut();
      await tester.pumpAndSettle();
      final current = tester.state<NavigatorState>(find.byType(Navigator));
      expect(current, isNot(same(previous)));
      expect(current.canPop(), isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell, skipOffstage: false), findsNothing);
      auth.finish(signedIn: true);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'login has Google below email and supports appearance controls: $theme',
      (tester) async {
        final preview = GlobalKey();
        final (_, auth) = await _open(
          tester,
          theme: theme,
          previewKey: preview,
        );
        auth.finish();
        await tester.pumpAndSettle();
        final submit = find.byKey(const ValueKey('account-submit'));
        final google = find.byKey(const ValueKey('google-sign-in'));
        expect(
          tester.getTopLeft(google).dy,
          greaterThan(tester.getBottomLeft(submit).dy),
        );
        expect(google.hitTestable(), findsOneWidget);
        expect(find.byTooltip('Language'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('WRITE_AUTH_PREVIEWS')) {
          final boundary =
              preview.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = File('artifacts/auth/login-${theme.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byKey(const ValueKey('account-email')),
          'preserved@example.invalid',
        );
        await tester.ensureVisible(find.text('Create an account'));
        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();
        expect(find.text('preserved@example.invalid'), findsOneWidget);
        expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
