import 'package:agenda/l10n/region.dart';
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
import 'support/address_wrap.dart';
import 'support/no_counter.dart';
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
          find.text(
            'Signed in as ${breakableAddress('design@example.invalid')}',
          ),
          findsOneWidget,
        );
        if (available) {
          expect(find.text('Staging crew'), findsOneWidget);
          // Editor, the only role it can carry, goes without saying.
          expect(find.text('Editor'), findsNothing);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(api.accepted, {'decision': 'accept', 'code': _link.code});
          expect(api.acceptedAccount, 1);
          expect(find.byType(InvitationReviewScreen), findsNothing);
        } else {
          expect(find.text('Accept invitation'), findsNothing);
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
        find.text(es.signedInAs(breakableAddress('design@example.invalid'))),
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
        expect(
          es.invitationCodeWrong,
          'Pide a quien te invitó el código actual.',
        );
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
      final problem = requestProblemText(es, failure, keptNote: false);
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

  // ---- P80 (UX-326): the invitation says who sent it ----

  const anaInvitation = {...comprasInvitation, 'invited_by_name': 'Ana'};
  const comprasLink = 'taskflow://invite?kind=list&id=$listId&code=$code';

  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
      'UX-326: ($language) with invited_by_name Ana, Calendar’s card and the review screen name Ana',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final api = _Invitations(lists: [anaInvitation]);
        await _openApp(tester, api, language: language);
        final named = find.text(l.invitedByTo('Ana', 'Compras'));
        expect(l.invitedByTo('Ana', 'Compras'), contains('Ana'));
        expect(l.invitedByTo('Ana', 'Compras'), contains('Compras'));
        expect(named.hitTestable(), findsOneWidget);
        expect(find.text(l.invitedTo('Compras')), findsNothing);

        // The review screen, opened from the emailed link.
        await tester.pumpWidget(const SizedBox());
        await _openApp(
          tester,
          _Invitations(lists: [anaInvitation]),
          language: language,
          link: comprasLink,
        );
        expect(find.byType(InvitationReviewScreen), findsOneWidget);
        final headline = l.invitationFrom('Ana', 'Compras');
        expect(headline, contains('Ana'));
        expect(headline, contains('Compras'));
        expect(
          find.descendant(
            of: find.byType(InvitationReviewScreen),
            matching: find.text(headline),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-326: a group invitation with invited_by_name Ana names Ana on Calendar’s card',
    (tester) async {
      final api = _Invitations(
        groups: [
          {...familiaInvitation, 'invited_by_name': 'Ana'},
        ],
      );
      await _openApp(tester, api);
      expect(find.text(es.invitedByTo('Ana', 'Familia')), findsOneWidget);
      expect(card('Familia'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (label, sender) in [
    ('null', null),
    ('missing', 'missing'),
    ('blank', '  '),
  ]) {
    testWidgets(
      'UX-326: with invited_by_name $label, the card and the review screen keep today’s wording',
      (tester) async {
        final invitation = <String, dynamic>{...comprasInvitation};
        if (sender != 'missing') invitation['invited_by_name'] = sender;
        await _openApp(tester, _Invitations(lists: [invitation]));
        expect(card('Compras'), findsOneWidget);
        expect(find.text(es.invitedByTo('', 'Compras')), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await _openApp(
          tester,
          _Invitations(lists: [invitation]),
          link: comprasLink,
        );
        final review = find.byType(InvitationReviewScreen);
        expect(review, findsOneWidget);
        expect(
          find.descendant(of: review, matching: find.text('Compras')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: review,
            matching: find.textContaining(es.invitationFrom('', 'Compras')),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P78 (UX-487): ‘Ahora no’ is remembered across restarts ----

  testWidgets(
    'UX-487: a stored invitation not yet answered reopens the review on a cold start',
    (tester) async {
      final storage = _MemoryStorage();
      await _openApp(
        tester,
        _Invitations(lists: [comprasInvitation]),
        link: comprasLink,
        storage: storage,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(storage.values, isNotEmpty);
      // The app is killed with the review open, then started again.
      await tester.pumpWidget(const SizedBox());
      await _openApp(
        tester,
        _Invitations(lists: [comprasInvitation]),
        storage: storage,
        restore: true,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-487: after Ahora no, a restart from the same storage stays on Calendar, whose card still offers the invitation with its code',
    (tester) async {
      final storage = _MemoryStorage();
      await _openApp(
        tester,
        _Invitations(lists: [comprasInvitation]),
        link: comprasLink,
        storage: storage,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      await tester.tap(find.text(es.invitationNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(storage.values, isNotEmpty);

      // Force-stop and reopen: a fresh container over the same storage.
      await tester.pumpWidget(const SizedBox());
      final api = _Invitations(lists: [comprasInvitation]);
      final container = await _openApp(
        tester,
        api,
        storage: storage,
        restore: true,
      );
      expect(container.read(invitationLinkProvider), isNotNull);
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(card('Compras').hitTestable(), findsOneWidget);
      await tester.tap(card('Compras'));
      await tester.pumpAndSettle();
      expect(codeInField(tester), code);
      expect(api.responses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-487: opening the invitation link again after Ahora no opens the review, in the same session and after a restart',
    (tester) async {
      final storage = _MemoryStorage();
      final container = await _openApp(
        tester,
        _Invitations(lists: [comprasInvitation]),
        link: comprasLink,
        storage: storage,
      );
      await tester.tap(find.text(es.invitationNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsNothing);
      // The same link, tapped again in the email.
      container
          .read(invitationLinkProvider.notifier)
          .receive(Uri.parse(comprasLink));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      await tester.tap(find.text(es.invitationNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsNothing);

      // After a restart, the postponed invitation stays quiet until its
      // link is opened again.
      await tester.pumpWidget(const SizedBox());
      final restarted = await _openApp(
        tester,
        _Invitations(lists: [comprasInvitation]),
        storage: storage,
        restore: true,
      );
      expect(find.byType(InvitationReviewScreen), findsNothing);
      restarted
          .read(invitationLinkProvider.notifier)
          .receive(Uri.parse(comprasLink));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-19-app, round 1 · P182 (UX-1509): a dead invitation
  // closes; the access line says what a role other than editor means ----

  test('UX-1509: Cerrar and the two access lines read as the plan wrote them '
      'in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect([en.close, es.close, ca.close], ['Close', 'Cerrar', 'Tanca']);
    expect(en.invitationViewerAccess, 'You’ll be able to see it, not change it.');
    expect(es.invitationViewerAccess, 'Solo podrás verlo, no cambiarlo.');
    expect(ca.invitationViewerAccess, 'Només el podràs veure, no canviar.');
    expect(en.invitationAdminAccess, 'You’ll be able to manage the group.');
    expect(es.invitationAdminAccess, 'Podrás gestionar el grupo.');
    expect(ca.invitationAdminAccess, 'Podràs gestionar el grup.');
  });

  Finder inReview(Finder finder) =>
      find.descendant(of: find.byType(InvitationReviewScreen), matching: finder);

  testWidgets(
    'UX-1509: an invitation answered 404 shows no Reintentar and no Ahora no, one Cerrar, which closes the screen and clears the stored link',
    (tester) async {
      final storage = _MemoryStorage();
      final container = await _openApp(
        tester,
        _Invitations(),
        link: comprasLink,
        storage: storage,
      );
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(storage.values, isNotEmpty, reason: 'the link is stored');
      expect(inReview(find.text(es.tryAgain)), findsNothing);
      expect(inReview(find.text(es.invitationNotNow)), findsNothing);
      expect(inReview(find.text(es.acceptInvitation)), findsNothing);
      final close = find.ancestor(
        of: inReview(find.text(es.close)),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(close, findsOneWidget);
      expect(
        inReview(
          find.byWidgetPredicate(
            (w) => w is FilledButton || w is OutlinedButton || w is TextButton,
          ),
        ),
        findsOneWidget,
        reason: 'one button below the message',
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(container.read(invitationLinkProvider), isNull);
      expect(storage.values, isEmpty, reason: 'the stored link is cleared');
      // A restart doesn't bring it back.
      await tester.pumpWidget(const SizedBox());
      await _openApp(tester, _Invitations(), storage: storage, restore: true);
      expect(find.byType(InvitationReviewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1509: an invitation that can’t load offline still offers Reintentar and Ahora no, and no Cerrar',
    (tester) async {
      await _openApp(tester, _OfflineInvitations(), link: comprasLink);
      expect(find.byType(InvitationReviewScreen), findsOneWidget);
      expect(inReview(find.text(es.tryAgain)), findsOneWidget);
      expect(inReview(find.text(es.invitationNotNow)), findsOneWidget);
      expect(inReview(find.text(es.close)), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, scale) in [('es', 1.0), ('ca', 2.0)]) {
    testWidgets(
      'UX-1509: ($language, ${scale}x, 360x800) Ana’s editor invitation to Compras has no access line',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _openApp(
          tester,
          _Invitations(lists: [anaInvitation]),
          language: language,
          link: comprasLink,
        );
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        expect(find.byType(InvitationReviewScreen), findsOneWidget);
        expect(inReview(find.text(l.invitationFrom('Ana', 'Compras'))),
            findsOneWidget);
        for (final gone in [
          l.roleEditor,
          l.invitationViewerAccess,
          l.invitationAdminAccess,
          if (language == 'es') 'Acceso' else 'Accés',
        ]) {
          expect(inReview(find.text(gone)), findsNothing, reason: gone);
        }
        expect(inReview(find.text(l.acceptInvitation)), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  for (final (role, line) in [
    ('viewer', es.invitationViewerAccess),
    ('admin', es.invitationAdminAccess),
  ]) {
    testWidgets(
      'UX-1509: a group invitation with the $role role says «$line» and not the role’s name',
      (tester) async {
        await _openApp(
          tester,
          _Invitations(groups: [{...familiaInvitation, 'role': role}]),
          link:
              'taskflow://invite?kind=group&id=${familiaInvitation['id']}&code=$code',
        );
        expect(find.byType(InvitationReviewScreen), findsOneWidget);
        expect(inReview(find.text('Familia')), findsOneWidget);
        expect(inReview(find.text(line)), findsOneWidget);
        expect(inReview(find.text(es.roleViewer)), findsNothing);
        expect(inReview(find.text(es.groupAdmin)), findsNothing);
        expect(inReview(find.text('Acceso')), findsNothing);
        expect(inReview(find.text(es.acceptInvitation)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('P284 · invitation page', () {
    // Measure wrapping in the app's own font, not the square test font.
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    /// The button whose label is [label], on the invitation page.
    Finder button(String label) => find.ancestor(
      of: inReview(find.text(label)),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

    void expectApart(WidgetTester tester, Finder upper, Finder lower) {
      expect(upper, findsOneWidget);
      expect(lower, findsOneWidget);
      final a = tester.getRect(upper);
      final b = tester.getRect(lower);
      expect(
        b.top - a.bottom,
        greaterThanOrEqualTo(7.99),
        reason: 'the buttons stand ${(b.top - a.bottom).toStringAsFixed(1)} dp apart',
      );
    }

    testWidgets(
      'UX-2511: the offline invitation page reads «No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.» with nothing after it',
      (tester) async {
        const network =
            'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.';
        expect(es.requestError('network'), network);
        await _openApp(tester, _OfflineInvitations(), link: comprasLink);
        expect(find.byType(InvitationReviewScreen), findsOneWidget);
        expect(inReview(find.text(network)), findsOneWidget);
        expect(
          inReview(find.textContaining('Tus tareas siguen guardadas')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2518: (es, ${scale}x, 360x800) «Aceptar invitación» and «Ahora no» stand 8 dp or more apart',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _openApp(
            tester,
            _Invitations(lists: [anaInvitation]),
            link: comprasLink,
          );
          tester.view.physicalSize = const Size(360, 800);
          await tester.pumpAndSettle();
          expect(find.byType(InvitationReviewScreen), findsOneWidget);
          expectApart(
            tester,
            button(es.acceptInvitation),
            button(es.invitationNotNow),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-2518: (es, ${scale}x, 360x800) offline, «Reintentar» and «Ahora no» stand 8 dp or more apart',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _openApp(tester, _OfflineInvitations(), link: comprasLink);
          tester.view.physicalSize = const Size(360, 800);
          await tester.pumpAndSettle();
          expect(find.byType(InvitationReviewScreen), findsOneWidget);
          expectApart(
            tester,
            button(es.tryAgain),
            button(es.invitationNotNow),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-2513: (es, ${scale}x, 360x800) «Sesión iniciada como …» wraps the address only after «@» or «.», and TalkBack reads it whole',
        (tester) async {
          final semantics = tester.ensureSemantics();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _openApp(
            tester,
            _Invitations(lists: [anaInvitation]),
            link: comprasLink,
          );
          tester.view.physicalSize = const Size(360, 800);
          await tester.pumpAndSettle();
          const address = 'design@example.invalid';
          final line = inReview(
            find.text(es.signedInAs(breakableAddress(address))),
          );
          expect(line, findsOneWidget);
          expectAddressWrapsWhole(tester, line, address);
          expect(spokenLabel(tester, line), es.signedInAs(address));
          expect(tester.getRect(line).right, lessThanOrEqualTo(360.5));
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('P285 · invitation code shows no counter', () {
    testWidgets(
      'UX-2505: the join dialog’s code field shows no 0/128 or 43/128 counter, reads out no Quedan … caracteres, and still stops at 128',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openApp(tester, _Invitations(lists: [comprasInvitation]));
        await tester.tap(card('Compras'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final field = find.descendant(
          of: dialog,
          matching: find.byKey(const ValueKey('accept-invitation-code')),
        );
        expect(field, findsOneWidget);
        // A link's code is 43 characters: it would have read «43/128».
        await tester.enterText(field, 'c' * 43);
        await tester.pump();
        expect(find.text('43/128'), findsNothing);
        expect(
          find.descendant(of: dialog, matching: find.textContaining(counterText)),
          findsNothing,
        );
        expect(find.bySemanticsLabel(counterSpeech), findsNothing);
        await tester.enterText(field, '');
        await tester.pump();
        await expectNoCounter(tester, 128);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// The server can't be reached: every request fails as offline.
class _OfflineInvitations extends _Invitations {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async => throw ApiException(0, 'Offline. Retry when connected.');
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
  FlutterSecureStorage? storage,
  String language = 'es',
  // Reads the stored invitation back, as a cold start does.
  bool restore = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      invitationLinkProvider.overrideWith(
        (ref) => InvitationLinks(
          storage: storage ?? _Storage(),
          listen: false,
          restore: restore,
        ),
      ),
      hasProProvider.overrideWithValue(true),
      billingLoadingProvider.overrideWithValue(false),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(RegionalPreferences(language: language)),
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

/// The phone's secure storage, keeping what is written, as it survives a
/// restart.
class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          values.remove(key);
        } else {
          values[key!] = value;
        }
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
    }
    return Future<void>.value();
  }
}
