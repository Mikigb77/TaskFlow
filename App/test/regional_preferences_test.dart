import 'dart:async';
import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'support/design_fixtures.dart';

void main() {
  sqfliteFfiInit();
  test(
    'SQLite preferences survive recreation without changing tasks or pending captures',
    () async {
      final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final db = TaskDatabase.forTesting(sql);
      addTearDown(db.close);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      await db.insertTasks([
        Task(
          title: 'Timed near DST change',
          priority: 1,
          dueDate: DateTime.utc(2026, 10, 25, 1, 30).toLocal(),
        ),
        Task(
          title: 'Calendar date',
          priority: 1,
          dueDate: DateTime(2026, 10, 25),
          hasTime: false,
          recurrence: 'weekly',
          repeatWeekdays: [1, 5],
        ),
        Task(title: 'Inbox', priority: 1),
      ]);
      final captures = CaptureStore(db);
      final saved = await captures.create(
        'local',
        'Europe/Madrid',
        text: 'Friday at five',
        now: DateTime.utc(2026, 9, 22, 23),
      );
      final taskRows = jsonEncode(await sql.query('tasks'));
      final captureRows = jsonEncode(await sql.query('captures'));
      final controller = RegionalController(RegionalPreferenceStore(db));
      await controller.ready;
      await Future.wait([
        controller.set(
          const RegionalPreferences(
            language: 'es',
            clock: ClockFormat.twelve,
            weekStart: 0,
          ),
        ),
        controller.set(
          const RegionalPreferences(
            language: 'en',
            clock: ClockFormat.twentyFour,
            weekStart: 6,
            captureTimezone: 'America/New_York',
          ),
        ),
      ]);
      controller.dispose();
      final restored = RegionalController(RegionalPreferenceStore(db));
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.state.clock, ClockFormat.twentyFour);
      expect(restored.state.weekStart, 6);
      await restored.set(restored.state.withLanguage('ca'));
      expect((await RegionalPreferenceStore(db).read()).language, 'ca');
      expect(restored.state.captureTimezone, 'America/New_York');
      expect(jsonEncode(await sql.query('tasks')), taskRows);
      expect(jsonEncode(await sql.query('captures')), captureRows);
      expect(
        (await captures.read(saved.id, 'local'))!.timezone,
        'Europe/Madrid',
      );
      expect(
        (await CaptureTimezone.resolve(
          restored.state,
          readDevice: () async => 'Europe/Madrid',
        ))
            .identifier,
        'America/New_York',
      );
      final latest = await captures.create(
        'local',
        restored.state.captureTimezone!,
        text: 'New capture',
      );
      expect(latest.timezone, 'America/New_York');
    },
  );

  test(
    'late restore and failed rapid writes retain the last persisted preference',
    () async {
      final store = _DelayedStore();
      final controller = RegionalController(store);
      addTearDown(controller.dispose);
      final selected = controller.set(
        const RegionalPreferences(language: 'es'),
      );
      store.reading.complete(const RegionalPreferences(language: 'en'));
      await selected;
      expect(controller.state.language, 'es');
      store.fail = true;
      final first = controller.set(
        const RegionalPreferences(clock: ClockFormat.twelve),
      );
      final second = controller.set(
        const RegionalPreferences(clock: ClockFormat.twentyFour),
      );
      await Future.wait([
        expectLater(first, throwsStateError),
        expectLater(second, throwsStateError),
      ]);
      expect(controller.state.language, 'es');
      expect(controller.state.clock, ClockFormat.system);
    },
  );

  test(
    'language matching prefers device order and safely falls back to English',
    () {
      const automatic = RegionalPreferences();
      expect(
        automatic.localeFor([const Locale('ca', 'ES')]).languageCode,
        'ca',
      );
      expect(
        automatic.localeFor([const Locale('es', 'MX')]),
        const Locale('es', 'MX'),
      );
      expect(
        automatic.localeFor([
          const Locale('fr', 'FR'),
          const Locale('ca', 'ES'),
          const Locale('es', 'ES'),
        ]).languageCode,
        'ca',
      );
      expect(
        automatic.localeFor([const Locale('ja', 'JP')]).languageCode,
        'en',
      );
      expect(automatic.localeFor([]), const Locale('en'));
      expect(automatic.localeFor(null), const Locale('en'));
      expect(
        const RegionalPreferences(
          language: 'ca',
        ).localeFor([const Locale('en', 'US')]),
        const Locale('ca', 'US'),
      );
      expect(RegionalPreferences.fromJson({'language': 'ca'}).language, 'ca');
      expect(
        RegionalPreferences.fromJson({'language': 'de'}).language,
        'system',
      );
    },
  );

  test(
    'timezone resolution uses the device, validates overrides and preserves reminder zone',
    () async {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Pacific/Auckland'));
      final p = RegionalPreferences.fromJson({
        'language': 'invalid',
        'clock': 'invalid',
        'weekStart': 15,
        'captureTimezone': 'Not/AZone',
      });
      expect(p.language, 'system');
      expect(p.weekStart, isNull);
      expect(p.captureTimezone, isNull);
      expect(tz.local.name, 'Pacific/Auckland');
      final device = await CaptureTimezone.resolve(
        p,
        readDevice: () async => 'Asia/Tokyo',
      );
      expect(device.identifier, 'Asia/Tokyo');
      expect(device.fallback, isFalse);
      final unavailable = await CaptureTimezone.resolve(
        p,
        accountTimezone: 'Europe/London',
        readDevice: () async => throw StateError('Unavailable'),
      );
      expect(unavailable.identifier, 'Europe/London');
      expect(unavailable.fallback, isTrue);
      final invalid = await CaptureTimezone.resolve(
        p,
        accountTimezone: 'Bad/Zone',
        readDevice: () async => 'Bad/Zone',
      );
      expect(invalid.identifier, 'UTC');
      expect(invalid.fallback, isTrue);
      expect(
        const RegionalPreferences(
          language: 'es',
        ).localeFor([const Locale('en', 'US')]),
        const Locale('es', 'US'),
      );
    },
  );
}

class _DelayedStore extends MemoryRegionalStore {
  final reading = Completer<RegionalPreferences>();
  bool fail = false;
  @override
  Future<RegionalPreferences> read() => reading.future;
  @override
  Future<void> write(RegionalPreferences value) async {
    if (fail) throw StateError('Disk full');
    await super.write(value);
  }
}
