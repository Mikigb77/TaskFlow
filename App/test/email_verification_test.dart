// 2026-10-18 (DECISIONS.md): a password sign-up confirms its email address
// with a 6-digit code before the first sign-in. The real ApiClient talks to
// a stand-in server; the screens are the app's own.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:ui' show Tristate;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/verify_email_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/design_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));
final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
AppLocalizations strings(String language) =>
    lookupAppLocalizations(Locale(language));

/// What the person types as their password, everywhere here.
const typedPassword = 'una-clave-larga-2026';

http.Response _json(int status, [Object? body]) => http.Response.bytes(
  body == null ? const [] : utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _session(String email) => {
  'access': 'fixture-access',
  'refresh': 'fixture-refresh',
  'user': {'id': 7, 'email': email, 'timezone': 'Europe/Madrid'},
};

/// The server, as the contract describes it: a new account waits for its
/// code, and so does a sign-in to it. Each answer can be changed, and
/// every request is kept.
class _Server {
  final requests = <({String path, Map<String, dynamic> body})>[];
  http.Response Function(Map<String, dynamic> body) register = (body) => _json(
    201,
    {'verification_required': true, 'email': '${body['email']}'.toLowerCase()},
  );
  http.Response Function(Map<String, dynamic> body) login = (body) =>
      _json(403, {
        'code': 'email_unverified',
        'detail': 'Confirm your email address first.',
        'email': '${body['email']}'.toLowerCase(),
      });
  http.Response Function(Map<String, dynamic> body) verify = (body) =>
      _json(200, _session('${body['email']}'));
  http.Response Function(Map<String, dynamic> body) resend = (_) => _json(204);

  /// Google sign-in; this server has none unless a test gives it one.
  http.Response Function(Map<String, dynamic> body) google = (_) =>
      _json(404, {'detail': 'Not found.'});

  /// Holds the code's answer back until completed.
  Completer<void>? holdVerify;

  /// Holds the sign-in's answer back until completed.
  Completer<void>? holdLogin;

  /// No connection at all.
  bool offline = false;

  late final transport = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/', '');
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    requests.add((path: path, body: body));
    if (offline) throw http.ClientException('Network is unreachable');
    switch (path) {
      case 'auth/register/':
        return register(body);
      case 'auth/login/':
        final gate = holdLogin;
        if (gate != null) await gate.future;
        return login(body);
      case 'auth/verify-email/':
        final gate = holdVerify;
        if (gate != null) await gate.future;
        return verify(body);
      case 'auth/verify-email/resend/':
        return resend(body);
      case 'auth/google/':
        return google(body);
    }
    return _json(404, {'detail': 'Not found.'});
  });

  List<String> get paths => [for (final request in requests) request.path];
  List<Map<String, dynamic>> bodies(String path) => [
    for (final request in requests)
      if (request.path == path) request.body,
  ];
}

/// A clock the test moves by hand, read through calendarClockProvider.
class _Clock {
  DateTime now = DateTime(2026, 10, 18, 10);
  DateTime call() => now;
}

class _Google extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
}

/// Google, where the person picks their account and Google answers a token.
class _GoogleAccount extends _Google {
  @override
  Future<String?> authenticate() async => 'fixture-google-token';
  @override
  Future<void> signOut() async {}
}

/// The app signed out, in Spanish (or [language]), against its own
/// stand-in server. The phone is Android's: TalkBack takes no announcements
/// ([announces] is iOS), so what appears is read out through live regions.
class _App {
  _App(this.container, this.api, this.server);
  final ProviderContainer container;
  final ApiClient api;
  final _Server server;

  static Future<_App> open(
    WidgetTester tester, {
    String language = 'es',
    Size size = const Size(390, 844),
    bool announces = false,
    Map<String, String> storage = const {},
    DateTime Function()? clock,
    GoogleSignInService? google,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(supportsAnnounce: announces);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    FlutterSecureStorage.setMockInitialValues(Map.of(storage));
    final server = _Server();
    final api = ApiClient(
      transport: server.transport,
      url: 'http://verify.test',
    );
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(
          (ref) => AuthNotifier(api, activateReminders: (_) async {}),
        ),
        googleSignInServiceProvider.overrideWithValue(google ?? _Google()),
        billingConfigurationProvider.overrideWithValue(
          const BillingConfiguration(apiKey: '', supported: false),
        ),
        hasProProvider.overrideWithValue(false),
        billingLoadingProvider.overrideWithValue(false),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(RegionalPreferences(language: language)),
        ),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith((ref) async => []),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        if (clock != null) calendarClockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    // The test steps through the first frames itself.
    if (!settle) return _App(container, api, server);
    // Nothing is saved yet: the (mocked) secure storage says so.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    // Under «Confirma tu correo» when an address still waits for its code.
    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
    return _App(container, api, server);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app's own fonts, so text wraps as it does on the phone.
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  // What is said to the screen reader as an announcement.
  final announcements = <String>[];
  setUp(() {
    announcements.clear();
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
    platform.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          announcements.add('${(message['data'] as Map)['message']}');
        }
        return null;
      },
    );
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timezone, null);
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  final email = find.byKey(const ValueKey('account-email'));
  final password = find.byKey(const ValueKey('account-password'));
  final submit = find.byKey(const ValueKey('account-submit'));
  final code = find.byKey(const ValueKey('verify-email-code'));
  final askedPassword = find.byKey(const ValueKey('verify-email-password'));
  final confirm = find.byKey(const ValueKey('verify-email-confirm'));
  final resend = find.byKey(const ValueKey('verify-email-resend'));
  final otherAddress = find.byKey(const ValueKey('verify-email-other-address'));
  Finder screen() => find.byType(VerifyEmailScreen);

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Crear una cuenta, with [address] and [typedPassword].
  Future<void> createAccount(
    WidgetTester tester,
    AppLocalizations l, {
    String address = 'Ana@Example.invalid',
  }) async {
    await tapVisible(tester, find.text(l.createAnAccount));
    expect(find.text(l.registerHeading), findsOneWidget);
    await tester.enterText(email, address);
    await tester.enterText(password, typedPassword);
    await tapVisible(tester, submit);
  }

  /// Iniciar sesión, with [address] and [typedPassword].
  Future<void> signIn(
    WidgetTester tester, {
    String address = 'ana@example.invalid',
  }) async {
    await tester.enterText(email, address);
    await tester.enterText(password, typedPassword);
    await tapVisible(tester, submit);
  }

  String typed(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;
  String formText(WidgetTester tester, Finder field) =>
      tester.widget<TextFormField>(field).controller!.text;
  String? errorUnder(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).decoration!.errorText;
  bool focused(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).focusNode!.hasFocus;
  String resendLabel(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: resend, matching: find.byType(Text)))
      .data!;
  bool resendEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(resend).onPressed != null;

  /// The countdown's seconds, as the button says them; null once it can be
  /// tapped.
  int? waitLeft(WidgetTester tester, AppLocalizations l) {
    final label = resendLabel(tester);
    for (var seconds = 1; seconds <= 60; seconds++) {
      if (label == l.verifyEmailResendIn(seconds)) return seconds;
    }
    expect(label, l.verifyEmailResend);
    return null;
  }

  test('the confirm screen’s copy in Spanish, English and Catalan', () {
    expect(es.verifyEmailHeading, 'Confirma tu correo');
    expect(
      es.verifyEmailHelp('ana@example.invalid'),
      'Te hemos enviado un código de 6 cifras a ana@example.invalid. Escríbelo aquí.',
    );
    expect(es.verifyEmailCode, 'Código');
    expect(es.verifyEmailConfirm, 'Confirmar');
    expect(es.verifyEmailResend, 'Reenviar código');
    expect(es.verifyEmailResendIn(42), 'Reenviar código en 42 segundos');
    expect(es.verifyEmailResendIn(1), 'Reenviar código en 1 segundo');
    expect(es.verifyEmailResent, 'Te hemos enviado un código nuevo');
    expect(
      es.verifyEmailCodeInvalid,
      'Ese código no es correcto. Mira el último correo que te hemos enviado.',
    );
    expect(es.verifyEmailOtherAddress, 'Usar otro correo');
    expect(es.verifyEmailCodeLength, 'El código tiene 6 cifras');
    expect(
      es.verifyEmailReplaced,
      'Alguien ha vuelto a crear una cuenta con este correo. Créala de nuevo para continuar.',
    );
    expect(en.verifyEmailHeading, 'Confirm your email');
    expect(
      en.verifyEmailHelp('ana@example.invalid'),
      'We’ve sent a 6-digit code to ana@example.invalid. Type it here.',
    );
    expect(en.verifyEmailResendIn(42), 'Resend code in 42 seconds');
    expect(
      en.verifyEmailReplaced,
      'Someone has created an account with this email again. Create it again to continue.',
    );
    expect(ca.verifyEmailHeading, 'Confirma el teu correu');
    expect(
      ca.verifyEmailHelp('ana@example.invalid'),
      'T’hem enviat un codi de 6 xifres a ana@example.invalid. Escriu-lo aquí.',
    );
    expect(
      ca.verifyEmailResendIn(42),
      'Torna a enviar el codi d’aquí a 42 segons',
    );
    expect(
      ca.verifyEmailResendIn(1),
      'Torna a enviar el codi d’aquí a 1 segon',
    );
    expect(
      ca.verifyEmailReplaced,
      'Algú ha tornat a crear un compte amb aquest correu. Torna a crear-lo per continuar.',
    );
  });

  testWidgets(
    'a sign-up answered verification_required opens Confirma tu correo for the server’s address, with no keyboard until the field is tapped; nothing is signed in or saved yet',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      expect(screen(), findsOneWidget);
      expect(find.text(es.verifyEmailHeading), findsOneWidget);
      // The address as the server wrote it.
      expect(
        find.text(es.verifyEmailHelp('ana@example.invalid')),
        findsOneWidget,
      );
      expect(app.server.bodies('auth/register/').single, {
        'email': 'Ana@Example.invalid',
        'password': typedPassword,
        'timezone': 'Europe/Madrid',
        'language': 'es',
      });
      expect(focused(tester, code), isFalse);
      final field = tester.widget<TextField>(code);
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, [AutofillHints.oneTimeCode]);
      expect(askedPassword, findsNothing, reason: 'the password is known');
      expect(errorUnder(tester, code), isNull);
      expect(app.container.read(authProvider).account, isNull);
      expect(app.api.account, isNull);
      final saved = await tester.runAsync(
        () => const FlutterSecureStorage().readAll(),
      );
      expect(saved!['taskflow.session'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca', 'en']) {
    testWidgets(
      'creating an account sends the app’s language for its emails ($language); signing in sends none',
      (tester) async {
        final l = strings(language);
        final app = await _App.open(tester, language: language);
        await createAccount(tester, l);
        expect(
          app.server.bodies('auth/register/').single['language'],
          language,
        );
        await tapVisible(tester, otherAddress);
        await tapVisible(tester, find.text(l.alreadyHaveAccount));
        await signIn(tester);
        expect(
          app.server.bodies('auth/login/').single.containsKey('language'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a sign-in answered 403 email_unverified opens the same screen for the server’s address, as a step and not an error; Back returns to sign-in as it was',
    (tester) async {
      final app = await _App.open(tester);
      await signIn(tester, address: 'Ana@Example.invalid');
      expect(app.server.paths, ['auth/login/']);
      expect(screen(), findsOneWidget);
      expect(
        find.text(es.verifyEmailHelp('ana@example.invalid')),
        findsOneWidget,
      );
      expect(find.text('Confirm your email address first.'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(screen(), findsNothing);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(formText(tester, email), 'Ana@Example.invalid');
      expect(formText(tester, password), typedPassword);
      expect(find.text(es.requestError('forbidden')), findsNothing);
      expect(find.text(es.requestError('session')), findsNothing);
      expect(app.container.read(authProvider).error, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'six typed digits confirm by themselves with the address and the password just typed, Confirmar shows its own progress, and success lands on Calendar as any sign-in does; the password is never saved',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.holdVerify = Completer<void>();
      await tester.enterText(code, '12345');
      await tester.pump();
      expect(app.server.bodies('auth/verify-email/'), isEmpty);
      await tester.enterText(code, '123456');
      await tester.pump();
      expect(app.server.bodies('auth/verify-email/').single, {
        'email': 'ana@example.invalid',
        'code': '123456',
        'password': typedPassword,
      });
      expect(
        find.descendant(
          of: confirm,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(resendEnabled(tester), isFalse);
      app.server.holdVerify!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(screen(), findsNothing);
      expect(
        app.container.read(authProvider).account!.email,
        'ana@example.invalid',
      );
      final saved = await tester.runAsync(
        () => const FlutterSecureStorage().readAll(),
      );
      expect(saved!['taskflow.session'], contains('fixture-access'));
      for (final value in saved.values) {
        expect(value, isNot(contains(typedPassword)));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'after a sign-in answered email_unverified, the code goes with the password typed to sign in, and signs in',
    (tester) async {
      final app = await _App.open(tester);
      await signIn(tester);
      await tester.enterText(code, '765432');
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/verify-email/').single, {
        'email': 'ana@example.invalid',
        'code': '765432',
        'password': typedPassword,
      });
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a pasted code keeps only its digits and confirms by itself', (
    tester,
  ) async {
    final app = await _App.open(tester);
    await createAccount(tester, es);
    await tester.enterText(code, 'Tu código: 654 321');
    await tester.pumpAndSettle();
    expect(app.server.bodies('auth/verify-email/').single['code'], '654321');
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Confirmar with fewer than 6 digits says the code has 6 and sends nothing',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      await tester.enterText(code, '123');
      await tapVisible(tester, confirm);
      expect(errorUnder(tester, code), es.verifyEmailCodeLength);
      expect(app.server.bodies('auth/verify-email/'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'code_invalid says «Ese código no es correcto…» under the field, read out as it appears, and keeps the digits; a changed code clears it and confirms again',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.verify = (_) =>
          _json(400, {'code': 'code_invalid', 'detail': 'Invalid code.'});
      await tester.enterText(code, '111111');
      await tester.pumpAndSettle();
      expect(
        errorUnder(tester, code),
        'Ese código no es correcto. Mira el último correo que te hemos enviado.',
      );
      expect(find.text('Invalid code.'), findsNothing);
      expect(typed(tester, code), '111111');
      expect(screen(), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      final line = tester.getSemantics(find.text(es.verifyEmailCodeInvalid));
      expect(line.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(announcements, isEmpty, reason: 'read once, as a live region');
      app.server.verify = (body) => _json(200, _session('${body['email']}'));
      await tester.enterText(code, '11111');
      await tester.pump();
      expect(errorUnder(tester, code), isNull);
      await tester.enterText(code, '111112');
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(
        app.server.bodies('auth/verify-email/').map((body) => body['code']),
        ['111111', '111112'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'code_expired within the minute, with the address still unconfirmed, says to tap Reenviar código when the countdown ends, which keeps running; the new code clears it, empties the field and says «Te hemos enviado un código nuevo»',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      expect(waitLeft(tester, es), greaterThanOrEqualTo(59));
      expect(resendEnabled(tester), isFalse);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/login/').single, {
        'email': 'ana@example.invalid',
        'password': typedPassword,
        'timezone': 'UTC',
      });
      expect(errorUnder(tester, code), es.verifyEmailCodeSpentWait);
      expect(resendEnabled(tester), isFalse, reason: 'the countdown goes on');
      await tester.pump(const Duration(seconds: 61));
      expect(resendLabel(tester), 'Reenviar código');
      await tapVisible(tester, resend);
      expect(app.server.bodies('auth/verify-email/resend/').single, {
        'email': 'ana@example.invalid',
        'language': 'es',
      });
      expect(errorUnder(tester, code), isNull);
      expect(find.text('Te hemos enviado un código nuevo'), findsOneWidget);
      expect(typed(tester, code), isEmpty);
      expect(focused(tester, code), isTrue);
      expect(resendEnabled(tester), isFalse);
      expect(waitLeft(tester, es), greaterThanOrEqualTo(58));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reenviar código waits 60 seconds with the countdown shown, then emails a new code in the app’s language, says so, read out as it appears, and waits again',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      final start = waitLeft(tester, es)!;
      expect(start, greaterThanOrEqualTo(59));
      expect(resendEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(waitLeft(tester, es), start - 1);
      await tester.pump(Duration(seconds: start - 2));
      expect(resendLabel(tester), 'Reenviar código en 1 segundo');
      expect(resendEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(resendLabel(tester), 'Reenviar código');
      expect(resendEnabled(tester), isTrue);
      expect(app.server.paths, isNot(contains('auth/verify-email/resend/')));

      await tester.tap(resend);
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/verify-email/resend/').single, {
        'email': 'ana@example.invalid',
        'language': 'es',
      });
      final line = find.text(es.verifyEmailResent);
      expect(line, findsOneWidget);
      expect(
        tester
            .getSemantics(line)
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(announcements, isEmpty, reason: 'read once, as a live region');
      expect(resendEnabled(tester), isFalse);
      expect(waitLeft(tester, es), greaterThanOrEqualTo(58));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no connection and too many tries show the app’s usual messages under the field, for Confirmar and for Reenviar código, which waits again',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.offline = true;
      await tester.enterText(code, '333333');
      await tester.pumpAndSettle();
      expect(errorUnder(tester, code), es.requestError('network'));
      expect(screen(), findsOneWidget);

      app.server.offline = false;
      app.server.verify = (_) =>
          _json(429, {'detail': 'Request was throttled.'});
      await tapVisible(tester, confirm);
      expect(errorUnder(tester, code), es.requestError('rateLimit'));
      expect(find.text('Request was throttled.'), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      expect(resendEnabled(tester), isTrue);
      app.server.resend = (_) =>
          _json(429, {'detail': 'Request was throttled.'});
      await tapVisible(tester, resend);
      expect(errorUnder(tester, code), es.requestError('rateLimit'));
      expect(resendEnabled(tester), isFalse, reason: 'it waits again');
      expect(waitLeft(tester, es), greaterThanOrEqualTo(58));
      expect(tester.takeException(), isNull);
    },
  );

  for (final fromSignIn in [false, true]) {
    testWidgets(
      '«Usar otro correo» goes back to creating the account with the email kept (${fromSignIn ? 'after a sign-in' : 'after creating it'})',
      (tester) async {
        await _App.open(tester);
        if (fromSignIn) {
          await signIn(tester, address: 'ana@exmple.invalid');
        } else {
          await createAccount(tester, es, address: 'ana@exmple.invalid');
        }
        expect(screen(), findsOneWidget);
        await tapVisible(tester, otherAddress);
        expect(screen(), findsNothing);
        expect(find.text(es.registerHeading), findsOneWidget);
        expect(
          find.descendant(of: submit, matching: find.text(es.createAccount)),
          findsOneWidget,
        );
        expect(formText(tester, email), 'ana@exmple.invalid');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'signup_replaced goes back to creating the account with the email kept, the password cleared, and a line saying why, read out as it appears ($language)',
      (tester) async {
        final l = strings(language);
        final app = await _App.open(tester, language: language);
        await createAccount(tester, l);
        app.server.verify = (_) =>
            _json(400, {'code': 'signup_replaced', 'detail': 'Replaced.'});
        await tester.enterText(code, '444444');
        await tester.pumpAndSettle();
        expect(screen(), findsNothing);
        expect(find.text(l.registerHeading), findsOneWidget);
        expect(formText(tester, email), 'Ana@Example.invalid');
        expect(formText(tester, password), isEmpty);
        final why = find.text(l.verifyEmailReplaced);
        expect(why, findsOneWidget);
        expect(find.text('Replaced.'), findsNothing);
        final rect = tester.getRect(why);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844), reason: 'in view');
        expect(
          tester
              .getSemantics(why)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(tester.getSemantics(why).label, l.verifyEmailReplaced);
        expect(announcements, isEmpty, reason: 'read once, as a live region');
        expect(app.container.read(authProvider).account, isNull);
        // Created again, it needs a new password first.
        await tapVisible(tester, submit);
        expect(app.server.bodies('auth/register/'), hasLength(1));
        expect(find.text(l.passwordTooShort), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an older server that answers a new account with a session signs straight in, with no confirm screen',
    (tester) async {
      final app = await _App.open(tester);
      app.server.register = (body) =>
          _json(201, _session('${body['email']}'.toLowerCase()));
      await createAccount(tester, es);
      expect(screen(), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(app.server.paths.where((path) => path.startsWith('auth/')), [
        'auth/register/',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opened without the password, the screen asks for it once, on the same screen, and sends it with each code',
    (tester) async {
      final app = await _App.open(tester);
      // No flow opens it this way.
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const VerifyEmailScreen(email: 'ana@example.invalid'),
              ),
            ),
      );
      await tester.pumpAndSettle();
      expect(askedPassword, findsOneWidget);
      final field = tester.widget<TextField>(askedPassword);
      expect(field.decoration!.labelText, es.password);
      expect(field.obscureText, isTrue);
      // Six digits with no password: it asks, and sends nothing.
      await tester.enterText(code, '555555');
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/verify-email/'), isEmpty);
      expect(errorUnder(tester, askedPassword), es.enterPassword);
      expect(focused(tester, askedPassword), isTrue);

      app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
      await tester.enterText(askedPassword, typedPassword);
      await tester.pump();
      expect(errorUnder(tester, askedPassword), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/verify-email/').single, {
        'email': 'ana@example.invalid',
        'code': '555555',
        'password': typedPassword,
      });
      expect(errorUnder(tester, code), es.verifyEmailCodeInvalid);

      // Asked once: the next code goes with the same password.
      app.server.verify = (body) => _json(200, _session('${body['email']}'));
      await tester.enterText(code, '555556');
      await tester.pumpAndSettle();
      expect(
        app.server.bodies('auth/verify-email/').last['password'],
        typedPassword,
      );
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TalkBack: the heading, the help, the field named Código and each button are read one by one, in that order, and the countdown in full words',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      final help = es.verifyEmailHelp('ana@example.invalid');
      final seconds = waitLeft(tester, es)!;
      expect(es.verifyEmailResendIn(seconds), endsWith('segundos'));
      // Each its own node: the field isn't named by the heading or the help.
      final heading = tester.getSemantics(find.text(es.verifyEmailHeading));
      expect(heading.label, es.verifyEmailHeading);
      expect(heading.getSemanticsData().flagsCollection.isHeader, isTrue);
      expect(tester.getSemantics(find.text(help)).label, help);
      final field = find.bySemanticsLabel(es.verifyEmailCode);
      expect(field, findsOneWidget);
      expect(
        tester
            .getSemantics(field)
            .getSemanticsData()
            .flagsCollection
            .isTextField,
        isTrue,
      );
      final order = [
        es.verifyEmailHeading,
        help,
        es.verifyEmailCode,
        es.verifyEmailConfirm,
        es.verifyEmailResendIn(seconds),
        es.verifyEmailOtherAddress,
      ];
      final tops = [
        for (final label in order)
          tester.getRect(find.bySemanticsLabel(label)).top,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
      }
      final resendNode = tester
          .getSemantics(find.bySemanticsLabel(es.verifyEmailResendIn(seconds)))
          .getSemanticsData()
          .flagsCollection;
      expect(resendNode.isButton, isTrue);
      expect(resendNode.isEnabled, Tristate.isFalse, reason: 'it waits');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'where the platform prefers announcements (iOS), an error under the field is announced once instead of being a live region',
    (tester) async {
      final app = await _App.open(tester, announces: true);
      await createAccount(tester, es);
      app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
      await tester.enterText(code, '121212');
      await tester.pumpAndSettle();
      expect(errorUnder(tester, code), es.verifyEmailCodeInvalid);
      expect(announcements, [es.verifyEmailCodeInvalid]);
      expect(
        tester
            .getSemantics(find.text(es.verifyEmailCodeInvalid))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'at 2× text on 320 dp ($language), the confirm screen reads in full with no overflow, and the field, its longest messages, Confirmar, the countdown and Usar otro correo can all be reached',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final app = await _App.open(
          tester,
          language: language,
          size: const Size(320, 640),
        );
        await createAccount(
          tester,
          l,
          address: 'ana.garcia.lopez@example.invalid',
        );
        expect(screen(), findsOneWidget);

        Future<void> expectReadable(Finder finder) async {
          expect(finder, findsOneWidget);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
          expect(rect.right, lessThanOrEqualTo(320.5), reason: '$finder');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
          expect(rect.bottom, lessThanOrEqualTo(640.5), reason: '$finder');
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.descendant(
              of: finder,
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          )) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '“${paragraph.text.toPlainText()}”',
            );
          }
        }

        await expectReadable(find.text(l.verifyEmailHeading));
        await expectReadable(
          find.text(l.verifyEmailHelp('ana.garcia.lopez@example.invalid')),
        );
        await expectReadable(code);
        await expectReadable(confirm);
        // The countdown, the longest label, while it waits.
        expect(resendEnabled(tester), isFalse);
        await expectReadable(resend);
        await expectReadable(otherAddress);
        for (final otherButton in [confirm, resend, otherAddress]) {
          expect(otherButton.hitTestable(), findsOneWidget);
        }

        // The longest lines under the field.
        app.server.offline = true;
        await tester.enterText(code, '999999');
        await tester.pumpAndSettle();
        await expectReadable(find.text(l.requestError('network')));
        app.server.offline = false;
        app.server.verify = (_) => _json(400, {'code': 'code_expired'});
        await tester.enterText(code, '999998');
        await tester.pumpAndSettle();
        await expectReadable(find.text(l.verifyEmailCodeSpentWait));
        await expectReadable(resend);
        await tester.pump(const Duration(seconds: 61));
        await tapVisible(tester, resend);
        await expectReadable(find.text(l.verifyEmailResent));
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  group('the API client', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('a new account answered verification_required throws '
        'EmailVerificationRequired with the server’s address, and saves no '
        'session; an older server’s 201 with tokens signs in', () async {
      final server = _Server();
      final api = ApiClient(
        transport: server.transport,
        url: 'http://api.test',
      );
      addTearDown(api.close);
      await expectLater(
        api.signIn(
          ' Ana@Example.invalid ',
          typedPassword,
          register: true,
          timezone: 'Europe/Madrid',
          language: 'ca',
        ),
        throwsA(
          isA<EmailVerificationRequired>().having(
            (e) => e.email,
            'email',
            'ana@example.invalid',
          ),
        ),
      );
      expect(server.bodies('auth/register/').single, {
        'email': 'Ana@Example.invalid',
        'password': typedPassword,
        'timezone': 'Europe/Madrid',
        'language': 'ca',
      });
      expect(api.account, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );

      server.register = (body) => _json(201, _session('${body['email']}'));
      await api.signIn('ana@example.invalid', typedPassword, register: true);
      expect(api.account!.email, 'ana@example.invalid');
    });

    test(
      'a sign-in answered 403 email_unverified throws '
      'EmailVerificationRequired; another 403 stays an ApiException',
      () async {
        final server = _Server();
        final api = ApiClient(
          transport: server.transport,
          url: 'http://api.test',
        );
        addTearDown(api.close);
        await expectLater(
          api.signIn('Ana@Example.invalid', typedPassword, language: 'es'),
          throwsA(
            isA<EmailVerificationRequired>().having(
              (e) => e.email,
              'email',
              'ana@example.invalid',
            ),
          ),
        );
        expect(
          server.bodies('auth/login/').single.containsKey('language'),
          isFalse,
        );
        // Without the address in the answer, the typed one.
        server.login = (_) => _json(403, {'code': 'email_unverified'});
        await expectLater(
          api.signIn(' typed@example.invalid ', typedPassword),
          throwsA(
            isA<EmailVerificationRequired>().having(
              (e) => e.email,
              'email',
              'typed@example.invalid',
            ),
          ),
        );
        server.login = (_) => _json(403, {'detail': 'Not allowed.'});
        await expectLater(
          api.signIn('ana@example.invalid', typedPassword),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
        );
      },
    );

    test('verifyEmail sends the address, the code and the password, and '
        'signs in with the answer; resend sends the address and the '
        'language', () async {
      final server = _Server();
      final api = ApiClient(
        transport: server.transport,
        url: 'http://api.test',
      );
      addTearDown(api.close);
      await api.verifyEmail('ana@example.invalid', '123456', typedPassword);
      expect(server.bodies('auth/verify-email/').single, {
        'email': 'ana@example.invalid',
        'code': '123456',
        'password': typedPassword,
      });
      expect(api.account!.email, 'ana@example.invalid');
      final saved = await const FlutterSecureStorage().readAll();
      expect(saved['taskflow.session'], isNot(contains(typedPassword)));

      await api.resendVerificationCode('ana@example.invalid', language: 'ca');
      expect(server.bodies('auth/verify-email/resend/').single, {
        'email': 'ana@example.invalid',
        'language': 'ca',
      });
    });
  });

  // ---- Run 2026-10-18-commands, P132 (UX-402, UX-1208): sign-in errors
  // name the problem, from the server's real answers ----

  /// The server's own answer to a wrong password, or an address with no
  /// account (Backend/core/auth_views.py).
  http.Response wrongPassword(Map<String, dynamic> _) =>
      _json(401, {'detail': 'Email or password is incorrect.'});

  /// A refusal for too many tries, with [retryAfter] seconds when given.
  http.Response throttled({int? retryAfter, String? detail}) =>
      http.Response.bytes(
        utf8.encode(jsonEncode({'detail': detail ?? 'Request was throttled.'})),
        429,
        headers: {
          'content-type': 'application/json',
          if (retryAfter != null) 'retry-after': '$retryAfter',
        },
      );

  /// [text] is on screen: as a line, or as a field's error.
  bool says(WidgetTester tester, String text) =>
      find.text(text).evaluate().isNotEmpty ||
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.decoration?.errorText == text);

  final createWithEmail = find.byKey(
    const ValueKey('create-account-with-email'),
  );
  final signInWithEmail = find.byKey(const ValueKey('sign-in-with-email'));
  final recoverWithEmail = find.byKey(const ValueKey('recover-with-email'));

  testWidgets(
    'UX-402: sign-in answered 401 «Email or password is incorrect.» says «No encontramos esa cuenta o la contraseña no es correcta.» with «Crear una cuenta con este correo», keeps the email, and never says «Vuelve a iniciar sesión…»',
    (tester) async {
      final app = await _App.open(tester);
      app.server.login = wrongPassword;
      await signIn(tester, address: 'nueva@example.invalid');
      expect(app.server.paths.last, 'auth/login/');
      expect(
        es.requestError('credentials'),
        'No encontramos esa cuenta o la contraseña no es correcta.',
      );
      expect(says(tester, es.requestError('credentials')), isTrue);
      expect(says(tester, es.requestError('session')), isFalse);
      expect(find.text('Email or password is incorrect.'), findsNothing);
      expect(createWithEmail, findsOneWidget);
      expect(
        find.descendant(
          of: createWithEmail,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      expect(es.createAccountWithEmail, 'Crear una cuenta con este correo');
      expect(formText(tester, email), 'nueva@example.invalid');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-402 + UX-488: create → «Ya existe una cuenta…» → «Iniciar sesión con este correo» → the server’s 401 offers «¿Has olvidado tu contraseña?», not «Crear una cuenta con este correo»',
    (tester) async {
      final app = await _App.open(tester);
      app.server.register = (_) => _json(400, {
        'email': ['An account with this email already exists.'],
      });
      app.server.login = wrongPassword;
      await createAccount(tester, es, address: 'ana@example.invalid');
      expect(says(tester, es.requestError('emailUsed')), isTrue);
      expect(signInWithEmail, findsOneWidget);
      await tapVisible(tester, signInWithEmail);
      expect(find.text(es.signInHeading), findsOneWidget);
      await tapVisible(tester, submit);
      expect(app.server.paths.last, 'auth/login/');
      expect(says(tester, es.requestError('credentials')), isTrue);
      expect(says(tester, es.requestError('session')), isFalse);
      expect(recoverWithEmail, findsOneWidget);
      expect(
        find.descendant(
          of: recoverWithEmail,
          matching: find.text(es.forgotPassword),
        ),
        findsOneWidget,
      );
      expect(createWithEmail, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('UX-402: what a 401 means depends on where it came from', () {
    test('sign-in’s 401, whatever its wording, is wrong credentials; the '
        'same answer to an account being created is not', () async {
      final server = _Server()..login = wrongPassword;
      final api = ApiClient(
        transport: server.transport,
        url: 'http://api.test',
      );
      addTearDown(api.close);
      Object? signingIn;
      try {
        await api.signIn('ana@example.invalid', typedPassword);
      } catch (error) {
        signingIn = error;
      }
      expect(signingIn, isA<ApiException>());
      expect((signingIn as ApiException).status, 401);
      expect(signingIn.message, 'Email or password is incorrect.');
      expect(requestProblem(signingIn), 'credentials');

      server.register = wrongPassword;
      Object? creating;
      try {
        await api.signIn('ana@example.invalid', typedPassword, register: true);
      } catch (error) {
        creating = error;
      }
      expect(creating, isA<ApiException>());
      expect(requestProblem(creating!), isNot('credentials'));
    });

    test('an authenticated request elsewhere answered 401 still means the '
        'session ended', () {
      expect(
        requestProblem(
          ApiException(401, 'Email or password is incorrect.', {
            'detail': 'Email or password is incorrect.',
          }),
        ),
        'session',
      );
      expect(
        requestProblem(
          ApiException(401, 'Given token not valid for any token type', {
            'detail': 'Given token not valid for any token type',
          }),
        ),
        'session',
      );
      // Older servers' simplejwt wording still reads as credentials.
      expect(
        requestProblem(
          ApiException(
            401,
            'No active account found with the given credentials',
          ),
        ),
        'credentials',
      );
    });
  });

  testWidgets(
    'UX-1208: Confirmar answered 429 with Retry-After 42 says «Demasiados intentos. Espera un minuto y vuelve a intentarlo.»',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      expect(screen(), findsOneWidget);
      app.server.verify = (_) => throttled(retryAfter: 42);
      await tester.enterText(code, '333333');
      await tester.pumpAndSettle();
      if (app.server.paths.last != 'auth/verify-email/') {
        await tapVisible(tester, confirm);
      }
      expect(
        es.tooManyTriesWait(1),
        'Demasiados intentos. Espera un minuto y vuelve a intentarlo.',
      );
      expect(says(tester, es.tooManyTriesWait(1)), isTrue);
      expect(says(tester, es.requestError('rateLimit')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1208: sign-in answered 429 with Retry-After 900 says «Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.»',
    (tester) async {
      final app = await _App.open(tester);
      app.server.login = (_) => throttled(retryAfter: 900);
      await signIn(tester);
      expect(
        es.tooManyTriesWait(15),
        'Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.',
      );
      expect(says(tester, es.tooManyTriesWait(15)), isTrue);
      expect(says(tester, es.requestError('rateLimit')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1208: «Crea tu cuenta» answered 429 with Retry-After 60 says «Demasiados intentos. Espera un minuto y vuelve a intentarlo.»',
    (tester) async {
      final app = await _App.open(tester);
      app.server.register = (_) => throttled(retryAfter: 60);
      await createAccount(tester, es);
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(says(tester, es.tooManyTriesWait(1)), isTrue);
      expect(says(tester, es.requestError('rateLimit')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1208: a 429 with no Retry-After and no wait in its text keeps «Demasiadas solicitudes. Espera un poco antes de volver a intentarlo.»; DRF’s English «Expected available in 120 seconds.» reads as 2 minutes',
    (tester) async {
      final app = await _App.open(tester);
      app.server.login = (_) => throttled();
      await signIn(tester);
      expect(
        es.requestError('rateLimit'),
        'Demasiadas solicitudes. Espera un poco antes de volver a intentarlo.',
      );
      expect(says(tester, es.requestError('rateLimit')), isTrue);
      expect(find.textContaining('Demasiados intentos'), findsNothing);

      app.server.login = (_) => throttled(
        detail: 'Request was throttled. Expected available in 120 seconds.',
      );
      await tapVisible(tester, submit);
      expect(says(tester, es.tooManyTriesWait(2)), isTrue);
      expect(find.textContaining('Expected available'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-1208: the wait is whole minutes rounded up, at least 1, and only '
      'on the sign-in screens', () {
    ApiException wait(int seconds) => ApiException(
      429,
      'Request was throttled.',
      {},
      Duration(seconds: seconds),
    );
    expect(waitMinutesFor(wait(1)), 1);
    expect(waitMinutesFor(wait(42)), 1);
    expect(waitMinutesFor(wait(60)), 1);
    expect(waitMinutesFor(wait(61)), 2);
    expect(waitMinutesFor(wait(900)), 15);
    expect(waitMinutesFor(ApiException(429, 'Request was throttled.')), isNull);
    expect(
      waitMinutesFor(ApiException(400, 'x', {}, const Duration(seconds: 60))),
      isNull,
    );
    expect(
      requestProblemText(es, wait(900), onSignIn: true),
      es.tooManyTriesWait(15),
    );
    expect(
      requestProblemText(es, wait(900)),
      es.requestError('rateLimit'),
      reason: 'other screens keep today’s line',
    );
  });

  // ---- Run 2026-10-18-commands, round 2 (P133: UX-1201, UX-1203, UX-1204;
  // P134: UX-1202): the answer in view, the keyboard steady, an honest
  // «ya no sirve», and the screen survives the trip to the inbox ----

  /// [seconds] pass, on the clock the screen reads and for its countdown.
  Future<void> later(WidgetTester tester, _Clock clock, int seconds) async {
    clock.now = clock.now.add(Duration(seconds: seconds));
    await tester.pump(Duration(seconds: seconds));
  }

  /// The confirm screen's list, scrolled back to its top.
  void scrollToTop(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: screen(), matching: find.byType(Scrollable)).first,
      )
      .position
      .jumpTo(0);

  /// [text] shows whole inside a [size] screen, with no line cut off.
  Future<void> expectFits(WidgetTester tester, String text, Size size) async {
    final finder = find.text(text);
    expect(finder, findsOneWidget, reason: text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0), reason: text);
    expect(rect.right, lessThanOrEqualTo(size.width + 0.5), reason: text);
    expect(rect.top, greaterThanOrEqualTo(0), reason: text);
    expect(rect.bottom, lessThanOrEqualTo(size.height + 0.5), reason: text);
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: finder,
        matching: find.byType(RichText),
        matchRoot: true,
      ),
    )) {
      expect(paragraph.didExceedMaxLines, isFalse, reason: text);
    }
  }

  /// Opens «Confirma tu correo» for [address] as a cold start does: without
  /// the password, which the screen then asks for.
  Future<void> openWithoutPassword(
    WidgetTester tester, {
    String address = 'ana@example.invalid',
  }) async {
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => VerifyEmailScreen(email: address),
            ),
          ),
    );
    await tester.pumpAndSettle();
    expect(askedPassword, findsOneWidget);
  }

  /// The phone's storage now, without the session: what TaskFlow finds when
  /// Android has closed it and it starts again.
  Future<Map<String, String>> storedWithoutSession(WidgetTester tester) async {
    final saved = await tester.runAsync(
      () => const FlutterSecureStorage().readAll(),
    );
    return Map.of(saved!)
      ..removeWhere((_, value) => value.contains('fixture-access'));
  }

  /// TaskFlow starts again from nothing, with [storage] on the phone.
  Future<_App> coldStart(
    WidgetTester tester,
    Map<String, String> storage, {
    _Clock? clock,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    return _App.open(tester, storage: storage, clock: clock?.call);
  }

  testWidgets(
    'UX-1201: the keyboard stays up from the 6th digit until the answer arrives, and after it; what is typed while it confirms is ignored',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      await tester.showKeyboard(code);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      app.server.holdVerify = Completer<void>();
      app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
      await tester.enterText(code, '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.server.bodies('auth/verify-email/'), hasLength(1));
      expect(tester.testTextInput.isVisible, isTrue, reason: '6th digit');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.testTextInput.isVisible, isTrue, reason: 'confirming');
      await tester.enterText(code, '999999');
      await tester.pump();
      expect(typed(tester, code), '123456', reason: 'ignored while confirming');
      expect(tester.testTextInput.isVisible, isTrue);
      app.server.holdVerify!.complete();
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue, reason: 'answered');
      expect(errorUnder(tester, code), es.verifyEmailCodeInvalid);
      expect(focused(tester, code), isTrue);
      expect(app.server.bodies('auth/verify-email/'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1201: at 1.3× on 360×740 the screen opens with nothing focused and no keyboard, and «Reenviar código en 60 segundos» and «Usar otro correo» are on screen',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _App.open(tester, size: const Size(360, 740));
      await createAccount(tester, es);
      expect(screen(), findsOneWidget);
      expect(focused(tester, code), isFalse);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(es.verifyEmailResendIn(60), 'Reenviar código en 60 segundos');
      for (final label in [
        es.verifyEmailResendIn(60),
        es.verifyEmailOtherAddress,
      ]) {
        final line = find.text(label);
        expect(line, findsOneWidget, reason: label);
        final rect = tester.getRect(line);
        expect(rect.top, greaterThanOrEqualTo(0), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(740), reason: label);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
        'UX-1201: with the keyboard up ($language, $scale×, 360×740), each answer under the code field (refused, no connection, spent within the minute, spent after it, a new code sent) ends above the keyboard',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final l = strings(language);
          final clock = _Clock();
          final app = await _App.open(
            tester,
            language: language,
            size: const Size(360, 740),
            clock: clock.call,
          );
          await createAccount(tester, l);
          // The keyboard takes the bottom 300 dp.
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.showKeyboard(code);
          await tester.pumpAndSettle();

          void expectAboveKeyboard(String line) {
            final shown = find.text(line);
            expect(shown, findsOneWidget, reason: line);
            final rect = tester.getRect(shown);
            expect(rect.top, greaterThanOrEqualTo(0), reason: line);
            expect(rect.bottom, lessThanOrEqualTo(440), reason: line);
          }

          Future<void> answer(String digits, String line) async {
            scrollToTop(tester);
            await tester.pump();
            await tester.enterText(code, digits);
            await tester.pumpAndSettle();
            expectAboveKeyboard(line);
          }

          app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
          await answer('111111', l.verifyEmailCodeInvalid);
          app.server.offline = true;
          await answer('222222', l.requestError('network'));
          app.server.offline = false;
          app.server.verify = (_) => _json(400, {'code': 'code_expired'});
          await answer('333333', l.verifyEmailCodeSpentWait);
          await later(tester, clock, 61);
          await answer('444444', l.verifyEmailCodeSpentNew);

          await later(tester, clock, 61);
          expect(resendEnabled(tester), isTrue);
          await tapVisible(tester, resend);
          expect(app.server.bodies('auth/verify-email/resend/'), hasLength(1));
          expectAboveKeyboard(l.verifyEmailResent);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'UX-1204: refused digits are not sent again: Confirmar, the keyboard’s done action and the same six digits typed again keep «Ese código no es correcto. Mira el último correo que te hemos enviado.»; one changed digit clears it and six new digits send one request',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
      int sent() => app.server.bodies('auth/verify-email/').length;
      const refused =
          'Ese código no es correcto. Mira el último correo que te hemos enviado.';
      expect(es.verifyEmailCodeInvalid, refused);
      await tester.enterText(code, '111111');
      await tester.pumpAndSettle();
      expect(sent(), 1);
      expect(errorUnder(tester, code), refused);

      await tapVisible(tester, confirm);
      expect(sent(), 1, reason: 'Confirmar');
      expect(errorUnder(tester, code), refused);

      await tester.showKeyboard(code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent(), 1, reason: 'the keyboard’s done action');
      expect(errorUnder(tester, code), refused);

      await tester.enterText(code, '11111');
      await tester.pump();
      expect(errorUnder(tester, code), isNull, reason: 'a digit changed');
      await tester.enterText(code, '111111');
      await tester.pumpAndSettle();
      expect(sent(), 1, reason: 'the same six digits typed again');
      expect(errorUnder(tester, code), refused);

      await tester.enterText(code, '11111');
      await tester.pump();
      expect(errorUnder(tester, code), isNull);
      await tester.enterText(code, '111112');
      await tester.pumpAndSettle();
      expect(sent(), 2);
      expect(
        app.server.bodies('auth/verify-email/').map((body) => body['code']),
        ['111111', '111112'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1203: verify answered code_expired and the sign-in answered a session opens the app on Calendar, and no «ya no sirve» line ever shows',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      app.server.login = (body) => _json(200, _session('${body['email']}'));
      app.server.holdLogin = Completer<void>();
      bool saysSpent() =>
          says(tester, es.verifyEmailCodeSpentNew) ||
          says(tester, es.verifyEmailCodeSpentWait);
      await tester.enterText(code, '222222');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(app.server.paths.last, 'auth/login/');
      final login = app.server.bodies('auth/login/').single;
      expect(login['email'], 'ana@example.invalid');
      expect(login['password'], typedPassword);
      expect(saysSpent(), isFalse, reason: 'while signing in');
      expect(screen(), findsOneWidget);
      expect(
        find.descendant(
          of: confirm,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'still confirming',
      );
      app.server.holdLogin!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(screen(), findsNothing);
      expect(saysSpent(), isFalse);
      expect(
        app.container.read(authProvider).account!.email,
        'ana@example.invalid',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1204: code_expired 61 s after the screen opened, the address still unconfirmed, says «Ese código ya no sirve. Te hemos enviado uno nuevo.», empties and focuses the field, and the countdown starts again at 60',
    (tester) async {
      final clock = _Clock();
      final app = await _App.open(tester, clock: clock.call);
      await createAccount(tester, es);
      await later(tester, clock, 61);
      expect(resendEnabled(tester), isTrue);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(app.server.paths, contains('auth/login/'));
      expect(
        es.verifyEmailCodeSpentNew,
        'Ese código ya no sirve. Te hemos enviado uno nuevo.',
      );
      expect(errorUnder(tester, code), es.verifyEmailCodeSpentNew);
      expect(typed(tester, code), isEmpty);
      expect(focused(tester, code), isTrue);
      expect(resendLabel(tester), 'Reenviar código en 60 segundos');
      expect(resendEnabled(tester), isFalse);
      expect(screen(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1204: code_expired 20 s after the screen opened says «Ese código ya no sirve. Toca «Reenviar código» cuando acabe la cuenta atrás.», and the button reads «Reenviar código en 40 segundos» and stays off',
    (tester) async {
      final clock = _Clock();
      final app = await _App.open(tester, clock: clock.call);
      await createAccount(tester, es);
      await later(tester, clock, 20);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(app.server.paths, contains('auth/login/'));
      expect(
        es.verifyEmailCodeSpentWait,
        'Ese código ya no sirve. Toca «Reenviar código» cuando acabe la cuenta atrás.',
      );
      expect(errorUnder(tester, code), es.verifyEmailCodeSpentWait);
      expect(resendLabel(tester), 'Reenviar código en 40 segundos');
      expect(resendEnabled(tester), isFalse);
      await tester.tap(resend, warnIfMissed: false);
      await tester.pump();
      expect(app.server.paths, isNot(contains('auth/verify-email/resend/')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1204 + UX-1202: at 2× on 320×640 ($language), «Ese código no es correcto…», both «ya no sirve» lines and «Esa contraseña no es la de esta cuenta.» fit with no overflow',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const size = Size(320, 640);
        final l = strings(language);
        final clock = _Clock();
        final app = await _App.open(
          tester,
          language: language,
          size: size,
          clock: clock.call,
        );
        await openWithoutPassword(tester);
        await tester.enterText(askedPassword, typedPassword);
        app.server.verify = (_) => _json(400, {'code': 'signup_replaced'});
        await tester.enterText(code, '101010');
        await tester.pumpAndSettle();
        await expectFits(tester, l.verifyEmailWrongPassword, size);
        await tester.enterText(askedPassword, '$typedPassword!');
        app.server.verify = (_) => _json(400, {'code': 'code_invalid'});
        await tester.enterText(code, '111111');
        await tester.pumpAndSettle();
        await expectFits(tester, l.verifyEmailCodeInvalid, size);
        app.server.verify = (_) => _json(400, {'code': 'code_expired'});
        await tester.enterText(code, '222222');
        await tester.pumpAndSettle();
        await expectFits(tester, l.verifyEmailCodeSpentWait, size);
        await later(tester, clock, 61);
        await tester.enterText(code, '333333');
        await tester.pumpAndSettle();
        await expectFits(tester, l.verifyEmailCodeSpentNew, size);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  testWidgets(
    'UX-1202: Android closes TaskFlow after the sign-up; started again with no session, it opens «Confirma tu correo» for that address with the password field, sending nothing, and the emailed code then signs in',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      expect(screen(), findsOneWidget);
      final storage = await storedWithoutSession(tester);
      final again = await coldStart(tester, storage);
      expect(screen(), findsOneWidget);
      expect(find.text(es.verifyEmailHeading), findsOneWidget);
      expect(
        find.text(es.verifyEmailHelp('ana@example.invalid')),
        findsOneWidget,
      );
      expect(askedPassword, findsOneWidget);
      expect(again.server.requests, isEmpty, reason: 'nothing sent');

      await tester.enterText(askedPassword, typedPassword);
      await tester.enterText(code, '123456');
      await tester.pumpAndSettle();
      expect(again.server.bodies('auth/verify-email/').single, {
        'email': 'ana@example.invalid',
        'code': '123456',
        'password': typedPassword,
      });
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1202: Back from «Confirma tu correo» keeps the address waiting: started again, the app opens that screen',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(screen(), findsNothing);
      final again = await coldStart(tester, await storedWithoutSession(tester));
      expect(screen(), findsOneWidget);
      expect(askedPassword, findsOneWidget);
      expect(again.server.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final ending in ['31 minutes later', 'Usar otro correo', 'confirmed']) {
    testWidgets(
      'UX-1202: after the sign-up, then $ending, a cold start with no session opens plain sign-in',
      (tester) async {
        final clock = _Clock();
        final app = await _App.open(tester, clock: clock.call);
        await createAccount(tester, es);
        expect(screen(), findsOneWidget);
        switch (ending) {
          case 'Usar otro correo':
            await tapVisible(tester, otherAddress);
            expect(screen(), findsNothing);
          case 'confirmed':
            await tester.enterText(code, '123456');
            await tester.pumpAndSettle();
            expect(find.byType(CalendarScreen), findsOneWidget);
            expect(app.container.read(authProvider).account, isNotNull);
          default:
            clock.now = clock.now.add(const Duration(minutes: 31));
        }
        final storage = await storedWithoutSession(tester);
        final again = await coldStart(tester, storage, clock: clock);
        expect(screen(), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text(es.signInHeading), findsOneWidget);
        expect(again.server.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1202: the phone’s storage never holds the password, only the address and a time',
    (tester) async {
      final clock = _Clock();
      final app = await _App.open(tester, clock: clock.call);
      await createAccount(tester, es);
      await later(tester, clock, 61);
      await tapVisible(tester, resend);
      expect(app.server.bodies('auth/verify-email/resend/'), hasLength(1));
      final saved = (await tester.runAsync(
        () => const FlutterSecureStorage().readAll(),
      ))!;
      for (final value in saved.values) {
        expect(value, isNot(contains(typedPassword)));
      }
      final pending = [
        for (final value in saved.values)
          if (value.contains('ana@example.invalid')) value,
      ];
      expect(pending, hasLength(1));
      final entry = jsonDecode(pending.single) as Map<String, dynamic>;
      expect(entry, hasLength(2));
      expect(entry.values, contains('ana@example.invalid'));
      final other = entry.values.firstWhere(
        (value) => value != 'ana@example.invalid',
      );
      expect(DateTime.tryParse('$other'), isNotNull, reason: 'a time: $other');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1202: on the cold-start screen, verify answered signup_replaced says «Esa contraseña no es la de esta cuenta.» under the password field, and the screen stays',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      final again = await coldStart(tester, await storedWithoutSession(tester));
      expect(screen(), findsOneWidget);
      again.server.verify = (_) =>
          _json(400, {'code': 'signup_replaced', 'detail': 'Replaced.'});
      await tester.enterText(askedPassword, 'otra-clave-mal-escrita');
      await tester.enterText(code, '444444');
      await tester.pumpAndSettle();
      expect(again.server.bodies('auth/verify-email/'), hasLength(1));
      expect(
        es.verifyEmailWrongPassword,
        'Esa contraseña no es la de esta cuenta. ¿No la recuerdas? Toca '
        '«Usar otro correo» y crea la cuenta de nuevo.',
      );
      expect(errorUnder(tester, askedPassword), es.verifyEmailWrongPassword);
      expect(errorUnder(tester, code), isNull);
      expect(screen(), findsOneWidget);
      expect(find.text(es.registerHeading), findsNothing);
      expect(find.text(es.verifyEmailReplaced), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1202: on the cold-start screen, a spent code whose sign-in check answers wrong credentials says «Esa contraseña no es la de esta cuenta.» under the password field',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      final again = await coldStart(tester, await storedWithoutSession(tester));
      again.server.verify = (_) => _json(400, {'code': 'code_expired'});
      again.server.login = wrongPassword;
      await tester.enterText(askedPassword, 'otra-clave-mal-escrita');
      await tester.enterText(code, '444444');
      await tester.pumpAndSettle();
      expect(again.server.paths, contains('auth/login/'));
      expect(errorUnder(tester, askedPassword), es.verifyEmailWrongPassword);
      expect(says(tester, es.verifyEmailCodeSpentWait), isFalse);
      expect(says(tester, es.verifyEmailCodeSpentNew), isFalse);
      expect(screen(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1203: verify answered code_expired and the sign-in check answered something else (too many tries) shows that answer under the code field, and the screen stays',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      app.server.login = (_) => throttled(retryAfter: 120);
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(app.server.paths, contains('auth/login/'));
      expect(errorUnder(tester, code), es.tooManyTriesWait(2));
      expect(says(tester, es.verifyEmailCodeSpentWait), isFalse);
      expect(says(tester, es.verifyEmailCodeSpentNew), isFalse);
      expect(screen(), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, round 2 (b2) · P149 (UX-1215 to UX-1218):
  // «Confirma tu correo» reopened after a restart ----

  /// The sign-up's address waits; [after] passes; TaskFlow starts again with
  /// no session, on the same storage.
  Future<({_App app, _Clock clock, Map<String, String> storage})>
  reopenedAfter(
    WidgetTester tester,
    Duration after, {
    String language = 'es',
    Size size = const Size(390, 844),
  }) async {
    final clock = _Clock();
    await _App.open(tester, clock: clock.call, language: language, size: size);
    await createAccount(tester, strings(language));
    expect(screen(), findsOneWidget);
    final storage = await storedWithoutSession(tester);
    clock.now = clock.now.add(after);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final app = await _App.open(
      tester,
      storage: storage,
      clock: clock.call,
      language: language,
      size: size,
    );
    expect(screen(), findsOneWidget);
    return (app: app, clock: clock, storage: storage);
  }

  testWidgets(
    'UX-1215: reopened a minute after the sign-up, signup_replaced says from the first refusal «Esa contraseña no es la de esta cuenta. ¿No la recuerdas? Toca «Usar otro correo» y crea la cuenta de nuevo.» under the password field; the screen stays, and «Usar otro correo» lands on «Crea tu cuenta» with the address',
    (tester) async {
      final again = await reopenedAfter(tester, const Duration(minutes: 1));
      final app = again.app;
      app.server.verify = (_) =>
          _json(400, {'code': 'signup_replaced', 'detail': 'Replaced.'});
      await tester.enterText(askedPassword, 'no-la-recuerdo');
      await tester.enterText(code, '444444');
      await tester.pumpAndSettle();
      expect(app.server.bodies('auth/verify-email/'), hasLength(1));
      expect(
        es.verifyEmailWrongPassword,
        'Esa contraseña no es la de esta cuenta. ¿No la recuerdas? Toca '
        '«Usar otro correo» y crea la cuenta de nuevo.',
      );
      expect(errorUnder(tester, askedPassword), es.verifyEmailWrongPassword);
      expect(screen(), findsOneWidget);
      // The way out it names is the button on this screen.
      expect(
        find.descendant(
          of: otherAddress,
          matching: find.text(es.verifyEmailOtherAddress),
        ),
        findsOneWidget,
      );
      await tapVisible(tester, otherAddress);
      expect(screen(), findsNothing);
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(
        find.descendant(of: submit, matching: find.text(es.createAccount)),
        findsOneWidget,
      );
      expect(formText(tester, email), 'ana@example.invalid');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-1215: the wrong-password line names «Use another email» in English and Catalan too, with each catalog’s own label',
    () {
      expect(
        en.verifyEmailWrongPassword,
        'That isn’t this account’s password. Don’t remember it? Tap '
        '“Use another email” and create the account again.',
      );
      expect(
        ca.verifyEmailWrongPassword,
        'Aquesta contrasenya no és la d’aquest compte. No la recordes? Toca '
        '«Utilitza un altre correu» i torna a crear el compte.',
      );
      expect(
        en.verifyEmailWrongPassword,
        contains('“${en.verifyEmailOtherAddress}”'),
      );
      expect(
        es.verifyEmailWrongPassword,
        contains('«${es.verifyEmailOtherAddress}»'),
      );
      expect(
        ca.verifyEmailWrongPassword,
        contains('«${ca.verifyEmailOtherAddress}»'),
      );
    },
  );

  testWidgets(
    'UX-1215: at 2× on 320×640 in Catalan, reopened after a restart, the whole wrong-password line shows under the password field, not cut or ellipsized',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const size = Size(320, 640);
      final again = await reopenedAfter(
        tester,
        const Duration(minutes: 1),
        language: 'ca',
        size: size,
      );
      again.app.server.verify = (_) => _json(400, {'code': 'signup_replaced'});
      await tester.enterText(askedPassword, 'no-la-recordo');
      await tester.enterText(code, '444444');
      await tester.pumpAndSettle();
      expect(errorUnder(tester, askedPassword), ca.verifyEmailWrongPassword);
      await expectFits(tester, ca.verifyEmailWrongPassword, size);
      // Under the password field.
      final line = tester.getRect(find.text(ca.verifyEmailWrongPassword));
      final field = tester.getRect(
        find.descendant(of: askedPassword, matching: find.byType(EditableText)),
      );
      expect(line.top, greaterThanOrEqualTo(field.bottom - 0.5));
      expect(tester.takeException(), isNull, reason: 'no overflow');
    },
  );

  testWidgets(
    'UX-1216: reopened 5 minutes after the sign-up, «Reenviar código» is on at once; the saved time isn’t rewritten; a code_expired whose sign-in check sends a new code says «Te hemos enviado uno nuevo» and empties the code field',
    (tester) async {
      final again = await reopenedAfter(tester, const Duration(minutes: 5));
      final app = again.app;
      expect(resendLabel(tester), es.verifyEmailResend);
      expect(waitLeft(tester, es), isNull);
      expect(resendEnabled(tester), isTrue);
      expect(app.server.requests, isEmpty, reason: 'nothing sent');
      // Reopening doesn't count as a new code.
      expect(await storedWithoutSession(tester), again.storage);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      await tester.enterText(askedPassword, typedPassword);
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(app.server.paths, ['auth/verify-email/', 'auth/login/']);
      expect(errorUnder(tester, code), es.verifyEmailCodeSpentNew);
      expect(says(tester, es.verifyEmailCodeSpentWait), isFalse);
      expect(typed(tester, code), isEmpty);
      expect(screen(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1216: reopened 20 seconds after the sign-up, the button reads «Reenviar código en 40 segundos» and is off; 40 seconds later it is on',
    (tester) async {
      final again = await reopenedAfter(tester, const Duration(seconds: 20));
      expect(es.verifyEmailResendIn(40), 'Reenviar código en 40 segundos');
      expect(resendLabel(tester), es.verifyEmailResendIn(40));
      expect(resendEnabled(tester), isFalse);
      await later(tester, again.clock, 40);
      await tester.pumpAndSettle();
      expect(resendLabel(tester), es.verifyEmailResend);
      expect(resendEnabled(tester), isTrue);
      expect(again.app.server.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1217: a cold start with a waiting address goes from SessionLoadingScreen straight to «Confirma tu correo», over sign-in, at most one frame of sign-in between, with no transition, sending nothing',
    (tester) async {
      await _App.open(tester);
      await createAccount(tester, es);
      final storage = await storedWithoutSession(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final again = await _App.open(tester, storage: storage, settle: false);
      // What each frame shows, from the first.
      final frames = <String>[];
      String shown() {
        if (find.byType(SessionLoadingScreen).evaluate().isNotEmpty) {
          return 'loading';
        }
        if (screen().evaluate().isNotEmpty) {
          final route = ModalRoute.of(tester.element(screen()))!;
          final at = tester.getTopLeft(screen());
          return route.animation!.value == 1 && at == Offset.zero
              ? 'confirm'
              : 'confirm-moving';
        }
        if (find.byType(LoginScreen).evaluate().isNotEmpty) return 'sign-in';
        // Before the app's localizations load, nothing is drawn yet.
        if (find.byType(Scaffold).evaluate().isEmpty) return 'blank';
        return 'other';
      }

      frames.add(shown());
      for (var i = 0; i < 60 && !frames.contains('confirm'); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        frames.add(shown());
      }
      expect(frames, contains('confirm'), reason: '$frames');
      // Nothing, or SessionLoadingScreen, until the stored address is read.
      final start = frames.indexWhere(
        (frame) => frame != 'blank' && frame != 'loading',
      );
      expect(
        frames.take(start),
        everyElement(isIn(['blank', 'loading'])),
        reason: '$frames',
      );
      final after = frames.sublist(start);
      final first = after.indexOf('confirm');
      expect(
        after.take(first).where((frame) => frame == 'sign-in').length,
        lessThanOrEqualTo(1),
        reason: 'at most one frame of sign-in: $frames',
      );
      expect(
        after.take(first),
        everyElement(isIn(['sign-in'])),
        reason: 'no sliding or zooming in: $frames',
      );
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(screen()))!;
      expect(route, isA<TransitionRoute<dynamic>>());
      expect(
        (route as TransitionRoute<dynamic>).transitionDuration,
        Duration.zero,
      );
      // Over sign-in, which Back returns to.
      expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
      expect(again.server.requests, isEmpty, reason: 'nothing sent');
      expect(tester.takeException(), isNull);
    },
  );

  for (final via in ['password', 'Google']) {
    testWidgets(
      'UX-1218: an address waiting for its code, then a sign-in as another account ($via), then sign-out: no address waits, sign-in stays on «Inicia sesión», and a cold start opens plain sign-in',
      (tester) async {
        final app = await _App.open(tester, google: _GoogleAccount());
        await createAccount(tester, es);
        expect(screen(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(screen(), findsNothing);
        app.server.login = (body) => _json(200, _session('${body['email']}'));
        app.server.google = (_) => _json(200, _session('bea@example.invalid'));
        if (via == 'password') {
          await tapVisible(tester, find.text(es.alreadyHaveAccount));
          await signIn(tester, address: 'bea@example.invalid');
        } else {
          await tapVisible(tester, find.byKey(const ValueKey('google-sign-in')));
        }
        expect(
          app.container.read(authProvider).account?.email,
          'bea@example.invalid',
        );
        expect(find.byType(CalendarScreen), findsOneWidget);
        unawaited(app.container.read(authProvider.notifier).signOut());
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        final saved = (await tester.runAsync(
          () => const FlutterSecureStorage().readAll(),
        ))!;
        expect(
          saved.values.where((value) => value.contains('ana@example.invalid')),
          isEmpty,
          reason: 'no address waits',
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text(es.signInHeading), findsOneWidget);
        expect(screen(), findsNothing);
        final again = await coldStart(
          tester,
          await storedWithoutSession(tester),
        );
        expect(screen(), findsNothing);
        expect(find.text(es.signInHeading), findsOneWidget);
        expect(again.server.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Run 2026-10-18-commands, round 3 (b2) · P151 (UX-1220): Back from
  // the reopened «Confirma tu correo» plays the usual transition ----

  /// How long Back takes from a plain page pushed on [navigator], as every
  /// other screen of the app is pushed.
  Future<Duration> plainBack(WidgetTester tester, NavigatorState navigator) async {
    final plain = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('plain-page')),
    );
    unawaited(navigator.push(plain));
    await tester.pumpAndSettle();
    final duration = plain.reverseTransitionDuration;
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('plain-page'), findsNothing);
    return duration;
  }

  testWidgets(
    'UX-1220: reopened after a restart, «Confirma tu correo» opens with no transition and closes with the same Back duration as a plain page on the same navigator',
    (tester) async {
      await reopenedAfter(tester, const Duration(seconds: 5));
      final route =
          ModalRoute.of(tester.element(screen()))! as TransitionRoute<dynamic>;
      expect(route.transitionDuration, Duration.zero);
      final usual = await plainBack(tester, route.navigator!);
      expect(usual, greaterThan(Duration.zero));
      expect(route.reverseTransitionDuration, usual);
      // The page class keeps no Back duration of its own.
      final source = File('lib/screens/login_screen.dart').readAsStringSync();
      expect(source, isNot(contains('reverseTransitionDuration')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1220: Back from the reopened «Confirma tu correo» returns to «Inicia sesión», and the page stays on screen while the usual Back transition runs',
    (tester) async {
      final again = await reopenedAfter(tester, const Duration(seconds: 5));
      final route =
          ModalRoute.of(tester.element(screen()))! as TransitionRoute<dynamic>;
      final usual = await plainBack(tester, route.navigator!);
      expect(screen(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      // Step through the Back transition one frame at a time.
      const frame = Duration(milliseconds: 10);
      var mounted = Duration.zero;
      while (screen().evaluate().isNotEmpty && mounted < usual * 3) {
        await tester.pump(frame);
        mounted += frame;
      }
      expect(screen(), findsNothing);
      expect(
        mounted,
        greaterThanOrEqualTo(usual - frame),
        reason: 'closing ran for $mounted; a plain page closes in $usual',
      );
      expect(mounted, lessThanOrEqualTo(usual + frame * 2));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(again.app.server.requests, isEmpty, reason: 'nothing sent');
      expect(tester.takeException(), isNull);
    },
  );
}
