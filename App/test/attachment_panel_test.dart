// P91 (UX-500, round 1 of 2026-10-13-app): the file-space usage line and the
// refused-file messages.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  final task = Task(id: 1, title: 'Appointment', priority: 3);
  const pending = TaskAttachment(
      id: 'pending',
      taskId: 'task',
      name: 'Blood test results.pdf',
      size: 100,
      sha256: '',
      uploadPending: true,
      error: 'The connection was interrupted. Retry when connected.');
  const removed = TaskAttachment(
      id: 'removed',
      taskId: 'task',
      name: 'Old results.pdf',
      size: 100,
      sha256: '',
      remote: true,
      deleted: true,
      deletePending: true);
  testWidgets(
      'attachment states and controls fit 2x text in both languages and themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repository();
    for (final language in ['en', 'es']) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(ProviderScope(
            key: ValueKey('$language-$dark'),
            overrides: [
              taskRepositoryProvider.overrideWithValue(repo),
              attachmentEntriesProvider.overrideWith((ref, id) async => [
                    const AttachmentEntry(
                        'Blood test results.pdf', '/local/file', true,
                        item: pending),
                    const AttachmentEntry('Old results.pdf', null, false,
                        item: removed),
                    const AttachmentEntry(
                        'Local notes.txt', '/local/notes', true),
                  ]),
            ],
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: Scaffold(
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AttachmentPanel(task: task))))));
        await tester.pumpAndSettle();
        expect(
            find.text(language == 'en' ? 'Upload queued' : 'Subida pendiente'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.text(
                language == 'en' ? 'Removal pending' : 'Eliminación pendiente'),
            220);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.text(language == 'en' ? 'Upload' : 'Subir'), 220);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'opening uses the retained file; cancelling removal makes no change',
      (tester) async {
    final repository = _Repository();
    String? opened;
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      attachmentEntriesProvider.overrideWith((ref, id) async =>
          repository.store.removed
              ? []
              : [
                  const AttachmentEntry(
                      'Results.txt', '/retained/results.txt', true)
                ]),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: AttachmentPanel(
                    task: task,
                    openFile: (path) async {
                      opened = path;
                    })))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, '/retained/results.txt');
    await tester.tap(find.text('Remove attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.store.removed, isFalse);
    expect(find.text('Results.txt'), findsOneWidget);
    await tester.tap(find.text('Remove attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove attachment')));
    await tester.pumpAndSettle();
    expect(repository.store.removed, isTrue);
    expect(find.text('Results.txt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ---- P91 · UX-500: file space ----

  const megabyte = 1024 * 1024;
  TaskAttachment refused({bool shared = false}) => TaskAttachment(
      id: shared ? 'refused-shared' : 'refused-own',
      taskId: 'task',
      name: 'Scan.pdf',
      size: 100,
      sha256: '',
      uploadPending: true,
      error: shared
          ? TaskAttachment.storageFullShared
          : TaskAttachment.storageFull);

  Future<_Repository> pumpPanel(WidgetTester tester,
      {String language = 'en',
      bool pro = false,
      int? usedMb,
      List<AttachmentEntry>? entries,
      double textScale = 1}) async {
    final repository = _Repository();
    final api = OfflineApiClient();
    addTearDown(api.close);
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => _StorageAuth(
              api,
              usedMb == null
                  ? null
                  : {
                      'used_bytes': usedMb * megabyte,
                      'limit_bytes': 100 * megabyte
                    })),
          hasProProvider.overrideWithValue(pro),
          taskRepositoryProvider.overrideWithValue(repository),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          attachmentEntriesProvider.overrideWith((ref, id) async =>
              entries ??
              [const AttachmentEntry('Local notes.txt', '/local/notes', true)]),
        ],
        child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AttachmentPanel(task: task))))));
    await tester.pumpAndSettle();
    return repository;
  }

  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
        'UX-500: at 80 of 100 MB a free account sees the usage line ($language, 2x text at 320 dp); below 80% and with Pro it sees nothing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l = lookupAppLocalizations(Locale(language));
      await pumpPanel(tester, language: language, usedMb: 80, textScale: 2);
      expect(find.text(l.storageUsage(80, 100)), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpPanel(tester, language: language, usedMb: 79);
      expect(find.text(l.storageUsage(79, 100)), findsNothing);
      expect(find.textContaining(l.storageUsage(79, 100).split(' ').first),
          findsNothing);

      await pumpPanel(tester, language: language, usedMb: 95, pro: true);
      expect(find.text(l.storageUsage(95, 100)), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final shared in [false, true]) {
    testWidgets(
        'UX-500: a file refused for ${shared ? 'a shared project owner’s' : 'the user’s own'} full space says so${shared ? ' without' : ' with'} Ver Pro, never a recovery-code error, and its Retry sends it again',
        (tester) async {
      final item = refused(shared: shared);
      for (final language in ['es', 'ca', 'en']) {
        final l = lookupAppLocalizations(Locale(language));
        final repository = await pumpPanel(tester,
            language: language,
            usedMb: 100,
            entries: [
              AttachmentEntry('Scan.pdf', '/local/scan.pdf', true, item: item)
            ]);
        expect(find.text(shared ? l.storageFullShared : l.storageFull(100)),
            findsOneWidget);
        expect(find.widgetWithText(TextButton, l.voiceProAction),
            shared ? findsNothing : findsOneWidget);
        expect(find.text(l.requestError('recoveryCode')), findsNothing);
        expect(find.textContaining('attachment_problem'), findsNothing);
        expect(find.text(l.fileQueued), findsNothing);
        final retry = find.widgetWithText(TextButton, l.fileRetry);
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(repository.store.retried, [item.id]);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('UX-500: when Pro turns on, the app sends refused files again',
      (tester) async {
    final repository = _Repository();
    final pro = StateProvider<bool>((ref) => false);
    final api = _BillingApi();
    final container = ProviderContainer(overrides: [
      invitationLinkProvider
          .overrideWith((ref) => InvitationLinks(listen: false)),
      hasProProvider.overrideWith((ref) => ref.watch(pro)),
      billingLoadingProvider.overrideWithValue(false),
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
      pendingCapturesProvider.overrideWith((ref) async => []),
      taskListsProvider.overrideWith((ref) async => []),
      taskRepositoryProvider.overrideWithValue(repository),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(api.close);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    expect(repository.store.retriedAll, 0);
    container.read(pro.notifier).state = true;
    await tester.pumpAndSettle();
    expect(api.billing, 1);
    expect(repository.store.retriedAll, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ---- Round 2 · P95 · UX-506, UX-507 ----

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-506: a file refused for the user’s own full space says to remove files from other tasks, with Ver Pro, and fits ($language, 2x text at 320 dp)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l = lookupAppLocalizations(Locale(language));
      final item = refused();
      await pumpPanel(tester,
          language: language,
          usedMb: 100,
          textScale: 2,
          entries: [
            AttachmentEntry('Scan.pdf', '/local/scan.pdf', true, item: item)
          ]);
      final message = find.text(l.storageFull(100));
      expect(message, findsOneWidget);
      await tester.ensureVisible(message);
      await tester.pumpAndSettle();
      var rect = tester.getRect(message);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320.5));
      final pro = find.widgetWithText(TextButton, l.voiceProAction);
      expect(pro, findsOneWidget);
      await tester.ensureVisible(pro);
      await tester.pumpAndSettle();
      rect = tester.getRect(pro);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320.5));
      expect(tester.takeException(), isNull, reason: 'no overflow');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('UX-506: storageFull points to other tasks, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.storageFull(100),
        'Tu espacio para archivos está lleno (100 MB). Elimina archivos de otras tareas para hacer sitio o hazte Pro para tener espacio ilimitado.');
    expect(en.storageFull(100),
        'Your file space is full (100 MB). Remove files from other tasks to make room, or get Pro for unlimited space.');
    expect(ca.storageFull(100),
        'El teu espai per a fitxers és ple (100 MB). Treu fitxers d’altres tasques per fer lloc o fes-te Pro per tenir espai il·limitat.');
    for (final l in [en, es, ca]) {
      expect(l.storageFull(100), isNot(contains('Remove a file')));
    }
  });

  for (final (language, heading) in [
    ('es', 'Archivos'),
    ('en', 'Files'),
    ('ca', 'Fitxers adjunts'),
  ]) {
    testWidgets(
        'UX-507: the panel’s heading reads $heading over the usage line at 85 of 100 MB ($language)',
        (tester) async {
      final l = lookupAppLocalizations(Locale(language));
      expect(l.attachments, heading);
      await pumpPanel(tester, language: language, usedMb: 85);
      // SectionLabel shows its text in capitals.
      expect(find.text(heading.toUpperCase()), findsOneWidget);
      final usage = find.text(l.storageUsage(85, 100));
      expect(usage, findsOneWidget);
      if (language == 'es') {
        expect(find.text('Archivos: 85 de 100 MB usados'), findsOneWidget);
      }
      expect(
          tester.getTopLeft(find.text(heading.toUpperCase())).dy,
          lessThan(tester.getTopLeft(usage).dy),
          reason: 'the heading sits above the usage line');
      expect(find.text('ADJUNTOS'), findsNothing);
      expect(find.text('ATTACHMENTS'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
      'UX-510: fileUploadHelp has no MiB and no per-account 64 in EN, ES and CA, and says 6 MB each',
      () {
    for (final (language, each) in [
      ('en', 'up to 6 MB each'),
      ('es', 'hasta 6 MB cada uno'),
      ('ca', 'fins a 6 MB cadascun'),
    ]) {
      final help = lookupAppLocalizations(Locale(language)).fileUploadHelp;
      expect(help, isNot(contains('MiB')), reason: language);
      expect(help, isNot(contains('64')), reason: language);
      expect(help, contains(each), reason: language);
    }
  });

  testWidgets(
      'UX-507: the task editor’s files heading reads Archivos in Spanish; UX-510: its upload help says 6 MB each, with no MiB and no per-account cap',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final es = lookupAppLocalizations(const Locale('es'));
    final api = OfflineApiClient();
    final container = ProviderContainer(overrides: [
      invitationLinkProvider
          .overrideWith((ref) => InvitationLinks(listen: false)),
      hasProProvider.overrideWithValue(false),
      billingLoadingProvider.overrideWithValue(false),
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore(
          const RegionalPreferences(
              language: 'es', clock: ClockFormat.twentyFour, weekStart: 1))),
      pendingCapturesProvider.overrideWith((ref) async => []),
      taskListsProvider.overrideWith((ref) async => []),
      // A signed-in phone: new files upload to the account.
      taskRepositoryProvider.overrideWithValue(_CloudTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(api.close);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => TaskEditor(
                task: Task(
                    id: 7,
                    title: 'Médico',
                    priority: 3,
                    filePaths: const ['/local/resultados.pdf']))));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    final scroll = find
        .descendant(
            of: find.byType(TaskEditor), matching: find.byType(Scrollable))
        .first;
    // Files sit under Más detalles.
    final more = find.byKey(const ValueKey('task-more-details'));
    await tester.scrollUntilVisible(more, 200, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    final heading = find.text(es.attachments.toUpperCase());
    await tester.scrollUntilVisible(heading, 200, scrollable: scroll);
    await tester.pumpAndSettle();
    expect(heading, findsOneWidget);
    expect(es.attachments, 'Archivos');
    expect(find.text('ADJUNTOS'), findsNothing);

    final help = find.text(es.fileUploadHelp);
    await tester.scrollUntilVisible(help, 200, scrollable: scroll);
    expect(help, findsOneWidget);
    expect(
        es.fileUploadHelp,
        startsWith(
            'Los archivos nuevos se suben a tu cuenta al guardar, hasta 6 MB cada uno.'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ---- b7 round 3 · P99 (UX-512): the file size limit says 6 MB everywhere ----

  test(
      'UX-512: fileLocalHelp, fileLimit and requestError(fileLimit) say 6 MB and never MiB in EN, ES and CA; fileLimit still allows 20 files per task',
      () {
    for (final (language, twenty) in [
      ('en', 'up to 20 files per task'),
      ('es', 'hasta 20 archivos por tarea'),
      ('ca', 'fins a 20 fitxers per tasca'),
    ]) {
      final l = lookupAppLocalizations(Locale(language));
      for (final text in [
        l.fileLocalHelp,
        l.fileLimit,
        l.requestError('fileLimit'),
      ]) {
        expect(text, contains('6 MB'), reason: '$language: $text');
        expect(text, isNot(contains('MiB')), reason: '$language: $text');
      }
      expect(l.fileLimit, contains(twenty), reason: language);
    }
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.fileLocalHelp,
        'Files stay on this device until you sign in and choose Upload in task details. Up to 6 MB per file.');
    expect(en.fileLimit,
        'Choose a non-empty file up to 6 MB. You can attach up to 20 files per task.');
    expect(en.requestError('fileLimit'), 'Choose a non-empty file up to 6 MB.');
    expect(ca.fileLocalHelp, endsWith('Fins a 6 MB per fitxer.'));
    expect(ca.requestError('fileLimit'),
        'Tria un fitxer no buit de fins a 6 MB.');
  });

  test(
      'UX-512: the internal message “Choose a non-empty file up to 6 MiB.” still maps to fileLimit, and in Spanish reads “Elige un archivo no vacío de hasta 6 MB.”',
      () {
    final es = lookupAppLocalizations(const Locale('es'));
    const internal = FormatException('Choose a non-empty file up to 6 MiB.');
    expect(requestProblem(internal), 'fileLimit');
    expect(requestProblemText(es, internal),
        'Elige un archivo no vacío de hasta 6 MB.');
    // The server's own 413 maps the same way.
    expect(requestProblemText(es, ApiException(413, 'Too large.')),
        'Elige un archivo no vacío de hasta 6 MB.');
  });

  for (final signedIn in [false, true]) {
    testWidgets(
        'UX-512: the task editor in Spanish, ${signedIn ? 'signed in, says new files upload up to 6 MB each' : 'signed out with a local file, ends its file help with Hasta 6 MB por archivo.'}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final es = lookupAppLocalizations(const Locale('es'));
      final api = OfflineApiClient();
      final container = ProviderContainer(overrides: [
        hasProProvider.overrideWithValue(false),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) =>
            signedIn ? SignedInFixtureAuth(api) : _SignedOutAuth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore(
            const RegionalPreferences(
                language: 'es', clock: ClockFormat.twentyFour, weekStart: 1))),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith((ref) async => []),
        taskRepositoryProvider
            .overrideWithValue(signedIn ? _CloudTasks() : MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      addTearDown(api.close);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: const Locale('es'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: TaskEditor(
                  task: Task(
                      id: 7,
                      title: 'Médico',
                      priority: 3,
                      filePaths: const ['/local/resultados.pdf'])))));
      await tester.pumpAndSettle();
      expect(container.read(authProvider).account == null, !signedIn);
      final scroll = find
          .descendant(
              of: find.byType(TaskEditor), matching: find.byType(Scrollable))
          .first;
      final more = find.byKey(const ValueKey('task-more-details'));
      await tester.scrollUntilVisible(more, 200, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      final help =
          find.text(signedIn ? es.fileUploadHelp : es.fileLocalHelp);
      await tester.scrollUntilVisible(help, 200, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(help, findsOneWidget);
      final shown = tester.widget<Text>(help).data!;
      if (signedIn) {
        expect(shown, contains('hasta 6 MB cada uno'));
        expect(find.text(es.fileLocalHelp), findsNothing);
      } else {
        expect(shown, endsWith('Hasta 6 MB por archivo.'));
        expect(find.text(es.fileUploadHelp), findsNothing);
      }
      expect(shown, isNot(contains('MiB')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

/// Nobody is signed in: files stay on this phone.
class _SignedOutAuth extends AuthNotifier {
  _SignedOutAuth(super.api);
  @override
  Future<void> restore() async {
    if (mounted) state = const AuthState();
  }
}

/// The tasks of a signed-in account: files upload to it.
class _CloudTasks extends MemoryTasks {
  @override
  String get ownerKey => 'http://fixture/users/1';
}

class _StorageAuth extends AuthNotifier {
  _StorageAuth(super.api, this.storage);
  final Map<String, dynamic>? storage;
  @override
  Future<void> restore() async {
    state = AuthState(
        account: Account.fromJson({
      'id': 1,
      'email': 'files@example.invalid',
      'timezone': 'Europe/Madrid',
      if (storage != null) 'storage': storage,
    }));
  }
}

/// Answers the billing access check that follows Pro turning on.
class _BillingApi extends OfflineApiClient {
  int billing = 0;
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (path == 'billing/access/') {
      billing++;
      return {};
    }
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

class _Repository extends MemoryTasks {
  final store = _Store();
  @override
  String get ownerKey => 'http://fixture/users/1';
  @override
  AttachmentStore get attachments => store;
}

class _Store extends AttachmentStore {
  _Store() : super(TaskDatabase(), 'http://fixture/users/1');
  bool removed = false;
  final retried = <String>[];
  int retriedAll = 0;
  @override
  Future<void> removeLocal(int taskId, String path) async {
    removed = true;
  }

  @override
  Future<void> retryRefused([String? id]) async {
    if (id == null) {
      retriedAll++;
    } else {
      retried.add(id);
    }
  }
}
