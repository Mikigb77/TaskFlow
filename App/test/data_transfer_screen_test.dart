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
        await tester.scrollUntilVisible(find.text(chooseLabel), 160);
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
