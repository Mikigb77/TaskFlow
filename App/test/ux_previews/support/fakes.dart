// Stand-ins for the server, the phone and storage, so previews run with no
// network, no device and no database. Modelled on the suite's own fakes.
import 'dart:async';

import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/occurrence_change.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Database;
import 'package:uuid/uuid.dart';

import '../../support/design_fixtures.dart';

/// The server. The assistant (`ai/drafts/`) answers [answer], after [hold]
/// if set, or fails with [failure]. Other requests go to [handlers] by
/// `METHOD path`; anything else fails as offline.
class PreviewApi extends OfflineApiClient {
  Map<String, dynamic> answer = const {'transcript': '', 'tasks': []};
  Completer<void>? hold;
  Object? failure;
  final handlers =
      <String, FutureOr<dynamic> Function(Map<String, dynamic>? data)>{};
  final asked = <String>[];

  /// A sign-in saves the server's address to secure storage first; there is
  /// none here.
  @override
  Future<void> setServer(String value) async {}

  /// The assistant answers at last, so nothing waits after the test.
  void release() {
    final gate = hold;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    asked.add('$method $path');
    if (method == 'POST' && path == 'ai/drafts/') {
      final gate = hold;
      if (gate != null) await gate.future;
      final error = failure;
      if (error != null) throw error;
      return answer;
    }
    final handler = handlers['$method $path'];
    if (handler != null) return handler(data);
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// Google sign-in set up, as in a release build: the button is on. Choosing
/// an account is Google's own screen, so a tap here is cancelled.
class PreviewGoogle extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
  @override
  Future<String?> authenticate() async => null;
  @override
  Future<void> signOut() async {}
}

/// Signed in as [user] at once, or signed out when it's null. With
/// [restoring], the saved session is still being read: it never finishes.
class PreviewAuth extends AuthNotifier {
  PreviewAuth(super.api, this.user, {this.restoring = false})
    : super(activateReminders: _noReminders);
  final Map<String, dynamic>? user;
  final bool restoring;

  static Future<void> _noReminders(String owner) async {}

  @override
  Future<void> restore() async {
    if (restoring) return;
    state = AuthState(account: user == null ? null : Account.fromJson(user!));
  }

  /// The server ended the session: sign-in comes up over the open screens.
  void expire() {
    state = AuthState(
      account: state.account,
      expired: true,
      error: ApiException(401, 'Please sign in again.'),
    );
  }

  @override
  Future<void> signOut() async {
    state = const AuthState();
  }
}

/// Tasks in memory, numbered as they are added; a repetition moves as the
/// app's own does.
class PreviewTasks extends DesignTaskNotifier {
  PreviewTasks(this.initial);
  final List<Task> initial;
  int _next = 500;

  Task? byId(int id) =>
      state.requireValue.where((task) => task.id == id).firstOrNull;

  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }

  @override
  Future<void> showLocal() async {}

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }

  @override
  Future<void> addTasks(List<Task> tasks) async {
    for (final task in tasks) {
      await addTask(task);
    }
  }

  @override
  Future<void> moveToList(int taskId, String? listId) async {
    final task = byId(taskId);
    if (task != null) await updateTask(task.copyWith(listId: listId));
  }

  @override
  Future<OccurrenceChange> changeOccurrence(
    Task occurrence,
    DateTime? date,
    bool hasTime, {
    bool skip = false,
    bool reset = false,
  }) async {
    final task = byId(occurrence.id!)!;
    final key = occurrence.occurrenceId!;
    final before = task.exceptions
        .where((change) => change.originalDate == key)
        .firstOrNull;
    final after = OccurrenceException(
      originalDate: key,
      date: hasTime ? date : (date == null ? null : Task.day(date)),
      hasTime: hasTime,
      skipped: skip,
    );
    await updateTask(
      task.copyWith(
        exceptions: [
          ...task.exceptions.where((change) => change.originalDate != key),
          after,
        ],
      ),
    );
    return OccurrenceChange(task, key, before, after);
  }

  @override
  Future<bool> undoOccurrence(OccurrenceChange change) async {
    final task = byId(change.series.id!);
    if (task == null || !change.canUndo(task)) return false;
    await updateTask(change.restore(task));
    return true;
  }
}

/// Projects in memory: created ones are added, and taken back.
class PreviewLists extends TaskListStore {
  PreviewLists(List<TaskListInfo> projects)
    : projects = [...projects],
      super(TaskDatabase(), 'preview');
  final List<TaskListInfo> projects;

  @override
  Future<List<TaskListInfo>> all() async => [...projects];

  @override
  Future<void> create(TaskListInfo list) async => projects.add(list);

  @override
  Future<void> update(TaskListInfo list) async {
    final index = projects.indexWhere((p) => p.id == list.id);
    if (index >= 0) projects[index] = list;
  }

  @override
  Future<bool> takeBack(String id, {ApiClient? api, int? accountId}) async {
    projects.removeWhere((project) => project.id == id);
    return true;
  }
}

/// Every capture in memory, by id. Saving adds the drafts' tasks and is done
/// once no draft and no command waits, as the real store's transaction is;
/// Undo takes them out again.
class PreviewCaptures extends CaptureStore {
  PreviewCaptures(this.tasks, {TaskDatabase? database})
    : super(database ?? TaskDatabase());
  final PreviewTasks tasks;
  final sessions = <String, CaptureSession>{};

  @override
  Future<CaptureSession> create(
    String ownerKey,
    String timezone, {
    String text = '',
    DateTime? now,
    bool audio = false,
    String kind = 'task',
    String? projectId,
    String? source,
    DateTime? day,
    String? id,
    String? language,
  }) async {
    final session = CaptureSession(
      // Unique across tests: the processor keeps requests in flight by id.
      id: id ?? const Uuid().v4(),
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
      language: language,
    );
    return sessions[session.id] = session;
  }

  @override
  Future<CaptureSession?> acceptEntry(
    String id,
    String ownerKey,
    String timezone, {
    required String text,
    required DateTime capturedAt,
  }) async => sessions[id] ??= CaptureSession(
    id: id,
    ownerKey: ownerKey,
    timezone: timezone,
    text: text,
    capturedAt: capturedAt.toUtc(),
    source: 'shared',
  );

  @override
  Future<void> update(CaptureSession value) async {
    if (sessions[value.id]?.terminal ?? false) {
      throw StateError('This capture is no longer available.');
    }
    sessions[value.id] = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async => sessions[id];

  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [
    for (final session in sessions.values)
      if (!session.terminal) session,
  ];

  @override
  Future<void> cleanFinished(String ownerKey) async {}

  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null && !session.terminal) {
      sessions[id] = session.copyWith(status: 'discarded');
    }
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final session = sessions[id]!;
    final drafts = [
      for (final draft in session.drafts)
        if (draftIds.contains(draft.id) && draft.pending)
          draft.copyWith(savedTaskId: await tasks.addTask(draft.task))
        else
          draft,
    ];
    final completed =
        (drafts.isNotEmpty || session.commands.isNotEmpty) &&
        drafts.every((d) => !d.pending) &&
        session.commands.every((c) => !c.pending);
    return sessions[id] = session.copyWith(
      drafts: drafts,
      status: completed ? 'saved' : 'ready',
      commands: completed ? const [] : session.commands,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    for (final id in savedIds.values) {
      await tasks.deleteTask(id);
    }
    return sessions[before.id] = before.copyWith(
      status: 'ready',
      drafts: [
        for (final draft in before.drafts)
          savedIds.containsKey(draft.id)
              ? draft.copyWith(clearSavedTaskId: true)
              : draft,
      ],
    );
  }
}

/// The phone's on-device recognizer, ready in the app's language; the
/// preview sends what it hears. [access] is the microphone permission.
class PreviewSpeech extends NativeSpeech {
  PreviewSpeech({
    this.access = SpeechPermission.granted,
    this.language = 'es-ES',
    this.installed = true,
  });
  SpeechPermission access;
  final String language;

  /// The language's on-device speech pack is on the phone.
  final bool installed;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int? _run;
  int starts = 0;

  @override
  Future<SpeechCapability> capability({String? language}) async =>
      SpeechCapability(
        onDevice: true,
        language: language ?? this.language,
        languageInstalled: installed,
      );

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<SpeechPermission> permission() async => access;

  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    _run = id;
  }

  /// The recognizer reports [kind]: `ready`, `partial`, `segment`, `level`,
  /// `ended` or `error`.
  void send(String kind, {String? text, double? level, String? error}) {
    final run = _run;
    if (run != null) {
      _events.add(SpeechEvent(run, kind, text: text, level: level, error: error));
    }
  }

  @override
  Future<void> stop(int id) async => send('ended');

  @override
  Future<void> cancel(int id) async {}
}

/// The phone's own calendars (Android's calendar provider): [access] is the
/// calendar permission; [data] the events on any day asked for.
class PreviewDeviceCalendars extends DeviceCalendars {
  PreviewDeviceCalendars({this.access = CalendarAccess.denied})
    : super(supported: true);
  CalendarAccess access;
  static const work = DeviceCalendar(
    id: '1',
    name: 'Trabajo',
    account: 'maria.lopez@example.com',
    sourceId: 'work',
  );
  static const family = DeviceCalendar(
    id: '2',
    name: 'Familia',
    account: 'maria.lopez@example.com',
    sourceId: 'family',
  );
  List<DeviceCalendar> sources = const [work, family];
  List<DeviceCalendarEvent> data = const [];

  @override
  Future<CalendarAccess> status({bool request = false}) async => access;

  @override
  Future<CalendarRead<DeviceCalendar>> calendars() async =>
      CalendarRead(sources);

  @override
  Future<CalendarRead<DeviceCalendarEvent>> events(
    Set<String> ids,
    DateTime day,
  ) async => CalendarRead([
    for (final event in data)
      if (event.start.toLocal().year == day.year &&
          event.start.toLocal().month == day.month &&
          event.start.toLocal().day == day.day)
        event,
  ]);
}

/// Which phone calendars Calendar shows, in memory.
class PreviewCalendarPreferences extends CalendarPreferenceStore {
  PreviewCalendarPreferences([this.value = const CalendarPreferences()])
    : super('preview');
  CalendarPreferences value;
  @override
  Future<CalendarPreferences> read() async => value;
  @override
  Future<void> write(CalendarPreferences preferences) async {
    value = preferences;
  }
}

/// The phone's database, answering only what Capture diagnostics reads: its
/// recorded timings. Anything else is refused, as a phone without them.
class DiagnosticsDatabase extends Fake implements Database {
  DiagnosticsDatabase(this.rows);
  final List<Map<String, Object?>> rows;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => table == 'diagnostics' ? rows : const [];
}

/// The used-up notice's "seen" month, in memory: never seen.
class MemoryNotices extends FreeVoiceNoticeStore {
  MemoryNotices() : super(TaskDatabase());
  DateTime? month;
  @override
  Future<DateTime?> seen(String owner) async => month;
  @override
  Future<void> markSeen(String owner, DateTime resetsAt) async {
    month = resetsAt;
  }
}

/// Overrides that keep a provider from reaching a database it would open.
List<Override> quietStores(PreviewLists lists) => [
  freeVoiceNoticeStoreProvider.overrideWithValue(MemoryNotices()),
];
