// Run 2026-10-18-commands, b4 · P155 (UX-1112, UX-1102; D8): a password
// account with no name is asked for one once, right after its first
// invitation goes out or it first joins a project; people show as the
// server names them.
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/invitation_cards.dart';
import 'package:agenda/widgets/name_ask_sheet.dart';
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

const paulEmail = 'paul.smith84@example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUpAll(() async {
    // The app's own font, so lines wrap as they do on the phone.
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  // ---- The account and the call ----

  test('UX-1112: Account.fromJson reads first_name «Paul» as firstName '
      '«Paul», and a missing or null one as an empty name', () {
    Map<String, dynamic> user([Map<String, dynamic> extra = const {}]) => {
      'id': 1,
      'email': paulEmail,
      'timezone': 'Europe/Madrid',
      ...extra,
    };
    expect(Account.fromJson(user({'first_name': 'Paul'})).firstName, 'Paul');
    expect(Account.fromJson(user()).firstName, '');
    expect(Account.fromJson(user({'first_name': null})).firstName, '');
  });

  test('UX-1112: the name is sent as PATCH auth/me/ with exactly '
      '{"first_name": "Paul"}, and the saved account then reads «Paul», '
      'also after the app starts again', () async {
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode({
        'access': 'fixture-access',
        'refresh': 'fixture-refresh',
        'user': {'id': 1, 'email': paulEmail, 'timezone': 'Europe/Madrid'},
      }),
    });
    final sent = <http.Request>[];
    final api = ApiClient(
      url: 'http://names.test',
      transport: MockClient((request) async {
        sent.add(request);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 1,
              'email': paulEmail,
              'timezone': 'Europe/Madrid',
              'first_name': 'Paul',
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await api.restore();
    expect(api.account!.firstName, '');
    final account = await api.setFirstName('Paul');
    expect(sent, hasLength(1));
    expect(sent.single.method, 'PATCH');
    expect(sent.single.url.path, '/api/auth/me/');
    expect(jsonDecode(sent.single.body), {'first_name': 'Paul'});
    expect(account.firstName, 'Paul');
    expect(api.account!.firstName, 'Paul');
    final restarted = ApiClient(url: 'http://names.test');
    addTearDown(restarted.close);
    await restarted.restore();
    expect(restarted.account!.firstName, 'Paul');
  });

  // ---- When the sheet asks ----

  final title = find.text(es.nameAskTitle);
  Finder field() => find.byKey(const ValueKey('name-ask-field'));
  String typedName(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!.text;
  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  test('UX-1112: the sheet’s copy in Spanish, English and Catalan', () {
    expect(es.nameAskTitle, '¿Cómo te llamas?');
    expect(
      es.nameAskBody,
      'Así te verán las personas con las que compartes proyectos.',
    );
    expect(es.nameAskField, 'Nombre');
    expect(es.nameAskNotNow, 'Ahora no');
    expect(es.save, 'Guardar');
    expect(en.nameAskTitle, 'What’s your name?');
    expect(
      en.nameAskBody,
      'It’s how people you share projects with will see you.',
    );
    expect(en.nameAskField, 'Name');
    expect(en.nameAskNotNow, 'Not now');
    expect(ca.nameAskTitle, 'Com et dius?');
    expect(
      ca.nameAskBody,
      'Així et veuran les persones amb qui comparteixes projectes.',
    );
    expect(ca.nameAskField, 'Nom');
    expect(ca.nameAskNotNow, 'Ara no');
  });

  test('UX-1112: the suggested name is the email’s part before the @, cut at '
      'the first dot, underscore, hyphen, plus or digit, with a capital; with '
      'fewer than 2 letters left, the whole part', () {
    expect(suggestedName('paul.smith84@example.com'), 'Paul');
    expect(suggestedName('mgarcia61@example.com'), 'Mgarcia');
    expect(suggestedName('ana_lopez@example.com'), 'Ana');
    expect(suggestedName('jordi-puig@example.com'), 'Jordi');
    expect(suggestedName('marta+tasks@example.com'), 'Marta');
    expect(suggestedName('j.smith@example.com'), 'j.smith');
  });

  testWidgets(
    'UX-1112: a password account «paul.smith84@example.com» with no name sends its first invitation and closes «Invitación enviada»: «¿Cómo te llamas?» shows with the field prefilled «Paul»; «Guardar» sends the name and closes the sheet',
    (tester) async {
      final app = await _NameApp.open(tester);
      await app.invite(tester, 'ana@example.invalid');
      expect(title, findsOneWidget);
      expect(inSheet(title), findsOneWidget);
      expect(inSheet(find.text(es.nameAskBody)), findsOneWidget);
      expect(typedName(tester), 'Paul');
      expect(
        tester.widget<TextField>(field()).decoration!.labelText,
        es.nameAskField,
      );
      expect(tester.widget<TextField>(field()).autofocus, isTrue);
      expect(app.api.names, isEmpty, reason: 'nothing sent yet');
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.save)));
      await tester.pumpAndSettle();
      expect(app.api.names, ['Paul']);
      expect(title, findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.container.read(authProvider).account!.firstName, 'Paul');
      expect(find.byType(ListSharingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1112: once asked, «Ahora no» closes it for good: a second invitation and a join show no sheet, and neither does the app rebuilt with the same storage',
    (tester) async {
      final asked = _Asked();
      var app = await _NameApp.open(tester, asked: asked);
      await app.invite(tester, 'ana@example.invalid');
      expect(title, findsOneWidget);
      await tester.tap(
        inSheet(find.widgetWithText(TextButton, es.nameAskNotNow)),
      );
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(app.api.names, isEmpty);

      await app.invite(tester, 'marta@example.invalid', reopen: false);
      expect(title, findsNothing, reason: 'second invitation');
      await app.join(tester);
      expect(find.byType(HomeScreen), findsWidgets);
      expect(title, findsNothing, reason: 'after joining');

      // The app starts again, with the same phone storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      app = await _NameApp.open(tester, asked: asked);
      await app.invite(tester, 'jordi@example.invalid');
      expect(title, findsNothing, reason: 'rebuilt, inviting');
      await app.join(tester);
      expect(title, findsNothing, reason: 'rebuilt, joining');
      expect(app.api.names, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1112: a password account with no name joins a project with «Unirme»: the project’s page opens and the sheet shows once',
    (tester) async {
      final app = await _NameApp.open(tester);
      await app.join(tester);
      final page = find.byWidgetPredicate(
        (widget) => widget is HomeScreen && widget.listId == 'casa',
      );
      expect(page, findsOneWidget, reason: 'the project’s page opened');
      expect(title, findsOneWidget);
      expect(typedName(tester), 'Paul');
      await tester.tap(
        inSheet(find.widgetWithText(TextButton, es.nameAskNotNow)),
      );
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(page, findsOneWidget);
      // Joining again on this run: no second sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await app.join(tester);
      expect(title, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1112: an account whose name is «Ana» never sees the sheet, after inviting or after joining',
    (tester) async {
      final app = await _NameApp.open(
        tester,
        email: 'ana.lopez@example.com',
        firstName: 'Ana',
      );
      await app.invite(tester, 'paul@example.invalid');
      expect(title, findsNothing, reason: 'after inviting');
      await app.join(tester);
      expect(title, findsNothing, reason: 'after joining');
      expect(app.asked.owners, isEmpty, reason: 'never asked');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1112: «Guardar» answered with no connection keeps the sheet open, with the name kept and the network problem under the field',
    (tester) async {
      final app = await _NameApp.open(tester);
      app.api.nameFailure = ApiException(0, 'Offline. Retry when connected.');
      await app.invite(tester, 'ana@example.invalid');
      await tester.enterText(field(), 'Pau');
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.save)));
      await tester.pumpAndSettle();
      expect(app.api.names, ['Pau']);
      expect(title, findsOneWidget, reason: 'the sheet stays open');
      expect(typedName(tester), 'Pau');
      final problem = es.requestError('network');
      expect(tester.widget<TextField>(field()).decoration!.errorText, problem);
      expect(find.text(problem), findsOneWidget);
      expect(find.textContaining('Tus tareas'), findsNothing);
      expect(
        tester.getRect(find.text(problem)).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Pau')).bottom),
        reason: 'under the field',
      );
      // Saved once the connection is back.
      app.api.nameFailure = null;
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.save)));
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(app.api.names, ['Pau', 'Pau']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-1112: «Guardar» is off while the field is empty', (
    tester,
  ) async {
    final app = await _NameApp.open(tester);
    await app.invite(tester, 'ana@example.invalid');
    await tester.enterText(field(), '   ');
    await tester.pumpAndSettle();
    final save = inSheet(find.widgetWithText(FilledButton, es.save));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(app.api.names, isEmpty);
    expect(title, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1112 ($language, 2× on 320×640 with the keyboard): the title, the field and «${strings(language).save}» show whole, and nothing overflows',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final app = await _NameApp.open(
          tester,
          language: language,
          size: const Size(320, 640),
        );
        await app.invite(tester, 'ana@example.invalid', l: l);
        expect(find.text(l.nameAskTitle), findsOneWidget);
        // The keyboard takes the bottom 300 dp.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        const above = 640 - 300 + 0.5;
        for (final target in [
          find.text(l.nameAskTitle),
          field(),
          inSheet(find.widgetWithText(FilledButton, l.save)),
        ]) {
          expect(target, findsOneWidget, reason: '$target');
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final rect = tester.getRect(target);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$target');
          expect(rect.right, lessThanOrEqualTo(320.5), reason: '$target');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '$target');
          expect(rect.bottom, lessThanOrEqualTo(above), reason: '$target');
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.descendant(
              of: target,
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          )) {
            expect(paragraph.didExceedMaxLines, isFalse, reason: '$target');
          }
        }
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  // ---- Round 2 · P164 (UX-1229, UX-1230): a plain error, and progress
  // while «Guardar» waits ----

  for (final language in ['es', 'en']) {
    testWidgets(
      'UX-1229 ($language): «Guardar» answered with no connection reads only the reason under the field, with nothing about the tasks; the sheet stays open with the name kept',
      (tester) async {
        final l = strings(language);
        final app = await _NameApp.open(tester, language: language);
        app.api.nameFailure = ApiException(
          0,
          'Offline. Retry when connected.',
        );
        await app.invite(tester, 'ana@example.invalid', l: l);
        await tester.enterText(field(), 'Pau');
        await tester.pumpAndSettle();
        await tester.tap(inSheet(find.widgetWithText(FilledButton, l.save)));
        await tester.pumpAndSettle();
        final expected = {
          'es':
              'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.',
          'en': 'No connection. Check Wi-Fi or mobile data and try again.',
        }[language]!;
        expect(l.requestError('network'), expected);
        expect(
          tester.widget<TextField>(field()).decoration!.errorText,
          expected,
        );
        expect(inSheet(find.text(expected)), findsOneWidget);
        expect(
          find.textContaining(
            language == 'es' ? 'Tus tareas' : 'Your tasks are still saved',
          ),
          findsNothing,
        );
        expect(find.text(l.nameAskTitle), findsOneWidget);
        expect(typedName(tester), 'Pau');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1229: «Guardar» answered by an unknown failure reads «No se ha podido completar la solicitud. Inténtalo de nuevo.», with nothing about the tasks',
    (tester) async {
      final app = await _NameApp.open(tester);
      app.api.nameFailure = StateError('boom');
      await app.invite(tester, 'ana@example.invalid');
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.save)));
      await tester.pumpAndSettle();
      expect(
        es.requestError('other'),
        'No se ha podido completar la solicitud. Inténtalo de nuevo.',
      );
      expect(
        tester.widget<TextField>(field()).decoration!.errorText,
        es.requestError('other'),
      );
      expect(find.textContaining('Tus tareas'), findsNothing);
      expect(title, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  Finder sheetSave() => inSheet(find.byType(FilledButton));
  Finder notNow() =>
      inSheet(find.widgetWithText(TextButton, es.nameAskNotNow));

  /// The sheet open after an invitation, with «Guardar» tapped and its call
  /// held; returns the button's size before the tap.
  Future<Size> savingHeld(WidgetTester tester, _NameApp app) async {
    await app.invite(tester, 'ana@example.invalid');
    expect(title, findsOneWidget);
    final before = tester.getSize(sheetSave());
    app.api.nameHold = Completer<void>();
    await tester.tap(sheetSave());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return before;
  }

  testWidgets(
    'UX-1230: while «Guardar»’s call hasn’t returned, the button shows a spinner labelled «Guardar» and no «Guardar» text, at its size from before the tap; «Ahora no» is off and tapping it leaves the sheet open',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _NameApp.open(tester);
      final before = await savingHeld(tester, app);
      expect(app.api.names, ['Paul']);
      final spinner = find.descendant(
        of: sheetSave(),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(
        find.descendant(of: sheetSave(), matching: find.text(es.save)),
        findsNothing,
      );
      expect(tester.getSize(sheetSave()), before);
      expect(
        tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
        es.save,
      );
      // TalkBack reads the button as «Guardar», off while it waits.
      expect(
        tester.getSemantics(spinner),
        isSemantics(label: es.save, isButton: true, isEnabled: false),
      );
      expect(tester.widget<TextButton>(notNow()).onPressed, isNull);
      await tester.tap(notNow(), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(title, findsOneWidget, reason: 'the sheet stays open');
      expect(find.byType(BottomSheet), findsOneWidget);
      // Let the held call finish so nothing is left pending.
      app.api.nameHold!.complete();
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1230: when the held call fails, «Guardar» reads again, «Ahora no» is on, and the error shows under the field',
    (tester) async {
      final app = await _NameApp.open(tester);
      await savingHeld(tester, app);
      expect(tester.widget<TextButton>(notNow()).onPressed, isNull);
      app.api.nameFailure = ApiException(0, 'Offline. Retry when connected.');
      app.api.nameHold!.complete();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sheetSave(), matching: find.text(es.save)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheetSave(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(tester.widget<FilledButton>(sheetSave()).onPressed, isNotNull);
      expect(tester.widget<TextButton>(notNow()).onPressed, isNotNull);
      expect(
        tester.widget<TextField>(field()).decoration!.errorText,
        es.requestError('network'),
      );
      expect(find.text(es.requestError('network')), findsOneWidget);
      expect(title, findsOneWidget);
      // «Ahora no» now closes the sheet.
      await tester.tap(notNow());
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-1230: when the held call succeeds, the sheet closes', (
    tester,
  ) async {
    final app = await _NameApp.open(tester);
    await savingHeld(tester, app);
    expect(title, findsOneWidget);
    app.api.nameHold!.complete();
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(app.api.names, ['Paul']);
    expect(app.container.read(authProvider).account!.firstName, 'Paul');
    expect(tester.takeException(), isNull);
  });

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1229 ($language, 2× on 320×640 with the keyboard): after the no-connection failure, the error line shows whole under the field and nothing overflows',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final app = await _NameApp.open(
          tester,
          language: language,
          size: const Size(320, 640),
        );
        app.api.nameFailure = ApiException(
          0,
          'Offline. Retry when connected.',
        );
        await app.invite(tester, 'ana@example.invalid', l: l);
        // The keyboard takes the bottom 300 dp.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final save = inSheet(find.widgetWithText(FilledButton, l.save));
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        final line = l.requestError('network');
        expect(
          line,
          {
            'es':
                'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.',
            'ca':
                'No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar.',
          }[language],
        );
        final shown = inSheet(find.text(line));
        expect(shown, findsOneWidget);
        await tester.ensureVisible(shown);
        await tester.pumpAndSettle();
        final rect = tester.getRect(shown);
        const above = 640 - 300 + 0.5;
        expect(rect.left, greaterThanOrEqualTo(0), reason: line);
        expect(rect.right, lessThanOrEqualTo(320.5), reason: line);
        expect(rect.top, greaterThanOrEqualTo(0), reason: line);
        expect(rect.bottom, lessThanOrEqualTo(above), reason: line);
        expect(
          rect.top,
          greaterThanOrEqualTo(tester.getRect(find.text('Paul')).bottom),
          reason: 'under the field',
        );
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: shown,
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse, reason: line);
        }
        expect(find.textContaining('Tus tareas'), findsNothing);
        expect(find.textContaining('Les tasques continuen'), findsNothing);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  // ---- UX-1102: people as the server names them ----

  testWidgets(
    'UX-1102: a shared project whose people come back named «Paul» shows the chip «Paul», and a task he created reads «Creada por Paul»',
    (tester) async {
      final project = TaskListInfo.fromApi({
        'id': 'casa',
        'name': 'Casa',
        'color': 'blue',
        'role': 'owner',
        'shared': true,
        'owner_id': 1,
        'version': 2,
        'people': [
          {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
          {'user_id': 3, 'name': 'Paul', 'role': 'editor'},
        ],
      });
      final task = Task.fromApi({
        ...Task(
          title: 'Comprar pan',
          priority: 1,
          listId: 'casa',
          assignment: 'group',
        ).toApi(),
        'created_by': 3,
        'created_by_name': 'Paul',
      }).copyWith(id: 1);
      await _NameApp.open(
        tester,
        email: 'ana.lopez@example.com',
        firstName: 'Ana',
        projects: [project],
        tasks: [task],
      );
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(isRoot: false, listId: 'casa'),
        ),
      );
      await tester.pumpAndSettle();
      final chip = find.byKey(const ValueKey('people-3'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('Paul')),
        findsOneWidget,
      );
      expect(find.textContaining('paul.smith'), findsNothing);

      navigator.pushNamed('/taskDetails', arguments: 1);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('task-created-by'))).data,
        es.createdBy('Paul'),
      );
      expect(es.createdBy('Paul'), 'Creada por Paul');
      expect(tester.takeException(), isNull);
    },
  );
}

/// The phone's memory of who was asked their name.
class _Asked extends NameAskStore {
  _Asked() : super(TaskDatabase());
  final owners = <String>{};
  @override
  Future<bool> asked(String owner) async => owners.contains(owner);
  @override
  Future<void> markAsked(String owner) async {
    owners.add(owner);
  }
}

/// The server: invitations answer a code, a join answers the project, and
/// the name is saved unless [nameFailure] is set.
class _NameApi extends OfflineApiClient {
  _NameApi(this.user);
  Map<String, dynamic> user;
  final calls = <(String, String, Map<String, dynamic>?)>[];
  final names = <String>[];
  Object? nameFailure;

  @override
  Account get account => Account.fromJson(user);

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    calls.add((method, path, data));
    if (path.endsWith('invite/')) return {'code': 'K7P2Q9MX'};
    if (path.endsWith('respond/')) return {'list_id': 'casa'};
    return {};
  }

  /// While set, the name's call waits for it, as a slow connection does.
  Completer<void>? nameHold;

  @override
  Future<Account> setFirstName(String firstName) async {
    names.add(firstName);
    await nameHold?.future;
    final error = nameFailure;
    if (error != null) throw error;
    user = {...user, 'first_name': firstName};
    return Account.fromJson(user);
  }
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(account: api.account);
  }
}

class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }
}

/// The app in Spanish (or [language]) for a password account, with project
/// «Casa» of its own and an invitation to join «Casa» waiting.
class _NameApp {
  _NameApp(this.container, this.api, this.asked);
  final ProviderContainer container;
  final _NameApi api;
  final _Asked asked;

  static Future<_NameApp> open(
    WidgetTester tester, {
    String email = paulEmail,
    String? firstName,
    String language = 'es',
    Size size = const Size(390, 844),
    _Asked? asked,
    List<TaskListInfo>? projects,
    List<Task> tasks = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _NameApi({
      'id': 1,
      'email': email,
      'timezone': 'Europe/Madrid',
      'first_name': ?firstName,
    });
    final names = asked ?? _Asked();
    final container = ProviderContainer(
      overrides: [
        firstTaskStoreProvider.overrideWithValue(MemoryFirstTaskStore()),
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _Auth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(RegionalPreferences(language: language)),
        ),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith(
          (ref) async =>
              projects ??
              [
                TaskListInfo(
                  id: 'casa',
                  name: 'Casa',
                  role: 'owner',
                  version: 1,
                ),
              ],
        ),
        listSharingProvider.overrideWith(
          (ref, id) async => {
            'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
            'members': [],
            'invitations': [],
          },
        ),
        pendingInvitationsProvider.overrideWith(
          (ref) async => [
            PendingInvitation.fromJson('list', {
              'id': 'invitation-casa',
              'list_name': 'Casa',
              'list_id': 'casa',
              'role': 'editor',
            }),
          ],
        ),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => _Tasks(tasks)),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        nameAskStoreProvider.overrideWithValue(names),
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _NameApp(container, api, names);
  }

  NavigatorState _navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  /// From «Casa»'s sharing screen (opened unless [reopen] is false), an
  /// invitation to [address], then «Listo» on «Invitación enviada».
  Future<void> invite(
    WidgetTester tester,
    String address, {
    bool reopen = true,
    AppLocalizations? l,
  }) async {
    final strings = l ?? es;
    if (reopen || find.byType(ListSharingScreen).evaluate().isEmpty) {
      _navigator(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => const ListSharingScreen(listId: 'casa'),
        ),
      );
      await tester.pumpAndSettle();
    }
    final person = find.byKey(const ValueKey('invite-person'));
    await tester.scrollUntilVisible(
      person,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListSharingScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(person);
    await tester.pumpAndSettle();
    final email = find.byKey(const ValueKey('invite-email'));
    await tester.ensureVisible(email);
    await tester.enterText(email, address);
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, strings.sendInvitation);
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text(strings.invitationSent), findsOneWidget);
    final done = find.widgetWithText(FilledButton, strings.done);
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
  }

  /// The waiting invitation to «Casa», opened from the invitations list,
  /// with its code and «Unirme».
  Future<void> join(WidgetTester tester) async {
    _navigator(tester).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(body: ListView(children: const [PendingInvitations()])),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(InvitationCard).first;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    final code = find.byKey(const ValueKey('accept-invitation-code'));
    await tester.ensureVisible(code);
    await tester.enterText(code, 'synthetic-invitation-code-2026');
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.joinInvitation));
    await tester.pumpAndSettle();
  }
}
