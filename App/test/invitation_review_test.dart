import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/invitation_review_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/invitation_cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _link = InvitationLink(
  'group',
  'f4ec527c-44b7-462d-943f-094932762ee1',
  'synthetic-code-1234',
);

void main() {
  for (final available in [true, false]) {
    testWidgets(
      available
          ? 'Invitation needs explicit confirmation with account and role visible'
          : 'Wrong account cannot accept an invitation',
      (tester) async {
        final api = _InvitationApi(available);
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(api.close);
        container.read(authProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const InvitationReviewScreen(invitation: _link),
                      ),
                    ),
                    child: const Text('Open invitation'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open invitation'));
        await tester.pumpAndSettle();
        expect(api.accepted, isNull);
        expect(
          find.text('Signed in as design@example.invalid'),
          findsOneWidget,
        );
        if (available) {
          expect(find.text('Staging crew'), findsOneWidget);
          expect(find.text('Editor'), findsOneWidget);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(api.accepted, {'decision': 'accept', 'code': _link.code});
          expect(api.acceptedAccount, 1);
          expect(find.byType(InvitationReviewScreen), findsNothing);
        } else {
          expect(find.byType(FilledButton), findsNothing);
          expect(find.textContaining('email address'), findsWidgets);
          expect(api.accepted, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P14 (UX-306, UX-307, UX-326): find invitations, join, land ----

  final es = lookupAppLocalizations(const Locale('es'));
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  const listId = '0b6a3d52-6f3c-4f57-9d43-1c2a7f0e5a11';
  const comprasInvitation = {
    'id': listId,
    'list_id': 'compras',
    'list_name': 'Compras',
    'role': 'editor',
  };
  const code = 'Synthetic-Invitation-Code_2026';

  Finder card(String name) => find.text(es.invitedTo(name));

  testWidgets(
    'UX-306: with a pending project invitation, Calendar shows Te han invitado a Compras · Ver; after a confirmed Rechazar the card is gone',
    (tester) async {
      expect(es.invitedTo('Compras'), 'Te han invitado a Compras · Ver');
      final api = _Invitations(lists: [comprasInvitation]);
      await _openApp(tester, api);
      expect(card('Compras').hitTestable(), findsOneWidget);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      expect(find.text(es.joinInvitationTitle('Compras')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('decline-invitation')));
      await tester.pumpAndSettle();
      expect(
        es.declineInvitationConfirm('Compras'),
        '¿Rechazar la invitación a Compras? Para unirte más tarde necesitarías otra.',
      );
      expect(find.text(es.declineInvitationConfirm('Compras')), findsOneWidget);
      // Nothing is sent before the confirmation.
      expect(api.responses, isEmpty);
      await tester.tap(find.byKey(const ValueKey('confirm-decline')));
      await tester.pumpAndSettle();
      expect(api.responses, [
        [
          'invitations/$listId/respond/',
          {'decision': 'decline'},
        ],
      ]);
      expect(card('Compras'), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-306: cancelling the Rechazar question keeps the invitation and its card',
    (tester) async {
      final api = _Invitations(lists: [comprasInvitation]);
      await _openApp(tester, api);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decline-invitation')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, es.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.responses, isEmpty);
      expect(card('Compras'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-306: with several invitations, Calendar shows the first and +N',
    (tester) async {
      final api = _Invitations(
        groups: [
          {
            'id': 'a1b2c3d4-0000-4000-8000-000000000001',
            'group_id': 'familia',
            'group_name': 'Familia',
            'role': 'editor',
          },
        ],
        lists: [
          comprasInvitation,
          {
            'id': 'a1b2c3d4-0000-4000-8000-000000000002',
            'list_id': 'obra',
            'list_name': 'Obra',
            'role': 'editor',
          },
        ],
      );
      await _openApp(tester, api);
      expect(find.byType(InvitationCard), findsOneWidget);
      expect(card('Familia'), findsOneWidget);
      expect(card('Compras'), findsNothing);
      expect(find.text(es.invitationsMore(2)), findsOneWidget);
      expect(es.invitationsMore(2), '+2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-306: Calendar’s pull-to-refresh brings a new invitation in', (
    tester,
  ) async {
    final api = _Invitations();
    await _openApp(tester, api);
    expect(find.byType(InvitationCard), findsNothing);
    api.lists = [comprasInvitation];
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    // The phone-calendar half of the refresh never answers here, so step the
    // frames rather than wait for the spinner to settle.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(card('Compras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UX-306: the join dialog says Unirte a Compras, the invitee’s text, a code field and Unirme, with Rechazar away from Unirme',
    (tester) async {
      expect(es.joinInvitationTitle('Compras'), 'Unirte a Compras');
      expect(
        es.joinInvitationHelp,
        'Abre el correo de invitación y pulsa su enlace. O pega aquí el código que aparece.',
      );
      expect(es.joinInvitation, 'Unirme');
      final api = _Invitations(lists: [comprasInvitation]);
      await _openApp(tester, api);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text(es.joinInvitationHelp)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const ValueKey('accept-invitation-code')),
        ),
        findsOneWidget,
      );
      final join = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, es.joinInvitation),
      );
      final decline = find.byKey(const ValueKey('decline-invitation'));
      final cancel = find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, es.cancel),
      );
      expect(join, findsOneWidget);
      // Apart on either axis: side by side, or stacked when the row is full.
      double apart(Rect a, Rect b) => [
        b.left - a.right,
        a.left - b.right,
        b.top - a.bottom,
        a.top - b.bottom,
      ].reduce((x, y) => x > y ? x : y);
      final gapToJoin = apart(tester.getRect(decline), tester.getRect(join));
      // They were 8 dp apart, side by side; Rechazar now sits away from
      // Unirme, with Cancelar between them when the buttons stack.
      expect(
        gapToJoin,
        greaterThanOrEqualTo(40),
        reason:
            'Rechazar ${tester.getRect(decline)}, Unirme ${tester.getRect(join)}, '
            'Cancelar ${tester.getRect(cancel)}',
      );
      // An empty code is refused with the existing message.
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(find.text(es.invitationCodeRequired), findsOneWidget);
      expect(api.responses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-307: joining from Calendar’s card opens the project’s page and says Te has unido a Compras',
    (tester) async {
      expect(es.joinedInvitation('Compras'), 'Te has unido a Compras');
      final api = _Invitations(lists: [comprasInvitation]);
      final container = await _openApp(tester, api);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('accept-invitation-code')),
        code,
      );
      await tester.tap(find.widgetWithText(FilledButton, es.joinInvitation));
      await tester.pumpAndSettle();
      expect(api.responses, [
        [
          'invitations/$listId/respond/',
          {'decision': 'accept', 'code': code},
        ],
      ]);
      final page = find.byWidgetPredicate(
        (w) => w is HomeScreen && w.listId == 'compras',
      );
      expect(page, findsOneWidget);
      expect(
        find.descendant(of: page, matching: find.text('Compras')),
        findsWidgets,
      );
      expect(find.text(es.joinedInvitation('Compras')), findsOneWidget);
      expect(container.read(pendingInvitationsProvider).valueOrNull, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-307 / UX-326: from an invitation link, the review reads the new copy; after Aceptar invitación the project’s page is on screen with Te has unido a Compras',
    (tester) async {
      expect(es.invitationReviewHelp, 'Verás sus tareas, notas y archivos.');
      expect(
        es.signedInAs('design@example.invalid'),
        'Sesión iniciada como design@example.invalid',
      );
      final api = _Invitations(lists: [comprasInvitation]);
      final storage = _Storage();
      final container = await _openApp(
        tester,
        api,
        link: 'taskflow://invite?kind=list&id=$listId&code=$code',
        storage: storage,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(find.text(es.invitationReviewHelp), findsOneWidget);
      expect(
        find.text(es.signedInAs('design@example.invalid')),
        findsOneWidget,
      );
      expect(find.textContaining('a continuación'), findsNothing);
      await tester.tap(find.text(es.acceptInvitation));
      await tester.pumpAndSettle();
      expect(api.responses, [
        [
          'invitations/$listId/respond/',
          {'decision': 'accept', 'code': code},
        ],
      ]);
      expect(find.byType(InvitationReviewScreen), findsNothing);
      final page = find.byWidgetPredicate(
        (w) => w is HomeScreen && w.listId == 'compras',
      );
      expect(page, findsOneWidget);
      expect(
        find.descendant(of: page, matching: find.text('Compras')),
        findsWidgets,
      );
      expect(find.text(es.joinedInvitation('Compras')), findsOneWidget);
      // Handled: the link is forgotten.
      expect(container.read(invitationLinkProvider), isNull);
      expect(storage.deletes, greaterThan(0));
      // Back from the project goes to Calendar, not to the review.
      // Android's Back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-326: Ahora no closes the review without clearing the stored invitation; Calendar’s card then offers it with its code',
    (tester) async {
      expect(es.invitationNotNow, 'Ahora no');
      final api = _Invitations(lists: [comprasInvitation]);
      final storage = _Storage();
      final container = await _openApp(
        tester,
        api,
        link: 'taskflow://invite?kind=list&id=$listId&code=$code',
        storage: storage,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      final link = container.read(invitationLinkProvider);
      expect(link, isNotNull);
      expect(find.text(es.cancel), findsNothing);
      await tester.tap(find.text(es.invitationNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(api.responses, isEmpty);
      // Kept, on the phone too.
      expect(identical(container.read(invitationLinkProvider), link), isTrue);
      expect(storage.deletes, 0);
      // It isn't pushed again; Calendar's card offers it, code filled in.
      expect(card('Compras'), findsOneWidget);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('accept-invitation-code')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        code,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-306: the group join dialog shows the invitee’s text and Unirme, not Guardar or the inviter’s help',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _Invitations(
        groups: [
          {
            'id': 'a1b2c3d4-0000-4000-8000-000000000001',
            'group_id': 'familia',
            'group_name': 'Familia',
            'role': 'editor',
          },
        ],
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          groupsProvider.overrideWith((ref) async => []),
          taskListsProvider.overrideWith((ref) async => []),
          invitationLinkProvider.overrideWith(
            (ref) => InvitationLinks(listen: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GroupsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(card('Familia'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(es.joinInvitationTitle('Familia')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(es.joinInvitationHelp)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(es.joinInvitation)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(es.save)),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(es.groupInviteHelp)),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('accept-invitation-code')),
        code,
      );
      await tester.tap(find.text(es.joinInvitation));
      await tester.pumpAndSettle();
      expect(
        api.responses.single[0],
        'group-invitations/a1b2c3d4-0000-4000-8000-000000000001/respond/',
      );
      // Lands on the group's page.
      final page = find.byWidgetPredicate(
        (w) => w is GroupScreen && w.groupId == 'familia',
      );
      expect(page, findsOneWidget);
      expect(find.text(es.joinedInvitation('Familia')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  // ---- P74 (UX-478, UX-480): the join dialog waits; a wrong code stays ----

  const pasted = 'Synthetic-Code-20chr';
  const familiaInvitation = {
    'id': 'a1b2c3d4-0000-4000-8000-000000000001',
    'group_id': 'familia',
    'group_name': 'Familia',
    'role': 'editor',
  };
  final codeField = find.byKey(const ValueKey('accept-invitation-code'));
  String codeInField(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: codeField, matching: find.byType(TextField)),
      )
      .controller!
      .text;
  String? errorUnderField(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: codeField, matching: find.byType(TextField)),
      )
      .decoration!
      .errorText;

  /// Calendar's card for [name] → Ver, the code pasted, Unirme tapped.
  Future<void> joinFromCard(WidgetTester tester, String name) async {
    await tester.tap(card(name));
    await tester.pumpAndSettle();
    expect(pasted.length, 20);
    await tester.enterText(codeField, pasted);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, es.joinInvitation));
  }

  testWidgets(
    'UX-478: while respond takes 2 s the join dialog stays, with a spinner inside Unirme (still read as Unirme), Rechazar, Cancelar and the code disabled, and Back or a tap outside doesn’t close it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final api = _Invitations(lists: [comprasInvitation])
        ..delay = const Duration(seconds: 2);
      await _openApp(tester, api);
      await joinFromCard(tester, 'Compras');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(api.responses, hasLength(1));
      final join = find.descendant(
        of: dialog,
        matching: find.byType(FilledButton),
      );
      final spinner = find.descendant(
        of: join,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(tester.getSize(spinner), const Size(20, 20));
      expect(tester.widget<CircularProgressIndicator>(spinner).strokeWidth, 2);
      expect(tester.getSemantics(join).label, contains(es.joinInvitation));
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('decline-invitation')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: dialog,
                matching: find.widgetWithText(TextButton, es.cancel),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: codeField, matching: find.byType(TextField)),
            )
            .enabled,
        isFalse,
      );
      // Android's Back, then a tap on the scrim.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(dialog, findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(dialog, findsOneWidget);
      expect(spinner, findsOneWidget);
      // The wait ends: the project opens.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(api.responses, hasLength(1));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-478: when respond succeeds after the wait, the dialog closes and the Compras page says Te has unido a Compras',
    (tester) async {
      final api = _Invitations(lists: [comprasInvitation])
        ..delay = const Duration(seconds: 2);
      await _openApp(tester, api);
      await joinFromCard(tester, 'Compras');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.responses, [
        [
          'invitations/$listId/respond/',
          {'decision': 'accept', 'code': pasted},
        ],
      ]);
      final page = find.byWidgetPredicate(
        (w) => w is HomeScreen && w.listId == 'compras',
      );
      expect(page, findsOneWidget);
      expect(ModalRoute.of(tester.element(page))!.isCurrent, isTrue);
      expect(find.text(es.joinedInvitation('Compras')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (kind, invitation, name, message) in [
    (
      'group',
      familiaInvitation,
      'Familia',
      'Ask a group administrator for the current invitation code.',
    ),
    (
      'project',
      comprasInvitation,
      'Compras',
      'Ask the list owner for the current invitation code.',
    ),
  ]) {
    testWidgets(
      'UX-478: a $kind invitation refused with “$message” keeps the dialog and the code, shows Pide a quien te invitó el código actual. under the field and no SnackBar',
      (tester) async {
        expect(es.invitationCodeWrong, 'Pide a quien te invitó el código actual.');
        final api = _Invitations(
          groups: kind == 'group' ? [invitation] : const [],
          lists: kind == 'project' ? [invitation] : const [],
        )..failure = ApiException(400, message);
        await _openApp(tester, api);
        await joinFromCard(tester, name);
        await tester.pumpAndSettle();
        expect(api.responses, hasLength(1));
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(codeInField(tester), pasted);
        expect(errorUnderField(tester), es.invitationCodeWrong);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(es.invitationCodeWrong),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('propietario'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        // Editing the code clears the problem.
        await tester.enterText(codeField, '${pasted}x');
        await tester.pump();
        expect(errorUnderField(tester), isNull);
        expect(find.text(es.invitationCodeWrong), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-478: a connection error keeps the dialog and the code, with the problem inside the dialog and no SnackBar',
    (tester) async {
      final failure = ApiException(0, 'Offline. Retry when connected.');
      final api = _Invitations(lists: [comprasInvitation])..failure = failure;
      await _openApp(tester, api);
      await joinFromCard(tester, 'Compras');
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(codeInField(tester), pasted);
      final problem = requestProblemText(es, failure);
      expect(problem, isNotEmpty);
      expect(errorUnderField(tester), problem);
      expect(
        find.descendant(of: dialog, matching: find.text(problem)),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      // Unirme can be tried again.
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: dialog, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-480: after Rechazar, the confirm button is red: colorScheme.error behind colorScheme.onError',
    (tester) async {
      final api = _Invitations(lists: [comprasInvitation]);
      await _openApp(tester, api);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decline-invitation')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('confirm-decline'));
      expect(confirm, findsOneWidget);
      expect(
        find.descendant(of: confirm, matching: find.text(es.decline)),
        findsOneWidget,
      );
      final colors = Theme.of(tester.element(confirm)).colorScheme;
      final style = tester.widget<FilledButton>(confirm).style!;
      expect(style.backgroundColor!.resolve({}), colors.error);
      expect(style.foregroundColor!.resolve({}), colors.onError);
      expect(api.responses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

}

class _InvitationApi extends OfflineApiClient {
  _InvitationApi(this.available);
  final bool available;
  Map<String, dynamic>? accepted;
  int? acceptedAccount;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'GET' && path == 'group-invitations/') {
      return {
        'invitations': available
            ? [
                {
                  'id': _link.id,
                  'group_name': 'Staging crew',
                  'role': 'editor',
                },
              ]
            : [],
      };
    }
    if (method == 'POST' && path == 'group-invitations/${_link.id}/respond/') {
      accepted = data;
      acceptedAccount = accountId;
      return {};
    }
    throw StateError('Unexpected invitation request');
  }
}

/// The app in Spanish, signed in on Calendar, with invitations answered by
/// [api]. [link] is an invitation link opened before the app started.
Future<ProviderContainer> _openApp(
  WidgetTester tester,
  _Invitations api, {
  String? link,
  _Storage? storage,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      invitationLinkProvider.overrideWith(
        (ref) => InvitationLinks(storage: storage ?? _Storage(), listen: false),
      ),
      hasProProvider.overrideWithValue(true),
      billingLoadingProvider.overrideWithValue(false),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(const RegionalPreferences(language: 'es')),
      ),
      pendingCapturesProvider.overrideWith((ref) async => []),
      taskListsProvider.overrideWith(
        (ref) async => [
          TaskListInfo(
            id: 'compras',
            name: 'Compras',
            version: 1,
            shared: true,
            role: 'editor',
          ),
        ],
      ),
      groupsProvider.overrideWith((ref) async => []),
      apiClientProvider.overrideWithValue(api),
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
  await tester.pumpAndSettle();
  if (link != null) {
    // The link arrives as the app runs, as app_links and storage deliver it.
    container.read(invitationLinkProvider.notifier).receive(Uri.parse(link));
    await tester.pumpAndSettle();
  }
  return container;
}

/// The server's invitations: answering one removes it.
class _Invitations extends OfflineApiClient {
  _Invitations({this.groups = const [], this.lists = const []});
  List<Map<String, dynamic>> groups;
  List<Map<String, dynamic>> lists;

  /// Each answer sent: its path and body.
  final responses = <List<Object?>>[];

  /// How long an answer takes to come back.
  Duration delay = Duration.zero;

  /// What the server answers instead, when it refuses.
  Object? failure;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'GET' && path == 'group-invitations/') {
      return {
        'invitations': [...groups],
      };
    }
    if (method == 'GET' && path == 'invitations/') {
      return {
        'invitations': [...lists],
      };
    }
    if (method == 'POST' && path.endsWith('/respond/')) {
      responses.add([path, data]);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (failure != null) throw failure!;
      final id = path.split('/')[1];
      final answered = [
        ...groups,
        ...lists,
      ].where((item) => item['id'] == id).firstOrNull;
      groups = groups.where((item) => item['id'] != id).toList();
      lists = lists.where((item) => item['id'] != id).toList();
      return {
        if (answered?['list_id'] != null) 'list_id': answered!['list_id'],
        if (answered?['group_id'] != null) 'group_id': answered!['group_id'],
      };
    }
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// The phone's secure storage, counting deletions.
class _Storage implements FlutterSecureStorage {
  int deletes = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #delete) deletes++;
    if (invocation.memberName == #read) return Future<String?>.value();
    return Future<void>.value();
  }
}
