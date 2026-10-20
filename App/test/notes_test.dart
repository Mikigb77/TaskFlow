import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/note_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late TaskDatabase database;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-notes-');
    path = p.join(directory.path, 'data.db');
    final sql = await databaseFactoryFfi.openDatabase(path);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
  });
  tearDown(() async {
    await database.close();
    expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
    await directory.delete(recursive: true);
  });

  test(
      'notes persist independently of tasks and cannot be completed or scheduled',
      () async {
    final note = Task(
        kind: 'note',
        title: 'Reference',
        priority: 1,
        notes: 'Friday at 5 is the opening time, not my appointment.',
        checklist: [ChecklistItem(title: 'Read reference', completed: true)]);
    final id = await database.insertTask(note);
    await database.insertTask(Task(title: 'Buy milk', priority: 1));
    await database.close();
    database =
        TaskDatabase.forTesting(await databaseFactoryFfi.openDatabase(path));
    final restored =
        (await database.getTasks()).singleWhere((item) => item.isNote);
    expect(restored.toApi(), note.toApi());
    expect(restored.nextOpenOccurrence(), isNull);
    expect(restored.calendarOccurrencesOn(DateTime(2026, 9, 25)), isEmpty);
    expect(restored.reminderDate, isNull);
    expect(restored.checklistDone, 1);
    expect(() => restored.copyWith(isCompleted: true), throwsArgumentError);
    expect(() => restored.copyWith(dueDate: DateTime(2026, 9, 25)),
        throwsArgumentError);
    await expectLater(
        database.updateTask(Task(id: id, title: 'Changed type', priority: 1)),
        throwsStateError);
    expect(
        (await database.getTasks()).where((item) => !item.isNote).single.title,
        'Buy milk');
  });

  test('typed note capture survives restart, uses no network and saves once',
      () async {
    var store = CaptureStore(database, directory: directory);
    final session = await store.create('local', 'Europe/Madrid',
        kind: 'note',
        text: 'Reference for Friday at 17:00\nhttps://example.org/details');
    await database.close();
    database =
        TaskDatabase.forTesting(await databaseFactoryFfi.openDatabase(path));
    store = CaptureStore(database, directory: directory);
    final restored = (await store.pending('local')).single;
    expect(restored.kind, 'note');
    expect(await store.pending('someone-else'), isEmpty);
    final api = _NoNetwork();
    addTearDown(api.close);
    final ready = await CaptureProcessor(store, api).process(restored);
    expect(ready.ready.single.task.isNote, isTrue);
    expect(ready.ready.single.task.notes, session.text);
    expect(ready.ready.single.task.dueDate, isNull);
    expect(api.calls, 0);
    final timing = await CaptureDiagnostics(database).summary();
    expect(
        timing.singleWhere((row) => row['event'] == 'notePrepared')['samples'],
        1);
    expect(timing.singleWhere((row) => row['event'] == 'processing')['samples'],
        0);
    final ids = ready.ready.map((draft) => draft.id).toSet();
    await store.saveReady(session.id, 'local', ids);
    await store.saveReady(session.id, 'local', ids);
    expect((await database.getTasks()).single.kind, 'note');
    expect((await store.read(session.id, 'local'))!.text, isEmpty);
    expect((await store.read(session.id, 'local'))!.kind, 'note');
    expect(await store.pending('local'), isEmpty);
  });

  test(
      'note archive v2 keeps structure and imports idempotently; v1 tasks still load',
      () async {
    final note = Task(
        kind: 'note',
        title: 'Trip reference',
        priority: 1,
        notes: 'https://example.org/tickets',
        labels: [
          'travel'
        ],
        checklist: [
          ChecklistItem(title: 'Check opening times', completed: true)
        ]);
    await database.insertTask(note);
    final text = await ArchiveStore(database, 'local').export();
    expect(jsonDecode(text)['version'], 2);
    final archive = TaskArchive.parse(text);
    final imported = ArchiveStore(database, 'imported');
    final ids = archive.tasks.map((item) => item.sourceId).toSet();
    expect((await imported.import(archive, ids)).added, 1);
    expect((await imported.import(archive, ids)).alreadyImported, 1);
    expect((await database.getTasks(ownerKey: 'imported')).single.toApi(),
        note.toApi());
    final old = jsonDecode(text) as Map<String, dynamic>;
    old['version'] = 1;
    (old['tasks'][0] as Map).remove('kind');
    expect(TaskArchive.parse(jsonEncode(old)).tasks.single.task!.kind, 'task');
    old['tasks'][0]['kind'] = 'unknown';
    expect(TaskArchive.parse(jsonEncode(old)).tasks.single.error, isNotNull);
  });

  test('schema 14 task content survives adding explicit note type', () async {
    final sql = await database.database;
    await sql.execute('ALTER TABLE tasks DROP COLUMN kind');
    await sql.insert('tasks', {
      'title': 'Old task',
      'priority': 2,
      'dueDate': '2026-09-25T17:00:00',
      'hasTime': 1
    });
    await TaskDatabase.upgrade(sql, 14, 15);
    final task = (await database.getTasks()).single;
    expect(task.kind, 'task');
    expect(task.priority, 2);
    expect(task.dueDate, DateTime(2026, 9, 25, 17));
  });

  test('note links expose only unique explicit web URLs with no credentials',
      () {
    final links = noteLinks(
        'Reference https://example.org/a, then https://example.org/a. '
        'javascript:alert(1) file:///private http://name:password@example.org/ '
        'https://example.org/details?item=2&lang=es');
    expect(links.map((uri) => uri.toString()), [
      'https://example.org/a',
      'https://example.org/details?item=2&lang=es'
    ]);
  });

  test(
      'recorded note failures retain audio and type; retry does not log extraction',
      () async {
    final store = CaptureStore(database, directory: directory);
    final capture =
        await store.create('local', 'UTC', kind: 'note', audio: true);
    final bytes = Uint8List(32044);
    final header = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, ascii.encode('RIFF'));
    bytes.setRange(8, 12, ascii.encode('WAVE'));
    bytes.setRange(12, 16, ascii.encode('fmt '));
    header.setUint32(4, bytes.length - 8, Endian.little);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    bytes.setRange(36, 40, ascii.encode('data'));
    header.setUint32(40, bytes.length - 44, Endian.little);
    await File(capture.audioPath!).writeAsBytes(bytes);
    final api = _RecordedNoteApi();
    addTearDown(api.close);
    final processor = CaptureProcessor(store, api);
    await expectLater(processor.process(capture), throwsA(isA<ApiException>()));
    expect((await store.read(capture.id, 'local'))!.kind, 'note');
    expect(await File(capture.audioPath!).readAsBytes(), bytes);
    api.fail = false;
    api.kind = 'task';
    await expectLater(processor.process(capture), throwsStateError);
    expect((await store.pending('local')).single.drafts, isEmpty);
    api.kind = 'note';
    final ready = await processor.process(capture);
    expect(ready.drafts.single.task.isNote, isTrue);
    final timing = await CaptureDiagnostics(database).summary();
    expect(timing.singleWhere((row) => row['event'] == 'extraction')['samples'],
        0);
    expect(
        timing
            .singleWhere((row) => row['event'] == 'noteTranscribed')['samples'],
        1);
    await store.saveReady(
        capture.id, 'local', ready.ready.map((draft) => draft.id).toSet());
    expect(await File(capture.audioPath!).exists(), isFalse);
  });

  test(
      'UX-113: a 160-character spoken note gets a title of about 60 characters that ends at a word; the words stay in the body',
      () async {
    const said =
        'Apunta que la clave del wifi de la casa de la playa es la que viene '
        'en la pegatina del router del salón y que el vecino del tercero guarda '
        'una copia de la llave';
    expect(said.length, 160);
    expect(said, isNot(contains('.')));
    final store = CaptureStore(database, directory: directory);
    final session = await store.create('local', 'Europe/Madrid',
        kind: 'note', text: said, source: 'speech');
    final api = _NoNetwork();
    addTearDown(api.close);
    final ready = await CaptureProcessor(store, api).process(session);
    final note = ready.ready.single.task;
    expect(note.isNote, isTrue);
    expect(note.notes, said);
    expect(note.title.length, lessThanOrEqualTo(64));
    expect(note.title.length, greaterThanOrEqualTo(30));
    expect(said, startsWith(note.title));
    // Cut at a word: the next character in the words is a space.
    expect(said[note.title.length], ' ');
    expect(note.title, isNot(endsWith(' ')));
    expect(api.calls, 0);
  });

  test('UX-113: a spoken note with sentences is titled by its first sentence',
      () {
    expect(
        CaptureProcessor.noteTitle(
            'La clave del wifi es TaskFlow2026. Está en la pegatina del router.'),
        'La clave del wifi es TaskFlow2026');
    expect(CaptureProcessor.noteTitle('Comprar pan'), 'Comprar pan');
  });

  // ---- Run 2026-10-19-app, round 1 · P185 (UX-1320): whole note titles ----

  test('UX-1320: a note said «Para la reunión del cole: preguntar por el '
      'comedor y por la excursión de primavera» is titled «Para la reunión del '
      'cole», said or typed', () {
    const said = 'Para la reunión del cole: preguntar por el comedor y por la '
        'excursión de primavera';
    expect(CaptureProcessor.noteTitle(said), 'Para la reunión del cole');
    final typed = localDrafts(said, DateTime(2026, 10, 20), kind: 'note');
    expect(typed.single.task.title, 'Para la reunión del cole');
    expect(typed.single.task.notes, said, reason: 'the words stay whole');
  });

  test('UX-1320: «:» or «;» ends the title only after at least 3 words', () {
    expect(CaptureProcessor.noteTitle('Lista de la compra; leche, pan y huevos'),
        'Lista de la compra');
    // Two words before the colon: the colon doesn't end it.
    expect(CaptureProcessor.noteTitle('Wifi casa: TaskFlow2026'),
        'Wifi casa: TaskFlow2026');
  });

  test('UX-1320: a title cut near 60 characters never ends on a short linking '
      'word (ES y, de, la, por; CA i, amb; EN the, and)', () {
    const linking = {
      'y', 'o', 'de', 'del', 'la', 'el', 'los', 'las', 'por', 'para', 'a',
      'en', 'con', 'que', 'i', 'els', 'les', 'per', 'amb', 'and', 'or', 'of',
      'the', 'to', 'for', 'with',
    };
    const starts = {
      'es': 'Preguntar en la reunión del colegio sobre el comedor',
      'ca': 'Preguntar a la reunió de l’escola sobre el menjador',
      'en': 'Ask at the school meeting about the lunch menu',
    };
    const ends = {
      'es': ['y', 'de', 'la', 'por'],
      'ca': ['i', 'amb'],
      'en': ['the', 'and'],
    };
    var checked = 0;
    for (final language in starts.keys) {
      for (final word in ends[language]!) {
        // Move the linking word across the 60-character cut.
        for (var pad = 0; pad < 16; pad++) {
          final text = '${starts[language]}${' xx' * pad} $word '
              'resto de palabras que siguen después del corte';
          final title = CaptureProcessor.noteTitle(text);
          final last = title.split(RegExp(r'\s+')).last.toLowerCase();
          expect(linking, isNot(contains(last)),
              reason: '«$title» from «$text»');
          expect(title, isNotEmpty);
          expect(text.startsWith(title), isTrue, reason: title);
          expect(title.runes.length, lessThanOrEqualTo(noteTitleLength),
              reason: title);
          // The phone's own titles for typed notes agree.
          expect(
              localDrafts(text, DateTime(2026, 10, 20), kind: 'note')
                  .single
                  .task
                  .title,
              title);
          checked++;
        }
      }
    }
    expect(checked, greaterThan(100));
  });
}

class _NoNetwork extends ApiClient {
  int calls = 0;
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    calls++;
    throw ApiException(0, 'No network');
  }
}

class _RecordedNoteApi extends ApiClient {
  bool fail = true;
  String kind = 'note';
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    expect(data!['capture_type'], 'note');
    expect(audioPath, isNotNull);
    if (fail) throw ApiException(503, 'Synthetic provider outage');
    return {
      'transcript': 'Friday reference',
      'tasks': [
        {
          'kind': kind,
          'title': 'Reference',
          'notes': 'Friday reference',
          'priority': 1,
          'questions': []
        }
      ],
      'timings': {'transcription_ms': 1200, 'extraction_ms': 0}
    };
  }
}
