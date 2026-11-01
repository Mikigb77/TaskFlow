import 'package:agenda/widgets/app_components.dart';
import 'dart:io';
import 'dart:convert';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/services/archive_files.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/theme/app_theme.dart';
import 'support/button_label.dart';
import 'support/icon_button_label.dart';
import 'support/design_fixtures.dart';

void main() {
  for (final lang in ['en', 'es']) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '$lang preview, locale switch, deselection and repeat import at large text in $brightness',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final files = _Files();
        final store = _Store();
        final locale = ValueNotifier(Locale(lang));
        addTearDown(locale.dispose);
        final exportLabel =
            lang == 'es' ? 'Exportar archivo TaskFlow' : 'Export TaskFlow file';
        final chooseLabel = lang == 'es'
            ? 'Elegir archivo para importar'
            : 'Choose import file';
        final parent = designContainer();
        addTearDown(parent.dispose);
        final container = ProviderContainer(parent: parent, overrides: [
          archiveFilesProvider.overrideWithValue(files),
          archiveStoreProvider.overrideWithValue(store)
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: ValueListenableBuilder<Locale>(
                valueListenable: locale,
                builder: (context, currentLocale, child) => MaterialApp(
                    locale: currentLocale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: ThemeData(brightness: brightness),
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: const TextScaler.linear(2)),
                        child: child!),
                    home: const DataTransferScreen()))));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(exportLabel), 220);
        await tester.pumpAndSettle();
        await tester.tap(find.text(exportLabel));
        await tester.pumpAndSettle();
        expect(files.saved, store.contents);
        // The result banner, under the help, is brought into view: back up.
        await tester.scrollUntilVisible(find.text(chooseLabel), -160);
        await tester.pumpAndSettle();
        await tester.tap(find.text(chooseLabel));
        await tester.pumpAndSettle();
        expect(store.receipts, isEmpty);
        final skip = find.widgetWithText(CheckboxListTile, 'Keep for later');
        await tester.scrollUntilVisible(skip, 220);
        await tester.pumpAndSettle();
        await tester.tap(skip);
        final invalid = find.widgetWithText(CheckboxListTile, 'Invalid task');
        await tester.scrollUntilVisible(invalid, 200);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(invalid).onChanged, isNull);
        expect(
            find.textContaining(lang == 'es'
                ? 'prioridad: valor no válido (1–3)'
                : 'Invalid priority (1–3)'),
            findsOneWidget);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('confirm-import')), 180);
        await tester.pumpAndSettle();
        locale.value = Locale(lang == 'es' ? 'en' : 'es');
        await tester.pumpAndSettle();
        expect(
            find.text(lang == 'es'
                ? 'Import 1 selected item and projects'
                : 'Importar 1 elemento seleccionado y proyectos'),
            findsOneWidget);
        expect(store.receipts, isEmpty);
        locale.value = Locale(lang);
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const ValueKey('confirm-import')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('confirm-import')));
        await tester.pumpAndSettle();
        expect(store.receipts.length, 1);
        expect(store.calls, 1);
        expect(store.importedTasks.single.title, 'Bring results');
        expect(store.importedTasks.single.notes, 'Original user note');
        expect(store.importedTasks.single.dueDate, DateTime(2030, 9, 23));
        expect(store.importedTasks.single.hasTime, isFalse);
        expect(
            find.textContaining(
                lang == 'es' ? 'Se han añadido 1 elemento' : 'Added 1 item'),
            findsWidgets);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(chooseLabel), -240);
        await tester.pumpAndSettle();
        await tester.tap(find.text(chooseLabel));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.widgetWithText(CheckboxListTile, 'Bring results'), 200);
        await tester.pumpAndSettle();
        final imported = tester.widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Bring results'));
        expect(imported.onChanged, isNull);
        expect(imported.value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'a bad replacement file clears the old preview and error follows locale without writes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = _Files();
    final store = _Store();
    final parent = designContainer();
    addTearDown(parent.dispose);
    final container = ProviderContainer(parent: parent, overrides: [
      archiveFilesProvider.overrideWithValue(files),
      archiveStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    final locale = ValueNotifier(const Locale('es'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, current, child) => MaterialApp(
            locale: current,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const DataTransferScreen(),
          ),
        )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Elegir archivo para importar'), 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo para importar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Vista previa de importación'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Vista previa de importación'), findsOneWidget);
    files.contents = '{invalid JSON';
    await tester.scrollUntilVisible(
        find.text('Elegir archivo para importar'), -220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo para importar'));
    await tester.pumpAndSettle();
    final error =
        find.text('El archivo no contiene JSON o texto UTF-8 válido.');
    await tester.scrollUntilVisible(error, 200);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-import')), findsNothing);
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(
        find.text('The file is not valid JSON or UTF-8 text.'), findsOneWidget);
    expect(store.calls, 0);
    expect(store.receipts, isEmpty);
    files.contents = _fixture();
    await tester.scrollUntilVisible(find.text('Choose import file'), -180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose import file'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Import preview'), 180);
    await tester.pumpAndSettle();
    expect(find.text('Import preview'), findsOneWidget);
    expect(
        find.text('The file is not valid JSON or UTF-8 text.'), findsNothing);
    expect(store.receipts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // ---- P44 · UX-423: the export intro in one line ----

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-423: Export opens with its one line, and no inventory of what a file holds ($language, 2x text at 320 dp)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final parent = designContainer();
      addTearDown(parent.dispose);
      final container = ProviderContainer(parent: parent, overrides: [
        archiveFilesProvider.overrideWithValue(_Files()),
        archiveStoreProvider.overrideWithValue(_Store()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const DataTransferScreen())));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(language));
      // The line opens the screen; no headline above it (UX-1620).
      final intro = find.text(l.exportImportIntro, skipOffstage: false);
      expect(intro, findsOneWidget);
      expect(tester.getRect(intro).right, lessThanOrEqualTo(320.5));
      // The old 45-word inventory (Spanish: 'proyectos de pasos') is gone.
      for (final word in ['proyectos de pasos', 'etiquetas', 'credentials']) {
        expect(find.textContaining(word, skipOffstage: false), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('UX-423: the export line is one sentence naming a file and Todoist', () {
    for (final language in ['en', 'es', 'ca']) {
      final line = lookupAppLocalizations(Locale(language)).exportImportIntro;
      expect(line, contains('Todoist'));
      expect('.'.allMatches(line).length, 1, reason: line);
      expect(line.split(' ').length, lessThan(20), reason: line);
    }
  });

  // ---- Run 2026-10-19-app · P188 (UX-1620): Exportar e importar ----

  test('UX-1620: the import help reads as planned in EN, ES and CA, with no formats or limits',
      () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.chooseImportFileHelp,
        'Choose a TaskFlow file or a project exported from Todoist. You’ll review it before importing.');
    expect(es.chooseImportFileHelp,
        'Elige un archivo de TaskFlow o un proyecto exportado de Todoist. Podrás revisarlo antes de importar.');
    expect(ca.chooseImportFileHelp,
        'Tria un fitxer de TaskFlow o un projecte exportat de Todoist. El podràs revisar abans d’importar-lo.');
    for (final l in [en, es, ca]) {
      for (final word in ['JSON', 'CSV', '32 MB', '5.000', '5,000']) {
        expect(l.chooseImportFileHelp, isNot(contains(word)));
      }
    }
    for (final language in ['en', 'es', 'ca']) {
      expect(File('lib/l10n/app_$language.arb').readAsStringSync(),
          isNot(contains('"keepYourTasks"')),
          reason: language);
    }
  });

  testWidgets(
      'UX-1620: Exportar e importar has no Llévate tus tareas., says the new help, and shows each result once, in the banner, with no snackbar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final es = lookupAppLocalizations(const Locale('es'));
    final files = _Files();
    final store = _Store();
    final parent = designContainer();
    addTearDown(parent.dispose);
    final container = ProviderContainer(parent: parent, overrides: [
      archiveFilesProvider.overrideWithValue(files),
      archiveStoreProvider.overrideWithValue(store)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DataTransferScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Llévate tus tareas.', skipOffstage: false), findsNothing);
    expect(
        find.text(
            'Elige un archivo de TaskFlow o un proyecto exportado de Todoist. Podrás revisarlo antes de importar.',
            skipOffstage: false),
        findsOneWidget);
    expect(find.text(es.chooseImportFileHelp, skipOffstage: false),
        findsOneWidget);

    Future<void> expectNoSnackBar() async {
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(SnackBar), findsNothing, reason: 'frame $frame');
      }
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }

    // Export: the result in the banner only.
    final export = find.text('Exportar archivo TaskFlow');
    await tester.scrollUntilVisible(export, 200);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await expectNoSnackBar();
    expect(files.saved, store.contents);
    expect(find.byType(MessageBanner, skipOffstage: false), findsOneWidget);

    // Import: the result in the banner only.
    final choose = find.text('Elegir archivo para importar');
    await tester.scrollUntilVisible(choose, -200);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('confirm-import'));
    await tester.scrollUntilVisible(confirm, 200);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await expectNoSnackBar();
    expect(store.calls, 1);
    final added = find.textContaining('Se han añadido', skipOffstage: false);
    expect(added, findsOneWidget, reason: 'said once');
    expect(
        find.descendant(
            of: find.byType(MessageBanner, skipOffstage: false),
            matching: added),
        findsOneWidget);
    // Brought into view.
    final rect = tester.getRect(added);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app · P217 (UX-1652): the reveal jumps with animations off ----

  for (final animationsOff in [true, false]) {
    testWidgets(
        animationsOff
            ? 'UX-1652: with animations off, the import result banner is fully in view one frame later, with no scroll frames in between'
            : 'UX-1652: with animations on, the import result banner still scrolls into view with an animation',
        (tester) async {
      // A short view, so revealing the banner needs a scroll.
      tester.view.physicalSize = const Size(360, 450);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final es = lookupAppLocalizations(const Locale('es'));
      final files = _Files();
      final store = _Store();
      final parent = designContainer();
      addTearDown(parent.dispose);
      final container = ProviderContainer(parent: parent, overrides: [
        archiveFilesProvider.overrideWithValue(files),
        archiveStoreProvider.overrideWithValue(store)
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: animationsOff),
                  child: child!),
              home: const DataTransferScreen())));
      await tester.pumpAndSettle();

      await tester.tap(find.text(es.chooseImportFile));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('confirm-import'));
      await tester.scrollUntilVisible(confirm, 200);
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
              of: find.byType(DataTransferScreen),
              matching: find.byType(Scrollable))
          .first;
      double offset() =>
          tester.state<ScrollableState>(scrollable).position.pixels;
      final atConfirm = offset();
      expect(atConfirm, greaterThan(0), reason: 'scrolled down to confirm');

      final banner = find.byType(MessageBanner, skipOffstage: false);
      bool inView() {
        if (banner.evaluate().isEmpty) return false;
        final rect = tester.getRect(banner);
        final viewport = tester.getRect(scrollable);
        return rect.top >= viewport.top - 0.5 &&
            rect.bottom <= viewport.bottom + 0.5;
      }

      await tester.tap(confirm);
      // Frame by frame until the result's banner is built.
      var frames = 0;
      while (banner.evaluate().isEmpty && frames < 30) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(banner, findsOneWidget, reason: 'the result shows in a banner');
      expect(store.calls, 1);
      // Then every later frame's scroll position.
      final offsets = <double>[offset()];
      final shown = <bool>[inView()];
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        offsets.add(offset());
        shown.add(inView());
      }
      await tester.pumpAndSettle();
      expect(inView(), isTrue, reason: 'brought into view');
      final finalOffset = offset();
      expect((finalOffset - atConfirm).abs(), greaterThan(50),
          reason: 'the reveal had to scroll: $atConfirm → $finalOffset');
      if (animationsOff) {
        // One frame after the banner is built it is fully in view, and the
        // list doesn't move again.
        expect(shown[1], isTrue, reason: 'offsets $offsets');
        for (var frame = 1; frame < offsets.length; frame++) {
          expect(offsets[frame], moreOrLessEquals(finalOffset),
              reason: 'frame $frame of $offsets');
        }
      } else {
        // The 250 ms reveal passes through positions between start and end.
        final between = offsets
            .where((o) =>
                (o - offsets.first).abs() > 0.5 &&
                (o - finalOffset).abs() > 0.5)
            .toSet();
        expect(between.length, greaterThanOrEqualTo(3),
            reason: 'offsets $offsets');
      }
      expect(tester.takeException(), isNull);
    });
  }


  // ---- UX loop 2026-10-28-app, round 1 · P289 (UX-2608, UX-2108) ----
  group('P289 · padded, centred filled buttons', () {
    for (final language in ['es', 'ca']) {
      testWidgets(
          'UX-2608 / UX-2108: $language 2× on 320×640, «Exportar archivo TaskFlow» is at least 58 dp tall, its lines centred with at least 8 dp above and below',
          (tester) async {
        await loadManrope();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l = lookupAppLocalizations(Locale(language));
        final parent = designContainer();
        addTearDown(parent.dispose);
        final container = ProviderContainer(parent: parent, overrides: [
          archiveFilesProvider.overrideWithValue(_Files()),
          archiveStoreProvider.overrideWithValue(_Store())
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const DataTransferScreen())));
        await tester.pumpAndSettle();
        final export = filledButtonWithText(l.exportTaskFlowFile);
        await tester.ensureVisible(export);
        await tester.pumpAndSettle();
        expect(tester.getRect(export).height, greaterThanOrEqualTo(58));
        expectCentredPaddedLabel(tester, export, l.exportTaskFlowFile);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---- UX loop 2026-10-28-app, round 2 · P304 (UX-2630, UX-2631, UX-2108) ----
  group('P304 · icon buttons centre their wrapped labels', () {
    /// Exportar e importar in [language] at [scale] on 360×800.
    Future<void> pumpTransfer(
        WidgetTester tester, String language, double scale) async {
      await loadManrope();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final parent = designContainer();
      addTearDown(parent.dispose);
      final container = ProviderContainer(parent: parent, overrides: [
        archiveFilesProvider.overrideWithValue(_Files()),
        archiveStoreProvider.overrideWithValue(_Store())
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const DataTransferScreen())));
      await tester.pumpAndSettle();
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
          'UX-2630: $language 2× on 360×800 (settings/data-transfer.start.$language.light.2x), the download icon sits beside «Exportar archivo TaskFlow»’s longest line, and icon and label are centred in the button',
          (tester) async {
        await pumpTransfer(tester, language, 2);
        final l = lookupAppLocalizations(Locale(language));
        final export = filledButtonWithText(l.exportTaskFlowFile);
        await tester.ensureVisible(export);
        await tester.pumpAndSettle();
        expect(labelLines(tester, export, l.exportTaskFlowFile).length,
            greaterThanOrEqualTo(2),
            reason: 'the label wraps here, as in the render');
        expectIconBesideCentredLabel(tester, export, l.exportTaskFlowFile);
        expectCentredPaddedLabel(tester, export, l.exportTaskFlowFile);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'UX-2631: $language 2× on 360×800, «Elegir archivo para importar» is centred with its icon, its lines centred, with at least 8 dp between its text and the button’s top and bottom edges',
          (tester) async {
        await pumpTransfer(tester, language, 2);
        final l = lookupAppLocalizations(Locale(language));
        final import = outlinedButtonWithText(l.chooseImportFile);
        await tester.ensureVisible(import);
        await tester.pumpAndSettle();
        // Measured against the visible outline, not the tap target.
        expectCentredPaddedLabel(
            tester, visibleButton(import), l.chooseImportFile,
            wraps: language == 'es');
        expectIconBesideCentredLabel(tester, import, l.chooseImportFile);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2631 / UX-2108: es 1× on 360×800, the one-line «Elegir archivo para importar» stays 52 dp tall and «Exportar archivo TaskFlow» 60 dp',
        (tester) async {
      await pumpTransfer(tester, 'es', 1);
      final l = lookupAppLocalizations(const Locale('es'));
      final import = outlinedButtonWithText(l.chooseImportFile);
      final export = filledButtonWithText(l.exportTaskFlowFile);
      expect(labelLines(tester, import, l.chooseImportFile), hasLength(1),
          reason: 'one line at 1×');
      // The visible buttons; the tap target is measured apart.
      expect(tester.getRect(visibleButton(import)).height, closeTo(52, 0.5));
      expect(tester.getRect(visibleButton(export)).height, closeTo(60, 0.5));
      expect(tester.takeException(), isNull);
    });
  });
}


String _fixture() {
  final data = {
    'format': 'taskflow',
    'version': 1,
    'export_id': 'b99eb0c2-0baf-4ff0-97b5-cd6f1fa2bfaf',
    'lists': [],
    'tasks': [
      for (final title in ['Bring results', 'Keep for later'])
        {
          'id': const Uuid().v5('b99eb0c2-0baf-4ff0-97b5-cd6f1fa2bfaf', title),
          ...Task(
                  title: title,
                  priority: 1,
                  notes: 'Original user note',
                  dueDate: DateTime(2030, 9, 23),
                  hasTime: false)
              .toApi(),
          'attachments': ['report.pdf'],
        },
      {
        'id': '8465af7c-f1c3-40a4-afcb-e03b892c3254',
        ...Task(title: 'Invalid task', priority: 5).toApi()
      },
    ]
  };
  return jsonEncode(data);
}

class _Files extends ArchiveFiles {
  String? saved;
  String contents = _fixture();
  @override
  Future<bool> save(String contents) async {
    saved = contents;
    return true;
  }

  @override
  Future<ArchiveFile?> choose() async => ArchiveFile('tasks.json', contents);
}

class _Store extends ArchiveStore {
  _Store() : super(TaskDatabase(), 'local');
  final contents = _fixture();
  final receipts = <String>{};
  final importedTasks = <Task>[];
  int calls = 0;
  @override
  Future<String> export() async => contents;
  @override
  Future<Set<String>> imported(String archiveId) async => {...receipts};
  @override
  Future<ImportResult> import(TaskArchive archive, Set<String> selected) async {
    calls++;
    final added = selected.difference(receipts).length;
    importedTasks.addAll(archive.tasks
        .where((row) =>
            selected.contains(row.sourceId) && !receipts.contains(row.sourceId))
        .map((row) => row.task!));
    receipts.addAll(selected);
    return ImportResult(added, selected.length - added);
  }
}
