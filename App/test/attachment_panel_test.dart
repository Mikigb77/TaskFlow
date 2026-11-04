// P91 (UX-500, round 1 of 2026-10-13-app): the file-space usage line and the
// refused-file messages.
import 'dart:math' as math;

import 'package:agenda/providers/no_retry.dart';
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
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
            retry: noRetry,
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
    final container = ProviderContainer(retry: noRetry, overrides: [
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
        retry: noRetry,
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
        'UX-500: a file refused for ${shared ? 'a shared project owner’s' : 'the user’s own'} full space says so${shared ? ' without' : ' with'} Ver Pro, never a recovery-code error, and ${shared ? 'its Retry sends it again' : 'offers no Retry (UX-1414)'}',
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
        if (!shared) {
          // A removal or Pro sends it again; a retry can't help.
          expect(retry, findsNothing);
          expect(tester.takeException(), isNull);
          continue;
        }
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
    final container = ProviderContainer(retry: noRetry, overrides: [
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

  // ---- Run 2026-10-18-commands, b4 · P154 (UX-1223) ----

  testWidgets(
      'UX-1223: at 100 of 100 MB, a file refused for the account’s own full space shows «Ver tareas con archivos» beside «Ver Pro»; one refused for a shared project owner’s space shows neither',
      (tester) async {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.storageSeeTasks, 'Ver tareas con archivos');
    await pumpPanel(tester, language: 'es', usedMb: 100, entries: [
      AttachmentEntry('Scan.pdf', '/local/scan.pdf', true, item: refused())
    ]);
    final see = find.widgetWithText(TextButton, es.storageSeeTasks);
    final pro = find.widgetWithText(TextButton, es.voiceProAction);
    expect(see, findsOneWidget);
    expect(pro, findsOneWidget);
    // In the file's row of actions, next to each other.
    final actions = find.ancestor(of: pro, matching: find.byType(Wrap)).first;
    expect(find.descendant(of: actions, matching: see), findsOneWidget);
    final buttons = tester
        .widgetList<TextButton>(
            find.descendant(of: actions, matching: find.byType(TextButton)))
        .toList();
    final proAt = buttons.indexOf(tester.widget<TextButton>(pro));
    expect(buttons[proAt + 1], tester.widget<TextButton>(see),
        reason: 'right after Ver Pro');
    expect(tester.takeException(), isNull);

    await pumpPanel(tester, language: 'es', usedMb: 100, entries: [
      AttachmentEntry('Scan.pdf', '/local/scan.pdf', true,
          item: refused(shared: true))
    ]);
    expect(find.text(es.storageFullShared), findsOneWidget);
    expect(find.widgetWithText(TextButton, es.storageSeeTasks), findsNothing);
    expect(find.widgetWithText(TextButton, es.voiceProAction), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('UX-1414: storageFull is one sentence, in EN, ES and CA', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.storageFull(100),
        'Tu espacio para archivos está lleno (100\u00a0MB).');
    expect(en.storageFull(100), 'Your file space is full (100\u00a0MB).');
    expect(ca.storageFull(100),
        'El teu espai per a fitxers és ple (100\u00a0MB).');
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
        expect(find.text('Archivos: 85 de 100 MB usados'), findsOneWidget);
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
    final container = ProviderContainer(retry: noRetry, overrides: [
      invitationLinkProvider
          .overrideWith((ref) => InvitationLinks(listen: false)),
      hasProProvider.overrideWithValue(false),
      billingLoadingProvider.overrideWithValue(false),
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      // A file kept only on the phone, which shows «Subir» (UX-2419).
      attachmentEntriesProvider.overrideWith((ref, taskId) async => const [
            AttachmentEntry('resultados.pdf', '/local/resultados.pdf', true)
          ]),
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

    // The upload help sits in the attach sheet, not in the form.
    final help = find.text(es.fileUploadHelp);
    expect(help, findsNothing);
    final attach = find.text(es.addAttachment);
    await tester.scrollUntilVisible(attach, 200, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.tap(attach);
    await tester.pumpAndSettle();
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
      'UX-512: fileLimit and requestError(fileLimit) say 6 MB and never MiB in EN, ES and CA; fileLimit still allows 20 files per task',
      () {
    for (final (language, twenty) in [
      ('en', 'up to 20 files per task'),
      ('es', 'hasta 20 archivos por tarea'),
      ('ca', 'fins a 20 fitxers per tasca'),
    ]) {
      final l = lookupAppLocalizations(Locale(language));
      for (final text in [
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
    expect(en.fileLimit,
        'Choose a non-empty file up to 6 MB. You can attach up to 20 files per task.');
    expect(en.requestError('fileLimit'), 'Choose a non-empty file up to 6 MB.');
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
        'UX-512: the task editor in Spanish, ${signedIn ? 'signed in with a file kept only on the phone, says new files upload up to 6 MB each' : 'signed out with a local file, which offers no «Subir», shows no file help (UX-2419)'}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final es = lookupAppLocalizations(const Locale('es'));
      final api = OfflineApiClient();
      final container = ProviderContainer(retry: noRetry, overrides: [
        hasProProvider.overrideWithValue(false),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) =>
            signedIn ? SignedInFixtureAuth(api) : _SignedOutAuth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => const [
              AttachmentEntry('resultados.pdf', '/local/resultados.pdf', true)
            ]),
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
      // The file help shows in the attach sheet, not in the form.
      final help = find.text(es.fileUploadHelp);
      expect(help, findsNothing);
      final attach = find.text(es.addAttachment);
      await tester.scrollUntilVisible(attach, 200, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(attach);
      await tester.pumpAndSettle();
      expect(find.text(es.attachFile), findsOneWidget);
      if (signedIn) {
        expect(help, findsOneWidget);
        final shown = tester.widget<Text>(help).data!;
        expect(shown, contains('hasta 6 MB cada uno'));
        expect(shown, isNot(contains('MiB')));
      } else {
        expect(help, findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // ---- Run 2026-10-19-app, round 1 · P179 (UX-1414) ----

  /// The card of the file named [name].
  Finder card(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(AppSurface))
      .first;

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'UX-1414: a file refused for the account’s own full space (tasks/detail.file-space-full, es, ${scale}x on 360 dp) says one sentence and shows exactly 4 buttons, with no «Reintentar transferencia»; «Quitar archivo» is last, in the error colour, at least 12 dp below the others, and no two buttons are under 8 dp apart',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final es = lookupAppLocalizations(const Locale('es'));
      await pumpPanel(tester,
          language: 'es',
          usedMb: 100,
          textScale: scale,
          entries: [
            AttachmentEntry('Billetes de avión.pdf', '/local/billetes.pdf', true,
                item: refused())
          ]);
      final file = card('Billetes de avión.pdf');
      expect(
          find.descendant(
              of: file,
              matching:
                  find.text('Tu espacio para archivos está lleno (100\u00a0MB).')),
          findsOneWidget);
      final buttons = find.descendant(
          of: file,
          matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton));
      final labels = [
        for (final element in buttons.evaluate())
          tester
              .widgetList<Text>(find.descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(Text)))
              .map((text) => text.data)
              .join(),
      ];
      expect(labels, [
        es.fileOpen,
        es.voiceProAction,
        es.storageSeeTasks,
        es.fileRemove,
      ]);
      expect(find.descendant(of: file, matching: find.text(es.fileRetry)),
          findsNothing);
      expect(find.textContaining('transferencia'), findsNothing);
      final rects = [
        for (final element in buttons.evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      final remove = rects.last;
      final others = rects.sublist(0, rects.length - 1);
      final lowest = others.map((rect) => rect.bottom).reduce(math.max);
      expect(remove.top - lowest, greaterThanOrEqualTo(12 - 0.5),
          reason: 'apart from the others');
      final removeButton = tester.widget<ButtonStyleButton>(
          find.byWidget(buttons.evaluate().last.widget));
      final context = tester.element(file);
      expect(removeButton.style?.foregroundColor?.resolve({}),
          Theme.of(context).colorScheme.error);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final a = rects[i], b = rects[j];
          final apart = math.max(
            math.max(b.left - a.right, a.left - b.right),
            math.max(b.top - a.bottom, a.top - b.bottom),
          );
          expect(apart, greaterThanOrEqualTo(8 - 0.5),
              reason: '«${labels[i]}» and «${labels[j]}» are $apart dp apart');
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'UX-1414: the removal’s confirm button uses the error colour, like other deletions',
      (tester) async {
    final es = lookupAppLocalizations(const Locale('es'));
    await pumpPanel(tester, language: 'es', usedMb: 100, entries: [
      AttachmentEntry('Scan.pdf', '/local/scan.pdf', true, item: refused())
    ]);
    final remove = find.widgetWithText(TextButton, es.fileRemove);
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final confirm = find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, es.fileRemove));
    expect(confirm, findsOneWidget);
    final colors = Theme.of(tester.element(dialog)).colorScheme;
    final style = tester.widget<FilledButton>(confirm).style;
    expect(style?.backgroundColor?.resolve({}), colors.error);
    expect(style?.foregroundColor?.resolve({}), colors.onError);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-1414: a file that failed for another reason offers «Volver a subir» ($language)',
        (tester) async {
      final l = lookupAppLocalizations(Locale(language));
      expect(
          l.fileRetry,
          switch (language) {
            'es' => 'Volver a subir',
            'en' => 'Upload again',
            _ => 'Torna a pujar',
          });
      await pumpPanel(tester, language: language, entries: [
        const AttachmentEntry('Blood test results.pdf', '/local/file', true,
            item: pending)
      ]);
      expect(find.widgetWithText(TextButton, l.fileRetry), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // ---- Run 2026-10-28-app, round 1 · P281 (UX-2419): the attach sheet
  // explains files only to a task with one kept only on the phone. ----
  group('P281 · attach sheet', () {
    const uploaded = TaskAttachment(
        id: 'uploaded',
        taskId: '7',
        name: 'resultados.pdf',
        size: 100,
        sha256: '',
        remote: true);

    /// A signed-in account's saved task «Médico» in the Spanish edit form,
    /// whose files are [entries]; its «Añadir adjunto» sheet open.
    Future<void> openAttachSheet(
        WidgetTester tester, List<AttachmentEntry> entries) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = OfflineApiClient();
      final container = ProviderContainer(retry: noRetry, overrides: [
        hasProProvider.overrideWithValue(false),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => entries),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore(
            const RegionalPreferences(
                language: 'es', clock: ClockFormat.twentyFour, weekStart: 1))),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith((ref) async => []),
        taskRepositoryProvider.overrideWithValue(_CloudTasks()),
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
      final scroll = find
          .descendant(
              of: find.byType(TaskEditor), matching: find.byType(Scrollable))
          .first;
      final more = find.byKey(const ValueKey('task-more-details'));
      await tester.scrollUntilVisible(more, 200, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      final attach = find.text(
          lookupAppLocalizations(const Locale('es')).addAttachment);
      await tester.scrollUntilVisible(attach, 200, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(attach);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    }

    /// The sheet's texts, top to bottom.
    List<String> sheetTexts(WidgetTester tester) => [
          for (final element in find
              .descendant(
                  of: find.byType(BottomSheet), matching: find.byType(Text))
              .evaluate())
            (element.widget as Text).data ?? '',
        ];

    for (final (name, entries) in [
      ('no files kept on the phone', const <AttachmentEntry>[]),
      (
        'only a file already in the account',
        const [
          AttachmentEntry('resultados.pdf', '/local/resultados.pdf', true,
              item: uploaded)
        ]
      ),
      (
        'a phone-only file that is missing from the phone, so shows no «Subir»',
        const [AttachmentEntry('resultados.pdf', null, false)]
      ),
    ]) {
      testWidgets(
          'UX-2419: «Añadir adjunto» on a saved task with $name shows its two rows and no paragraph',
          (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await openAttachSheet(tester, entries);
        expect(find.text(es.fileUploadHelp), findsNothing);
        expect(sheetTexts(tester), [es.choosePhoto, es.attachFile]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets(
        'UX-2419: «Añadir adjunto» on a saved task with a file kept only on the phone, which shows «Subir», shows the paragraph above its two rows',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      await openAttachSheet(tester, const [
        AttachmentEntry('resultados.pdf', '/local/resultados.pdf', true,
            item: uploaded),
        AttachmentEntry('receta.pdf', '/local/receta.pdf', true),
      ]);
      expect(
          find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(es.fileUploadHelp)),
          findsOneWidget);
      expect(sheetTexts(tester),
          [es.fileUploadHelp, es.choosePhoto, es.attachFile]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ---- UX loop 2026-10-28-app, round 1 · P293 (UX-2418): «Quitar archivo»
  // in Spanish ----
  group('P293 · Quitar archivo', () {
    for (final (language, button, question) in [
      ('es', 'Quitar archivo', '¿Quitar este archivo de la tarea?'),
      ('en', 'Remove attachment', 'Remove this attachment?'),
      ('ca', 'Treu el fitxer adjunt', 'Vols treure aquest fitxer adjunt?'),
    ]) {
      testWidgets(
        'UX-2418: the remove-file dialog in $language reads «$question» with «$button»${language == 'es' ? '' : ' (unchanged)'}, and no «Eliminar»',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          expect(l.fileRemove, button);
          expect(l.fileRemoveQuestion, question);
          await pumpPanel(tester, language: language);
          final remove = find.widgetWithText(TextButton, button);
          await tester.ensureVisible(remove);
          await tester.pumpAndSettle();
          await tester.tap(remove);
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          expect(
            find.descendant(of: dialog, matching: find.text(question)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(FilledButton, button),
            ),
            findsOneWidget,
          );
          // The help under it still says the original stays.
          expect(
            find.descendant(
              of: dialog,
              matching: find.textContaining(l.fileRemoveHelp),
            ),
            findsOneWidget,
          );
          if (language == 'es') {
            expect(
              find.descendant(
                of: dialog,
                matching: find.textContaining('Eliminar'),
              ),
              findsNothing,
            );
          }
          await tester.tap(find.widgetWithText(TextButton, l.cancel));
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });

  // ---- UX loop 2026-11-01-screens, round 1 · P315 (UX-2645): the
  // remove-file help says «Se quitará» ----
  group('P315 · the task page', () {
    const es =
        'Se quitará de la tarea y, si lo has subido, de tus otros dispositivos al sincronizar. Tu archivo original no se elimina.';
    const en =
        'This removes it from the task and, if uploaded, your other devices when they sync. Your original file is not deleted.';
    const ca =
        'Es traurà de la tasca i, si s’ha pujat, dels altres dispositius quan se sincronitzin. El fitxer original no se suprimirà.';

    testWidgets(
      'UX-2645: in ES the remove-file dialog reads «¿Quitar este archivo de la tarea?», the file’s name, then «Se quitará de la tarea…», with «Quitar archivo»; nothing in it says «Se eliminará»',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        expect(l.fileRemoveHelp, es);
        await pumpPanel(tester, language: 'es');
        final remove = find.widgetWithText(TextButton, l.fileRemove);
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);

        final question = find.descendant(
          of: dialog,
          matching: find.text(l.fileRemoveQuestion),
        );
        final body = find.descendant(
          of: dialog,
          matching: find.text('Local notes.txt\n\n$es'),
        );
        final button = find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, l.fileRemove),
        );
        expect(question, findsOneWidget);
        expect(body, findsOneWidget, reason: 'the name, then the help');
        expect(button, findsOneWidget);
        // Read top to bottom: the question, the name and help, the button.
        expect(
          tester.getTopLeft(question).dy,
          lessThan(tester.getTopLeft(body).dy),
        );
        expect(
          tester.getBottomLeft(body).dy,
          lessThanOrEqualTo(tester.getTopLeft(button).dy),
        );

        final words = tester
            .widgetList<Text>(
              find.descendant(of: dialog, matching: find.byType(Text)),
            )
            .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
            .join(' | ');
        expect(words, isNot(contains('Se eliminará')), reason: words);
        expect(words, isNot(contains('eliminará')), reason: words);

        await tester.tap(find.widgetWithText(TextButton, l.cancel));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final (language, help) in [('en', en), ('ca', ca)]) {
      testWidgets(
        'UX-2645: the $language help line under the remove-file question is unchanged',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          expect(l.fileRemoveHelp, help);
          await pumpPanel(tester, language: language);
          final remove = find.widgetWithText(TextButton, l.fileRemove);
          await tester.ensureVisible(remove);
          await tester.pumpAndSettle();
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Local notes.txt\n\n$help'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(TextButton, l.cancel));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });
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
