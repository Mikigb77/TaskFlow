// Deleting the account from the app (Backend/docs/ACCOUNT_DELETION.md):
// the Account screen's last row, the delete page, and what is left on the
// phone afterwards.
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/archive_diagnostic.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/screens/delete_account_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/services/account_deletion.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/archive_files.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/services/site_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show CustomerInfo;

import 'support/billing_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/reading_order.dart';
import 'support/shown_text.dart';
import 'support/address_wrap.dart';

final es = lookupAppLocalizations(const Locale('es'));
const password = 'synthetic-only-password';
const invite =
    'taskflow://invite?kind=list&id=0b9f6c2e-3d4a-4f5b-8c6d-7e8f9a0b1c2d&code=Fixture_Invite_Code_123';

Map<String, dynamic> previewJson({
  int tasks = 12,
  int notes = 3,
  int files = 2,
  int projects = 1,
  int groups = 0,
  int kept = 4,
  // Absent unless given, as from a server older than kept_files_in_shared.
  int? keptFiles,
  List<Map<String, dynamic>> handovers = const [
    {'kind': 'project', 'id': 'p-1', 'name': 'Casa', 'to': 'Ana'},
    {'kind': 'group', 'id': 'g-1', 'name': 'Matemáticas', 'to': 'Luis'},
  ],
  bool pro = false,
  String reauth = 'password',
  String? plan = 'plan-1',
}) => {
  'personal': {
    'tasks': tasks,
    'notes': notes,
    'files': files,
    'projects': projects,
    'groups': groups,
  },
  'kept_in_shared': kept,
  if (keptFiles != null) 'kept_files_in_shared': keptFiles,
  'handovers': handovers,
  'pro': pro,
  'reauth': reauth,
  if (plan != null) 'plan': plan,
};

/// The server's side of deleting: the preview, then the confirmation.
class _DeletionApi extends OfflineApiClient {
  _DeletionApi(this.preview);
  Map<String, dynamic> preview;
  Object? previewError;
  Completer<void>? holdPreview;
  Object? deleteError;
  Completer<void>? holdDelete;
  final requests = <(String, String, Map<String, dynamic>?, int?)>[];

  int count(String method) =>
      requests.where((request) => request.$1 == method).length;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    requests.add((method, path, data, accountId));
    if (path != 'auth/delete-account/') {
      throw ApiException(0, ApiClient.offlineMessage);
    }
    if (method == 'GET') {
      await holdPreview?.future;
      if (previewError != null) throw previewError!;
      return preview;
    }
    await holdDelete?.future;
    if (deleteError != null) throw deleteError!;
    return null; // 204
  }
}

/// Google sign-in on the phone: each tap takes the next answer, a token,
/// null (closed without choosing) or an error.
class _Google extends GoogleSignInService {
  final answers = <Object?>[];
  int calls = 0, signOuts = 0;
  @override
  bool get supported => true;
  @override
  bool get configured => true;
  @override
  Future<String?> authenticate() async {
    calls++;
    final answer = answers.isEmpty ? null : answers.removeAt(0);
    if (answer is Exception) throw answer;
    return answer as String?;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

class _Auth extends AuthNotifier {
  _Auth(
    super.api, {
    super.google,
    required super.activateReminders,
    super.prepareErase,
    this.complimentary = false,
    this.email = 'ana@example.invalid',
    this.googleLinked = false,
  });
  final bool complimentary;
  final String email;
  final bool googleLinked;
  @override
  Future<void> restore() async {
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': email,
        'timezone': 'Europe/Madrid',
        'complimentary_pro': complimentary,
        'google_linked': googleLinked,
      }),
    );
  }
}

/// Notes the erase instead of touching the phone; the real one is tested
/// against SQLite in account_erase_test.dart.
class _Erase extends LocalAccountData {
  _Erase(this.log) : super(TaskDatabase());
  final List<String> log;
  @override
  Future<void> erase(String owner) async => log.add('erase $owner');
}

/// Notes when deletion waits for a sync already under way.
class _Tasks extends MemoryTasks {
  _Tasks(this.log);
  final List<String> log;
  @override
  Future<void> get settled async => log.add('settled');
}

/// Syncs as the real one starts: by asking for the account's projects.
class _SyncingTasks extends _Tasks {
  _SyncingTasks(super.log, this.api);
  final ApiClient api;
  @override
  Future<void> sync() async {
    try {
      await api.request('GET', 'lists/access/', accountId: 1);
    } on ApiException {
      syncError = 'Saved on this phone.';
    }
  }
}

/// The phone's tasks as an export file, without SQLite.
class _Archive extends ArchiveStore {
  _Archive() : super(TaskDatabase(), 'local');
  static const contents = '{"format":"taskflow"}';
  int exports = 0;
  Object? error;
  @override
  Future<String> export() async {
    exports++;
    if (error != null) throw error!;
    return contents;
  }
}

/// Android's save screen: saved (true), backed out of (false), or an error.
class _SaveScreen extends ArchiveFiles {
  final saved = <String>[];
  bool answer = true;
  Object? error;
  @override
  Future<bool> save(String contents) async {
    saved.add(contents);
    if (error != null) throw error!;
    return answer;
  }
}

class _Phone {
  _Phone(Map<String, dynamic> preview) : api = _DeletionApi(preview);
  final _DeletionApi api;
  final google = _Google();
  final archive = _Archive();
  final saveScreen = _SaveScreen();
  final billing = FakeRevenueCat();
  late final subscription = SubscriptionController(
    billing,
    const BillingConfiguration(apiKey: 'test_fixture', supported: true),
  );
  final log = <String>[];
  final opened = <Uri>[];
  bool opens = true;
  late final ProviderContainer container;
  String get owner => '${api.baseUrl}/users/1';
  AuthState get auth => container.read(authProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  /// Account, with the delete page on top unless [onAccount].
  Future<_Phone> open(
    WidgetTester tester, {
    Map<String, dynamic>? preview,
    String language = 'es',
    double textScale = 1,
    bool dark = false,
    Size size = const Size(390, 1600),
    bool onAccount = false,
    bool complimentary = false,
    CustomerInfo? purchases,
    String email = 'ana@example.invalid',
    bool googleLinked = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final phone = _Phone(preview ?? previewJson());
    // Billing stays not ready unless the test gives it the store's purchases.
    if (purchases != null) {
      phone.billing.info = purchases;
      await phone.subscription.setIdentity('owner', () async => 'owner-id');
    }
    phone.container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(phone.api),
        googleSignInServiceProvider.overrideWithValue(phone.google),
        authProvider.overrideWith(
          (ref) => _Auth(
            phone.api,
            google: phone.google,
            activateReminders: (owner) async =>
                phone.log.add('reminders $owner'),
            // As the app wires it.
            prepareErase: (id) => prepareAccountErase(ref.read, id),
            complimentary: complimentary,
            email: email,
            googleLinked: googleLinked,
          ),
        ),
        subscriptionProvider.overrideWith((_) => phone.subscription),
        billingConfigurationProvider.overrideWithValue(
          phone.subscription.configuration,
        ),
        taskRepositoryProvider.overrideWithValue(_Tasks(phone.log)),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        localAccountDataProvider.overrideWithValue(_Erase(phone.log)),
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        openWebPageProvider.overrideWithValue((uri) async {
          phone.opened.add(uri);
          return phone.opens;
        }),
        archiveStoreProvider.overrideWithValue(phone.archive),
        archiveFilesProvider.overrideWithValue(phone.saveScreen),
      ],
    );
    addTearDown(phone.container.dispose);
    addTearDown(phone.api.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: phone.container,
        child: MaterialApp(
          locale: Locale(language),
          theme: dark ? AppTheme.dark : AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const AccountScreen(),
          routes: {
            '/deleteAccount': (_) => const DeleteAccountScreen(),
            '/dataTransfer': (_) => const DataTransferScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!onAccount) {
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/deleteAccount');
      await tester.pumpAndSettle();
    }
    return phone;
  }

  /// Frames for a page whose spinner never settles.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final confirm = find.byKey(const ValueKey('delete-account-confirm'));
  final passwordField = find.byKey(const ValueKey('delete-account-password'));
  final googleButton = find.byKey(const ValueKey('delete-account-google'));
  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(confirm).onPressed != null;
  String? fieldError(WidgetTester tester) =>
      tester.widget<TextField>(passwordField).decoration!.errorText;

  /// Scrolls [target] into view, building it first if it is far below.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
  }

  /// The last request: [method] to auth/delete-account/ for account 1.
  void sentLast(_Phone phone, String method, Map<String, dynamic>? data) {
    final (sentMethod, path, body, account) = phone.api.requests.last;
    expect(sentMethod, method);
    expect(path, 'auth/delete-account/');
    expect(body, data);
    expect(account, 1);
  }

  // ---- The Account screen ----

  testWidgets(
    'Eliminar cuenta is the Account screen’s last row, red like Cerrar sesión, and opens the delete page',
    (tester) async {
      final phone = await open(tester, onAccount: true);
      final row = find.byKey(const ValueKey('account-delete'));
      expect(row, findsOneWidget);
      final label = find.descendant(
        of: row,
        matching: find.text(es.deleteAccount),
      );
      expect(label, findsOneWidget);
      final signOut = find.ancestor(
        of: find.text(es.signOut),
        matching: find.byType(TextButton),
      );
      final colors = Theme.of(tester.element(row)).colorScheme;
      expect(tester.widget<Text>(label).style!.color, colors.error);
      expect(
        tester.widget<Text>(find.text(es.signOut)).style!.color,
        colors.error,
        reason: 'the same destructive style',
      );
      expect(
        tester.getTopLeft(row).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(signOut).dy),
      );
      for (final button in tester.widgetList<ButtonStyleButton>(
        find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      )) {
        expect(
          tester.getTopLeft(find.byWidget(button)).dy,
          lessThanOrEqualTo(tester.getTopLeft(row).dy),
          reason: 'nothing comes after it',
        );
      }
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text(es.deleteAccountQuestion), findsOneWidget);
      expect(phone.api.requests, hasLength(1));
      sentLast(phone, 'GET', null);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- What the page says ----

  testWidgets(
    'the page says, in order: the title, the account, what deleting does, the counts, what stays for the others with each handover, the copy link, the password and the red button',
    (tester) async {
      await open(tester);
      final order = [
        find.text(es.deleteAccountQuestion),
        findShown('ana@example.invalid'),
        find.text(
          'Se eliminarán tu cuenta de TaskFlow y tus tareas, notas y archivos en todos tus dispositivos. No se puede deshacer.',
        ),
        find.text(es.deleteAccountWhatGoes),
        find.text('12 tareas'),
        find.text('3 notas'),
        find.text('2 archivos'),
        find.text('1 proyecto'),
        find.text('Lo que se queda para los demás:'),
        find.text(
          '4 tareas que añadiste a proyectos compartidos, sin tu nombre',
        ),
        find.text('El proyecto «Casa» pasará a Ana'),
        find.text('El grupo «Matemáticas» y sus proyectos pasarán a Luis'),
        find.text(es.deleteAccountSaveCopy),
        find.text(es.deleteAccountPasswordHelp),
        passwordField,
        confirm,
      ];
      var top = double.negativeInfinity;
      for (final item in order) {
        expect(item, findsOneWidget);
        final y = tester.getTopLeft(item).dy;
        expect(y, greaterThan(top), reason: '$item');
        top = y;
      }
      // No groups to delete: no line for them. No Pro: no subscription line.
      expect(find.textContaining('grupos'), findsNothing);
      expect(find.text(es.deleteAccountSubscription), findsNothing);
      expect(
        find.byKey(const ValueKey('delete-account-manage-subscription')),
        findsNothing,
      );
      expect(find.byType(GoogleLoginButton), findsNothing);
      expect(
        find.descendant(of: confirm, matching: find.text('Eliminar mi cuenta')),
        findsOneWidget,
      );
      final colors = Theme.of(tester.element(confirm)).colorScheme;
      expect(
        tester
            .widget<FilledButton>(confirm)
            .style!
            .backgroundColor!
            .resolve({}),
        colors.error,
      );
      expect(enabled(tester), isFalse, reason: 'not before the password');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one task kept for the others reads in the singular under its own heading, and with nothing of their own to delete there is no first list',
    (tester) async {
      await open(
        tester,
        preview: previewJson(
          tasks: 0,
          notes: 0,
          files: 0,
          projects: 0,
          kept: 1,
          handovers: [],
        ),
      );
      expect(find.text(es.deleteAccountWhatStays), findsOneWidget);
      expect(
        find.text(
          '1 tarea que añadiste a proyectos compartidos, sin tu nombre',
        ),
        findsOneWidget,
      );
      expect(find.text(es.deleteAccountWhatGoes), findsNothing);
      expect(find.textContaining('pasará a'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'with Pro, the page says in plain weight that deleting doesn’t cancel a Google Play subscription; Gestionar suscripción opens Google Play’s subscriptions page while billing knows of no purchase',
    (tester) async {
      final phone = await open(tester, preview: previewJson(pro: true));
      final line = find.text(
        'Si pagas TaskFlow Pro en Google Play, eliminar tu cuenta no cancela la suscripción.',
      );
      expect(line, findsOneWidget);
      expect(
        tester.widget<Text>(line).style?.fontWeight,
        isNot(FontWeight.w700),
      );
      final link = find.byKey(
        const ValueKey('delete-account-manage-subscription'),
      );
      expect(
        find.descendant(of: link, matching: find.text('Gestionar suscripción')),
        findsOneWidget,
      );
      // Before the copy link and the password.
      expect(
        tester.getTopLeft(link).dy,
        lessThan(tester.getTopLeft(find.text(es.deleteAccountSaveCopy)).dy),
      );
      await tapVisible(tester, link);
      await tester.pumpAndSettle();
      expect(
        phone.opened.single.toString(),
        'https://play.google.com/store/account/subscriptions',
      );
      expect(phone.billing.centers, 0);

      // Nothing could open it: say so briefly.
      phone.opens = false;
      await tapVisible(tester, link);
      await tester.pumpAndSettle();
      expect(find.text(es.webPageOpenError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Guardar antes una copia de tus tareas saves the export file from the page itself; once saved, Copia guardada takes its place',
    (tester) async {
      final phone = await open(tester);
      final link = find.byKey(const ValueKey('delete-account-export'));
      expect(find.text(es.deleteAccountCopyNoFiles), findsOneWidget);
      await tapVisible(tester, link);
      await tester.pumpAndSettle();
      expect(phone.archive.exports, 1);
      expect(phone.saveScreen.saved, [_Archive.contents]);
      expect(find.byType(DataTransferScreen), findsNothing);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(link, findsNothing);
      expect(find.text(es.deleteAccountCopySaved), findsOneWidget);
      expect(find.text(es.deleteAccountCopyNoFiles), findsOneWidget);
      expect(find.text(es.exportSaved), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the preview shows a spinner while loading; failing or offline, it says so with Reintentar, which loads it again',
    (tester) async {
      final phone = await open(tester, onAccount: true);
      // The answer is slow, then the phone turns out to be offline.
      phone.api
        ..holdPreview = Completer<void>()
        ..previewError = ApiException(0, ApiClient.offlineMessage);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/deleteAccount');
      await frames(tester);
      expect(
        find.descendant(
          of: find.byType(DeleteAccountScreen),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(passwordField, findsNothing);
      expect(confirm, findsNothing);
      // What it says doesn't wait for the answer.
      expect(find.text(es.deleteAccountIntro), findsOneWidget);

      phone.api.holdPreview!.complete();
      await tester.pumpAndSettle();
      expect(find.text(es.loadFailed), findsOneWidget);
      expect(
        find.text('No se ha podido cargar. Revisa la conexión.'),
        findsOneWidget,
      );
      final retry = find.text(es.retry);
      expect(retry, findsOneWidget);
      expect(es.retry, 'Reintentar');
      expect(confirm, findsNothing);

      phone.api
        ..holdPreview = null
        ..previewError = null;
      final before = phone.api.count('GET');
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(phone.api.count('GET'), before + 1);
      expect(find.text('12 tareas'), findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (missing, preview) in [
    (
      'who receives a project',
      previewJson(
        handovers: [
          {'kind': 'project', 'id': 'p-1', 'name': 'Casa'},
        ],
      ),
    ),
    ('its plan', previewJson(plan: null)),
  ]) {
    testWidgets(
      'an answer without $missing isn’t shown in part: the page says it couldn’t load',
      (tester) async {
        await open(tester, preview: preview);
        expect(find.text(es.loadFailed), findsOneWidget);
        expect(find.text('12 tareas'), findsNothing);
        expect(confirm, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Confirming with the password ----

  testWidgets(
    'with the password: the button waits for it; deleting shows progress in the button and blocks Back; after 204 the account is forgotten, reminders stop, then the phone is erased',
    (tester) async {
      final phone = await open(tester);
      final links = phone.container.read(invitationLinkProvider.notifier);
      links.receive(Uri.parse(invite));
      await tester.pump();
      expect(phone.container.read(invitationLinkProvider), isNotNull);

      expect(enabled(tester), isFalse);
      await tester.enterText(passwordField, password);
      await tester.pump();
      expect(enabled(tester), isTrue);

      phone.api.holdDelete = Completer<void>();
      await tapVisible(tester, confirm);
      await frames(tester);
      final spinner = find.descendant(
        of: confirm,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(
        find.descendant(
          of: confirm,
          matching: find.text(es.deleteAccountDeleting),
        ),
        findsOneWidget,
      );
      expect(enabled(tester), isFalse, reason: 'it can’t be sent twice');
      expect(tester.widget<TextField>(passwordField).enabled, isFalse);
      // The password, with the plan the preview showed.
      sentLast(phone, 'POST', {'password': password, 'plan': 'plan-1'});
      // Back is blocked while the request runs.
      await tester.binding.handlePopRoute();
      await frames(tester);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty, reason: 'nothing happens before the answer');

      phone.api.holdDelete!.complete();
      await frames(tester);
      expect(phone.auth.account, isNull);
      expect(phone.auth.deleted, isTrue);
      expect(phone.google.signOuts, 1);
      // Reminders are cancelled before their records are erased, and a sync
      // under way finishes first.
      expect(phone.log, [
        'reminders signed-out',
        'settled',
        'erase ${phone.owner}',
      ]);
      expect(phone.container.read(invitationLinkProvider), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: 'taskflow.pending-invitation',
        ),
        isNull,
      );
      expect(phone.api.count('POST'), 1);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Confirming with Google ----

  testWidgets(
    'with Google: no password field; Confirmar con Google gets a fresh token, closing Google changes nothing, and the token is what is sent',
    (tester) async {
      final phone = await open(tester, preview: previewJson(reauth: 'google'));
      expect(passwordField, findsNothing);
      expect(
        findShown(
          'Para confirmar, elige ana@example.invalid cuando Google te lo pida. Tu cuenta de Google no se elimina.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: googleButton,
          matching: find.text('Confirmar con Google'),
        ),
        findsOneWidget,
      );
      expect(enabled(tester), isFalse);

      // Closed without choosing an account.
      phone.google.answers.add(null);
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(phone.google.calls, 1);
      expect(googleButton, findsOneWidget);
      expect(enabled(tester), isFalse);

      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(googleButton, findsNothing);
      expect(find.text(es.deleteAccountGoogleConfirmed), findsOneWidget);
      expect(enabled(tester), isTrue);

      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {
        'google_id_token': 'fresh-google-id-token',
        'plan': 'plan-1',
      });
      expect(phone.auth.deleted, isTrue);
      expect(phone.log, [
        'reminders signed-out',
        'settled',
        'erase ${phone.owner}',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a Google sign-in that fails on the phone says so under the button and sends nothing',
    (tester) async {
      final phone = await open(tester, preview: previewJson(reauth: 'google'));
      phone.google.answers.add(const GoogleSignInProblem('google_unavailable'));
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(
        find.text(es.googleSignInError('google_unavailable')),
        findsOneWidget,
      );
      expect(googleButton, findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(phone.api.count('POST'), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'google_reauth_failed names the Google account to choose, under the Google button, and asks for Google again',
    (tester) async {
      final phone = await open(tester, preview: previewJson(reauth: 'google'));
      phone.google.answers.add('other-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      phone.api.deleteError = ApiException(400, 'Google account mismatch.', {
        'code': 'google_reauth_failed',
        'detail': 'Google account mismatch.',
      });
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      final message = findShown(
        'Elige ana@example.invalid, la cuenta de Google con la que entras en TaskFlow.',
      );
      expect(message, findsOneWidget);
      expect(googleButton, findsOneWidget, reason: 'confirm again');
      expect(
        tester.getTopLeft(message).dy,
        greaterThan(tester.getBottomLeft(googleButton).dy),
      );
      expect(
        tester.getTopLeft(message).dy,
        lessThan(tester.getTopLeft(confirm).dy),
      );
      expect(enabled(tester), isFalse);
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX-815: a password account with Google linked ----

  const linkedEmail = 'ana@example.com';

  testWidgets(
    'UX-815: a password account with Google linked shows the password help and field, then «O confirma con Google…» and Confirmar con Google, before the red button',
    (tester) async {
      await open(tester, email: linkedEmail, googleLinked: true);
      final help = find.text(es.deleteAccountPasswordHelp);
      final instead = findShown(es.deleteAccountGoogleInstead(linkedEmail));
      var top = double.negativeInfinity;
      for (final item in [help, passwordField, instead, googleButton, confirm]) {
        expect(item, findsOneWidget, reason: '$item');
        final y = tester.getTopLeft(item).dy;
        expect(y, greaterThan(top), reason: '$item');
        top = y;
      }
      expect(
        tester.getTopLeft(instead).dy - tester.getBottomLeft(passwordField).dy,
        greaterThanOrEqualTo(15.5),
        reason: 'the Google way comes 16 dp after the password section',
      );
      expect(
        find.descendant(
          of: googleButton,
          matching: find.text(es.deleteAccountConfirmGoogle),
        ),
        findsOneWidget,
      );
      expect(findShown(es.deleteAccountGoogleHelp(linkedEmail)), findsNothing);
      expect(find.text(es.deleteAccountGoogleConfirmed), findsNothing);
      expect(enabled(tester), isFalse, reason: 'neither way confirmed yet');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-815: once confirmed with Google, Confirmado con Google shows, the password field goes, Eliminar mi cuenta is enabled, and the request sends google_id_token and plan, no password',
    (tester) async {
      final phone = await open(tester, email: linkedEmail, googleLinked: true);
      // Typed something, then chose Google instead.
      await tester.enterText(passwordField, 'half-remembered');
      await tester.pump();
      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(phone.google.calls, 1);
      expect(find.text(es.deleteAccountGoogleConfirmed), findsOneWidget);
      expect(passwordField, findsNothing);
      expect(find.text(es.deleteAccountPasswordHelp), findsNothing);
      expect(googleButton, findsNothing);
      expect(enabled(tester), isTrue);

      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {
        'google_id_token': 'fresh-google-id-token',
        'plan': 'plan-1',
      });
      expect(phone.api.requests.last.$3!.containsKey('password'), isFalse);
      expect(phone.auth.deleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-815: a password account with Google linked can still confirm with its password, which is what is sent',
    (tester) async {
      final phone = await open(tester, email: linkedEmail, googleLinked: true);
      await tester.enterText(passwordField, password);
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {'password': password, 'plan': 'plan-1'});
      expect(phone.google.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final linked in [true, false]) {
    testWidgets(
      linked
          ? 'UX-815: a wrong password with Google linked names Confirmar con Google'
          : 'UX-815: a wrong password without Google keeps UX-801’s sign-out-and-recover line',
      (tester) async {
        final phone = await open(
          tester,
          email: linkedEmail,
          googleLinked: linked,
        );
        phone.api.deleteError = ApiException(400, 'Wrong password.', {
          'code': 'wrong_password',
          'detail': 'Wrong password.',
        });
        await tester.enterText(passwordField, 'not-the-password');
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        expect(
          fieldError(tester),
          linked
              ? es.deleteAccountWrongPasswordGoogle
              : es.deleteAccountWrongPassword,
        );
        expect(googleButton, linked ? findsOneWidget : findsNothing);
        expect(phone.auth.account, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-815: google_reauth_failed on a password account with Google linked names the account to choose and brings the password field back',
    (tester) async {
      final phone = await open(tester, email: linkedEmail, googleLinked: true);
      phone.google.answers.add('other-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(passwordField, findsNothing);
      phone.api.deleteError = ApiException(400, 'Google account mismatch.', {
        'code': 'google_reauth_failed',
        'detail': 'Google account mismatch.',
      });
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(
        findShown(es.deleteAccountOtherGoogle(linkedEmail)),
        findsOneWidget,
      );
      expect(find.text(es.deleteAccountGoogleConfirmed), findsNothing);
      expect(passwordField, findsOneWidget, reason: 'the password is back');
      expect(find.text(es.deleteAccountPasswordHelp), findsOneWidget);
      expect(googleButton, findsOneWidget, reason: 'or Google again');
      expect(enabled(tester), isFalse);
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty);

      // The password way works again.
      phone.api.deleteError = null;
      await tester.enterText(passwordField, password);
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {'password': password, 'plan': 'plan-1'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-815: an account without Google linked shows no Google button; a Google-only account still shows only the Google way, with its own help line',
    (tester) async {
      await open(tester, email: linkedEmail);
      expect(passwordField, findsOneWidget);
      expect(googleButton, findsNothing);
      expect(find.byType(GoogleLoginButton), findsNothing);
      expect(
        findShown(es.deleteAccountGoogleInstead(linkedEmail)),
        findsNothing,
      );

      await open(
        tester,
        email: linkedEmail,
        googleLinked: true,
        preview: previewJson(reauth: 'google'),
      );
      expect(passwordField, findsNothing);
      expect(find.text(es.deleteAccountPasswordHelp), findsNothing);
      expect(
        findShown(es.deleteAccountGoogleHelp(linkedEmail)),
        findsOneWidget,
      );
      expect(
        findShown(es.deleteAccountGoogleInstead(linkedEmail)),
        findsNothing,
      );
      expect(googleButton, findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-815: the two new lines read as planned in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      en.deleteAccountGoogleInstead('a@b.c'),
      'Or confirm with Google and choose a@b.c. Your Google account isn’t deleted.',
    );
    expect(
      es.deleteAccountGoogleInstead('a@b.c'),
      'O confirma con Google y elige a@b.c. Tu cuenta de Google no se elimina.',
    );
    expect(
      ca.deleteAccountGoogleInstead('a@b.c'),
      'O confirma-ho amb Google i tria a@b.c. El compte de Google no se suprimeix.',
    );
    expect(
      es.deleteAccountWrongPasswordGoogle,
      'La contraseña no es correcta. Si no la recuerdas, toca «Confirmar con Google».',
    );
    // Each names the button as the page shows it.
    for (final l in [en, es, ca]) {
      expect(
        l.deleteAccountWrongPasswordGoogle,
        contains(l.deleteAccountConfirmGoogle),
      );
    }
  });

  // ---- UX-1232: the «O confirma con Google…» line goes once confirmed ----

  /// Any text that offers Google as the alternative to the password,
  /// whatever email it names: the copy up to its email placeholder.
  Finder orConfirmWithGoogle(AppLocalizations l) {
    const marker = '\u0000';
    final full = l.deleteAccountGoogleInstead(marker);
    return find.textContaining(full.substring(0, full.indexOf(marker)));
  }

  testWidgets(
    'UX-1232: before confirming, a password account with Google linked shows the password help, the field, «O confirma con Google…» and Confirmar con Google',
    (tester) async {
      await open(tester, email: linkedEmail, googleLinked: true);
      expect(find.text(es.deleteAccountPasswordHelp), findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(
        findShown(es.deleteAccountGoogleInstead(linkedEmail)),
        findsOneWidget,
      );
      expect(
        findShown(
          'O confirma con Google y elige ana@example.com. Tu cuenta de Google no se elimina.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: googleButton,
          matching: find.text(es.deleteAccountConfirmGoogle),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1232: once confirmed with Google, no «O confirma con Google» text shows; Confirmado con Google stands alone above an enabled Eliminar mi cuenta',
    (tester) async {
      final phone = await open(tester, email: linkedEmail, googleLinked: true);
      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(phone.google.calls, 1);

      expect(orConfirmWithGoogle(es), findsNothing);
      expect(
        find.textContaining('O confirma con Google'),
        findsNothing,
        reason: 'the literal Spanish copy is gone too',
      );
      expect(find.text(es.deleteAccountGoogleConfirmed), findsOneWidget);
      expect(passwordField, findsNothing);
      expect(find.text(es.deleteAccountPasswordHelp), findsNothing);
      expect(
        findShown(es.deleteAccountGoogleHelp(linkedEmail)),
        findsNothing,
        reason: 'no other Google help line takes its place',
      );
      expect(enabled(tester), isTrue);
      expect(
        tester.getTopLeft(find.text(es.deleteAccountGoogleConfirmed)).dy,
        lessThan(tester.getTopLeft(confirm).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1232: a Google confirmation the server refuses with google_reauth_failed brings «O confirma con Google…» back with the password field and names the account to choose',
    (tester) async {
      final phone = await open(tester, email: linkedEmail, googleLinked: true);
      phone.google.answers.add('other-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(orConfirmWithGoogle(es), findsNothing);

      phone.api.deleteError = ApiException(400, 'Google account mismatch.', {
        'code': 'google_reauth_failed',
        'detail': 'Google account mismatch.',
      });
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();

      expect(
        findShown(es.deleteAccountGoogleInstead(linkedEmail)),
        findsOneWidget,
      );
      expect(passwordField, findsOneWidget);
      expect(
        findShown(es.deleteAccountOtherGoogle(linkedEmail)),
        findsOneWidget,
      );
      expect(
        findShown(
          'Elige ana@example.com, la cuenta de Google con la que entras en TaskFlow.',
        ),
        findsOneWidget,
      );
      expect(googleButton, findsOneWidget);
      expect(find.text(es.deleteAccountGoogleConfirmed), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1232: a Google-only account keeps its «Para confirmar, elige…» help before and after confirming, above Confirmado con Google',
    (tester) async {
      final phone = await open(
        tester,
        email: linkedEmail,
        googleLinked: true,
        preview: previewJson(reauth: 'google'),
      );
      final help = findShown(es.deleteAccountGoogleHelp(linkedEmail));
      expect(help, findsOneWidget);
      expect(
        findShown(
          'Para confirmar, elige ana@example.com cuando Google te lo pida. Tu cuenta de Google no se elimina.',
        ),
        findsOneWidget,
      );

      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      final confirmed = find.text(es.deleteAccountGoogleConfirmed);
      expect(confirmed, findsOneWidget);
      expect(help, findsOneWidget, reason: 'unchanged for Google-only');
      expect(
        tester.getTopLeft(help).dy,
        lessThan(tester.getTopLeft(confirmed).dy),
      );
      expect(orConfirmWithGoogle(es), findsNothing);
      expect(enabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- What fails, and that nothing changes then ----

  testWidgets(
    'wrong_password keeps what was typed and says so under the field; typing again clears it',
    (tester) async {
      final phone = await open(tester);
      phone.api.deleteError = ApiException(400, 'Wrong password.', {
        'code': 'wrong_password',
        'detail': 'Wrong password.',
      });
      await tester.enterText(passwordField, 'not-the-password');
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(
        fieldError(tester),
        'La contraseña no es correcta. Si no la recuerdas, cierra sesión y '
        'toca «¿Has olvidado tu contraseña?».',
      );
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        'not-the-password',
      );
      expect(find.byType(MessageBanner), findsNothing);
      expect(enabled(tester), isTrue, reason: 'try again');
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty);
      await tester.enterText(passwordField, password);
      await tester.pump();
      expect(fieldError(tester), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, error, message) in [
    (
      'offline',
      ApiException(0, ApiClient.offlineMessage),
      'Necesitas conexión para eliminar tu cuenta. No se ha eliminado nada.',
    ),
    (
      'throttled',
      ApiException(429, 'Request was throttled.'),
      'Demasiados intentos. Inténtalo más tarde.',
    ),
    (
      'no answer in time',
      ApiException(0, ApiClient.timeoutMessage),
      'No ha llegado respuesta. Revisa la conexión e inténtalo de nuevo.',
    ),
    (
      'a server failure',
      ApiException(500, 'Internal error'),
      'No se ha podido eliminar tu cuenta. Inténtalo más tarde.',
    ),
    (
      'plan_required',
      ApiException(400, 'Plan required.', {
        'code': 'plan_required',
        'detail': 'Plan required.',
      }),
      'No se ha podido eliminar tu cuenta. Inténtalo más tarde.',
    ),
  ]) {
    testWidgets(
      '$name: the page says so under the button, keeps the password, and nothing changes on the phone',
      (tester) async {
        final phone = await open(tester);
        phone.api.deleteError = error;
        await tester.enterText(passwordField, password);
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        final banner = find.widgetWithText(MessageBanner, message);
        expect(banner, findsOneWidget);
        expect(
          tester.getTopLeft(banner).dy,
          greaterThan(tester.getBottomLeft(confirm).dy),
        );
        expect(fieldError(tester), isNull);
        expect(
          tester.widget<TextField>(passwordField).controller!.text,
          password,
        );
        expect(enabled(tester), isTrue, reason: 'try again');
        expect(phone.auth.account, isNotNull);
        expect(phone.auth.deleted, isFalse);
        expect(phone.log, isEmpty);
        expect(phone.google.signOuts, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reauth_required asks to confirm again and loads the page again, in case the way to confirm changed',
    (tester) async {
      final phone = await open(tester);
      phone.api.deleteError = ApiException(400, 'Confirm first.', {
        'code': 'reauth_required',
        'detail': 'Confirm first.',
      });
      // The account turns out to sign in with Google now.
      phone.api.preview = previewJson(reauth: 'google');
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(phone.api.count('GET'), 2);
      expect(find.text('Vuelve a confirmar que eres tú.'), findsOneWidget);
      expect(googleButton, findsOneWidget);
      expect(passwordField, findsNothing);
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan_changed (409): nothing is deleted; the page reloads in place keeping the password, says what changed above the button and in bold in the list, and sends nothing by itself; the next tap sends the new plan',
    (tester) async {
      final phone = await open(tester);
      await tester.enterText(passwordField, password);
      phone.api
        ..deleteError = ApiException(409, 'Plan changed.', {
          'code': 'plan_changed',
          'detail': 'Plan changed.',
        })
        // Ana left Casa meanwhile: it goes to Luis now.
        ..preview = previewJson(
          plan: 'plan-2',
          handovers: [
            {'kind': 'project', 'id': 'p-1', 'name': 'Casa', 'to': 'Luis'},
          ],
        )
        ..holdPreview = Completer<void>();
      await tapVisible(tester, confirm);
      await frames(tester);
      final line = find.text(
        'Algo ha cambiado desde que abriste esta pantalla. Revisa lo que pasará y vuelve a confirmar.',
      );
      // While it reloads, the page stays as it was, and can't be confirmed.
      expect(line, findsOneWidget);
      expect(find.text('El proyecto «Casa» pasará a Ana'), findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(phone.api.count('GET'), 2);

      phone.api.holdPreview!.complete();
      await tester.pumpAndSettle();
      final moved = find.text('El proyecto «Casa» pasará a Luis');
      expect(moved, findsOneWidget);
      expect(find.text('El proyecto «Casa» pasará a Ana'), findsNothing);
      expect(
        tester.widget<Text>(moved).style?.fontWeight,
        FontWeight.w700,
        reason: 'the changed line stands out',
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        password,
      );
      final changed = find.text(
        'Algo ha cambiado desde que abriste esta pantalla:\n'
        '• El proyecto «Casa» pasará a Luis\n'
        'Revísalo y vuelve a confirmar.',
      );
      expect(line, findsNothing);
      expect(changed, findsOneWidget);
      expect(
        tester.getBottomLeft(changed).dy,
        lessThan(tester.getTopLeft(confirm).dy),
        reason: 'above the button',
      );
      expect(
        tester.getTopLeft(changed).dy,
        greaterThan(tester.getBottomLeft(passwordField).dy),
      );
      expect(enabled(tester), isTrue);
      expect(phone.api.count('POST'), 1, reason: 'not sent again by itself');
      expect(phone.auth.account, isNotNull);
      expect(phone.log, isEmpty);
      expect(tester.takeException(), isNull);

      phone.api.deleteError = null;
      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {'password': password, 'plan': 'plan-2'});
      expect(phone.auth.deleted, isTrue);
      expect(phone.log.last, 'erase ${phone.owner}');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan_changed with Google keeps the Google confirmation, so confirming again is one tap',
    (tester) async {
      final phone = await open(tester, preview: previewJson(reauth: 'google'));
      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      phone.api
        ..deleteError = ApiException(409, 'Plan changed.', {
          'code': 'plan_changed',
        })
        ..preview = previewJson(reauth: 'google', plan: 'plan-2');
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(find.text(es.deleteAccountPlanChanged), findsOneWidget);
      expect(find.text(es.deleteAccountGoogleConfirmed), findsOneWidget);
      expect(enabled(tester), isTrue);
      phone.api.deleteError = null;
      await tapVisible(tester, confirm);
      await frames(tester);
      sentLast(phone, 'POST', {
        'google_id_token': 'fresh-google-id-token',
        'plan': 'plan-2',
      });
      expect(phone.google.calls, 1);
      expect(phone.auth.deleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2× text on a 320 dp phone ----

  for (final language in ['es', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets(
        'at 2× text on 320 dp in $language (dark=$dark), the whole page fits its width: Pro, handovers, the password, an error, and the Google variant',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          Future<void> fits(Finder target) async {
            await tester.scrollUntilVisible(
              target,
              120,
              scrollable: find
                  .descendant(
                    of: find.byType(DeleteAccountScreen),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            final rect = tester.getRect(target);
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$target');
            expect(rect.right, lessThanOrEqualTo(320.5), reason: '$target');
          }

          final phone = await open(
            tester,
            language: language,
            dark: dark,
            textScale: 2,
            size: const Size(320, 640),
            preview: previewJson(groups: 2, pro: true),
          );
          for (final text in [
            'ana@example.invalid',
            l.deleteAccountIntro,
            l.deleteAccountTasks(12),
            l.deleteAccountGroups(2),
            l.deleteAccountWhatStays,
            l.deleteAccountKeptShared(4),
            l.deleteAccountHandover('project', 'Casa', 'Ana'),
            l.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
            l.deleteAccountSubscription,
            l.billingManage,
            l.deleteAccountSaveCopy,
            l.deleteAccountCopyNoFiles,
            l.deleteAccountPasswordHelp,
            l.deleteAccountButton,
          ]) {
            await fits(findShown(text));
          }
          await fits(passwordField);
          expect(tester.takeException(), isNull);

          phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
          await tester.enterText(passwordField, password);
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await fits(find.text(l.deleteAccountOffline));
          expect(tester.takeException(), isNull);

          phone.api.deleteError = ApiException(400, 'Wrong password.', {
            'code': 'wrong_password',
          });
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await fits(find.text(l.deleteAccountWrongPassword));
          expect(tester.takeException(), isNull);

          phone.api.deleteError = ApiException(409, 'Plan changed.', {
            'code': 'plan_changed',
          });
          await tester.enterText(passwordField, password);
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await fits(find.text(l.deleteAccountPlanChanged));
          await fits(find.text(l.deleteAccountButton));
          expect(tester.takeException(), isNull);

          final google = await open(
            tester,
            language: language,
            dark: dark,
            textScale: 2,
            size: const Size(320, 640),
            preview: previewJson(reauth: 'google'),
          );
          await fits(
            findShown(l.deleteAccountGoogleHelp('ana@example.invalid')),
          );
          await fits(find.text(l.deleteAccountConfirmGoogle));
          google.google.answers.add('fresh-google-id-token');
          await tapVisible(tester, googleButton);
          await tester.pumpAndSettle();
          await fits(find.text(l.deleteAccountGoogleConfirmed));
          google.api.deleteError = ApiException(400, 'Mismatch.', {
            'code': 'google_reauth_failed',
          });
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await fits(
            findShown(l.deleteAccountOtherGoogle('ana@example.invalid')),
          );
          await fits(find.text(l.deleteAccountConfirmGoogle));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'at 2× text on 320 dp in $language, the Account screen’s Eliminar cuenta row fits, last',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await open(
          tester,
          onAccount: true,
          language: language,
          textScale: 2,
          size: const Size(320, 640),
        );
        final row = find.byKey(const ValueKey('account-delete'));
        await tester.scrollUntilVisible(
          row,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.text(l.deleteAccount)),
          findsOneWidget,
        );
        final rect = tester.getRect(row);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(
          rect.top,
          greaterThan(tester.getRect(find.text(l.signOut)).bottom),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'at 2× text on 320 dp in $language, sign-in after deleting shows the notice within the screen, until the next try',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l = lookupAppLocalizations(Locale(language));
        final api = OfflineApiClient();
        addTearDown(api.close);
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => _DeletedAuth(api)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(language),
              theme: AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final notice = find.text(l.accountDeleted);
        expect(notice, findsOneWidget);
        final rect = tester.getRect(notice);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(rect.bottom, lessThanOrEqualTo(640), reason: 'seen on arrival');
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text(l.createAnAccount));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.createAnAccount));
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- The whole app ----

  final user = {
    'id': 1,
    'email': 'ana@example.invalid',
    'timezone': 'Europe/Madrid',
  };
  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  /// The whole app, signed in from a saved session, on a real ApiClient whose
  /// requests are noted in [sent]. [answer] answers what it knows (null for
  /// the rest, which get the usual empty answers).
  Future<(ProviderContainer, ApiClient)> openApp(
    WidgetTester tester, {
    required List<String> sent,
    required List<String> log,
    Future<http.Response?> Function(http.Request request, String path)? answer,
    TaskRepository Function(ApiClient api)? tasks,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode({
        'access': 'old-access',
        'refresh': 'old-refresh',
        'user': user,
      }),
    });
    final api = ApiClient(
      transport: MockClient((request) async {
        final path = request.url.path.replaceFirst('/api/', '');
        sent.add('${request.method} $path');
        final answered = await answer?.call(request, path);
        if (answered != null) return answered;
        if (path == 'auth/me/') return json(user);
        if (path.endsWith('invitations/')) return json({'invitations': []});
        if (path == 'notifications/unread/') return json({'count': 0});
        return json({'results': [], 'next': null});
      }),
    );
    addTearDown(api.close);
    final google = _Google();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        googleSignInServiceProvider.overrideWithValue(google),
        authProvider.overrideWith(
          (ref) => AuthNotifier(
            api,
            google: google,
            activateReminders: (owner) async => log.add('reminders $owner'),
            prepareErase: (id) => prepareAccountErase(ref.read, id),
          ),
        ),
        taskRepositoryProvider.overrideWithValue(
          tasks?.call(api) ?? _Tasks(log),
        ),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        pendingCapturesProvider.overrideWith((ref) async => []),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(const RegionalPreferences(language: 'es')),
        ),
        localAccountDataProvider.overrideWithValue(_Erase(log)),
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    return (container, api);
  }

  testWidgets(
    'in the app: confirming again after a lost answer, the server no longer knows the account: sign-in says it was deleted, with no error on the way',
    (tester) async {
      final sent = <String>[];
      final log = <String>[];
      final (container, api) = await openApp(
        tester,
        sent: sent,
        log: log,
        answer: (request, path) async {
          if (path != 'auth/delete-account/') return null;
          if (request.method == 'GET') return json(previewJson());
          // The first try was deleted, but its answer never arrived.
          return json({
            'detail': 'User not found',
            'code': 'user_not_found',
          }, 401);
        },
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/deleteAccount');
      await tester.pumpAndSettle();
      // On a phone-sized screen the field is below the fold.
      await tester.scrollUntilVisible(
        passwordField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Tu cuenta se ha eliminado.'), findsOneWidget);
      expect(find.text(es.deleteAccountFailed), findsNothing);
      final owner = '${api.baseUrl}/users/1';
      expect(log, [
        'reminders $owner',
        'reminders signed-out',
        'settled',
        'erase $owner',
      ]);
      expect(sent.last, 'POST auth/delete-account/');
      expect(container.read(authProvider).deleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'in the app: when the account was deleted on another phone, the next sync lands on sign-in saying so, with this phone’s copy erased and nothing more sent',
    (tester) async {
      final sent = <String>[];
      final log = <String>[];
      var deleted = false;
      final (container, api) = await openApp(
        tester,
        sent: sent,
        log: log,
        // Once deleted, the server no longer knows the token's account.
        answer: (request, path) async =>
            deleted && request.headers['Authorization'] != null
            ? json({'detail': 'User not found', 'code': 'user_not_found'}, 401)
            : null,
        tasks: (api) => _SyncingTasks(log, api),
      );
      final owner = '${api.baseUrl}/users/1';
      expect(log, ['reminders $owner']);

      deleted = true;
      final before = sent.length;
      await container.read(taskRepositoryProvider).sync();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Tu cuenta se ha eliminado.'), findsOneWidget);
      expect(container.read(authProvider).account, isNull);
      expect(container.read(authProvider).expired, isFalse);
      expect(log, [
        'reminders $owner',
        'reminders signed-out',
        'settled',
        'erase $owner',
      ]);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
      // The sync's one request, and no refresh with the old token.
      expect(sent.skip(before), ['GET lists/access/']);

      await container.read(authProvider.notifier).refreshAccount();
      await container.read(taskRepositoryProvider).sync();
      await tester.pumpAndSettle();
      expect(sent.skip(before), ['GET lists/access/']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'in the app: after the server deletes the account, sign-in says “Tu cuenta se ha eliminado.”, the session is gone, and nothing more reaches the server with the old account',
    (tester) async {
      final sent = <String>[];
      final log = <String>[];
      final (container, api) = await openApp(
        tester,
        sent: sent,
        log: log,
        answer: (request, path) async {
          if (path != 'auth/delete-account/') return null;
          if (request.method == 'GET') return json(previewJson());
          expect(request.headers['Authorization'], 'Bearer old-access');
          expect(jsonDecode(request.body), {
            'password': password,
            'plan': 'plan-1',
          });
          return http.Response('', 204);
        },
      );
      final owner = '${api.baseUrl}/users/1';
      expect(log, ['reminders $owner']);

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/account');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('12 tareas'), findsOneWidget);
      // On a phone-sized screen the field is below the fold.
      await tester.scrollUntilVisible(
        passwordField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsNothing);
      expect(find.text('Tu cuenta se ha eliminado.'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
        reason: 'Back can’t return to the deleted account',
      );
      expect(container.read(authProvider).account, isNull);
      expect(api.account, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
      expect(log, [
        'reminders $owner',
        'reminders signed-out',
        'settled',
        'erase $owner',
      ]);
      expect(sent.last, 'POST auth/delete-account/');
      final deleted = sent.length;

      // Whatever would sync or refresh now sends nothing for the old account.
      await container.read(taskProvider.notifier).loadTasks();
      await container.read(authProvider.notifier).refreshAccount();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      await expectLater(
        api.request('GET', 'tasks/', accountId: 1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(sent.length, deleted, reason: sent.skip(deleted).join(', '));
      expect(find.text('Tu cuenta se ha eliminado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'the Spanish copy keeps its names and the ending from ACCOUNT_DELETION.md, and says what stays and what changed',
    () {
      expect(es.deleteAccount, 'Eliminar cuenta');
      expect(es.deleteAccountButton, 'Eliminar mi cuenta');
      expect(es.deleteAccountConfirmGoogle, 'Confirmar con Google');
      expect(es.accountDeleted, 'Tu cuenta se ha eliminado.');
      expect(
        es.deleteAccountKeptShared(3),
        '3 tareas que añadiste a proyectos compartidos, sin tu nombre',
      );
      expect(
        es.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
        'El grupo «Matemáticas» y sus proyectos pasarán a Luis',
      );
      expect(
        es.deleteAccountHandover('project', 'Casa', 'Luis'),
        'El proyecto «Casa» pasará a Luis',
      );
      expect(
        es.deleteAccountChangedIntro,
        'Algo ha cambiado desde que abriste esta pantalla:',
      );
      expect(es.deleteAccountChangedCheck, 'Revísalo y vuelve a confirmar.');
      expect(
        es.deleteAccountPlanChanged,
        'Algo ha cambiado desde que abriste esta pantalla. Revisa lo que pasará y vuelve a confirmar.',
      );
      for (final language in ['en', 'es', 'ca']) {
        final l = lookupAppLocalizations(Locale(language));
        // Offline names the connection and that nothing was deleted; a lost
        // answer can't say that.
        expect(l.deleteAccountOffline, isNot(l.deleteAccountNoAnswer));
        expect(l.deleteAccountTasks(1), isNot(l.deleteAccountTasks(2)));
        expect(
          l.deleteAccountHandover('group', 'G', 'P'),
          isNot(l.deleteAccountHandover('project', 'G', 'P')),
        );
      }
    },
  );

  // ---- Acceptance: UX loop 2026-10-15-deletion, round 1 ----

  final copyLink = find.byKey(const ValueKey('delete-account-export'));
  final copySaved = find.byKey(const ValueKey('delete-account-copy-saved'));
  final manageLink = find.byKey(
    const ValueKey('delete-account-manage-subscription'),
  );
  final googleConfirmed = find.byKey(
    const ValueKey('delete-account-google-confirmed'),
  );
  final pageScroll = find
      .descendant(
        of: find.byType(DeleteAccountScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  final backArrow = find.descendant(
    of: find.byType(DeleteAccountScreen),
    matching: find.byType(BackButton),
  );

  /// Inside a live region, so TalkBack says it when it appears.
  bool inLiveRegion(Finder target) => find
      .ancestor(
        of: target,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      )
      .evaluate()
      .isNotEmpty;

  /// Brings [target] on screen, building it first if it is far below.
  Future<void> reach(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 120, scrollable: pageScroll);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  /// On screen, and within the width of a [width] dp phone.
  Future<void> fitsWidth(
    WidgetTester tester,
    Finder target, {
    double width = 320,
  }) async {
    await reach(tester, target);
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$target');
    expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: '$target');
  }

  bool bold(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style?.fontWeight == FontWeight.w700;

  bool linkEnabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(copyLink).onPressed != null;

  // P120 · UX-807, UX-802: save a copy from the delete page itself.

  testWidgets(
    'UX-807: one tap on Guardar antes una copia saves the export through Android’s save screen, and Copia guardada takes the link’s place after a check icon, in a live region',
    (tester) async {
      final phone = await open(tester);
      await reach(tester, copyLink);
      expect(
        find.descendant(
          of: copyLink,
          matching: find.text(es.deleteAccountSaveCopy),
        ),
        findsOneWidget,
      );
      final linkIcon = find.descendant(
        of: copyLink,
        matching: find.byIcon(Icons.download_outlined),
      );
      expect(linkIcon, findsOneWidget);
      final iconLeft = tester.getTopLeft(linkIcon).dx;
      final linkCenter = tester.getCenter(copyLink).dy;

      await tester.tap(copyLink);
      await tester.pumpAndSettle();
      expect(phone.archive.exports, 1);
      expect(phone.saveScreen.saved, [_Archive.contents]);
      expect(find.byType(DataTransferScreen), findsNothing);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(copyLink, findsNothing);

      final saved = find.text('Copia guardada');
      expect(find.descendant(of: copySaved, matching: saved), findsOneWidget);
      final check = find.descendant(
        of: copySaved,
        matching: find.byIcon(Icons.check_circle_outline),
      );
      expect(check, findsOneWidget);
      final colors = Theme.of(tester.element(saved)).colorScheme;
      expect(tester.widget<Icon>(check).color, colors.primary);
      expect(
        tester.getTopLeft(check).dx,
        moreOrLessEquals(iconLeft, epsilon: 1),
        reason: 'the check sits where the link’s icon was',
      );
      expect(
        tester.getTopLeft(saved).dx,
        greaterThanOrEqualTo(tester.getTopRight(check).dx),
        reason: 'after the check icon',
      );
      expect(
        tester.getCenter(copySaved).dy,
        moreOrLessEquals(linkCenter, epsilon: 4),
        reason: 'in place of the link',
      );
      expect(inLiveRegion(saved), isTrue);
      expect(
        inLiveRegion(find.text(es.deleteAccountQuestion)),
        isFalse,
        reason: 'the check is specific, not the whole page',
      );
      expect(find.text(es.exportSaved), findsNothing, reason: 'no snackbar');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-807: backing out of Android’s save screen changes nothing: the link stays, enabled, with no Copia guardada and no error',
    (tester) async {
      final phone = await open(tester);
      phone.saveScreen.answer = false;
      await tapVisible(tester, copyLink);
      await tester.pumpAndSettle();
      expect(phone.saveScreen.saved, hasLength(1));
      expect(copyLink, findsOneWidget);
      expect(linkEnabled(tester), isTrue);
      expect(copySaved, findsNothing);
      expect(find.text(es.deleteAccountCopySaved), findsNothing);
      expect(find.text(es.transferError), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-807: a failed save, or an export too large, says so under the link in the error colour, in a live region; the next tap clears it',
    (tester) async {
      final phone = await open(tester);
      phone.saveScreen.error = Exception('the save screen failed');
      await tapVisible(tester, copyLink);
      await tester.pumpAndSettle();
      final failed = find.text(
        'No se pudo completar la operación. Tus tareas y notas no han cambiado. Inténtalo de nuevo.',
      );
      expect(failed, findsOneWidget);
      expect(copyLink, findsOneWidget, reason: 'the link stays');
      expect(linkEnabled(tester), isTrue);
      expect(copySaved, findsNothing);
      final colors = Theme.of(tester.element(failed)).colorScheme;
      expect(tester.widget<Text>(failed).style?.color, colors.error);
      expect(inLiveRegion(failed), isTrue);
      expect(
        tester.getTopLeft(failed).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(copyLink).dy - 0.5),
        reason: 'under the link',
      );

      // The next tap clears it (backed out this time).
      phone.saveScreen
        ..error = null
        ..answer = false;
      await tapVisible(tester, copyLink);
      await tester.pumpAndSettle();
      expect(failed, findsNothing);

      // Too much to export: that diagnostic's own words instead.
      phone.archive.error = const ArchiveDiagnostic(ArchiveCode.exportTooLarge);
      await tapVisible(tester, copyLink);
      await tester.pumpAndSettle();
      final tooLarge = find.text(es.archiveExportTooLarge);
      expect(tooLarge, findsOneWidget);
      expect(failed, findsNothing);
      expect(copyLink, findsOneWidget);
      expect(tester.widget<Text>(tooLarge).style?.color, colors.error);
      expect(inLiveRegion(tooLarge), isTrue);
      expect(phone.saveScreen.saved, hasLength(2), reason: 'nothing to save');

      phone.archive.error = null;
      await tapVisible(tester, copyLink);
      await tester.pumpAndSettle();
      expect(tooLarge, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-807: with no tasks and no notes there is nothing of their own to copy, so no link; one note is enough for it',
    (tester) async {
      await open(tester, preview: previewJson(tasks: 0, notes: 0, files: 0));
      expect(copyLink, findsNothing);
      expect(copySaved, findsNothing);
      expect(find.text(es.deleteAccountSaveCopy), findsNothing);
      expect(find.text(es.deleteAccountCopyNoFiles), findsNothing);
      expect(tester.takeException(), isNull);

      await open(tester, preview: previewJson(tasks: 0, notes: 1));
      expect(copyLink, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-807: while the account is being deleted, the copy link is disabled',
    (tester) async {
      final phone = await open(tester);
      await tester.enterText(passwordField, password);
      phone.api.holdDelete = Completer<void>();
      await tapVisible(tester, confirm);
      await frames(tester);
      expect(copyLink, findsOneWidget);
      expect(linkEnabled(tester), isFalse);

      phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
      phone.api.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(linkEnabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-802: with files, «La copia no incluye los archivos.» sits directly under the link, then under Copia guardada; with no files it isn’t there; EN and CA say it too',
    (tester) async {
      await open(tester);
      await reach(tester, copyLink);
      final noFiles = find.text('La copia no incluye los archivos.');
      expect(noFiles, findsOneWidget);
      final linkIcon = find.descendant(
        of: copyLink,
        matching: find.byIcon(Icons.download_outlined),
      );
      final gap =
          tester.getTopLeft(noFiles).dy - tester.getBottomLeft(copyLink).dy;
      expect(gap, inInclusiveRange(-0.5, 8), reason: 'directly under the link');
      expect(
        tester.getTopLeft(noFiles).dx,
        moreOrLessEquals(tester.getTopLeft(linkIcon).dx, epsilon: 1),
        reason: 'where the link’s icon starts',
      );
      final colors = Theme.of(tester.element(noFiles)).colorScheme;
      expect(
        tester.widget<Text>(noFiles).style?.color,
        colors.onSurfaceVariant,
      );

      await tester.tap(copyLink);
      await tester.pumpAndSettle();
      expect(copySaved, findsOneWidget);
      expect(noFiles, findsOneWidget);
      final savedGap =
          tester.getTopLeft(noFiles).dy - tester.getBottomLeft(copySaved).dy;
      expect(
        savedGap,
        inInclusiveRange(-0.5, 8),
        reason: 'under Copia guardada',
      );
      expect(
        tester.getTopLeft(noFiles).dx,
        moreOrLessEquals(
          tester
              .getTopLeft(
                find.descendant(
                  of: copySaved,
                  matching: find.byIcon(Icons.check_circle_outline),
                ),
              )
              .dx,
          epsilon: 1,
        ),
      );
      expect(tester.takeException(), isNull);

      await open(tester, preview: previewJson(files: 0));
      expect(copyLink, findsOneWidget);
      expect(noFiles, findsNothing);
      expect(tester.takeException(), isNull);

      await open(tester, language: 'en');
      expect(find.text('The copy doesn’t include files.'), findsOneWidget);
      await open(tester, language: 'ca');
      expect(find.text('La còpia no inclou els fitxers.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-807, UX-802: Copia guardada and the files line read exactly as planned in EN, ES and CA',
    () {
      for (final (language, saved, noFiles) in [
        ('en', 'Copy saved', 'The copy doesn’t include files.'),
        ('es', 'Copia guardada', 'La copia no incluye los archivos.'),
        ('ca', 'Còpia desada', 'La còpia no inclou els fitxers.'),
      ]) {
        final l = lookupAppLocalizations(Locale(language));
        expect(l.deleteAccountCopySaved, saved);
        expect(l.deleteAccountCopyNoFiles, noFiles);
      }
    },
  );

  // Both lists, the Google Play line and the copy, at 2× on a 320 dp phone.
  for (final language in ['es', 'en', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets(
        'UX-802, UX-804, UX-806, UX-807: at 2× on 320 dp in $language (dark=$dark), both headings and every bullet, the Google Play line and Gestionar suscripción, the copy link, Copia guardada and the files line fit the width',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await open(
            tester,
            language: language,
            dark: dark,
            textScale: 2,
            size: const Size(320, 640),
            preview: previewJson(groups: 2, pro: true),
          );
          for (final text in [
            l.deleteAccountWhatGoes,
            l.deleteAccountTasks(12),
            l.deleteAccountNotes(3),
            l.deleteAccountFiles(2),
            l.deleteAccountProjects(1),
            l.deleteAccountGroups(2),
            l.deleteAccountWhatStays,
            l.deleteAccountKeptShared(4),
            l.deleteAccountHandover('project', 'Casa', 'Ana'),
            l.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
            l.deleteAccountSubscription,
          ]) {
            await fitsWidth(tester, find.text(text));
          }
          await fitsWidth(tester, manageLink);
          await fitsWidth(
            tester,
            find.descendant(
              of: manageLink,
              matching: find.text(l.billingManage),
            ),
          );
          await fitsWidth(tester, copyLink);
          await fitsWidth(tester, find.text(l.deleteAccountSaveCopy));
          await fitsWidth(tester, find.text(l.deleteAccountCopyNoFiles));
          expect(tester.takeException(), isNull);

          await tapVisible(tester, copyLink);
          await tester.pumpAndSettle();
          await fitsWidth(tester, copySaved);
          await fitsWidth(tester, find.text(l.deleteAccountCopySaved));
          await fitsWidth(tester, find.text(l.deleteAccountCopyNoFiles));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // P121 · UX-801, UX-808, UX-809, UX-810.

  for (final (language, expected) in [
    (
      'es',
      'La contraseña no es correcta. Si no la recuerdas, cierra sesión y toca «¿Has olvidado tu contraseña?».',
    ),
    (
      'en',
      'That password isn’t right. If you don’t remember it, sign out and tap “Forgot password?”',
    ),
    (
      'ca',
      'La contrasenya no és correcta. Si no te’n recordes, tanca la sessió i toca «Has oblidat la contrasenya?».',
    ),
  ]) {
    testWidgets(
      'UX-801: in $language a wrong password says how to recover it, under the field; the typed password stays and typing clears it',
      (tester) async {
        final phone = await open(tester, language: language);
        phone.api.deleteError = ApiException(400, 'Wrong password.', {
          'code': 'wrong_password',
          'detail': 'Wrong password.',
        });
        await tester.enterText(passwordField, 'not-the-password');
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        expect(fieldError(tester), expected);
        expect(find.text(expected), findsOneWidget);
        expect(
          tester.widget<TextField>(passwordField).controller!.text,
          'not-the-password',
        );
        await tester.enterText(passwordField, password);
        await tester.pump();
        expect(fieldError(tester), isNull);
        expect(find.text(expected), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-801: in EN, ES and CA the wrong-password message names sign-in’s own Forgot password? and the Account screen’s sign-out',
    () {
      for (final (language, forgot) in [
        ('en', 'Forgot password?'),
        ('es', '¿Has olvidado tu contraseña?'),
        ('ca', 'Has oblidat la contrasenya?'),
      ]) {
        final l = lookupAppLocalizations(Locale(language));
        expect(l.forgotPassword, forgot);
        expect(l.deleteAccountWrongPassword, contains(l.forgotPassword));
      }
      expect(
        lookupAppLocalizations(const Locale('en')).deleteAccountWrongPassword,
        contains('sign out'),
      );
      expect(es.deleteAccountWrongPassword, contains('cierra sesión'));
      expect(
        lookupAppLocalizations(const Locale('ca')).deleteAccountWrongPassword,
        contains('tanca la sessió'),
      );
    },
  );

  for (final (language, deleting) in [
    ('es', 'Eliminando tu cuenta…'),
    ('en', 'Deleting your account…'),
    ('ca', 'S’està suprimint el compte…'),
  ]) {
    testWidgets(
      'UX-808: in $language, while deleting the button reads “$deleting” after a spinner, TalkBack hears it once, and there is no back arrow; after an error the arrow and the button’s name come back',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final l = lookupAppLocalizations(Locale(language));
        final phone = await open(tester, language: language);
        expect(backArrow, findsOneWidget, reason: 'there before deleting');
        await tester.enterText(passwordField, password);
        phone.api.holdDelete = Completer<void>();
        await tapVisible(tester, confirm);
        await frames(tester);

        final text = find.descendant(
          of: confirm,
          matching: find.text(deleting),
        );
        expect(text, findsOneWidget);
        expect(
          find.descendant(
            of: confirm,
            matching: find.text(l.deleteAccountButton),
          ),
          findsNothing,
        );
        final spinner = find.descendant(
          of: confirm,
          matching: find.byType(CircularProgressIndicator),
        );
        expect(spinner, findsOneWidget);
        expect(
          tester.getTopRight(spinner).dx,
          lessThanOrEqualTo(tester.getTopLeft(text).dx),
          reason: 'the spinner comes first',
        );
        expect(enabled(tester), isFalse);
        final label = tester.getSemantics(text).label;
        expect(
          RegExp(RegExp.escape(deleting)).allMatches(label).length,
          1,
          reason: label,
        );
        expect(backArrow, findsNothing);
        // System Back still leaves the page in place.
        await tester.binding.handlePopRoute();
        await frames(tester);
        expect(find.byType(DeleteAccountScreen), findsOneWidget);

        phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
        phone.api.holdDelete!.complete();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: confirm,
            matching: find.text(l.deleteAccountButton),
          ),
          findsOneWidget,
        );
        expect(text, findsNothing);
        expect(backArrow, findsOneWidget);
        expect(find.text(l.deleteAccountOffline), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  for (final (message, expected) in [
    (
      'Too many failed attempts. Try again in 15 minutes. Expected available in 900 seconds.',
      'Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.',
    ),
    (
      'Request was throttled. Expected available in 40 seconds.',
      'Demasiados intentos. Espera un minuto y vuelve a intentarlo.',
    ),
    (
      'Request was throttled. Expected available in 61 seconds.',
      'Demasiados intentos. Espera 2 minutos y vuelve a intentarlo.',
    ),
    ('Request was throttled.', 'Demasiados intentos. Inténtalo más tarde.'),
  ]) {
    testWidgets(
      'UX-809: a 429 saying “$message” shows «$expected» under the button and keeps the password',
      (tester) async {
        final phone = await open(tester);
        phone.api.deleteError = ApiException(429, message);
        await tester.enterText(passwordField, password);
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        final banner = find.widgetWithText(MessageBanner, expected);
        expect(banner, findsOneWidget);
        expect(
          tester.getTopLeft(banner).dy,
          greaterThan(tester.getBottomLeft(confirm).dy),
        );
        expect(
          tester.widget<TextField>(passwordField).controller!.text,
          password,
        );
        expect(enabled(tester), isTrue);
        expect(phone.auth.account, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-809: at 2× on 320 dp in Catalan, the 15-minute wait fits under the button; English reads “Too many tries. Wait 15 minutes and try again.”',
    (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        en.tooManyTriesWait(15),
        'Too many tries. Wait 15 minutes and try again.',
      );
      expect(
        en.tooManyTriesWait(1),
        'Too many tries. Wait a minute and try again.',
      );
      final phone = await open(
        tester,
        language: 'ca',
        textScale: 2,
        size: const Size(320, 640),
      );
      phone.api.deleteError = ApiException(
        429,
        'Too many failed attempts. Try again in 15 minutes. Expected available in 900 seconds.',
      );
      await reach(tester, passwordField);
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      final wait = find.text(
        'Massa intents. Espera 15 minuts i torna-ho a provar.',
      );
      await fitsWidth(tester, wait);
      expect(
        tester.getTopLeft(wait).dy,
        greaterThan(tester.getBottomLeft(confirm).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-810: once Google returns a token, Confirmado con Google is in a live region',
    (tester) async {
      final phone = await open(tester, preview: previewJson(reauth: 'google'));
      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(googleConfirmed, findsOneWidget);
      expect(
        find.descendant(
          of: googleConfirmed,
          matching: find.text(es.deleteAccountGoogleConfirmed),
        ),
        findsOneWidget,
      );
      expect(inLiveRegion(googleConfirmed), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-810: at 2× on 320 dp in Spanish, once Google returns a token, Eliminar mi cuenta comes fully into view, enabled',
    (tester) async {
      final phone = await open(
        tester,
        textScale: 2,
        size: const Size(320, 640),
        preview: previewJson(reauth: 'google'),
      );
      phone.google.answers.add('fresh-google-id-token');
      await tapVisible(tester, googleButton);
      await tester.pumpAndSettle();
      expect(googleConfirmed, findsOneWidget);
      expect(confirm, findsOneWidget);
      final viewport = tester.getRect(pageScroll);
      final button = tester.getRect(confirm);
      expect(button.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(button.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(320.5));
      expect(enabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // P122 · UX-803, UX-804, UX-805.

  testWidgets(
    'UX-803: under ¿Eliminar tu cuenta? the account’s email, in onSurfaceVariant, then the intro naming TaskFlow',
    (tester) async {
      await open(tester);
      final heading = find.text('¿Eliminar tu cuenta?');
      final email = findShown('ana@example.invalid');
      final intro = find.text(
        'Se eliminarán tu cuenta de TaskFlow y tus tareas, notas y archivos en todos tus dispositivos. No se puede deshacer.',
      );
      for (final item in [heading, email, intro]) {
        expect(item, findsOneWidget);
      }
      expect(
        tester.getTopLeft(email).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(heading).dy),
      );
      expect(
        tester.getTopLeft(intro).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(email).dy),
      );
      final colors = Theme.of(tester.element(email)).colorScheme;
      expect(tester.widget<Text>(email).style?.color, colors.onSurfaceVariant);
      expect(tester.takeException(), isNull);

      await open(tester, language: 'en');
      expect(
        find.text(
          'This deletes your TaskFlow account and your tasks, notes and files on all your devices. It can’t be undone.',
        ),
        findsOneWidget,
      );
      expect(findShown('ana@example.invalid'), findsOneWidget);
      await open(tester, language: 'ca');
      expect(
        find.text(
          'Es suprimiran el compte de TaskFlow i les teves tasques, notes i fitxers a tots els dispositius. No es pot desfer.',
        ),
        findsOneWidget,
      );
      expect(findShown('ana@example.invalid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, help, other) in [
    (
      'es',
      'Para confirmar, elige ana@example.invalid cuando Google te lo pida. Tu cuenta de Google no se elimina.',
      'Elige ana@example.invalid, la cuenta de Google con la que entras en TaskFlow.',
    ),
    (
      'en',
      'To confirm, choose ana@example.invalid when Google asks. Your Google account isn’t deleted.',
      'Choose ana@example.invalid, the Google account you use for TaskFlow.',
    ),
    (
      'ca',
      'Per confirmar-ho, tria ana@example.invalid quan Google t’ho demani. El compte de Google no se suprimeix.',
      'Tria ana@example.invalid, el compte de Google amb què entres a TaskFlow.',
    ),
  ]) {
    testWidgets(
      'UX-803: in $language, the Google help names the account’s email and says Google stays; google_reauth_failed names it under the Google button',
      (tester) async {
        final phone = await open(
          tester,
          language: language,
          preview: previewJson(reauth: 'google'),
        );
        final helpLine = findShown(help);
        expect(helpLine, findsOneWidget);
        expect(
          tester.getBottomLeft(helpLine).dy,
          lessThanOrEqualTo(tester.getTopLeft(googleButton).dy),
          reason: 'above Confirmar con Google',
        );
        phone.google.answers.add('other-google-id-token');
        await tapVisible(tester, googleButton);
        await tester.pumpAndSettle();
        phone.api.deleteError = ApiException(400, 'Google account mismatch.', {
          'code': 'google_reauth_failed',
        });
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        final otherLine = findShown(other);
        expect(otherLine, findsOneWidget);
        expect(googleButton, findsOneWidget);
        expect(
          tester.getTopLeft(otherLine).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(googleButton).dy),
          reason: 'under the Google button',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-803: at 2× on 320 dp in $language, a 34-character email fits in the heading area, the intro, the Google help and the other-Google error',
      (tester) async {
        const longEmail = 'maria.dolores.garcia1957@gmail.com';
        expect(longEmail.length, 34);
        final l = lookupAppLocalizations(Locale(language));
        final phone = await open(
          tester,
          language: language,
          textScale: 2,
          size: const Size(320, 640),
          email: longEmail,
          preview: previewJson(reauth: 'google'),
        );
        await fitsWidth(tester, find.text(l.deleteAccountQuestion));
        await fitsWidth(tester, findShown(longEmail));
        await fitsWidth(tester, find.text(l.deleteAccountIntro));
        await fitsWidth(
          tester,
          findShown(l.deleteAccountGoogleHelp(longEmail)),
        );
        expect(tester.takeException(), isNull);

        phone.google.answers.add('other-google-id-token');
        await tapVisible(tester, googleButton);
        await tester.pumpAndSettle();
        phone.api.deleteError = ApiException(400, 'Mismatch.', {
          'code': 'google_reauth_failed',
        });
        await tapVisible(tester, confirm);
        await tester.pumpAndSettle();
        await fitsWidth(
          tester,
          findShown(l.deleteAccountOtherGoogle(longEmail)),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-804: two lists, What goes then What stays for the others, each line after a bullet TalkBack doesn’t read and with no final full stop, before the copy link and the password help',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      final lines = [
        '12 tareas',
        '3 notas',
        '2 archivos',
        '1 proyecto',
        '4 tareas que añadiste a proyectos compartidos, sin tu nombre',
        'El proyecto «Casa» pasará a Ana',
        'El grupo «Matemáticas» y sus proyectos pasarán a Luis',
      ];
      final order = [
        find.text('Lo que se eliminará:'),
        ...lines.take(4).map(find.text),
        find.text('Lo que se queda para los demás:'),
        ...lines.skip(4).map(find.text),
        copyLink,
        find.text('Para confirmar, escribe tu contraseña.'),
      ];
      var top = double.negativeInfinity;
      for (final item in order) {
        expect(item, findsOneWidget, reason: '$item');
        final y = tester.getTopLeft(item).dy;
        expect(y, greaterThan(top), reason: '$item');
        top = y;
      }
      final headingStyle = tester
          .widget<Text>(find.text('Lo que se eliminará:'))
          .style;
      expect(
        tester.widget<Text>(find.text('Lo que se queda para los demás:')).style,
        headingStyle,
        reason: 'the same heading style',
      );
      for (final line in lines) {
        expect(line.endsWith('.'), isFalse, reason: line);
        final text = find.text(line);
        final row = find.ancestor(of: text, matching: find.byType(Row)).first;
        final dot = find.descendant(of: row, matching: find.text('•'));
        expect(dot, findsOneWidget, reason: line);
        expect(
          tester.getTopRight(dot).dx,
          lessThanOrEqualTo(tester.getTopLeft(text).dx),
          reason: line,
        );
        expect(
          find.ancestor(
            of: dot,
            matching: find.byWidgetPredicate(
              (widget) => widget is ExcludeSemantics && widget.excluding,
            ),
          ),
          findsWidgets,
          reason: line,
        );
      }
      expect(find.bySemanticsLabel(RegExp('•')), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-804: one kept task in the singular; nothing kept and no handovers, no second heading; no counts, one kept task, only the second list',
    (tester) async {
      await open(tester, preview: previewJson(kept: 1, handovers: []));
      expect(find.text('Lo que se queda para los demás:'), findsOneWidget);
      expect(
        find.text(
          '1 tarea que añadiste a proyectos compartidos, sin tu nombre',
        ),
        findsOneWidget,
      );

      await open(tester, preview: previewJson(kept: 0, handovers: []));
      expect(find.text('Lo que se eliminará:'), findsOneWidget);
      expect(find.text('Lo que se queda para los demás:'), findsNothing);

      await open(
        tester,
        preview: previewJson(
          tasks: 0,
          notes: 0,
          files: 0,
          projects: 0,
          groups: 0,
          kept: 1,
          handovers: [],
        ),
      );
      final heading = find.text('Lo que se queda para los demás:');
      expect(heading, findsOneWidget);
      expect(find.text('Lo que se eliminará:'), findsNothing);
      expect(find.text('•'), findsOneWidget, reason: 'its one bullet');
      expect(
        tester.getTopLeft(find.text('•')).dy,
        greaterThan(tester.getTopLeft(heading).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, stays, kept, project, group) in [
    (
      'en',
      'What stays for the others:',
      '4 tasks you added to shared projects, without your name',
      'The project “Casa” will go to Ana',
      'The group “Matemáticas” and its projects will go to Luis',
    ),
    (
      'ca',
      'El que es queda per als altres:',
      '4 tasques que vas afegir a projectes compartits, sense el teu nom',
      'El projecte «Casa» passarà a Ana',
      'El grup «Matemáticas» i els seus projectes passaran a Luis',
    ),
  ]) {
    testWidgets(
      'UX-804: in $language, the second heading, the kept line and each handover read as planned, in that order',
      (tester) async {
        await open(tester, language: language);
        var top = double.negativeInfinity;
        for (final line in [stays, kept, project, group]) {
          final item = find.text(line);
          expect(item, findsOneWidget, reason: line);
          final y = tester.getTopLeft(item).dy;
          expect(y, greaterThan(top), reason: line);
          top = y;
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  /// Password typed, then a 409 whose new preview is [after].
  Future<_Phone> planChanged(
    WidgetTester tester,
    Map<String, dynamic> after, {
    double textScale = 1,
    Size size = const Size(390, 1600),
  }) async {
    final phone = await open(tester, textScale: textScale, size: size);
    await reach(tester, passwordField);
    await tester.enterText(passwordField, password);
    phone.api
      ..deleteError = ApiException(409, 'Plan changed.', {
        'code': 'plan_changed',
        'detail': 'Plan changed.',
      })
      ..preview = after;
    await tapVisible(tester, confirm);
    await tester.pumpAndSettle();
    return phone;
  }

  final casaToLuis = previewJson(
    plan: 'plan-2',
    handovers: [
      {'kind': 'project', 'id': 'p-1', 'name': 'Casa', 'to': 'Luis'},
    ],
  );
  const changedBanner =
      'Algo ha cambiado desde que abriste esta pantalla:\n'
      '• El proyecto «Casa» pasará a Luis\n'
      'Revísalo y vuelve a confirmar.';
  const listLines = [
    '12 tareas',
    '3 notas',
    '2 archivos',
    '1 proyecto',
    '4 tareas que añadiste a proyectos compartidos, sin tu nombre',
  ];

  testWidgets(
    'UX-805: after a 409 where Casa now goes to Luis, the banner says what changed on three lines, above the button; only that list line is bold; the password stays',
    (tester) async {
      await planChanged(tester, casaToLuis);
      final banner = find.text(changedBanner);
      expect(banner, findsOneWidget);
      expect(
        find.ancestor(of: banner, matching: find.byType(MessageBanner)),
        findsOneWidget,
      );
      expect(inLiveRegion(banner), isTrue);
      expect(
        tester.getBottomLeft(banner).dy,
        lessThan(tester.getTopLeft(confirm).dy),
      );
      final moved = find.text('El proyecto «Casa» pasará a Luis');
      expect(moved, findsOneWidget, reason: 'in the list');
      expect(bold(tester, moved), isTrue);
      for (final line in listLines) {
        expect(bold(tester, find.text(line)), isFalse, reason: line);
      }
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        password,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-805: the next tap on Eliminar mi cuenta, answered with an error, leaves no list line bold',
    (tester) async {
      final phone = await planChanged(tester, casaToLuis);
      final moved = find.text('El proyecto «Casa» pasará a Luis');
      expect(bold(tester, moved), isTrue);
      phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(find.text(es.deleteAccountOffline), findsOneWidget);
      expect(bold(tester, moved), isFalse);
      for (final line in listLines) {
        expect(bold(tester, find.text(line)), isFalse, reason: line);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-805: when a handover only disappeared, the banner keeps the general line and nothing is bold',
    (tester) async {
      await planChanged(
        tester,
        previewJson(
          plan: 'plan-2',
          handovers: [
            {'kind': 'project', 'id': 'p-1', 'name': 'Casa', 'to': 'Ana'},
          ],
        ),
      );
      expect(
        find.text(
          'Algo ha cambiado desde que abriste esta pantalla. Revisa lo que pasará y vuelve a confirmar.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Revísalo y vuelve a confirmar.'),
        findsNothing,
      );
      final casa = find.text('El proyecto «Casa» pasará a Ana');
      expect(casa, findsOneWidget);
      expect(bold(tester, casa), isFalse);
      expect(find.textContaining('Matemáticas'), findsNothing);
      for (final line in listLines) {
        expect(bold(tester, find.text(line)), isFalse, reason: line);
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-804, UX-805: the second heading and the changed banner’s lines read exactly as planned in EN, ES and CA',
    () {
      for (final (language, stays, intro, check) in [
        (
          'en',
          'What stays for the others:',
          'Something has changed since you opened this screen:',
          'Check it and confirm again.',
        ),
        (
          'es',
          'Lo que se queda para los demás:',
          'Algo ha cambiado desde que abriste esta pantalla:',
          'Revísalo y vuelve a confirmar.',
        ),
        (
          'ca',
          'El que es queda per als altres:',
          'Alguna cosa ha canviat des que has obert aquesta pantalla:',
          'Revisa-ho i torna a confirmar-ho.',
        ),
      ]) {
        final l = lookupAppLocalizations(Locale(language));
        expect(l.deleteAccountWhatStays, stays);
        expect(l.deleteAccountChangedIntro, intro);
        expect(l.deleteAccountChangedCheck, check);
      }
    },
  );

  // P123 · UX-806: the Google Play line.

  const playLine =
      'Si pagas TaskFlow Pro en Google Play, eliminar tu cuenta no cancela la suscripción.';

  testWidgets(
    'UX-806: complimentary Pro sees neither the Google Play line nor Gestionar suscripción',
    (tester) async {
      await open(tester, preview: previewJson(pro: true), complimentary: true);
      expect(find.text(playLine), findsNothing);
      expect(find.text('Gestionar suscripción'), findsNothing);
      expect(manageLink, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-806: with a purchase billing knows of, the line reads in normal weight and Gestionar suscripción under it opens the Customer Center once, and no web page',
    (tester) async {
      final phone = await open(
        tester,
        preview: previewJson(pro: true),
        purchases: billingInfo(active: true),
      );
      final line = find.text(playLine);
      expect(line, findsOneWidget);
      expect(
        tester.widget<Text>(line).style?.fontWeight,
        isNot(FontWeight.w700),
      );
      final label = find.descendant(
        of: manageLink,
        matching: find.text('Gestionar suscripción'),
      );
      expect(label, findsOneWidget);
      expect(
        find.descendant(
          of: manageLink,
          matching: find.byIcon(Icons.manage_accounts_outlined),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(manageLink).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(line).dy - 0.5),
        reason: 'under the line',
      );
      await tapVisible(tester, manageLink);
      await tester.pumpAndSettle();
      expect(phone.billing.centers, 1);
      expect(phone.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, purchases) in [
    ('billing not ready', null),
    ('billing ready with no purchase', billingInfo()),
  ]) {
    testWidgets(
      'UX-806: with $name, Gestionar suscripción opens Google Play’s subscriptions page; when nothing opens it, the page says so',
      (tester) async {
        final phone = await open(
          tester,
          preview: previewJson(pro: true),
          purchases: purchases,
        );
        await tapVisible(tester, manageLink);
        await tester.pumpAndSettle();
        expect(phone.opened.map((uri) => uri.toString()), [
          'https://play.google.com/store/account/subscriptions',
        ]);
        expect(phone.billing.centers, 0);

        phone.opens = false;
        await tapVisible(tester, manageLink);
        await tester.pumpAndSettle();
        expect(find.text('No se ha podido abrir la página.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-806: without Pro, neither the Google Play line nor the link',
    (tester) async {
      await open(tester, preview: previewJson(pro: false));
      expect(find.text(playLine), findsNothing);
      expect(manageLink, findsNothing);
      expect(find.text('Gestionar suscripción'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-806: the Google Play line reads as planned in EN, ES and CA', () {
    for (final (language, line) in [
      (
        'en',
        'If you pay for TaskFlow Pro on Google Play, deleting your account doesn’t cancel the subscription.',
      ),
      ('es', playLine),
      (
        'ca',
        'Si pagues TaskFlow Pro a Google Play, suprimir el compte no cancel·la la subscripció.',
      ),
    ]) {
      expect(
        lookupAppLocalizations(Locale(language)).deleteAccountSubscription,
        line,
      );
    }
  });

  // P124 · UX-811: Eliminar cuenta apart from Cerrar sesión.

  testWidgets(
    'UX-811: on Account, Eliminar cuenta sits at least 24 dp below Cerrar sesión with a divider between, last, in the error colour',
    (tester) async {
      await open(tester, onAccount: true);
      final signOut = find.ancestor(
        of: find.text(es.signOut),
        matching: find.byType(TextButton),
      );
      final delete = find.byKey(const ValueKey('account-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      final signOutBottom = tester.getBottomLeft(signOut).dy;
      final deleteTop = tester.getTopLeft(delete).dy;
      expect(deleteTop - signOutBottom, greaterThanOrEqualTo(24));
      final dividers = tester
          .widgetList<Divider>(find.byType(Divider))
          .map((divider) => tester.getRect(find.byWidget(divider)))
          .where(
            (rect) => rect.top >= signOutBottom && rect.bottom <= deleteTop,
          );
      expect(dividers, hasLength(1), reason: 'a divider between them');
      for (final button in tester.widgetList<ButtonStyleButton>(
        find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      )) {
        expect(
          tester.getTopLeft(find.byWidget(button)).dy,
          lessThanOrEqualTo(deleteTop),
          reason: 'Eliminar cuenta is last',
        );
      }
      final label = find.descendant(
        of: delete,
        matching: find.text('Eliminar cuenta'),
      );
      expect(label, findsOneWidget);
      expect(
        tester.widget<Text>(label).style?.color,
        Theme.of(tester.element(delete)).colorScheme.error,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-811: at 2× on 320 dp in $language, Eliminar cuenta fits, below the divider, last',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await open(
          tester,
          onAccount: true,
          language: language,
          textScale: 2,
          size: const Size(320, 640),
        );
        final delete = find.byKey(const ValueKey('account-delete'));
        await tester.scrollUntilVisible(
          delete,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: delete, matching: find.text(l.deleteAccount)),
          findsOneWidget,
        );
        final rect = tester.getRect(delete);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        final signOutBottom = tester.getRect(find.text(l.signOut)).bottom;
        final divider = tester
            .widgetList<Divider>(find.byType(Divider))
            .map((divider) => tester.getRect(find.byWidget(divider)))
            .where((box) => box.top >= signOutBottom && box.bottom <= rect.top);
        expect(divider, hasLength(1), reason: 'below the divider');
        for (final button in tester.widgetList<ButtonStyleButton>(
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        )) {
          expect(
            tester.getTopLeft(find.byWidget(button)).dy,
            lessThanOrEqualTo(rect.top),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  // P125 · UX-816: the title holds still while deleting. UX-817: the
  // changed-plan banner is spoken once, with its final text, without bullets.

  final deleteAppBar = find.descendant(
    of: find.byType(DeleteAccountScreen),
    matching: find.byType(AppBar),
  );
  Finder appBarTitle(AppLocalizations l) =>
      find.descendant(of: deleteAppBar, matching: find.text(l.deleteAccount));

  /// [node] and every node under it.
  List<SemanticsData> semanticsUnder(SemanticsNode node) {
    final all = [node.getSemanticsData()];
    node.visitChildren((child) {
      all.addAll(semanticsUnder(child));
      return true;
    });
    return all;
  }

  testWidgets(
    'UX-816: in Spanish at 1×, while deleting the back arrow goes but «Eliminar cuenta» stays where it was; after an offline error the arrow is back and the title still hasn’t moved',
    (tester) async {
      final phone = await open(tester);
      final title = appBarTitle(es);
      expect(title, findsOneWidget);
      expect(backArrow, findsOneWidget, reason: 'there before deleting');
      final before = tester.getTopLeft(title).dx;

      await tester.enterText(passwordField, password);
      phone.api.holdDelete = Completer<void>();
      await tapVisible(tester, confirm);
      await frames(tester);
      expect(find.text(es.deleteAccountDeleting), findsOneWidget);
      expect(backArrow, findsNothing);
      expect(tester.getTopLeft(title).dx, closeTo(before, 0.5));

      phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
      phone.api.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(find.text(es.deleteAccountOffline), findsOneWidget);
      expect(backArrow, findsOneWidget);
      expect(tester.getTopLeft(title).dx, closeTo(before, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-816: at 2× on 320 dp in Spanish, the title’s left edge is the same before the tap, while deleting and after the error, and the app bar fits the width',
    (tester) async {
      final phone = await open(
        tester,
        textScale: 2,
        size: const Size(320, 640),
      );
      final title = appBarTitle(es);
      void barFits(String when) {
        final bar = tester.getRect(deleteAppBar);
        expect(bar.left, greaterThanOrEqualTo(-0.5), reason: when);
        expect(bar.right, lessThanOrEqualTo(320.5), reason: when);
        final rect = tester.getRect(title);
        expect(rect.left, greaterThanOrEqualTo(0), reason: when);
        expect(rect.right, lessThanOrEqualTo(320.5), reason: when);
      }

      expect(title, findsOneWidget);
      barFits('before the tap');
      final before = tester.getTopLeft(title).dx;

      await reach(tester, passwordField);
      await tester.enterText(passwordField, password);
      phone.api.holdDelete = Completer<void>();
      await reach(tester, confirm);
      await tester.tap(confirm);
      await frames(tester);
      expect(backArrow, findsNothing);
      barFits('while deleting');
      expect(tester.getTopLeft(title).dx, closeTo(before, 0.5));

      phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
      phone.api.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(backArrow, findsOneWidget);
      barFits('after the error');
      expect(tester.getTopLeft(title).dx, closeTo(before, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-816: while deleting, nothing in the app bar is a back button TalkBack can focus or tap (no «Atrás» tooltip, no tap action)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final phone = await open(tester);
      final back = MaterialLocalizations.of(
        tester.element(appBarTitle(es)),
      ).backButtonTooltip;
      expect(back, 'Atrás');
      bool backInBar() => semanticsUnder(
        tester.getSemantics(deleteAppBar),
      ).any((data) => data.tooltip == back);
      bool tapInBar() => semanticsUnder(
        tester.getSemantics(deleteAppBar),
      ).any((data) => data.hasAction(SemanticsAction.tap));
      // The check can see the arrow when it is there.
      expect(backInBar(), isTrue, reason: 'before deleting');
      expect(tapInBar(), isTrue, reason: 'before deleting');

      await tester.enterText(passwordField, password);
      phone.api.holdDelete = Completer<void>();
      await tapVisible(tester, confirm);
      await frames(tester);
      expect(backInBar(), isFalse);
      expect(tapInBar(), isFalse);

      phone.api.deleteError = ApiException(0, ApiClient.offlineMessage);
      phone.api.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(backInBar(), isTrue, reason: 'after the error');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  /// In [language], password typed, then a 409 whose new preview is [after].
  /// With [holdReload] the reload waits until the test completes it.
  Future<_Phone> changedPlan(
    WidgetTester tester,
    Map<String, dynamic> after, {
    String language = 'es',
    bool holdReload = false,
  }) async {
    final phone = await open(tester, language: language);
    await reach(tester, passwordField);
    await tester.enterText(passwordField, password);
    phone.api
      ..deleteError = ApiException(409, 'Plan changed.', {
        'code': 'plan_changed',
        'detail': 'Plan changed.',
      })
      ..preview = after;
    if (holdReload) phone.api.holdPreview = Completer<void>();
    await tapVisible(tester, confirm);
    if (holdReload) {
      await frames(tester);
    } else {
      await tester.pumpAndSettle();
    }
    return phone;
  }

  Finder bannerWith(String visible) => find.ancestor(
    of: find.text(visible),
    matching: find.byType(MessageBanner),
  );

  for (final (language, spoken) in [
    (
      'es',
      'Algo ha cambiado desde que abriste esta pantalla:\n'
          'El proyecto «Casa» pasará a Luis\n'
          'Revísalo y vuelve a confirmar.',
    ),
    (
      'en',
      'Something has changed since you opened this screen:\n'
          'The project “Casa” will go to Luis\n'
          'Check it and confirm again.',
    ),
    (
      'ca',
      'Alguna cosa ha canviat des que has obert aquesta pantalla:\n'
          'El projecte «Casa» passarà a Luis\n'
          'Revisa-ho i torna a confirmar-ho.',
    ),
  ]) {
    testWidgets(
      'UX-817: in $language, after a 409 where Casa now goes to Luis, the banner is read as its three lines without the bullet, in a live region; the bullet still shows',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final l = lookupAppLocalizations(Locale(language));
        await changedPlan(tester, casaToLuis, language: language);
        final handover = l.deleteAccountHandover('project', 'Casa', 'Luis');
        final visible = [
          l.deleteAccountChangedIntro,
          '• $handover',
          l.deleteAccountChangedCheck,
        ].join('\n');
        final banner = bannerWith(visible);
        expect(banner, findsOneWidget, reason: 'the bullet still shows');
        expect(inLiveRegion(find.text(visible)), isTrue);

        final node = tester.getSemantics(banner);
        expect(
          node.label,
          [
            l.deleteAccountChangedIntro,
            handover,
            l.deleteAccountChangedCheck,
          ].join('\n'),
        );
        expect(node.label, spoken, reason: 'as planned');
        expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
        for (final data in semanticsUnder(node)) {
          expect(data.label.contains('•'), isFalse, reason: data.label);
          expect(data.value.contains('•'), isFalse, reason: data.value);
        }
        expect(find.bySemanticsLabel(RegExp('•')), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'UX-817: in Spanish, while the reload is held the banner shows the general line and is not a live region; once it ends with the same handovers, it is live with that same label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final phone = await changedPlan(
        tester,
        previewJson(plan: 'plan-2'),
        holdReload: true,
      );
      expect(
        es.deleteAccountPlanChanged,
        'Algo ha cambiado desde que abriste esta pantalla. Revisa lo que pasará y vuelve a confirmar.',
      );
      final text = find.text(es.deleteAccountPlanChanged);
      expect(bannerWith(es.deleteAccountPlanChanged), findsOneWidget);
      expect(inLiveRegion(text), isFalse, reason: 'silent while reloading');
      expect(
        tester
            .getSemantics(bannerWith(es.deleteAccountPlanChanged))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );

      phone.api.holdPreview!.complete();
      await tester.pumpAndSettle();
      final banner = bannerWith(es.deleteAccountPlanChanged);
      expect(banner, findsOneWidget);
      expect(inLiveRegion(text), isTrue);
      final node = tester.getSemantics(banner);
      expect(node.label, es.deleteAccountPlanChanged);
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-817: when the new preview only drops Matemáticas, after the reload the banner is live and reads the general line',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await changedPlan(
        tester,
        previewJson(
          plan: 'plan-2',
          handovers: [
            {'kind': 'project', 'id': 'p-1', 'name': 'Casa', 'to': 'Ana'},
          ],
        ),
      );
      final banner = bannerWith(es.deleteAccountPlanChanged);
      expect(banner, findsOneWidget);
      expect(inLiveRegion(find.text(es.deleteAccountPlanChanged)), isTrue);
      final node = tester.getSemantics(banner);
      expect(node.label, es.deleteAccountPlanChanged);
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  // P126 · UX-804, UX-809: the files that stay are named; the lock's wait
  // comes from Retry-After.

  test(
    'UX-804: the preview reads kept_files_in_shared, and 0 from an older server that leaves it out',
    () {
      expect(
        DeletionPreview.parse(previewJson(keptFiles: 2)).keptFilesInShared,
        2,
      );
      expect(
        DeletionPreview.parse(previewJson(keptFiles: 0)).keptFilesInShared,
        0,
      );
      expect(DeletionPreview.parse(previewJson()).keptFilesInShared, 0);
    },
  );

  for (final (language, one, two) in [
    ('es', '1 archivo ', '2 archivos '),
    ('en', '1 file ', '2 files '),
    ('ca', '1 fitxer ', '2 fitxers '),
  ]) {
    test(
      'UX-804: in $language, the kept-files line counts files, singular and plural, in the tasks line’s words and without a final full stop',
      () {
        final l = lookupAppLocalizations(Locale(language));
        final single = l.deleteAccountKeptFiles(1);
        final plural = l.deleteAccountKeptFiles(2);
        expect(single, startsWith(one));
        expect(plural, startsWith(two));
        for (final line in [single, plural]) {
          expect(line.endsWith('.'), isFalse, reason: line);
          expect(line.trim(), line, reason: line);
        }
        // Same tone as the tasks line: everything after the count and noun
        // reads the same.
        String tail(String line) => line.substring(line.indexOf(' ', 2));
        expect(tail(plural), tail(l.deleteAccountKeptShared(2)));
        expect(tail(single), tail(l.deleteAccountKeptShared(1)));
      },
    );

    testWidgets(
      'UX-804: in $language, no kept tasks but 2 kept files shows the second heading and the files line under it, and 1 file reads in the singular',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await open(
          tester,
          language: language,
          preview: previewJson(kept: 0, keptFiles: 2, handovers: []),
        );
        final heading = find.text(l.deleteAccountWhatStays);
        final files = find.text(l.deleteAccountKeptFiles(2));
        await reach(tester, files);
        expect(heading, findsOneWidget);
        expect(files, findsOneWidget);
        expect(
          tester.getTopLeft(files).dy,
          greaterThan(tester.getTopLeft(heading).dy),
        );
        expect(find.text(l.deleteAccountKeptShared(0)), findsNothing);

        await open(
          tester,
          language: language,
          preview: previewJson(kept: 0, keptFiles: 1, handovers: []),
        );
        expect(find.text(l.deleteAccountWhatStays), findsOneWidget);
        expect(find.text(l.deleteAccountKeptFiles(1)), findsOneWidget);
        expect(find.text(l.deleteAccountKeptFiles(2)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  /// Any line naming what the person added to shared projects.
  Finder addedToShared(AppLocalizations l) {
    final files = l.deleteAccountKeptFiles(7);
    final tail = files.substring(files.indexOf(' ', 2));
    return find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').endsWith(tail),
    );
  }

  testWidgets(
    'UX-804: with no kept tasks and no kept files (0, or absent from an older server), there is no files line and, without handovers, no second heading',
    (tester) async {
      await open(
        tester,
        preview: previewJson(kept: 0, keptFiles: 0, handovers: []),
      );
      expect(find.text(es.deleteAccountWhatStays), findsNothing);
      expect(addedToShared(es), findsNothing);
      expect(find.text(es.deleteAccountKeptFiles(0)), findsNothing);

      await open(tester, preview: previewJson(kept: 0, handovers: []));
      expect(find.text(es.deleteAccountWhatStays), findsNothing);
      expect(addedToShared(es), findsNothing);

      // An older server with kept tasks: their line, and no files line.
      await open(tester, preview: previewJson(handovers: []));
      expect(find.text(es.deleteAccountKeptShared(4)), findsOneWidget);
      expect(addedToShared(es), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-804: kept tasks and kept files each get their line under Lo que se queda para los demás, tasks then files, before the handovers',
    (tester) async {
      await open(tester, preview: previewJson(keptFiles: 2));
      var top = double.negativeInfinity;
      for (final line in [
        es.deleteAccountWhatStays,
        es.deleteAccountKeptShared(4),
        es.deleteAccountKeptFiles(2),
        es.deleteAccountHandover('project', 'Casa', 'Ana'),
        es.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
      ]) {
        final item = find.text(line);
        await reach(tester, item);
        expect(item, findsOneWidget, reason: line);
        final y = tester.getTopLeft(item).dy;
        expect(y, greaterThan(top), reason: line);
        top = y;
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-804: at 2× on 320 dp in Catalan, the kept-files line fits the width',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      await open(
        tester,
        language: 'ca',
        textScale: 2,
        size: const Size(320, 640),
        preview: previewJson(keptFiles: 2),
      );
      await fitsWidth(tester, find.text(ca.deleteAccountKeptFiles(2)));
      expect(tester.takeException(), isNull);
    },
  );

  /// A 429 from the server, with [retryAfter] as its header when given.
  http.Response throttled(String detail, {String? retryAfter}) =>
      http.Response.bytes(
        utf8.encode(jsonEncode({'detail': detail})),
        429,
        headers: {
          'content-type': 'application/json',
          if (retryAfter != null) 'retry-after': retryAfter,
        },
      );

  const spanishDetail =
      'Solicitud fue regulada (throttled). Se espera que esté disponible en 900 segundos.';

  test(
    'UX-809: the API client keeps a 429’s Retry-After as the wait, and none when the header is missing or not whole seconds',
    () async {
      Future<ApiException> answer(http.Response response) async {
        final api = ApiClient(
          transport: MockClient((request) async => response),
          url: 'http://test.invalid',
        );
        addTearDown(api.close);
        try {
          await api.request(
            'POST',
            'auth/delete-account/',
            data: {},
            authenticated: false,
          );
        } on ApiException catch (error) {
          return error;
        }
        fail('expected an ApiException');
      }

      final withWait = await answer(
        throttled(spanishDetail, retryAfter: '900'),
      );
      expect(withWait.status, 429);
      expect(withWait.retryAfter, const Duration(seconds: 900));
      expect((await answer(throttled(spanishDetail))).retryAfter, isNull);
      expect(
        (await answer(
          throttled(spanishDetail, retryAfter: 'Wed, 21 Oct 2026 07:28:00 GMT'),
        )).retryAfter,
        isNull,
      );
    },
  );

  testWidgets(
    'UX-809: in the app, a 429 with Retry-After: 900 and a Spanish detail shows the 15-minute wait under the button and keeps the password',
    (tester) async {
      final sent = <String>[];
      final log = <String>[];
      await openApp(
        tester,
        sent: sent,
        log: log,
        answer: (request, path) async {
          if (path != 'auth/delete-account/') return null;
          if (request.method == 'GET') return json(previewJson());
          return throttled(spanishDetail, retryAfter: '900');
        },
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/deleteAccount');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        passwordField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(sent.last, 'POST auth/delete-account/');
      expect(
        es.tooManyTriesWait(15),
        contains('15 minutos'),
        reason: 'the wait is named in minutes',
      );
      final banner = find.widgetWithText(
        MessageBanner,
        es.tooManyTriesWait(15),
      );
      expect(banner, findsOneWidget);
      expect(
        tester.getTopLeft(banner).dy,
        greaterThan(tester.getBottomLeft(confirm).dy),
      );
      expect(find.text(es.deleteAccountThrottled), findsNothing);
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        password,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (label, error, expected) in [
    (
      'Retry-After 40 s with a Spanish detail',
      ApiException(429, spanishDetail, null, const Duration(seconds: 40)),
      es.tooManyTriesWait(1),
    ),
    (
      'Retry-After 900 s with a detail carrying no wait',
      ApiException(
        429,
        'Demasiadas solicitudes.',
        null,
        const Duration(seconds: 900),
      ),
      es.tooManyTriesWait(15),
    ),
    (
      'Retry-After 60 s while the English detail says 900 s',
      ApiException(
        429,
        'Request was throttled. Expected available in 900 seconds.',
        null,
        const Duration(seconds: 60),
      ),
      es.tooManyTriesWait(1),
    ),
    (
      'no Retry-After and a Spanish detail',
      ApiException(429, spanishDetail),
      es.deleteAccountThrottled,
    ),
  ]) {
    testWidgets('UX-809: a 429 with $label shows «$expected»', (tester) async {
      final phone = await open(tester);
      phone.api.deleteError = error;
      await tester.enterText(passwordField, password);
      await tapVisible(tester, confirm);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MessageBanner, expected), findsOneWidget);
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        password,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // UX-801 and UX-805 at 2×, with the app's own font, so the line count is real. Last,
  // because the font stays loaded for whatever runs after.
  group('with Manrope', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-801: at 2× on 320 dp in $language, the whole wrong-password message shows under the field, within its lines and the width',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final phone = await open(
            tester,
            language: language,
            textScale: 2,
            size: const Size(320, 640),
          );
          phone.api.deleteError = ApiException(400, 'Wrong password.', {
            'code': 'wrong_password',
          });
          await reach(tester, passwordField);
          await tester.enterText(passwordField, 'not-the-password');
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          final message = find.text(l.deleteAccountWrongPassword);
          await fitsWidth(tester, message);
          final paragraph = tester.renderObject<RenderParagraph>(message);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'no ellipsis');
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-815: at 2× on 320 dp in $language, with Google linked, every line of both ways shows whole, before and after confirming with Google, and Eliminar mi cuenta can be scrolled to',
        (tester) async {
          const email = 'ana@example.com';
          final l = lookupAppLocalizations(Locale(language));
          // From the top each time: the page builds lazily.
          Future<void> fromTop(Finder target) async {
            tester.state<ScrollableState>(pageScroll).position.jumpTo(0);
            await tester.pumpAndSettle();
            await fitsWidth(tester, target);
          }

          Future<void> whole(Finder target) async {
            await fromTop(target);
            final paragraphs = tester.renderObjectList<RenderParagraph>(
              find.descendant(
                of: target,
                matching: find.byType(RichText),
                matchRoot: true,
              ),
            );
            for (final paragraph in paragraphs) {
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$target is cut',
              );
            }
          }

          final phone = await open(
            tester,
            language: language,
            textScale: 2,
            size: const Size(320, 640),
            email: email,
            googleLinked: true,
          );
          await whole(find.text(l.deleteAccountPasswordHelp));
          await fromTop(passwordField);
          await whole(findShown(l.deleteAccountGoogleInstead(email)));
          await whole(find.text(l.deleteAccountConfirmGoogle));
          await whole(find.text(l.deleteAccountButton));
          expect(tester.takeException(), isNull);

          // A wrong password names the Google button.
          phone.api.deleteError = ApiException(400, 'Wrong password.', {
            'code': 'wrong_password',
          });
          await reach(tester, passwordField);
          await tester.enterText(passwordField, 'not-the-password');
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await whole(find.text(l.deleteAccountWrongPasswordGoogle));
          expect(tester.takeException(), isNull);

          phone.api.deleteError = null;
          phone.google.answers.add('fresh-google-id-token');
          await tapVisible(tester, googleButton);
          await tester.pumpAndSettle();
          await whole(find.text(l.deleteAccountGoogleConfirmed));
          await whole(find.text(l.deleteAccountButton));
          // Confirmed: the «O confirma con Google» line goes with the password.
          expect(findShown(l.deleteAccountGoogleInstead(email)), findsNothing);
          expect(passwordField, findsNothing);
          expect(enabled(tester), isTrue);

          phone.api.deleteError = ApiException(400, 'Mismatch.', {
            'code': 'google_reauth_failed',
          });
          await tapVisible(tester, confirm);
          await tester.pumpAndSettle();
          await whole(findShown(l.deleteAccountOtherGoogle(email)));
          await fromTop(passwordField);
          await whole(find.text(l.deleteAccountButton));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-805: at 2× on 320 dp in Spanish, with Manrope, after the reload the banner is in view, above Eliminar mi cuenta',
      (tester) async {
        await planChanged(
          tester,
          casaToLuis,
          textScale: 2,
          size: const Size(320, 640),
        );
        final banner = find.text(changedBanner);
        expect(banner, findsOneWidget);
        final viewport = tester.getRect(pageScroll);
        final rect = tester.getRect(banner);
        expect(rect.top, greaterThanOrEqualTo(viewport.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
        expect(rect.right, lessThanOrEqualTo(320.5));
        // The button follows, built just below the screen.
        final button = find.byKey(
          const ValueKey('delete-account-confirm'),
          skipOffstage: false,
        );
        expect(button, findsOneWidget);
        expect(rect.bottom, lessThan(tester.getTopLeft(button).dy));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // UX loop 2026-10-19-app, round 1 · P170 (UX-1604).
  testWidgets(
    'UX-1604: on the delete page (ES), TalkBack reads Guardar antes una copia de tus tareas before La copia no incluye los archivos., each as its own stop',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.text(es.deleteAccountCopyNoFiles), findsOneWidget);
      final stops = readingOrder(tester);
      final copy = readAt(
        stops,
        (label) => label.contains(es.deleteAccountSaveCopy),
      );
      final note = readAt(
        stops,
        (label) => label == es.deleteAccountCopyNoFiles,
      );
      expect(copy, isNot(-1), reason: '$stops');
      expect(note, isNot(-1), reason: 'the note is a stop of its own: $stops');
      expect(copy, lessThan(note));
      expect(
        stops[copy].label.contains(es.deleteAccountCopyNoFiles),
        isFalse,
        reason: 'not merged into the button',
      );
      semantics.dispose();
    },
  );
  // ---- Run 2026-10-19-app · P189 (UX-1618): whole addresses on the delete page ----

  group('UX-1618 with Manrope', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });
    const address = 'maria.lopez@example.com';

    testWidgets(
      'UX-1618: ES, 2× on 360×800, the delete page draws maria.lopez@example.com breaking only after «@» or «.», and TalkBack reads the plain address',
      (tester) async {
        await open(
          tester,
          textScale: 2,
          size: const Size(360, 800),
          email: address,
        );
        final line = findShown(address);
        expect(line, findsOneWidget);
        expectAddressWrapsWhole(tester, line, address);
        expect(spokenLabel(tester, line), address);
        expect(tester.getRect(line).right, lessThanOrEqualTo(360.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1618: ES, 2× on 360×800, the Google confirmation line names the address whole, and TalkBack reads it plain',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        await open(
          tester,
          textScale: 2,
          size: const Size(360, 800),
          email: address,
          preview: previewJson(reauth: 'google'),
        );
        final help = findShown(l.deleteAccountGoogleHelp(address));
        await tester.scrollUntilVisible(
          help,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(help, findsOneWidget);
        expectAddressWrapsWhole(tester, help, address);
        expect(spokenLabel(tester, help), l.deleteAccountGoogleHelp(address));
        expect(tester.takeException(), isNull);
      },
    );
  });
}


/// Sign-in right after the account was deleted.
class _DeletedAuth extends AuthNotifier {
  _DeletedAuth(super.api);
  @override
  Future<void> restore() async {
    state = const AuthState(deleted: true);
  }
}
