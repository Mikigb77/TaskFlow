// 2026-10-18 (DECISIONS.md): a password sign-up confirms its email address
// with a 6-digit code before the first sign-in. The real ApiClient talks to
// a stand-in server; the screens are the app's own.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
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

  /// Holds the code's answer back until completed.
  Completer<void>? holdVerify;

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
        return login(body);
      case 'auth/verify-email/':
        final gate = holdVerify;
        if (gate != null) await gate.future;
        return verify(body);
      case 'auth/verify-email/resend/':
        return resend(body);
    }
    return _json(404, {'detail': 'Not found.'});
  });

  List<String> get paths => [for (final request in requests) request.path];
  List<Map<String, dynamic>> bodies(String path) => [
    for (final request in requests)
      if (request.path == path) request.body,
  ];
}

class _Google extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(supportsAnnounce: announces);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    FlutterSecureStorage.setMockInitialValues({});
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
        googleSignInServiceProvider.overrideWithValue(_Google()),
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    // Nothing is saved yet: the (mocked) secure storage says so.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
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
    expect(es.verifyEmailCodeInvalid, 'Ese código no es correcto');
    expect(
      es.verifyEmailCodeExpired,
      'Ese código ha caducado. Pide uno nuevo.',
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
    'a sign-up answered verification_required opens Confirma tu correo for the server’s address, with the code field focused; nothing is signed in or saved yet',
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
      expect(focused(tester, code), isTrue);
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
    'code_invalid says «Ese código no es correcto» under the field, read out as it appears, and keeps the digits; a changed code clears it and confirms again',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      app.server.verify = (_) =>
          _json(400, {'code': 'code_invalid', 'detail': 'Invalid code.'});
      await tester.enterText(code, '111111');
      await tester.pumpAndSettle();
      expect(errorUnder(tester, code), 'Ese código no es correcto');
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
    'code_expired says «Ese código ha caducado. Pide uno nuevo.» and Reenviar código can be tapped at once; the new code clears it, empties the field and says «Te hemos enviado un código nuevo»',
    (tester) async {
      final app = await _App.open(tester);
      await createAccount(tester, es);
      expect(waitLeft(tester, es), greaterThanOrEqualTo(59));
      expect(resendEnabled(tester), isFalse);
      app.server.verify = (_) => _json(400, {'code': 'code_expired'});
      await tester.enterText(code, '222222');
      await tester.pumpAndSettle();
      expect(
        errorUnder(tester, code),
        'Ese código ha caducado. Pide uno nuevo.',
      );
      expect(resendEnabled(tester), isTrue, reason: 'offered at once');
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
        await expectReadable(find.text(l.verifyEmailCodeExpired));
        await expectReadable(resend);
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
}
