// Deleting the account from the app (Backend/docs/ACCOUNT_DELETION.md):
// the Account screen's last row, the delete page, and what is left on the
// phone afterwards.
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
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
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/google_login_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/design_fixtures.dart';

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
  });
  @override
  Future<void> restore() async {
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'ana@example.invalid',
        'timezone': 'Europe/Madrid',
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

class _Phone {
  _Phone(Map<String, dynamic> preview) : api = _DeletionApi(preview);
  final _DeletionApi api;
  final google = _Google();
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final phone = _Phone(preview ?? previewJson());
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
          ),
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
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
        '/deleteAccount',
      );
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
      final label = find.descendant(of: row, matching: find.text(es.deleteAccount));
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
    'the page says, in order: the title and what deleting does, the counts, what stays in shared projects, each handover, the copy link, the password and the red button',
    (tester) async {
      await open(tester);
      final order = [
        find.text(es.deleteAccountQuestion),
        find.text(
          'Se eliminarán tu cuenta y tus tareas, notas y archivos en todos tus dispositivos. No se puede deshacer.',
        ),
        find.text(es.deleteAccountWhatGoes),
        find.text('12 tareas'),
        find.text('3 notas'),
        find.text('2 archivos'),
        find.text('1 proyecto'),
        find.text(
          '4 tareas que añadiste a proyectos compartidos se quedan para los demás, sin tu nombre.',
        ),
        find.text('El proyecto «Casa» pasará a Ana.'),
        find.text('El grupo «Matemáticas» pasará a Luis.'),
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
      expect(find.byKey(const ValueKey('delete-account-play-help')), findsNothing);
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
    'one task kept for the others reads in the singular, and with nothing of their own to delete there is no list',
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
      expect(
        find.text(
          '1 tarea que añadiste a proyectos compartidos se queda para los demás, sin tu nombre.',
        ),
        findsOneWidget,
      );
      expect(find.text(es.deleteAccountWhatGoes), findsNothing);
      expect(find.textContaining('pasará a'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'with Pro, the page says deleting doesn’t cancel the Google Play subscription, and its link opens Google Play’s help page',
    (tester) async {
      final phone = await open(tester, preview: previewJson(pro: true));
      expect(
        find.text('Eliminar tu cuenta no cancela tu suscripción de Google Play.'),
        findsOneWidget,
      );
      final link = find.byKey(const ValueKey('delete-account-play-help'));
      expect(
        find.descendant(of: link, matching: find.text(es.deleteAccountSubscriptionHelp)),
        findsOneWidget,
      );
      // Before the copy link and the password.
      expect(
        tester.getTopLeft(link).dy,
        lessThan(tester.getTopLeft(find.text(es.deleteAccountSaveCopy)).dy),
      );
      await tapVisible(tester, link);
      await tester.pumpAndSettle();
      expect(phone.opened.single.toString(),
          'https://support.google.com/googleplay/answer/7018481');

      // Nothing could open it: say so briefly.
      phone.opens = false;
      await tapVisible(tester, link);
      await tester.pumpAndSettle();
      expect(find.text(es.deleteAccountLinkError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Guardar antes una copia de tus tareas opens Exportar e importar, and Back returns to the page',
    (tester) async {
      await open(tester);
      await tapVisible(tester, find.byKey(const ValueKey('delete-account-export')));
      await tester.pumpAndSettle();
      expect(find.byType(DataTransferScreen), findsOneWidget);
      expect(find.text(es.exportTaskFlowFile), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
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
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
        '/deleteAccount',
      );
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
      expect(find.text('No se ha podido cargar. Revisa la conexión.'), findsOneWidget);
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
        tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
        es.deleteAccountDeleting,
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
      expect(find.text(es.deleteAccountGoogleHelp), findsOneWidget);
      expect(
        find.descendant(of: googleButton, matching: find.text('Confirmar con Google')),
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
      expect(find.text(es.googleSignInError('google_unavailable')), findsOneWidget);
      expect(googleButton, findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(phone.api.count('POST'), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'google_reauth_failed says to choose the same Google account, under the Google button, and asks for Google again',
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
      final message = find.text(
        'Elige la misma cuenta de Google con la que entras en TaskFlow.',
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
      expect(fieldError(tester), 'La contraseña no es correcta.');
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
    'plan_changed (409): nothing is deleted; the page reloads in place keeping the password, says so above the button, and sends nothing by itself; the next tap sends the new plan',
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
      expect(find.text('El proyecto «Casa» pasará a Ana.'), findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(phone.api.count('GET'), 2);

      phone.api.holdPreview!.complete();
      await tester.pumpAndSettle();
      expect(find.text('El proyecto «Casa» pasará a Luis.'), findsOneWidget);
      expect(find.text('El proyecto «Casa» pasará a Ana.'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        password,
      );
      expect(line, findsOneWidget);
      expect(
        tester.getBottomLeft(line).dy,
        lessThan(tester.getTopLeft(confirm).dy),
        reason: 'above the button',
      );
      expect(
        tester.getTopLeft(line).dy,
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
            l.deleteAccountIntro,
            l.deleteAccountTasks(12),
            l.deleteAccountGroups(2),
            l.deleteAccountKeptShared(4),
            l.deleteAccountHandover('project', 'Casa', 'Ana'),
            l.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
            l.deleteAccountSubscription,
            l.deleteAccountSubscriptionHelp,
            l.deleteAccountSaveCopy,
            l.deleteAccountPasswordHelp,
            l.deleteAccountButton,
          ]) {
            await fits(find.text(text));
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
          await fits(find.text(l.deleteAccountGoogleHelp));
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
          await fits(find.text(l.deleteAccountOtherGoogle));
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
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
        '/deleteAccount',
      );
      await tester.pumpAndSettle();
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

      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
        '/account',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('12 tareas'), findsOneWidget);
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

  test('the Spanish copy reads as the owner’s brief', () {
    expect(es.deleteAccount, 'Eliminar cuenta');
    expect(es.deleteAccountButton, 'Eliminar mi cuenta');
    expect(es.deleteAccountConfirmGoogle, 'Confirmar con Google');
    expect(es.accountDeleted, 'Tu cuenta se ha eliminado.');
    expect(
      es.deleteAccountKeptShared(3),
      '3 tareas que añadiste a proyectos compartidos se quedan para los demás, sin tu nombre.',
    );
    expect(
      es.deleteAccountHandover('group', 'Matemáticas', 'Luis'),
      'El grupo «Matemáticas» pasará a Luis.',
    );
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
