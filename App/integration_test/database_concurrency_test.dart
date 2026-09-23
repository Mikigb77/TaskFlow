import 'dart:async';
import 'package:agenda/services/android_database_factory.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android foreground read does not block a reminder transaction',
      (tester) async {
    final path = p.join(await getDatabasesPath(),
        'taskflow_concurrency_${DateTime.now().microsecondsSinceEpoch}.db');
    final writer = await openDatabase(path, singleInstance: false);
    final reader = await openDatabase(path, singleInstance: false);
    addTearDown(() async {
      await reader.close();
      await writer.close();
      await deleteDatabase(path);
    });
    expect((await writer.rawQuery('PRAGMA journal_mode')).single.values.single,
        'wal');
    await writer
        .execute('CREATE TABLE marker (id INTEGER PRIMARY KEY, value INTEGER)');
    await writer.insert('marker', {'id': 1, 'value': 1});
    final written = Completer<void>();
    final release = Completer<void>();
    final transaction = writer.transaction((tx) async {
      await tx.update('marker', {'value': 2}, where: 'id = 1');
      written.complete();
      await release.future;
    });
    await written.future;
    try {
      // A second engine has a separate connection. It must see the committed
      // snapshot without occupying the worker needed to commit the writer.
      final snapshot =
          await reader.query('marker').timeout(const Duration(seconds: 3));
      expect(snapshot.single['value'], 1);
    } finally {
      release.complete();
      await transaction.timeout(const Duration(seconds: 10));
    }
    expect((await reader.query('marker')).single['value'], 2);
    // Exercise the actual app connection's configuration as well.
    expect(
        (await (await TaskReminders.engine.database.database)
                .rawQuery('PRAGMA journal_mode'))
            .single
            .values
            .single,
        'wal');
  }, timeout: const Timeout(Duration(seconds: 45)));

  testWidgets('Android connections complete competing writes without replay',
      (tester) async {
    final path = p.join(await getDatabasesPath(),
        'taskflow_writers_${DateTime.now().microsecondsSinceEpoch}.db');
    final factory = AndroidDatabaseFactory();
    final options = OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.rawQuery('PRAGMA busy_timeout = 0'));
    final first = await factory.openDatabase(path, options: options);
    final second = await factory.openDatabase(path, options: options);
    addTearDown(() async {
      await second.close();
      await first.close();
      await deleteDatabase(path);
    });
    await first.execute('CREATE TABLE marker (id INTEGER PRIMARY KEY)');
    var callbacks = 0;
    final entered = Completer<void>();
    final transaction = first.transaction((tx) async {
      callbacks++;
      await tx.insert('marker', {'id': 1});
      entered.complete();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await entered.future;
    final other = second.transaction((tx) async {
      callbacks++;
      await tx.insert('marker', {'id': 2});
    });
    await Future.wait([transaction, other]).timeout(const Duration(seconds: 3));
    expect(callbacks, 2);
    final rollback = StateError('intentional rollback');
    await expectLater(first.transaction((tx) async {
      callbacks++;
      await tx.insert('marker', {'id': 3});
      throw rollback;
    }), throwsA(same(rollback)));
    expect(callbacks, 3);
    expect(
        (await second.query('marker', orderBy: 'id')).map((row) => row['id']),
        [1, 2]);
    for (var round = 0; round < 10; round++) {
      await Future.wait([
        first.transaction((tx) async {
          await tx.insert('marker', {'id': 10 + round * 2});
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }),
        second.insert('marker', {'id': 11 + round * 2}),
      ]).timeout(const Duration(seconds: 3));
    }
    expect(await second.query('marker'), hasLength(22));
  }, timeout: const Timeout(Duration(seconds: 45)));
}
