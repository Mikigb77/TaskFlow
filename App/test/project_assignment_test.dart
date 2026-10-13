import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const owner = 'https://test.invalid/users/1';
const projectId = '88f1aa3c-3e1f-43ad-8fa5-f17df05736e8';
final project = TaskListInfo(
  id: projectId,
  name: 'Physics',
  shared: true,
  groupId: 'group-a',
  groupName: 'Master',
  ownerId: 1,
  people: const [
    ProjectMember(id: 1, name: 'Miki', role: 'owner'),
    ProjectMember(id: 2, name: 'Ana', role: 'editor'),
    ProjectMember(id: 3, name: 'Alex', role: 'viewer'),
  ],
);

void main() {
  sqfliteFfiInit();
  late Database sql;
  late TaskDatabase database;
  late TaskListStore projects;
  setUp(() async {
    sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    projects = TaskListStore(database, owner);
    await projects.create(project);
  });
  tearDown(() async => database.close());

  for (final synced in [false, true]) {
    test(
      'a removed assignee preserves ${synced ? 'synced' : 'unsent'} offline edits privately and syncs other tasks',
      () async {
        await sql.update('task_lists', {
          'remote_version': 1,
          'sync_pending': 0,
        });
        final api = _AssignmentApi();
        addTearDown(api.close);
        final repository = CloudTaskRepository(database, api, 1);
        final id = await repository.addTask(
          Task(
            title: 'Offline exercise',
            notes: 'My unsent work',
            priority: 1,
            listId: projectId,
            assignment: 'member',
            assigneeId: 2,
          ),
        );
        final row = (await sql.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        if (synced) {
          await sql.update(
            'tasks',
            {'remote_version': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
          api.remote.add({
            ...Task(
              title: 'Server exercise',
              priority: 1,
              listId: projectId,
              assignment: 'unassigned',
            ).toApi(),
            'id': row['sync_id'],
            'version': 2,
          });
        }
        await repository.addTask(Task(title: 'An unrelated task', priority: 1));
        await repository.sync();
        expect(repository.syncError, contains('responsibility changed'));
        final recovered = (await repository.getAllTasks()).singleWhere(
          (t) => t.notes == 'My unsent work',
        );
        expect(recovered.listId, isNull);
        expect(recovered.assignment, 'personal');
        expect(recovered.assigneeId, isNull);
        expect(
          api.remote.any((row) => row['title'] == 'An unrelated task'),
          isTrue,
        );
        await repository.sync();
        expect(await database.pending(owner), isEmpty);
        expect(
          api.remote.singleWhere(
            (row) => row['notes'] == 'My unsent work',
          )['list_id'],
          isNull,
        );
      },
    );
  }

  test(
    'schema 15 upgrades preserve existing tasks and normalize only shared responsibility',
    () async {
    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
      addTearDown(old.close);
      await old.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(old, 3, 15);
      await old.insert('task_lists', {
        'id': projectId,
        'owner_key': owner,
        'name': 'Existing shared project',
        'shared': 1,
      });
      for (final title in ['Shared', 'Personal']) {
        final row =
            Task(
                title: title,
                priority: 2,
                listId: title == 'Shared' ? projectId : null,
                notes: 'Keep me',
                filePaths: ['/private/existing.pdf'],
              ).toMap()
              ..remove('assignment')
              ..remove('assigneeId')
              ..remove('assigneeName')
              ..remove('createdBy');
        await old.insert('tasks', {
          ...row,
          'owner_key': owner,
          'sync_id': title,
          'revision': 7,
          'sync_pending': 1,
        });
      }
      await TaskDatabase.upgrade(old, 15, TaskDatabase.schemaVersion);
      final rows = await old.query('tasks', orderBy: 'title');
      expect(rows.map((row) => row['assignment']), ['personal', 'group']);
      expect(
        rows.every(
          (row) =>
              row['notes'] == 'Keep me' &&
              row['revision'] == 7 &&
              row['sync_pending'] == 1,
        ),
        isTrue,
      );
      expect(Task.fromMap(rows.first).filePaths, ['/private/existing.pdf']);
    },
  );

  test(
    'archived groups leave their projects accessible but out of daily scope and reminders',
    () async {
      final archived = TaskListInfo.fromApi({
        ...project.toApi(),
        'id': projectId,
        'version': 1,
        'group_archived': true,
        'shared': true,
        'people': [],
      });
      final task = Task(
        title: 'Archived group task',
        priority: 1,
        listId: projectId,
        assignment: 'group',
      );
      expect(
        taskInProjectScope(task, const ProjectScope(), 1, [archived]),
        isFalse,
      );
      expect(
        taskInProjectScope(task, const ProjectScope(projectId: projectId), 1, [
          archived,
        ]),
        isTrue,
      );
      await sql.update('task_lists', {'group_archived': 1});
      expect(await TaskDatabase.reminderTasks(sql, owner, [task]), isEmpty);
    },
  );

  test(
    'assignment and group directory survive storage and API serialization',
    () async {
      final id = await database.insertTask(
        Task(
          title: 'Exercise 3',
          priority: 1,
          listId: projectId,
          assignment: 'member',
          assigneeId: 2,
          assigneeName: 'Stale name',
          createdBy: 1,
          deadline: DateTime(2026, 10, 15),
        ),
        ownerKey: owner,
      );
      final restored = (await database.getTasks(ownerKey: owner)).single;
      expect(restored.id, id);
      expect(restored.assigneeName, 'Ana');
      expect(restored.createdBy, 1);
      expect(restored.toApi()['assignee_id'], 2);
      expect(restored.toApi(), isNot(contains('created_by')));
      expect(
        Task.fromApi({
          ...restored.toApi(),
          'created_by': 1,
          'assignee_name': 'Ana',
        }).assignment,
        'member',
      );
      final cached = (await projects.all()).single;
      expect(cached.groupId, 'group-a');
      expect(cached.people.map((p) => p.id), [1, 2, 3]);
    },
  );

  test(
    'new shared tasks normalize to everyone, and invalid assignees never save',
    () async {
      await database.insertTask(
        Task(title: 'Shared', priority: 1, listId: projectId),
        ownerKey: owner,
      );
      expect(
        (await database.getTasks(ownerKey: owner)).single.assignment,
        'group',
      );
      for (final id in [3, 99]) {
        await expectLater(
          database.insertTask(
            Task(
              title: 'Invalid',
              priority: 1,
              listId: projectId,
              assignment: 'member',
              assigneeId: id,
            ),
            ownerKey: owner,
          ),
          throwsStateError,
        );
      }
      await expectLater(
        database.insertTask(
          Task(
            title: 'Personal cannot assign',
            priority: 1,
            assignment: 'member',
            assigneeId: 2,
          ),
          ownerKey: owner,
        ),
        throwsStateError,
      );
      expect((await database.getTasks(ownerKey: owner)).length, 1);
    },
  );

  test(
    'a conflicting assignment preserves private work without sharing the copy',
    () async {
      final id = await database.insertTask(
        Task(
          title: 'Local edit',
          priority: 2,
          listId: projectId,
          assignment: 'member',
          assigneeId: 2,
          createdBy: 1,
        ),
        ownerKey: owner,
      );
      final pending = (await database.pending(owner)).single;
      final remote = {
        ...Task(
          title: 'Remote edit',
          priority: 1,
          listId: projectId,
          assignment: 'group',
        ).toApi(),
        'id': pending['sync_id'],
        'version': 2,
        'is_deleted': false,
      };
      await database.preserveConflict(owner, pending, remote);
      final tasks = await database.getTasks(ownerKey: owner);
      expect(tasks.singleWhere((t) => t.id == id).assignment, 'group');
      final copy = tasks.singleWhere((t) => t.id != id);
      expect(copy.title, contains('Local edit'));
      expect(copy.listId, isNull);
      expect(copy.assignment, 'personal');
      expect(copy.assigneeId, isNull);
      expect(copy.assigneeName, isNull);
      expect(copy.createdBy, isNull);
    },
  );

  test(
    'an unresolved voice assignment stays blocked after capture recovery',
    () async {
      final store = CaptureStore(database);
      final session = await store.create(
        owner,
        'Europe/Madrid',
        projectId: projectId,
      );
      final draft = CaptureDraft.fromAI(
        TaskDraft.fromJson({
          'title': 'Exercise',
          'priority': 1,
          'notes': '',
          'transcript': 'Alex do exercise three',
          'questions': <String>[],
          'kind': 'task',
          'confidence': 1.0,
          'assignment': 'unassigned',
          'list_id': projectId,
          'assignment_issues': ['ambiguous_member'],
          'assignment_hints': {'member_name': 'Alex'},
        }),
      );
      final reviewed = session.copyWith(
        status: 'ready',
        drafts: [draft.copyWith(confirmed: true)],
      );
      await store.update(reviewed);
      final recovered = CaptureSession.fromJson(
        jsonDecode(jsonEncode(reviewed.toJson())),
      );
      expect(recovered.projectId, projectId);
      expect(recovered.drafts.single.ready, isFalse);
      await expectLater(
        store.saveReady(session.id, owner, {draft.id}),
        throwsStateError,
      );
      expect(await database.getTasks(ownerKey: owner), isEmpty);
      await store.update(
        reviewed.copyWith(
          drafts: [
            draft.copyWith(
              confirmed: true,
              assignmentReviewed: true,
              task: draft.task.copyWith(assignment: 'member', assigneeId: 2),
            ),
          ],
        ),
      );
      await store.saveReady(session.id, owner, {draft.id});
      expect((await database.getTasks(ownerKey: owner)).single.assigneeId, 2);
    },
  );

  test(
    'personal scope and background reminders exclude another member’s task',
    () async {
      final tasks = [
        Task(title: 'Personal', priority: 1),
        Task(
          title: 'Everyone',
          priority: 1,
          listId: projectId,
          assignment: 'group',
        ),
        Task(
          title: 'Mine',
          priority: 1,
          listId: projectId,
          assignment: 'member',
          assigneeId: 1,
        ),
        Task(
          title: 'Ana',
          priority: 1,
          listId: projectId,
          assignment: 'member',
          assigneeId: 2,
        ),
        Task(
          title: 'Reassign',
          priority: 1,
          listId: projectId,
          assignment: 'unassigned',
        ),
      ];
      expect(
        tasks
            .where(
              (t) => taskInProjectScope(t, const ProjectScope(), 1, [project]),
            )
            .map((t) => t.title),
        ['Personal', 'Everyone', 'Mine', 'Reassign'],
      );
      expect(
        tasks
            .where(
              (t) => taskInProjectScope(
                t,
                const ProjectScope(team: true, projectId: projectId),
                1,
                [project],
              ),
            )
            .length,
        4,
      );
      expect(
        (await TaskDatabase.reminderTasks(
          sql,
          owner,
          tasks,
        )).map((t) => t.title),
        ['Personal', 'Everyone', 'Mine', 'Reassign'],
      );
      await projects.preferences(projectId, notifications: 'muted');
      expect(
        (await TaskDatabase.reminderTasks(
          sql,
          owner,
          tasks,
        )).map((t) => t.title),
        ['Personal'],
      );
    },
  );

  test(
    'queued preferences survive refresh and an edit during upload',
    () async {
      final api = _ProjectApi();
      addTearDown(api.close);
      await sql.update(
        'task_lists',
        {'remote_version': 1, 'sync_pending': 0},
        where: 'id = ?',
        whereArgs: [projectId],
      );
      await projects.preferences(
        projectId,
        pinned: true,
        notifications: 'muted',
      );
      await projects.refreshAccess(api, 1);
      expect((await projects.all()).single.pinned, isTrue);
      expect((await projects.all()).single.notifications, 'muted');
      api.onPreferences = () =>
          projects.preferences(projectId, notifications: 'all');
      await projects.sync(api, 1);
      final row = (await sql.query('task_lists')).single;
      expect(row['preference_pending'], 1);
      expect(row['notifications'], 'all');
      api.onPreferences = null;
      await projects.sync(api, 1);
      expect((await sql.query('task_lists')).single['preference_pending'], 0);
      expect(api.notifications, 'all');
    },
  );
}

class _ProjectApi extends ApiClient {
  _ProjectApi() : super(url: 'https://test.invalid');
  bool pinned = false;
  String notifications = 'assigned';
  Future<void> Function()? onPreferences;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'GET' && path == 'lists/access/') {
      return {
        'lists': [
          {
            ...project.toApi(),
            'id': projectId,
            'version': 1,
            'shared': true,
            'role': 'owner',
            'owner_id': 1,
            'group_name': 'Master',
            'people': project.people.map((p) => p.toJson()).toList(),
            'pinned': pinned,
            'notifications': notifications,
          },
        ],
      };
    }
    if (method == 'POST' && path.endsWith('/preferences/')) {
      pinned = data!['pinned'];
      notifications = data['notifications'];
      await onPreferences?.call();
      return {};
    }
    throw StateError('Unexpected request: $method $path');
  }
}

class _AssignmentApi extends _ProjectApi {
  final remote = <Map<String, dynamic>>[];
  bool removed = false;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (path == 'lists/access/') {
      final snapshot = await super.request(method, path, accountId: accountId);
      if (removed) {
        (snapshot['lists'][0]['people'] as List).removeWhere(
          (p) => p['user_id'] == 2,
        );
      }
      return snapshot;
    }
    if (path == 'health/') {
      return {
        'features': {'notes': true},
      };
    }
    if (method == 'GET' && path.startsWith('attachments/')) {
      return {'results': [], 'next': null};
    }
    if (method == 'GET' && path.startsWith('tasks/?')) {
      return {'results': remote, 'next': null};
    }
    if (method == 'GET' && path.startsWith('tasks/')) {
      return remote.singleWhere((row) => path == "tasks/${row['id']}/");
    }
    if (method == 'PUT' && path.startsWith('tasks/')) {
      if (data!['assignee_id'] == 2) {
        removed = true;
        throw ApiException(400, 'Member left', {
          'assignee_id': ['No longer a group member.'],
        });
      }
      final row = {
        ...data,
        'id': path.split('/')[1],
        'version': data['version'] + 1,
      };
      remote.removeWhere((other) => other['id'] == row['id']);
      remote.add(row);
      return row;
    }
    return super.request(
      method,
      path,
      data: data,
      audioPath: audioPath,
      authenticated: authenticated,
      accountId: accountId,
    );
  }
}
