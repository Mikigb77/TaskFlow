// Run 2026-10-18-commands, b4 · P154 (UX-1223): when a free account's own
// file space is full, «Ver tareas con archivos» lists the tasks whose files
// use it, largest first, so the person can make room.
import 'dart:async';
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/tasks_with_files_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
const megabyte = 1024 * 1024;
const owner = 'http://fixture/users/1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUpAll(() async {
    // The app's own font, so lines wrap as they do on the phone.
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });
  setUp(() {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  group('UX-1223: the phone counts each task’s files', () {
    late Directory directory;
    late TaskDatabase database;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'taskflow-tasks-with-files-',
      );
      final sql = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'data.db'),
      );
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      database = TaskDatabase.forTesting(sql);
    });
    tearDown(() async {
      await database.close();
      expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
      await directory.delete(recursive: true);
    });

    Future<(int, String)> task(String title) async {
      final id = await database.insertTask(
        Task(title: title, priority: 1),
        ownerKey: owner,
      );
      final row = (await (await database.database).query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      return (id, row['sync_id'] as String);
    }

    var files = 0;
    Future<void> file(
      String taskSyncId,
      int size, {
      bool deleted = false,
      bool deletePending = false,
      String? error,
      String ownerKey = owner,
      bool remote = true,
      bool uploadPending = false,
    }) async {
      await (await database.database).insert('task_attachments', {
        'owner_key': ownerKey,
        'id': 'file-${++files}',
        'task_id': taskSyncId,
        'name': 'file-$files.pdf',
        'size': size,
        'sha256': '',
        'remote': remote ? 1 : 0,
        'upload_pending': uploadPending ? 1 : 0,
        'is_deleted': deleted ? 1 : 0,
        'delete_pending': deletePending ? 1 : 0,
        'error': error,
      });
    }

    test(
      'UX-1223: files deleted, waiting to be removed, or refused for a full space aren’t counted; the rest are, with their total size',
      () async {
        final (trip, tripSync) = await task('Viaje');
        final (recipes, recipesSync) = await task('Recetas');
        final (refusedOnly, refusedSync) = await task('Fotos');
        await file(tripSync, 5 * megabyte);
        await file(tripSync, 4 * megabyte);
        await file(tripSync, (12.4 * megabyte).round() - 9 * megabyte);
        await file(tripSync, 2 * megabyte, deleted: true, deletePending: true);
        await file(tripSync, 2 * megabyte, deletePending: true);
        await file(tripSync, 2 * megabyte, error: TaskAttachment.storageFull);
        await file(
          tripSync,
          2 * megabyte,
          error: TaskAttachment.storageFullShared,
        );
        await file(recipesSync, (0.3 * megabyte).round());
        await file(refusedSync, megabyte, error: TaskAttachment.storageFull);
        // Another account's on the same phone.
        await file(tripSync, megabyte, ownerKey: 'http://fixture/users/2');

        final usage = await AttachmentStore(database, owner).usageByTask();
        expect(usage.keys.toSet(), {trip, recipes});
        expect(usage[trip]!.count, 3);
        expect(usage[trip]!.bytes, (12.4 * megabyte).round());
        expect(usage[recipes]!.count, 1);
        expect(usage[recipes]!.bytes, (0.3 * megabyte).round());
        expect(usage[refusedOnly], isNull);
      },
    );

    // ---- Round 2 · P163 (UX-1228): only files the server holds ----

    test(
      'UX-1228: a task whose only file is still waiting to upload (not on the server, size 0) has no entry',
      () async {
        final (pendingOnly, pendingSync) = await task('Fotos');
        await file(pendingSync, 0, remote: false, uploadPending: true);
        final usage = await AttachmentStore(database, owner).usageByTask();
        expect(usage[pendingOnly], isNull);
        expect(usage, isEmpty);
      },
    );

    test(
      'UX-1228: a task with two files on the server (5 MB and 4 MB) and one waiting to upload (3 MB) counts 2 files and 9 MB',
      () async {
        final (trip, tripSync) = await task('Viaje');
        await file(tripSync, 5 * megabyte);
        await file(tripSync, 4 * megabyte);
        await file(tripSync, 3 * megabyte, remote: false, uploadPending: true);
        final usage = await AttachmentStore(database, owner).usageByTask();
        expect(usage.keys, [trip]);
        expect(usage[trip]!.count, 2);
        expect(usage[trip]!.bytes, 9 * megabyte);
      },
    );
  });

  testWidgets(
    'UX-1228: on «Tareas con archivos», as the phone counts them, «Viaje» reads «2 archivos · 9,0 MB»; «Fotos», holding only a file waiting to upload, isn’t listed, and no row reads «0,0 MB»',
    (tester) async {
      // The phone's own count, from its database.
      final usage = (await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'taskflow-tasks-with-files-',
        );
        final sql = await databaseFactoryFfi.openDatabase(
          p.join(directory.path, 'data.db'),
        );
        await sql.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
        );
        await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
        final database = TaskDatabase.forTesting(sql);
        try {
          Future<String> task(int id, String title) async {
            final local = await database.insertTask(
              Task(title: title, priority: 1),
              ownerKey: owner,
            );
            // The same local id as the screen's task.
            await sql.update(
              'tasks',
              {'id': id},
              where: 'id = ?',
              whereArgs: [local],
            );
            final rows = await sql.query(
              'tasks',
              where: 'id = ?',
              whereArgs: [id],
            );
            return rows.single['sync_id'] as String;
          }

          var n = 0;
          Future<void> file(String sync, int size, {bool pending = false}) =>
              sql.insert('task_attachments', {
                'owner_key': owner,
                'id': 'file-${++n}',
                'task_id': sync,
                'name': 'file-$n.pdf',
                'size': size,
                'sha256': '',
                'remote': pending ? 0 : 1,
                'upload_pending': pending ? 1 : 0,
              });
          final trip = await task(_FilesApp.trip, 'Viaje');
          final photos = await task(_FilesApp.photos, 'Fotos');
          await file(trip, 5 * megabyte);
          await file(trip, 4 * megabyte);
          await file(trip, 3 * megabyte, pending: true);
          await file(photos, 0, pending: true);
          return await AttachmentStore(database, owner).usageByTask();
        } finally {
          await database.close();
          await directory.delete(recursive: true);
        }
      }))!;
      await _FilesApp.open(tester, files: const {}, store: _Counted(usage));
      unawaited(
        TasksWithFilesScreen.open(tester.element(find.byType(Scaffold).first)),
      );
      await tester.pumpAndSettle();
      expect(es.tasksWithFilesRow(2, '9,0'), '2 archivos · 9,0 MB');
      final row = find.ancestor(
        of: find.text('Viaje'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(es.tasksWithFilesRow(2, '9,0')),
        ),
        findsOneWidget,
      );
      expect(find.text('Fotos'), findsNothing);
      expect(find.textContaining('0,0 MB'), findsNothing);
      expect(find.textContaining('3 archivos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('UX-1223: Tareas con archivos', () {
    Finder seeTasks(AppLocalizations l) =>
        find.widgetWithText(TextButton, l.storageSeeTasks);
    Finder rowOf(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(InkWell));

    testWidgets(
      'UX-1223: «Ver tareas con archivos» under a refused file opens «Tareas con archivos»: the help line, then the account’s tasks largest first, «Viaje» «3 archivos · 12,4 MB» above «Recetas» «1 archivo · 0,3 MB»; a shared project another account owns isn’t listed',
      (tester) async {
        final app = await _FilesApp.open(tester);
        await app.details(tester, _FilesApp.photos);
        final button = seeTasks(es);
        await tester.scrollUntilVisible(
          button,
          200,
          scrollable: find
              .descendant(
                of: find.byType(TaskDetailScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.byType(TasksWithFilesScreen), findsOneWidget);
        expect(es.tasksWithFiles, 'Tareas con archivos');
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(es.tasksWithFiles),
          ),
          findsOneWidget,
        );
        expect(
          es.tasksWithFilesHelp,
          'Abre una tarea para eliminar los archivos que ya no necesites.',
        );
        expect(es.tasksWithFilesRow(3, '12,4'), '3 archivos · 12,4 MB');
        expect(es.tasksWithFilesRow(1, '0,3'), '1 archivo · 0,3 MB');
        final help = find.text(es.tasksWithFilesHelp);
        final trip = find.text(es.tasksWithFilesRow(3, '12,4'));
        final bills = find.text(es.tasksWithFilesRow(2, '4,1'));
        final recipes = find.text(es.tasksWithFilesRow(1, '0,3'));
        for (final finder in [help, trip, bills, recipes]) {
          expect(finder, findsOneWidget);
        }
        // Each row's title above its count.
        expect(
          find.descendant(of: rowOf('Viaje'), matching: trip),
          findsOneWidget,
        );
        expect(
          find.descendant(of: rowOf('Recetas'), matching: recipes),
          findsOneWidget,
        );
        expect(
          tester.getRect(help).bottom,
          lessThanOrEqualTo(tester.getRect(find.text('Viaje')).top),
        );
        expect(
          tester.getRect(trip).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.text('Factura del seguro')).top,
          ),
        );
        expect(
          tester.getRect(bills).bottom,
          lessThanOrEqualTo(tester.getRect(find.text('Recetas')).top),
        );
        // Another owner's space, and a task whose only file was refused.
        expect(find.text('Partituras'), findsNothing);
        expect(find.text('Fotos'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1223: tapping «Viaje» opens its details; after a file is removed there and the person goes back, its row reads «2 archivos · 7,4 MB»',
      (tester) async {
        await _FilesApp.open(tester);
        unawaited(
          TasksWithFilesScreen.open(
            tester.element(find.byType(Scaffold).first),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(es.tasksWithFilesRow(3, '12,4')), findsOneWidget);
        await tester.tap(find.text('Viaje'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        final remove = find.widgetWithText(TextButton, es.fileRemove).first;
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, es.fileRemove),
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TasksWithFilesScreen), findsOneWidget);
        expect(find.text(es.tasksWithFilesRow(3, '12,4')), findsNothing);
        expect(find.text(es.tasksWithFilesRow(2, '7,4')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1223: with no task holding files, the screen says «No hay tareas con archivos.»',
      (tester) async {
        await _FilesApp.open(tester, files: const {});
        unawaited(
          TasksWithFilesScreen.open(
            tester.element(find.byType(Scaffold).first),
          ),
        );
        await tester.pumpAndSettle();
        expect(es.tasksWithFilesEmpty, 'No hay tareas con archivos.');
        expect(find.text(es.tasksWithFilesEmpty), findsOneWidget);
        expect(find.text(es.tasksWithFilesHelp), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-1223 ($language, 2× on 320×640): the help line and every row show whole, wrapping, with no overflow',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final l = lookupAppLocalizations(Locale(language));
          await _FilesApp.open(
            tester,
            language: language,
            size: const Size(320, 640),
          );
          unawaited(
            TasksWithFilesScreen.open(
              tester.element(find.byType(Scaffold).first),
            ),
          );
          await tester.pumpAndSettle();
          final lines = [
            l.tasksWithFilesHelp,
            'Viaje',
            l.tasksWithFilesRow(3, '12,4'),
            'Factura del seguro',
            l.tasksWithFilesRow(2, '4,1'),
            'Recetas',
            l.tasksWithFilesRow(1, '0,3'),
          ];
          for (final line in lines) {
            final shown = find.text(line);
            expect(shown, findsOneWidget, reason: line);
            await tester.ensureVisible(shown);
            await tester.pumpAndSettle();
            final rect = tester.getRect(shown);
            expect(rect.left, greaterThanOrEqualTo(0), reason: line);
            expect(rect.right, lessThanOrEqualTo(320.5), reason: line);
            expect(rect.top, greaterThanOrEqualTo(0), reason: line);
            expect(rect.bottom, lessThanOrEqualTo(640.5), reason: line);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: shown,
                matching: find.byType(RichText),
                matchRoot: true,
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: line);
            if (line == l.tasksWithFilesHelp) {
              // Long enough to wrap at this size.
              expect(rect.height, greaterThan(40), reason: line);
            }
          }
          expect(tester.takeException(), isNull, reason: 'no overflow');
        },
      );
    }
  });

  // ---- Run 2026-10-19-app, round 1 · P179 (UX-1414) ----

  testWidgets(
    'UX-1414: a task with notes and steps opened from «Tareas con archivos» at 1× on 360×800 opens with its Archivos heading on screen, without scrolling',
    (tester) async {
      final app = await _FilesApp.open(tester, size: const Size(360, 800));
      final notifier = app.container.read(taskProvider.notifier);
      final trip = app.container
          .read(taskProvider)
          .requireValue
          .firstWhere((task) => task.id == _FilesApp.trip);
      await notifier.updateTask(
        trip.copyWith(
          dueDate: DateTime.now().add(const Duration(days: 3)),
          notes:
              'Llevar el pasaporte y el cargador.\nReservar el traslado al hotel.\nCambiar dinero en el aeropuerto.\nLlamar a la abuela al llegar.',
          checklist: [
            for (final (i, step) in [
              'Facturar la maleta',
              'Cambiar dinero',
              'Imprimir la reserva',
              'Comprar el adaptador',
              'Avisar al vecino',
            ].indexed)
              ChecklistItem(id: 's$i', title: step),
          ],
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        TasksWithFilesScreen.open(tester.element(find.byType(Scaffold).first)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viaje'));
      await tester.pumpAndSettle();
      final detail = find.byType(TaskDetailScreen);
      expect(detail, findsOneWidget);
      final heading = find.descendant(
        of: detail,
        matching: find.text(es.attachments.toUpperCase()),
      );
      expect(heading, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: detail, matching: find.byType(Scaffold)).first,
      );
      final top = tester
          .getRect(find.descendant(of: detail, matching: find.byType(AppBar)))
          .bottom;
      final bottom = scaffold.bottomNavigationBar == null
          ? 800.0
          : tester.getRect(find.byWidget(scaffold.bottomNavigationBar!)).top;
      final rect = tester.getRect(heading);
      expect(rect.top, greaterThanOrEqualTo(top), reason: 'below the app bar');
      expect(rect.bottom, lessThanOrEqualTo(bottom), reason: 'above the bar');
      expect(tester.takeException(), isNull);

      // Opened any other way it starts at its top: the files are further
      // down, so the check above is the list's doing.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await app.details(tester, _FilesApp.trip);
      expect(
        tester.getRect(heading).top,
        greaterThan(bottom),
        reason: 'opened from elsewhere, the files sit below the fold',
      );
    },
  );
}

/// A file, already uploaded, of [megabytes].
AttachmentEntry _file(String id, String task, double megabytes) =>
    AttachmentEntry(
      '$id.pdf',
      '/fixture/$id.pdf',
      true,
      item: TaskAttachment(
        id: id,
        taskId: task,
        name: '$id.pdf',
        size: (megabytes * megabyte).round(),
        sha256: '',
        remote: true,
      ),
    );

/// The app in Spanish (or [language]) for a free account whose 100 MB are
/// used, with tasks holding [files], by task id, as the phone keeps them.
class _FilesApp {
  _FilesApp(this.container);
  final ProviderContainer container;

  static const trip = 80;
  static const recipes = 81;
  static const scores = 83;
  static const photos = 84;
  static const bills = 85;

  static Map<int, List<AttachmentEntry>> defaultFiles() => {
    trip: [
      _file('billetes', 'trip', 5),
      _file('hotel', 'trip', 4),
      _file('mapa', 'trip', 3.4),
    ],
    recipes: [_file('tarta', 'recipes', 0.3)],
    scores: [for (var i = 0; i < 5; i++) _file('partitura-$i', 'scores', 6)],
    bills: [_file('poliza', 'bills', 2.05), _file('recibo', 'bills', 2.05)],
    photos: const [
      AttachmentEntry(
        'Playa.jpg',
        '/fixture/playa.jpg',
        true,
        item: TaskAttachment(
          id: 'playa',
          taskId: 'photos',
          name: 'Playa.jpg',
          size: 3 * megabyte,
          sha256: '',
          uploadPending: true,
          error: TaskAttachment.storageFull,
        ),
      ),
    ],
  };

  static Future<_FilesApp> open(
    WidgetTester tester, {
    Map<int, List<AttachmentEntry>>? files,
    String language = 'es',
    Size size = const Size(390, 844),
    AttachmentStore? store,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final held = {
      for (final MapEntry(:key, :value) in (files ?? defaultFiles()).entries)
        key: [...value],
    };
    final repository = _Repository(held, store: store);
    final api = OfflineApiClient();
    final container = ProviderContainer(
      overrides: [
        firstTaskStoreProvider.overrideWithValue(MemoryFirstTaskStore()),
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(false),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _FullAuth(api)),
        attachmentEntriesProvider.overrideWith(
          (ref, taskId) async => [...?held[taskId]],
        ),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(RegionalPreferences(language: language)),
        ),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith(
          (ref) async => [
            TaskListInfo(id: 'casa', name: 'Casa', role: 'owner', version: 1),
            TaskListInfo(
              id: 'coro',
              name: 'Coro',
              role: 'editor',
              shared: true,
              version: 1,
            ),
          ],
        ),
        taskRepositoryProvider.overrideWithValue(repository),
        taskProvider.overrideWith((ref) => _Tasks()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _FilesApp(container);
  }

  /// Opens the details of task [id].
  Future<void> details(WidgetTester tester, int id) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('/taskDetails', arguments: id);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
  }
}

class _Tasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    if (state.hasValue) return;
    state = AsyncData([
      Task(id: _FilesApp.trip, title: 'Viaje', priority: 1),
      Task(id: _FilesApp.recipes, title: 'Recetas', kind: 'note', priority: 1),
      Task(
        id: _FilesApp.scores,
        title: 'Partituras',
        priority: 1,
        listId: 'coro',
      ),
      Task(id: _FilesApp.photos, title: 'Fotos', priority: 1),
      Task(
        id: _FilesApp.bills,
        title: 'Factura del seguro',
        priority: 1,
        listId: 'casa',
      ),
    ]);
  }
}

/// A free account whose 100 MB of file space are used.
class _FullAuth extends AuthNotifier {
  _FullAuth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'files@example.invalid',
        'timezone': 'Europe/Madrid',
        'storage': {
          'used_bytes': 100 * megabyte,
          'limit_bytes': 100 * megabyte,
        },
      }),
    );
  }

  @override
  Future<void> refreshAccount() async {}
}

class _Repository extends MemoryTasks {
  _Repository(this.held, {AttachmentStore? store}) : _given = store;
  final Map<int, List<AttachmentEntry>> held;
  final AttachmentStore? _given;
  late final AttachmentStore _store = _given ?? _Files(held);
  @override
  String get ownerKey => owner;
  @override
  AttachmentStore get attachments => _store;
}

/// The phone's files: counted as the real store counts them, and removed
/// from [held].
class _Files extends AttachmentStore {
  _Files(this.held) : super(TaskDatabase(), owner);
  final Map<int, List<AttachmentEntry>> held;

  @override
  Future<Map<int, TaskFileUsage>> usageByTask() async => {
    for (final MapEntry(:key, :value) in held.entries)
      if (value.any((entry) => !(entry.item?.refused ?? false)))
        key: TaskFileUsage(
          value.where((entry) => !(entry.item?.refused ?? false)).length,
          value
              .where((entry) => !(entry.item?.refused ?? false))
              .fold(0, (sum, entry) => sum + (entry.item?.size ?? 0)),
        ),
  };

  @override
  Future<void> remove(String id) async {
    for (final files in held.values) {
      files.removeWhere((entry) => entry.item?.id == id);
    }
  }
}

/// The files the real store counted on a phone's database.
class _Counted extends AttachmentStore {
  _Counted(this.usage) : super(TaskDatabase(), owner);
  final Map<int, TaskFileUsage> usage;
  @override
  Future<Map<int, TaskFileUsage>> usageByTask() async => usage;
}
