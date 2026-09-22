import 'dart:convert';
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
  for (final brightness in Brightness.values) {
    testWidgets(
        'preview, deselection and repeat import at large text in $brightness',
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
        archiveStoreProvider.overrideWithValue(store)
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const DataTransferScreen())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Export TaskFlow file'), 220);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export TaskFlow file'));
      await tester.pumpAndSettle();
      expect(files.saved, store.contents);
      await tester.scrollUntilVisible(find.text('Choose import file'), 160);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose import file'));
      await tester.pumpAndSettle();
      expect(store.receipts, isEmpty);
      final skip = find.widgetWithText(CheckboxListTile, 'Keep for later');
      await tester.scrollUntilVisible(skip, 220);
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('confirm-import')), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('confirm-import')));
      await tester.pumpAndSettle();
      expect(store.receipts.length, 1);
      expect(store.calls, 1);
      expect(find.textContaining('Added 1 task'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Choose import file'), -240);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose import file'));
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
          ...Task(title: title, priority: 1).toApi()
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
  @override
  Future<bool> save(String contents) async {
    saved = contents;
    return true;
  }

  @override
  Future<ArchiveFile?> choose() async => ArchiveFile('tasks.json', _fixture());
}

class _Store extends ArchiveStore {
  _Store() : super(TaskDatabase(), 'local');
  final contents = _fixture();
  final receipts = <String>{};
  int calls = 0;
  @override
  Future<String> export() async => contents;
  @override
  Future<Set<String>> imported(String archiveId) async => {...receipts};
  @override
  Future<ImportResult> import(TaskArchive archive, Set<String> selected) async {
    calls++;
    final added = selected.difference(receipts).length;
    receipts.addAll(selected);
    return ImportResult(added, selected.length - added);
  }
}
