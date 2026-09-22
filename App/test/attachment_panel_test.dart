import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/attachment_panel.dart';
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
  @override
  Future<void> removeLocal(int taskId, String path) async {
    removed = true;
  }
}
