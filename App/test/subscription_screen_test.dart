// P44 (UX-423, D4d) and P92 (UX-501), round 1 of 2026-10-13-app: the Pro
// screen's buttons and the free tier's numbers.
import 'dart:convert';
import 'dart:io';

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
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.7)),
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  for (final (purchased, active) in [(true, false), (true, true), (false, false)]) {
    testWidgets(
      'UX-423: the Pro screen ${active ? 'for an active subscriber' : purchased ? 'for someone who bought Pro before' : 'for someone who never bought Pro'} shows ${purchased ? 'Gestionar suscripción' : 'no Gestionar suscripción'}${active ? ', no Restaurar compras (UX-1614)' : ', Restaurar compras and Ver suscripción'}, and no Abrir suscripciones de la tienda or Actualizar estado',
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
          'storage': {'used_bytes': 42 * megabyte, 'limit_bytes': 100 * megabyte},
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

  // ---- Run 2026-10-18-commands, b4 · P154 (UX-1223) ----

  testWidgets(
    'UX-1223: a free account’s Pro screen at 100 of 100 MB shows «Ver tareas con archivos» under «Archivos: 100 de 100 MB usados»; at 80 of 100 MB it doesn’t; with Pro it doesn’t',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final es = lookupAppLocalizations(const Locale('es'));
      Map<String, dynamic> used(int mb) => {
        'storage': {'used_bytes': mb * megabyte, 'limit_bytes': 100 * megabyte},
      };
      final see = find.widgetWithText(TextButton, es.storageSeeTasks);

      await openPro(tester, sdk: _CountingRevenueCat(), user: used(100));
      final usage = find.text(es.storageUsage(100, 100));
      expect(es.storageUsage(100, 100), 'Archivos: 100 de 100 MB usados');
      expect(usage, findsOneWidget);
      expect(see, findsOneWidget);
      expect(
        tester.getRect(see).top,
        greaterThanOrEqualTo(tester.getRect(usage).bottom - 0.5),
        reason: 'under the usage line',
      );
      final colors = Theme.of(
        tester.element(find.byType(SubscriptionScreen)),
      ).colorScheme;
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(of: see, matching: find.byType(RichText)),
      );
      expect(label.text.style?.color, colors.onPrimaryContainer);
      expect(tester.takeException(), isNull);

      await openPro(tester, sdk: _CountingRevenueCat(), user: used(80));
      expect(find.text(es.storageUsage(80, 100)), findsOneWidget);
      expect(see, findsNothing);

      await openPro(
        tester,
        sdk: _CountingRevenueCat()..info = billingInfo(active: true),
        user: used(100),
      );
      expect(see, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('UX-501: freeVoiceStatus has a singular and a plural in EN, ES and CA', () {
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
  });

  test(
    'UX-501: billingTestMode no longer says Pro unlocks voice capture, and the removed keys are gone from the three ARB files',
    () {
      for (final (language, voice) in [
        ('en', 'voice'),
        ('es', 'voz'),
        ('ca', 'veu'),
      ]) {
        final arb =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
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
    },
  );

  // ---- Round 2 · P96 · UX-509: billing messages point to what exists ----

  test(
    'UX-509: no billing message tells people to refresh: accountUnavailable, network and awaitingEntitlement in EN, ES and CA, and nothing in EN’s billingError or billingResult',
    () {
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
      final arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in ['billingError', 'billingResult']) {
        expect(
          (arb[key] as String).toLowerCase(),
          isNot(contains('refresh')),
          reason: key,
        );
      }
    },
  );

  test(
    'UX-509: billingError for accountUnavailable and network, and billingResult for awaitingEntitlement, in EN, ES and CA',
    () {
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
    },
  );

  test(
    'UX-514: billingError accountUnavailable names no server in EN, ES or CA, and still says to open the screen again',
    () {
      for (final (language, again) in [
        ('en', 'open this screen again'),
        ('es', 'vuelve a abrir esta pantalla'),
        ('ca', 'torna a obrir aquesta pantalla'),
      ]) {
        final message = lookupAppLocalizations(
          Locale(language),
        ).billingError('accountUnavailable');
        expect(
          message.toLowerCase(),
          isNot(matches(RegExp('server|servidor'))),
          reason: '$language: $message',
        );
        expect(message, contains(again), reason: language);
      }
    },
  );

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
    expect(en.billingIntro, 'Unlimited dictations, and room for all your files.');
    expect(es.billingIntro,
        'Dictados sin límite y espacio para todos tus archivos.');
    expect(ca.billingIntro,
        'Dictats sense límit i espai per a tots els fitxers.');
    for (final reason in ['store', 'other']) {
      expect(en.billingError(reason),
          'The store didn’t answer. Open this screen again.');
      expect(es.billingError(reason),
          'La tienda no respondió. Vuelve a abrir esta pantalla.');
      expect(ca.billingError(reason),
          'La botiga no ha respost. Torna a obrir aquesta pantalla.');
    }
  });

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1613: $language at 2× on 360×800, a free account sees what Pro gives and Ver suscripción without scrolling, and no second TaskFlow Pro heading or sparkle in the card',
      (tester) async {
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
        final intro = find.text(l.billingIntro);
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
        final buttons = tester
            .widgetList(find.byWidgetPredicate((w) => w is ButtonStyleButton))
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
        find.text('La tienda no pudo completar la solicitud. Inténtalo de nuevo.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
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
