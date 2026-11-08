// P44 (UX-423, D4d) and P92 (UX-501), round 1 of 2026-10-13-app: the Pro
// screen's buttons and the free tier's numbers.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/billing_fixtures.dart';
import 'support/button_label.dart';
import 'support/icon_button_label.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  for (final language in ['en', 'es', 'ca']) {
    testWidgets('complimentary Pro hides checkout and restore in $language', (
      tester,
    ) async {
      final sdk = FakeRevenueCat();
      final controller = SubscriptionController(
        sdk,
        const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      );
      await controller.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: noRetry,
          overrides: [
            apiClientProvider.overrideWithValue(OfflineApiClient()),
            authProvider.overrideWith(
              (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
            ),
            subscriptionProvider.overrideWith((_) => controller),
            billingConfigurationProvider.overrideWithValue(
              controller.configuration,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SubscriptionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SubscriptionScreen));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.billingStatus('active')), findsOneWidget);
      expect(find.text(l10n.billingComplimentary), findsOneWidget);
      for (final key in [
        'subscription-paywall',
        'subscription-purchase',
        'subscription-restore',
        'subscription-manage',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expect(sdk.configurations + sdk.purchases + sdk.paywalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'subscription controls fit a small phone in $language with large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = SubscriptionController(
          FakeRevenueCat(),
          const BillingConfiguration(apiKey: 'test_fixture', supported: true),
        );
        await controller.setIdentity('guest', () async => null);
        await tester.pumpWidget(
          ProviderScope(
            retry: noRetry,
            overrides: [
              apiClientProvider.overrideWithValue(OfflineApiClient()),
              subscriptionProvider.overrideWith((_) => controller),
              billingConfigurationProvider.overrideWithValue(
                controller.configuration,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: language == 'en' ? ThemeMode.light : ThemeMode.dark,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.7)),
                child: child!,
              ),
              home: const SubscriptionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final purchase = find.byKey(const ValueKey('subscription-purchase'));
        await tester.scrollUntilVisible(purchase, 250);
        await tester.pumpAndSettle();
        await tester.tap(purchase);
        await tester.pumpAndSettle();
        expect(controller.state.hasPro, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('subscription-manage')),
          200,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  // ---- P44 · UX-423 (D4d): fewer buttons; P92 · UX-501: the free tier ----

  const megabyte = 1024 * 1024;
  final resets = DateTime.utc(2026, 11);

  /// The Pro screen for a signed-in account [user], with billing in [sdk].
  Future<SubscriptionController> openPro(
    WidgetTester tester, {
    required _CountingRevenueCat sdk,
    String language = 'es',
    Map<String, dynamic> user = const {},
    Future<void> Function()? refreshAccount,
    double textScale = 1,
    ProReason? reason,
  }) async {
    final controller = SubscriptionController(
      sdk,
      const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      refreshAccount: refreshAccount,
    );
    await controller.setIdentity('owner', () async => 'owner-id');
    final api = OfflineApiClient();
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        key: UniqueKey(),
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => _UserAuth(api, user)),
          subscriptionProvider.overrideWith((_) => controller),
          billingConfigurationProvider.overrideWithValue(
            controller.configuration,
          ),
          calendarClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 20),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SubscriptionScreen(reason: reason),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  for (final (purchased, active) in [
    (true, false),
    (true, true),
    (false, false),
  ]) {
    testWidgets(
      'UX-423: the Pro screen ${active
          ? 'for an active subscriber'
          : purchased
          ? 'for someone who bought Pro before'
          : 'for someone who never bought Pro'} shows ${purchased ? 'Gestionar suscripción' : 'no Gestionar suscripción'}${active ? ', no Restaurar compras (UX-1614)' : ', Restaurar compras and Ver suscripción'}, and no Abrir suscripciones de la tienda or Actualizar estado',
      (tester) async {
        // Tall enough for every button to be built.
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final sdk = _CountingRevenueCat()
          ..info = billingInfo(active: active, purchased: purchased);
        await openPro(tester, sdk: sdk);
        final l = lookupAppLocalizations(const Locale('es'));
        Finder labelled(String text) => find.textContaining(text);
        expect(
          labelled(l.billingViewPlans),
          active ? findsNothing : findsOneWidget,
        );
        expect(
          labelled(l.billingRestore),
          active ? findsNothing : findsOneWidget,
        );
        expect(
          labelled(l.billingManage),
          purchased ? findsOneWidget : findsNothing,
        );
        expect(find.text('Abrir suscripciones de la tienda'), findsNothing);
        expect(find.text('Actualizar estado'), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('UX-423: opening the Pro screen asks for a status refresh', (
    tester,
  ) async {
    final sdk = _CountingRevenueCat();
    var accountRefreshes = 0;
    await openPro(
      tester,
      sdk: sdk,
      refreshAccount: () async => accountRefreshes++,
    );
    expect(accountRefreshes, 1);
    expect(sdk.infoReads, 1, reason: 'the store status is read on opening');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-501: a free account’s Pro screen shows the dictations left with the reset date and the file space used ($language, 2× text at 320 dp); a Pro account shows neither',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = lookupAppLocalizations(Locale(language));
        final user = {
          'free_voice': {
            'limit': 10,
            'left': 4,
            'resets_at': resets.toIso8601String(),
          },
          'storage': {
            'used_bytes': 42 * megabyte,
            'limit_bytes': 100 * megabyte,
          },
        };
        await openPro(
          tester,
          sdk: _CountingRevenueCat(),
          language: language,
          user: user,
          textScale: 2,
        );
        final date = tester
            .element(find.byType(SubscriptionScreen))
            .shortDate(resets.toLocal());
        final dictations = find.text(l.freeVoiceStatus(4, 10, date));
        final files = find.text(l.storageUsage(42, 100));
        expect(dictations, findsOneWidget);
        expect(files, findsOneWidget);
        for (final line in [dictations, files]) {
          final rect = tester.getRect(line);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320.5));
        }
        expect(tester.takeException(), isNull);

        await openPro(
          tester,
          sdk: _CountingRevenueCat()..info = billingInfo(active: true),
          language: language,
          user: user,
        );
        expect(find.text(l.freeVoiceStatus(4, 10, date)), findsNothing);
        expect(find.text(l.storageUsage(42, 100)), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  // ---- 2026-11-08: uploads count for life, so a full allowance has no files list ----

  testWidgets(
    'A free account’s Pro screen at 200 of 200 MB shows «Archivos subidos: 200 de 200 MB» and no button to remove files; with Pro, no usage line',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final es = lookupAppLocalizations(const Locale('es'));
      Map<String, dynamic> used(int mb) => {
        'storage': {'used_bytes': mb * megabyte, 'limit_bytes': 200 * megabyte},
      };
      await openPro(tester, sdk: _CountingRevenueCat(), user: used(200));
      expect(es.storageUsage(200, 200), 'Archivos subidos: 200\u00a0de 200\u00a0MB');
      expect(find.text(es.storageUsage(200, 200)), findsOneWidget);
      expect(find.textContaining('tareas con archivos'), findsNothing);
      expect(tester.takeException(), isNull);

      await openPro(
        tester,
        sdk: _CountingRevenueCat()..info = billingInfo(active: true),
        user: used(200),
      );
      expect(find.text(es.storageUsage(200, 200)), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'UX-501: freeVoiceStatus has a singular and a plural in EN, ES and CA',
    () {
      for (final language in ['en', 'es', 'ca']) {
        final l = lookupAppLocalizations(Locale(language));
        final one = l.freeVoiceStatus(1, 10, 'D');
        final four = l.freeVoiceStatus(4, 10, 'D');
        for (final text in [one, four]) {
          expect(text, contains('10'));
          expect(text, contains('D'));
        }
        expect(one, contains('1'));
        expect(four, contains('4'));
      }
      final es = lookupAppLocalizations(const Locale('es'));
      expect(es.freeVoiceStatus(1, 10, 'D'), contains('te queda 1'));
      expect(es.freeVoiceStatus(4, 10, 'D'), contains('te quedan 4'));
    },
  );

  test('UX-501: billingTestMode no longer says Pro unlocks voice capture, and the removed keys are gone from the three ARB files', () {
    for (final (language, voice) in [
      ('en', 'voice'),
      ('es', 'voz'),
      ('ca', 'veu'),
    ]) {
      final arb = jsonDecode(
        File('lib/l10n/app_$language.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final testMode = (arb['billingTestMode'] as String).toLowerCase();
      expect(testMode, isNot(contains(voice)), reason: language);
      for (final key in [
        'voiceAccessUnavailable',
        'voiceProRequired',
        'billingOpenStore',
        'billingRefresh',
      ]) {
        expect(arb.containsKey(key), isFalse, reason: '$language: $key');
      }
    }
  });

  // ---- Round 2 · P96 · UX-509: billing messages point to what exists ----

  test('UX-509: no billing message tells people to refresh: accountUnavailable, network and awaitingEntitlement in EN, ES and CA, and nothing in EN’s billingError or billingResult', () {
    // `No se pudo actualizar` / `Estado … actualizado` (update, updated) in
    // branches the plan keeps as they are are not a request to refresh.
    for (final language in ['en', 'es', 'ca']) {
      final l = lookupAppLocalizations(Locale(language));
      for (final text in [
        l.billingError('accountUnavailable'),
        l.billingError('network'),
        l.billingResult('awaitingEntitlement'),
      ]) {
        for (final word in ['refresh', 'actualiza', 'actualitza']) {
          expect(text.toLowerCase(), isNot(contains(word)), reason: text);
        }
      }
    }
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final key in ['billingError', 'billingResult']) {
      expect(
        (arb[key] as String).toLowerCase(),
        isNot(contains('refresh')),
        reason: key,
      );
    }
  });

  test('UX-509: billingError for accountUnavailable and network, and billingResult for awaitingEntitlement, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      es.billingError('network'),
      'No se pudo comprobar tu suscripción. Revisa tu conexión y vuelve a abrir esta pantalla.',
    );
    expect(
      en.billingError('network'),
      'Could not check your subscription. Check your connection and open this screen again.',
    );
    expect(
      ca.billingError('network'),
      'No s’ha pogut comprovar la subscripció. Revisa la connexió i torna a obrir aquesta pantalla.',
    );
    expect(
      es.billingError('accountUnavailable'),
      'No se pudo conectar con tu cuenta de TaskFlow. Revisa tu conexión y vuelve a abrir esta pantalla.',
    );
    expect(
      en.billingError('accountUnavailable'),
      'Could not connect to your TaskFlow account. Check your connection and open this screen again.',
    );
    expect(
      ca.billingError('accountUnavailable'),
      'No s’ha pogut connectar amb el teu compte de TaskFlow. Revisa la connexió i torna a obrir aquesta pantalla.',
    );
    // awaitingEntitlement names the restore button, as it reads.
    for (final (l, restore) in [
      (en, 'Restore purchases'),
      (es, 'Restaurar compras'),
      (ca, 'Restaura les compres'),
    ]) {
      expect(l.billingRestore, restore);
      expect(
        l.billingResult('awaitingEntitlement'),
        contains(restore),
        reason: l.localeName,
      );
    }
  });

  test('UX-514: billingError accountUnavailable names no server in EN, ES or CA, and still says to open the screen again', () {
    for (final (language, again) in [
      ('en', 'open this screen again'),
      ('es', 'vuelve a abrir esta pantalla'),
      ('ca', 'torna a obrir aquesta pantalla'),
    ]) {
      final message = lookupAppLocalizations(Locale(language))
          .billingError('accountUnavailable');
      expect(
        message.toLowerCase(),
        isNot(matches(RegExp('server|servidor'))),
        reason: '$language: $message',
      );
      expect(message, contains(again), reason: language);
    }
  });

  testWidgets(
    'UX-509: the Pro screen in Spanish with a network billing error says to check the connection and open the screen again',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sdk = _CountingRevenueCat()
        ..infoError = PlatformException(
          code: '${PurchasesErrorCode.offlineConnectionError.index}',
        );
      final controller = await openPro(tester, sdk: sdk);
      expect(controller.state.issue, BillingIssue.network);
      final es = lookupAppLocalizations(const Locale('es'));
      final error = find.byKey(const ValueKey('subscription-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, es.billingError('network'));
      expect(
        find.text(
          'No se pudo comprobar tu suscripción. Revisa tu conexión y vuelve a abrir esta pantalla.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('actualiza'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  // ---- Run 2026-10-19-app · P189 (UX-1613, UX-1614): what Pro gives, buttons apart ----

  final freeUser = {
    'free_voice': {
      'limit': 10,
      'left': 4,
      'resets_at': resets.toIso8601String(),
    },
    'storage': {'used_bytes': 42 * megabyte, 'limit_bytes': 100 * megabyte},
  };

  test('UX-1613 / UX-1614: the Pro copy reads as planned in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      en.proBenefitDictation,
      'Unlimited dictation, and 500\u00a0MB of files a month',
    );
    expect(
      es.proBenefitDictation,
      'Dictados sin límite y 500\u00a0MB de archivos al mes',
    );
    expect(
      ca.proBenefitDictation,
      'Dictats sense límit i 500\u00a0MB de fitxers al mes',
    );
    for (final reason in ['store', 'other']) {
      expect(
        en.billingError(reason),
        'The store didn’t answer. Open this screen again.',
      );
      expect(
        es.billingError(reason),
        'La tienda no respondió. Vuelve a abrir esta pantalla.',
      );
      expect(
        ca.billingError(reason),
        'La botiga no ha respost. Torna a obrir aquesta pantalla.',
      );
    }
  });

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1613: $language at 2× on 360×800, a free account sees what Pro gives and Ver suscripción without scrolling, and no second TaskFlow Pro heading or sparkle in the card',
      (tester) async {
        // A fit: measured in the app's own font (P312 put the plan first).
        await loadManrope();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l = lookupAppLocalizations(Locale(language));
        await openPro(
          tester,
          sdk: _CountingRevenueCat(),
          language: language,
          user: freeUser,
          textScale: 2,
        );
        final body = find.byType(ListView);
        final viewport = tester.getRect(body);
        final intro = find.text(l.proBenefitDictation);
        expect(intro, findsOneWidget);
        final introRect = tester.getRect(intro);
        expect(introRect.top, greaterThanOrEqualTo(viewport.top));
        expect(introRect.bottom, lessThanOrEqualTo(viewport.bottom));
        final offer = find.byKey(const ValueKey('subscription-paywall'));
        expect(offer, findsOneWidget);
        expect(
          find.descendant(of: offer, matching: find.text(l.billingViewPlans)),
          findsOneWidget,
        );
        // Pinned under the list, not inside it.
        expect(find.descendant(of: body, matching: offer), findsNothing);
        final offerRect = tester.getRect(offer);
        expect(offerRect.top, greaterThanOrEqualTo(0));
        expect(offerRect.bottom, lessThanOrEqualTo(800));
        expect(tester.widget<FilledButton>(offer).onPressed, isNotNull);
        // The app bar says «TaskFlow Pro»; the card doesn't again.
        expect(
          find.descendant(of: body, matching: find.text(l.taskflowPro)),
          findsNothing,
        );
        for (final sparkle in [
          Icons.auto_awesome,
          Icons.auto_awesome_outlined,
          Icons.auto_awesome_rounded,
        ]) {
          expect(
            find.descendant(of: body, matching: find.byIcon(sparkle)),
            findsNothing,
          );
        }
        expect(find.text('Tu suscripción, en un solo lugar.'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'UX-1614: a free account’s Pro screen keeps at least 8 dp between adjacent buttons, scrolled to the top and to the end',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPro(
        tester,
        sdk: _CountingRevenueCat()..info = billingInfo(purchased: true),
        user: freeUser,
      );
      // [at]: how many buttons are on screen at least.
      void expectApart(String where, {required int at}) {
        final buttons =
            tester
                .widgetList(
                  find.byWidgetPredicate((w) => w is ButtonStyleButton),
                )
                .map((w) => tester.getRect(find.byWidget(w)))
                .where((r) => r.bottom > 0 && r.top < 800)
                .toList()
              ..sort((a, b) => a.top.compareTo(b.top));
        expect(buttons.length, greaterThanOrEqualTo(at), reason: where);
        for (var i = 1; i < buttons.length; i++) {
          final above = buttons[i - 1], below = buttons[i];
          final sideBySide =
              below.top < above.bottom && below.left >= above.right;
          if (sideBySide) continue;
          expect(
            below.top - above.bottom,
            greaterThanOrEqualTo(8),
            reason: '$where: buttons $above and $below',
          );
        }
      }

      expectApart('top', at: 1);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expectApart('end', at: 3);
      // «Restaurar compras» stays in the list, apart from the pinned button.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(const ValueKey('subscription-restore')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'UX-1614: while Pro is active, Gestionar suscripción stands alone: no Restaurar compras and no restore help',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l = lookupAppLocalizations(const Locale('es'));
      await openPro(
        tester,
        sdk: _CountingRevenueCat()..info = billingInfo(active: true),
      );
      expect(find.byKey(const ValueKey('subscription-restore')), findsNothing);
      expect(find.textContaining(l.billingRestore), findsNothing);
      expect(find.text(l.billingRestoreHelp), findsNothing);
      final manage = find.byKey(const ValueKey('subscription-manage'));
      await tester.scrollUntilVisible(manage, 200);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: manage, matching: find.text(l.billingManage)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('subscription-paywall')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'UX-1614: when the store fails, the line reads La tienda no respondió. Vuelve a abrir esta pantalla.',
    (tester) async {
      final l = lookupAppLocalizations(const Locale('es'));
      await openPro(
        tester,
        sdk: _CountingRevenueCat()
          ..offeringsError = PlatformException(
            code: '${PurchasesErrorCode.storeProblemError.index}',
          ),
        user: freeUser,
      );
      final error = find.byKey(const ValueKey('subscription-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, l.billingError('store'));
      expect(
        tester.widget<Text>(error).data,
        'La tienda no respondió. Vuelve a abrir esta pantalla.',
      );
      expect(
        find.text(
          'La tienda no pudo completar la solicitud. Inténtalo de nuevo.',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  // ---- UX loop 2026-10-28-app, round 1 · P289 (UX-2608, UX-2108) ----
  group('P289 · padded, centred filled buttons', () {
    for (final language in ['ca', 'es']) {
      testWidgets(
        'UX-2608 / UX-2108: $language at 2× on 360×800 (settings/pro.free.$language.light.2x), «Ver suscripción» is at least 58 dp tall, its wrapped lines centred with at least 8 dp above and below',
        (tester) async {
          await loadManrope();
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final l = lookupAppLocalizations(Locale(language));
          await openPro(
            tester,
            sdk: _CountingRevenueCat(),
            language: language,
            user: freeUser,
            textScale: 2,
          );
          final offer = find.byKey(const ValueKey('subscription-paywall'));
          expect(
            tester.getRect(offer).height,
            greaterThanOrEqualTo(58),
            reason: 'the filled button is at least 58 dp tall',
          );
          // «Mostra la subscripció» wraps in the render; the Spanish may
          // not, and is held to the same centring and room when it does.
          expectCentredPaddedLabel(
            tester,
            offer,
            l.billingViewPlans,
            wraps: language == 'ca',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });

  // ---- UX loop 2026-10-28-app, round 2 · P304 (UX-2630) ----
  group('P304 · icon buttons centre their wrapped labels', () {
    for (final language in ['ca', 'es']) {
      testWidgets(
        'UX-2630: $language at 2× on 360×800 (settings/pro.free.$language.light.2x), the sparkle sits beside «${lookupAppLocalizations(Locale(language)).billingViewPlans}»’s longest line, and icon and label are centred in the button',
        (tester) async {
          await loadManrope();
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final l = lookupAppLocalizations(Locale(language));
          await openPro(
            tester,
            sdk: _CountingRevenueCat(),
            language: language,
            user: freeUser,
            textScale: 2,
          );
          final offer = find.byKey(const ValueKey('subscription-paywall'));
          if (language == 'ca') {
            expect(
              labelLines(tester, offer, l.billingViewPlans).length,
              greaterThanOrEqualTo(2),
              reason: 'the Catalan wraps here, as in the render',
            );
          }
          expectIconBesideCentredLabel(tester, offer, l.billingViewPlans);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });

  // ---- UX loop 2026-10-28-app, round 1 · P290 (UX-2603, UX-2607) ----
  group('P290 · what Pro gives, and the Pro screen’s copy', () {
    test('UX-2603: the three lines read as planned in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        [en.proBenefitDictation, en.proBenefitTyping, en.proBenefitReminders],
        [
          'Unlimited dictation, and 500\u00a0MB of files a month',
          'Sentences you type become tasks',
          'Ask for reminders in your own words',
        ],
      );
      expect(
        [es.proBenefitDictation, es.proBenefitTyping, es.proBenefitReminders],
        [
          'Dictados sin límite y 500\u00a0MB de archivos al mes',
          'Tus frases escritas se convierten en tareas',
          'Pide los recordatorios con tus palabras',
        ],
      );
      expect(
        [ca.proBenefitDictation, ca.proBenefitTyping, ca.proBenefitReminders],
        [
          'Dictats sense límit i 500\u00a0MB de fitxers al mes',
          'Les frases que escrius es converteixen en tasques',
          'Demana els recordatoris amb les teves paraules',
        ],
      );
    });

    for (final (language, scale) in [('es', 1.0), ('es', 2.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2603: settings/pro.free, $language at ${scale.toInt()}× on 360×800: three lines, each whole and on its own row, in that order; the old one-sentence intro is gone',
        (tester) async {
          await loadManrope();
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final l = lookupAppLocalizations(Locale(language));
          await openPro(
            tester,
            sdk: _CountingRevenueCat(),
            language: language,
            user: freeUser,
            textScale: scale,
          );
          final lines = [
            l.proBenefitDictation,
            l.proBenefitTyping,
            l.proBenefitReminders,
          ];
          // In that order, one under the other, before any scrolling.
          for (var i = 1; i < lines.length; i++) {
            expect(
              tester.getRect(find.text(lines[i])).top,
              greaterThanOrEqualTo(
                tester.getRect(find.text(lines[i - 1])).bottom,
              ),
              reason: '«${lines[i]}» under «${lines[i - 1]}»',
            );
          }
          for (final line in lines) {
            final text = find.text(line);
            expect(text, findsOneWidget, reason: line);
            await tester.ensureVisible(text);
            await tester.pumpAndSettle();
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(0), reason: line);
            expect(rect.right, lessThanOrEqualTo(360.5), reason: line);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: line);
            expect(
              paragraph.text.toPlainText(),
              line,
              reason: 'drawn whole, with no ellipsis',
            );
          }
          for (final old in [
            'Dictados sin límite y espacio para todos tus archivos.',
            'Dictats sense límit i espai per a tots els fitxers.',
          ]) {
            expect(find.text(old), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'UX-2603: reminders/sheet.pro-screen, opened from «A tu manera» (ES 1×): the list has the first two lines only',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final es = lookupAppLocalizations(const Locale('es'));
        await openPro(
          tester,
          sdk: _CountingRevenueCat(),
          user: freeUser,
          reason: ProReason.reminderPlans,
        );
        expect(
          find.byKey(const ValueKey('subscription-reason')),
          findsOneWidget,
        );
        expect(find.text(es.proBenefitDictation), findsOneWidget);
        expect(find.text(es.proBenefitTyping), findsOneWidget);
        expect(find.text(es.proBenefitReminders), findsNothing);
        expect(
          tester.getRect(find.text(es.proBenefitTyping)).top,
          greaterThan(tester.getRect(find.text(es.proBenefitDictation)).top),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    test('UX-2607: the Spanish Pro copy: «El {date} tendrás más.», «las condiciones de cualquier prueba»; the file line binds its numbers to their words in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        es.freeVoiceStatus(4, 10, '1 nov'),
        'Dictados gratis: te quedan 4 de 10 este mes. El 1 nov tendrás más.',
      );
      expect(
        es.freeVoiceStatus(1, 10, '1 nov'),
        'Dictados gratis: te queda 1 de 10 este mes. El 1 nov tendrás más.',
      );
      expect(
        es.billingRenewalHelp,
        'Se renueva automáticamente cada mes hasta que la canceles. Revisa el precio final y las condiciones de cualquier prueba antes de confirmar.',
      );
      expect(es.storageUsage(42, 100), 'Archivos subidos: 42\u00a0de 100\u00a0MB');
      expect(en.storageUsage(42, 100), 'Files uploaded: 42\u00a0of 100\u00a0MB');
      expect(ca.storageUsage(42, 100), 'Fitxers pujats: 42\u00a0de 100\u00a0MB');
    });

    testWidgets(
      'UX-2607: the Pro screen in Spanish reads «Dictados gratis: te quedan 4 de 10 este mes. El {date} tendrás más.» with the reset date as it shows it, and «…las condiciones de cualquier prueba antes de confirmar.»',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final es = lookupAppLocalizations(const Locale('es'));
        await openPro(tester, sdk: _CountingRevenueCat(), user: freeUser);
        final date = tester
            .element(find.byType(SubscriptionScreen))
            .shortDate(resets.toLocal());
        expect(
          find.text(
            'Dictados gratis: te quedan 4 de 10 este mes. El $date tendrás más.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('. Más el '), findsNothing);
        final renewal = find.text(es.billingRenewalHelp);
        await tester.scrollUntilVisible(renewal, 200);
        expect(renewal, findsOneWidget);
        expect(
          es.billingRenewalHelp,
          endsWith('las condiciones de cualquier prueba antes de confirmar.'),
        );
        expect(find.textContaining('condiciones de prueba'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX-2607: settings/pro.free.es.light.2x, «100 MB» stays on one line, and «42 de» too',
      (tester) async {
        await loadManrope();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final es = lookupAppLocalizations(const Locale('es'));
        await openPro(
          tester,
          sdk: _CountingRevenueCat(),
          user: freeUser,
          textScale: 2,
        );
        final usage = find.text(es.storageUsage(42, 100));
        expect(usage, findsOneWidget);
        await tester.ensureVisible(usage);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: usage, matching: find.byType(RichText)),
        );
        final drawn = paragraph.text.toPlainText();
        for (final bound in ['100 MB', '42 de']) {
          final start = drawn.indexOf(bound);
          expect(start, greaterThanOrEqualTo(0), reason: bound);
          final tops = {
            for (var i = start; i < start + bound.length; i++)
              for (final box in paragraph.getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1),
              ))
                box.top.round(),
          };
          expect(tops, hasLength(1), reason: '«$bound» on one line');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 2 · P312 (UX-2640): the Pro screen
  // shows your plan first; its checks stay 20 dp ----
  group('P312 · plan first', () {
    final status = find.byKey(const ValueKey('subscription-status'));
    final offer = find.byKey(const ValueKey('subscription-paywall'));
    List<String> benefits(AppLocalizations l) => [
      l.proBenefitDictation,
      l.proBenefitTyping,
      l.proBenefitReminders,
    ];

    /// The free dictations line, with the reset date as the screen shows it.
    String voiceLine(WidgetTester tester, AppLocalizations l) =>
        l.freeVoiceStatus(
          4,
          10,
          tester
              .element(find.byType(SubscriptionScreen))
              .shortDate(resets.toLocal()),
        );

    Future<void> openFree(
      WidgetTester tester,
      String language,
      double scale, {
      ProReason? reason,
    }) async {
      await loadManrope();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPro(
        tester,
        sdk: _CountingRevenueCat(),
        language: language,
        user: freeUser,
        textScale: scale,
        reason: reason,
      );
    }

    double top(WidgetTester tester, Finder finder) =>
        tester.getRect(finder).top;

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-2640: a free account with 4 dictations left, $language 2× on 360×800: the status and the whole free dictations line are in view above the pinned «Ver suscripción» with no scrolling, and so is the first benefit line',
        (tester) async {
          await openFree(tester, language, 2);
          final l = lookupAppLocalizations(Locale(language));
          expect(
            l.billingStatus('inactive'),
            language == 'es'
                ? 'No hay una suscripción Pro activa'
                : 'No hi ha cap subscripció Pro activa',
          );
          final body = find.byType(ListView);
          expect(
            tester
                .state<ScrollableState>(
                  find.descendant(of: body, matching: find.byType(Scrollable)),
                )
                .position
                .pixels,
            0,
            reason: 'nothing scrolled',
          );
          final viewport = tester.getRect(body);
          final pinned = tester.getRect(offer);
          final line = voiceLine(tester, l);
          expect(
            line,
            startsWith(language == 'es' ? 'Dictados gratis' : 'Dictats grat'),
          );
          for (final (name, finder) in [
            ('status', status),
            ('free dictations line', find.text(line)),
            ('first benefit', find.text(l.proBenefitDictation)),
          ]) {
            expect(finder, findsOneWidget, reason: name);
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: name);
            expect(
              rect.bottom,
              lessThanOrEqualTo(viewport.bottom),
              reason: '$name whole in view: $rect, list $viewport',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(pinned.top),
              reason: '$name above «Ver suscripción»',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    for (final (language, scale) in [('es', 1.0), ('es', 2.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2640: $language ${scale.toInt()}×: every benefit’s check is 20 × 20 dp, its centre within 4 dp of its text’s first line',
        (tester) async {
          await openFree(tester, language, scale);
          final l = lookupAppLocalizations(Locale(language));
          for (final benefit in benefits(l)) {
            final text = find.text(benefit);
            expect(text, findsOneWidget, reason: benefit);
            final row = find
                .ancestor(of: text, matching: find.byType(Row))
                .first;
            final check = find.descendant(
              of: row,
              matching: find.byIcon(Icons.check_rounded),
            );
            expect(check, findsOneWidget, reason: benefit);
            final icon = tester.getRect(check);
            expect(icon.width, closeTo(20, 0.5), reason: benefit);
            expect(icon.height, closeTo(20, 0.5), reason: benefit);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)),
            );
            final first = paragraph
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                  boxHeightStyle: ui.BoxHeightStyle.max,
                )
                .first;
            final lineCentre = paragraph
                .localToGlobal(Offset(0, (first.top + first.bottom) / 2))
                .dy;
            expect(
              (icon.center.dy - lineCentre).abs(),
              lessThanOrEqualTo(4),
              reason:
                  '$benefit: check at ${icon.center.dy}, line at $lineCentre',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'UX-2640: a free account, ES 1×: top to bottom, the status, «Dictados gratis: …», then the three benefit lines; the file space line follows them (the brief’s fallback for CA 2×)',
      (tester) async {
        await openFree(tester, 'es', 1);
        final l = lookupAppLocalizations(const Locale('es'));
        final order = [
          status,
          find.text(voiceLine(tester, l)),
          for (final benefit in benefits(l)) find.text(benefit),
          find.text(l.storageUsage(42, 100)),
        ];
        for (var i = 1; i < order.length; i++) {
          expect(order[i], findsOneWidget);
          expect(
            top(tester, order[i]),
            greaterThan(top(tester, order[i - 1])),
            reason: '${order[i]} under ${order[i - 1]}',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX-2640: why the file space line follows the benefits: at CA 2× on 360×800, put above them it would push the first benefit line under the pinned «Ver suscripción»',
      (tester) async {
        await openFree(tester, 'ca', 2);
        final l = lookupAppLocalizations(const Locale('ca'));
        final benefit = tester.getRect(find.text(l.proBenefitDictation));
        final storage = tester.getRect(find.text(l.storageUsage(42, 100)));
        final pinned = tester.getRect(offer);
        // The line and the 20 dp before it, moved above the benefits.
        expect(
          benefit.bottom + storage.height + 20,
          greaterThan(pinned.top),
          reason:
              'benefit ends at ${benefit.bottom}, the line takes ${storage.height + 20}, «Ver suscripción» starts at ${pinned.top}',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX-2640: opened from «A tu manera» (ES 1×): the reason heading and its example first, then the status, then only the first two benefit lines',
      (tester) async {
        await openFree(tester, 'es', 1, reason: ProReason.reminderPlans);
        final l = lookupAppLocalizations(const Locale('es'));
        final order = [
          find.byKey(const ValueKey('subscription-reason')),
          find.byKey(const ValueKey('subscription-reason-example')),
          status,
          find.text(l.proBenefitDictation),
          find.text(l.proBenefitTyping),
        ];
        for (var i = 1; i < order.length; i++) {
          expect(order[i], findsOneWidget);
          expect(
            top(tester, order[i]),
            greaterThan(top(tester, order[i - 1])),
            reason: '${order[i]} under ${order[i - 1]}',
          );
        }
        expect(find.text(l.proBenefitReminders), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX-2640: a Pro account (ES 1×): «Pro está activo» and its renewal date come before the benefit lines',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final sdk = _CountingRevenueCat()..info = billingInfo(active: true);
        await openPro(tester, sdk: sdk);
        final l = lookupAppLocalizations(const Locale('es'));
        expect(tester.widget<Text>(status).data, l.billingStatus('active'));
        expect(l.billingStatus('active'), 'Pro está activo');
        final date = MaterialLocalizations.of(
          tester.element(find.byType(SubscriptionScreen)),
        ).formatMediumDate(DateTime.parse('2026-10-29T00:00:00Z').toLocal());
        final renewal = find.text(l.billingUntil('renews', date));
        expect(renewal, findsOneWidget);
        expect(top(tester, renewal), greaterThan(top(tester, status)));
        for (final benefit in benefits(l)) {
          expect(
            top(tester, find.text(benefit)),
            greaterThan(top(tester, renewal)),
            reason: '«$benefit» after the renewal date',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  // ---- UX loop 2026-11-03-screens, round 1 · P326 (UX-2807, UX-2809): the
  // Pro screen for meetings: one heading for both ways in, meeting notes as
  // a benefit ----
  group('P326 · the Pro screen for meetings', () {
    final heading = find.byKey(const ValueKey('subscription-reason'));
    final example = find.byKey(const ValueKey('subscription-reason-example'));
    final status = find.byKey(const ValueKey('subscription-status'));
    final offer = find.byKey(const ValueKey('subscription-paywall'));

    Future<void> openFree(
      WidgetTester tester,
      String language,
      double scale, {
      ProReason? reason,
    }) async {
      await loadManrope();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPro(
        tester,
        sdk: _CountingRevenueCat(),
        language: language,
        user: freeUser,
        textScale: scale,
        reason: reason,
      );
    }

    /// [finder]'s text is drawn whole: inside 360 dp, no ellipsis or cut.
    void expectWhole(WidgetTester tester, Finder finder, String text) {
      expect(finder, findsOneWidget, reason: text);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: text);
      expect(rect.right, lessThanOrEqualTo(360.5), reason: text);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      expect(paragraph.text.toPlainText(), text, reason: 'drawn whole');
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
        ),
        reason: '$text: not clipped',
      );
    }

    test('UX-2807, UX-2809: the copy in EN, ES and CA: one heading for both ways in, the to-dos example, and the new benefit line', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        [
          es.billingReasonMeetingNotes,
          es.billingReasonMeetingNotesExample,
          es.proBenefitMeetingNotes(20),
        ],
        [
          'Con Pro, tus reuniones se convierten en notas:',
          'un resumen, las decisiones y las cosas por hacer',
          'Notas de las reuniones que grabas, hasta 20 horas al mes',
        ],
      );
      expect(
        [
          en.billingReasonMeetingNotes,
          en.billingReasonMeetingNotesExample,
          en.proBenefitMeetingNotes(20),
        ],
        [
          'With Pro, your meetings become notes:',
          'a summary, the decisions and the to-dos',
          'Notes from your recorded meetings, up to 20 hours a month',
        ],
      );
      expect(
        [
          ca.billingReasonMeetingNotes,
          ca.billingReasonMeetingNotesExample,
          ca.proBenefitMeetingNotes(20),
        ],
        [
          'Amb Pro, les teves reunions es converteixen en notes:',
          'un resum, les decisions i les coses per fer',
          'Notes de les reunions que enregistres, fins a 20 hores al mes',
        ],
      );
      // It never asks to record a meeting already recorded, and the notes
      // give to-dos, not tasks.
      for (final l in [en, es, ca]) {
        expect(
          l.billingReasonMeetingNotes.toLowerCase(),
          isNot(
            anyOf(
              contains('graba'),
              contains('record a'),
              contains('enregistra'),
            ),
          ),
        );
      }
      expect(es.billingReasonMeetingNotesExample, isNot(contains('tareas')));
      expect(ca.billingReasonMeetingNotesExample, isNot(contains('tasques')));
    });

    testWidgets(
      'UX-2807: reason meetingNotes, ES 1× with the priced store: the reason box reads «Con Pro, tus reuniones se convierten en notas:» then «un resumen, las decisiones y las cosas por hacer», then the plan, with the price and the pinned «Ver suscripción»',
      (tester) async {
        await openFree(tester, 'es', 1, reason: ProReason.meetingNotes);
        final l = lookupAppLocalizations(const Locale('es'));
        expect(tester.widget<Text>(heading).data, l.billingReasonMeetingNotes);
        expect(
          tester.widget<Text>(example).data,
          l.billingReasonMeetingNotesExample,
        );
        final order = [heading, example, status];
        for (var i = 1; i < order.length; i++) {
          expect(
            tester.getRect(order[i]).top,
            greaterThanOrEqualTo(tester.getRect(order[i - 1]).bottom),
            reason: '${order[i]} under ${order[i - 1]}',
          );
        }
        // Read as a heading.
        final node = tester.getSemantics(heading).getSemanticsData();
        expect(node.label, l.billingReasonMeetingNotes);
        expect(node.flagsCollection.isHeader, isTrue);
        // Under the benefits, a scroll away since the month's meeting time
        // joined the reason (D4).
        await tester.scrollUntilVisible(
          find.text(l.billingMonthlyPrice('€4.99')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l.billingMonthlyPrice('€4.99')), findsOneWidget);
        expect(offer, findsOneWidget);
        expect(find.byKey(const ValueKey('subscription-error')), findsNothing);
        expect(find.text(l.billingStatus('unknown')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'UX-2807: reason meetingNotes, CA 2× on 360×800: «Amb Pro, les teves reunions es converteixen en notes:» and its example, nothing cut',
      (tester) async {
        await openFree(tester, 'ca', 2, reason: ProReason.meetingNotes);
        final l = lookupAppLocalizations(const Locale('ca'));
        expectWhole(tester, heading, l.billingReasonMeetingNotes);
        expectWhole(tester, example, l.billingReasonMeetingNotesExample);
        expect(
          tester.getRect(example).top,
          greaterThanOrEqualTo(tester.getRect(heading).bottom),
        );
        // Both in view above the pinned «Ver suscripción», before scrolling.
        for (final finder in [heading, example]) {
          expect(
            tester.getRect(finder).bottom,
            lessThanOrEqualTo(tester.getRect(offer).top),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final (language, scale) in [('es', 1.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2809: from Ajustes (no reason), $language ${scale.toInt()}× on 360×800: the benefits include «Notas de las reuniones que grabas», last and whole; the first benefit is still above the pinned «Ver suscripción»',
        (tester) async {
          await openFree(tester, language, scale);
          final l = lookupAppLocalizations(Locale(language));
          final lines = [
            l.proBenefitDictation,
            l.proBenefitTyping,
            l.proBenefitReminders,
            l.proBenefitMeetingNotes(20),
          ];
          // The first benefit in view above «Ver suscripción», unscrolled
          // (UX-2640).
          final first = tester.getRect(find.text(l.proBenefitDictation));
          expect(
            first.bottom,
            lessThanOrEqualTo(tester.getRect(offer).top),
            reason: 'first benefit above «Ver suscripción»',
          );
          expect(first.top, greaterThanOrEqualTo(0));
          for (var i = 1; i < lines.length; i++) {
            expect(
              tester.getRect(find.text(lines[i])).top,
              greaterThanOrEqualTo(
                tester.getRect(find.text(lines[i - 1])).bottom,
              ),
              reason: '«${lines[i]}» under «${lines[i - 1]}»',
            );
          }
          final meeting = find.text(l.proBenefitMeetingNotes(20));
          await tester.ensureVisible(meeting);
          await tester.pumpAndSettle();
          expectWhole(tester, meeting, l.proBenefitMeetingNotes(20));
          // With its own check, as every benefit.
          final row = find
              .ancestor(of: meeting, matching: find.byType(Row))
              .first;
          expect(
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsOneWidget,
          );
          // The file space line still follows the benefits.
          expect(
            tester.getRect(find.text(l.storageUsage(42, 100))).top,
            greaterThan(tester.getRect(meeting).top),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'UX-2809: with reason meetingNotes the meeting line is hidden; with reminderPlans the reminders line is hidden as before and the meeting line shows (ES 1×)',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        await openFree(tester, 'es', 1, reason: ProReason.meetingNotes);
        expect(find.text(l.proBenefitMeetingNotes(20)), findsNothing);
        // D4: the month's meeting time is said up front, under the example.
        expect(
          find.text('Hasta 20 horas de reuniones al mes.'),
          findsOneWidget,
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('subscription-meeting-limit')))
              .top,
          greaterThanOrEqualTo(
            tester
                .getRect(
                  find.byKey(const ValueKey('subscription-reason-example')),
                )
                .bottom,
          ),
        );
        for (final line in [
          l.proBenefitDictation,
          l.proBenefitTyping,
          l.proBenefitReminders,
        ]) {
          expect(find.text(line), findsOneWidget, reason: line);
        }
        await tester.pumpWidget(const SizedBox());

        await openFree(tester, 'es', 1, reason: ProReason.reminderPlans);
        expect(find.text(l.proBenefitReminders), findsNothing);
        expect(
          find.byKey(const ValueKey('subscription-meeting-limit')),
          findsNothing,
        );
        expect(
          find.text('Notas de las reuniones que grabas, hasta 20 horas al mes'),
          findsOneWidget,
        );
        for (final line in [
          l.proBenefitDictation,
          l.proBenefitTyping,
          l.proBenefitMeetingNotes(20),
        ]) {
          expect(find.text(line), findsOneWidget, reason: line);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('P330 · the meeting hours set apart, and as a plural', () {
    final heading = find.byKey(const ValueKey('subscription-reason'));
    final example = find.byKey(const ValueKey('subscription-reason-example'));
    final limit = find.byKey(const ValueKey('subscription-meeting-limit'));

    for (final (language, scale) in [('es', 1.0), ('es', 2.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-3001: reason meetingNotes, $language ${scale.toInt()}× on 360×800 (meetings/pro.reason.$language.light.${scale.toInt()}x): «${language == 'es' ? 'Hasta 20 horas de reuniones al mes.' : 'Fins a 20 hores de reunions al mes.'}» sits at least 8 dp under the example, and the heading → example gap stays 4 dp',
        (tester) async {
          await loadManrope();
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await openPro(
            tester,
            sdk: _CountingRevenueCat(),
            language: language,
            user: freeUser,
            textScale: scale,
            reason: ProReason.meetingNotes,
          );
          final l = lookupAppLocalizations(Locale(language));
          expect(tester.widget<Text>(heading).data, l.billingReasonMeetingNotes);
          expect(
            tester.widget<Text>(example).data,
            l.billingReasonMeetingNotesExample,
          );
          expect(
            tester.widget<Text>(limit).data,
            language == 'es'
                ? 'Hasta 20 horas de reuniones al mes.'
                : 'Fins a 20 hores de reunions al mes.',
          );
          final headingRect = tester.getRect(heading);
          final exampleRect = tester.getRect(example);
          final limitRect = tester.getRect(limit);
          final exampleGap = limitRect.top - exampleRect.bottom;
          final headingGap = exampleRect.top - headingRect.bottom;
          expect(
            exampleGap,
            greaterThanOrEqualTo(8),
            reason: 'example → hours line gap',
          );
          expect(
            headingGap,
            moreOrLessEquals(4, epsilon: 0.5),
            reason: 'heading → example gap unchanged',
          );
          // Set apart: more room above the hours than above the example.
          expect(exampleGap, greaterThan(headingGap));
          // The hours line drawn whole, inside 360 dp.
          expect(limitRect.left, greaterThanOrEqualTo(0));
          expect(limitRect.right, lessThanOrEqualTo(360.5));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: limit, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    test(
      'UX-3002: proBenefitMeetingNotes and billingReasonMeetingNotesLimit read the singular with 1 and today’s text with 20, in EN, ES and CA',
      () {
        final expected = {
          'en': (
            benefit1: 'Notes from your recorded meetings, up to 1 hour a month',
            benefit20:
                'Notes from your recorded meetings, up to 20 hours a month',
            limit1: 'Up to 1 hour of meetings a month.',
            limit20: 'Up to 20 hours of meetings a month.',
          ),
          'es': (
            benefit1: 'Notas de las reuniones que grabas, hasta 1 hora al mes',
            benefit20:
                'Notas de las reuniones que grabas, hasta 20 horas al mes',
            limit1: 'Hasta 1 hora de reuniones al mes.',
            limit20: 'Hasta 20 horas de reuniones al mes.',
          ),
          'ca': (
            benefit1:
                'Notes de les reunions que enregistres, fins a 1 hora al mes',
            benefit20:
                'Notes de les reunions que enregistres, fins a 20 hores al mes',
            limit1: 'Fins a 1 hora de reunions al mes.',
            limit20: 'Fins a 20 hores de reunions al mes.',
          ),
        };
        for (final MapEntry(key: language, value: e) in expected.entries) {
          final l = lookupAppLocalizations(Locale(language));
          expect(l.proBenefitMeetingNotes(1), e.benefit1, reason: language);
          expect(l.proBenefitMeetingNotes(20), e.benefit20, reason: language);
          expect(
            l.billingReasonMeetingNotesLimit(1),
            e.limit1,
            reason: language,
          );
          expect(
            l.billingReasonMeetingNotesLimit(20),
            e.limit20,
            reason: language,
          );
          // Another count takes the plural too, with the number in it.
          expect(l.proBenefitMeetingNotes(2), contains('2'), reason: language);
          expect(
            l.proBenefitMeetingNotes(2),
            isNot(e.benefit1),
            reason: language,
          );
        }
      },
    );

    test(
      'UX-3002: both keys are whole-sentence ICU plurals in the three ARB files, with an =1 case and an other case',
      () {
        for (final language in ['en', 'es', 'ca']) {
          final arb =
              jsonDecode(
                    File('lib/l10n/app_$language.arb').readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          for (final key in [
            'proBenefitMeetingNotes',
            'billingReasonMeetingNotesLimit',
          ]) {
            final value = arb[key] as String;
            expect(
              value,
              startsWith('{hours, plural, =1{'),
              reason: '$language $key',
            );
            expect(value, contains('} other{'), reason: '$language $key');
            expect(value, endsWith('}}'), reason: '$language $key');
          }
        }
      },
    );
  });
}

class _UserAuth extends AuthNotifier {
  _UserAuth(super.api, this.extra);
  final Map<String, dynamic> extra;
  @override
  Future<void> restore() async {
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'pro@example.invalid',
        'timezone': 'Europe/Madrid',
        ...extra,
      }),
    );
  }
}

/// Counts every read of the store's status.
class _CountingRevenueCat extends FakeRevenueCat {
  int infoReads = 0;
  @override
  Future<CustomerInfo> customerInfo() {
    infoReads++;
    return super.customerInfo();
  }
}
