import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/task_database.dart';

/// A project or group the person owns that goes to someone else.
class Handover {
  const Handover({required this.group, required this.name, required this.to});
  final bool group;
  final String name;

  /// Who receives it, as the server names them.
  final String to;

  static Handover parse(Object? data) {
    if (data is! Map) throw const FormatException('Invalid handover.');
    final kind = data['kind'];
    final name = data['name'];
    final to = data['to'];
    if ((kind != 'project' && kind != 'group') ||
        name is! String ||
        name.trim().isEmpty ||
        to is! String ||
        to.trim().isEmpty) {
      throw const FormatException('Invalid handover.');
    }
    return Handover(group: kind == 'group', name: name, to: to);
  }
}

/// What deleting the account removes, keeps for others and hands over, as
/// the server counts it (`GET auth/delete-account/`).
class DeletionPreview {
  const DeletionPreview({
    required this.plan,
    this.tasks = 0,
    this.notes = 0,
    this.files = 0,
    this.projects = 0,
    this.groups = 0,
    this.keptInShared = 0,
    this.keptFilesInShared = 0,
    this.handovers = const [],
    this.pro = false,
    this.google = false,
  });

  /// The server's fingerprint of this preview, sent back with the
  /// confirmation: the deletion only goes ahead as it was shown.
  final String plan;

  /// The person's own items, deleted with the account.
  final int tasks, notes, files, projects, groups;

  /// Tasks they added to other people's projects: they stay, unsigned.
  final int keptInShared;

  /// Files they added in shared projects that stay, on their own tasks or on
  /// other people's. 0 from an older server, which doesn't count them.
  final int keptFilesInShared;
  final List<Handover> handovers;

  /// Has Pro, or billing couldn't be checked: a Google Play subscription may
  /// still be running.
  final bool pro;

  /// Confirmed with a fresh Google sign-in instead of the password.
  final bool google;

  /// Throws [FormatException] unless the answer says all of it: the page
  /// never shows part of a preview, so no handover goes unmentioned.
  static DeletionPreview parse(Object? data) {
    if (data is! Map || data['personal'] is! Map) {
      throw const FormatException('Invalid deletion preview.');
    }
    final personal = data['personal'] as Map;
    int count(Object? value) => value is int && value >= 0
        ? value
        : throw const FormatException('Invalid deletion preview.');
    final handovers = data['handovers'];
    final pro = data['pro'];
    final reauth = data['reauth'];
    final plan = data['plan'];
    if (handovers is! List ||
        pro is! bool ||
        (reauth != 'password' && reauth != 'google') ||
        plan is! String ||
        plan.isEmpty) {
      throw const FormatException('Invalid deletion preview.');
    }
    return DeletionPreview(
      plan: plan,
      tasks: count(personal['tasks']),
      notes: count(personal['notes']),
      files: count(personal['files']),
      projects: count(personal['projects']),
      groups: count(personal['groups']),
      keptInShared: count(data['kept_in_shared']),
      keptFilesInShared: data.containsKey('kept_files_in_shared')
          ? count(data['kept_files_in_shared'])
          : 0,
      handovers: handovers.map(Handover.parse).toList(),
      pro: pro,
      google: reauth == 'google',
    );
  }
}

final localAccountDataProvider = Provider<LocalAccountData>(
  (ref) => LocalAccountData(TaskDatabase()),
);

/// Readies erasing what account [accountId] left on this phone. Called while
/// it is still signed in, since its own providers go as soon as it does;
/// [read] is a provider reader, such as a Ref's.
Future<void> Function() prepareAccountErase(
  T Function<T>(ProviderListenable<T> provider) read,
  int accountId,
) {
  final owner = '${read(apiClientProvider).baseUrl}/users/$accountId';
  final repository = read(taskRepositoryProvider);
  final local = read(localAccountDataProvider);
  final invitation = read(invitationLinkProvider.notifier);
  return () async {
    // A sync already under way ends first, so it can't write afterwards.
    await repository.settled;
    await local.erase(owner);
    await invitation.forget();
  };
}

/// What one account left on this phone. Signing out keeps it, to be there
/// on signing back in; a deleted account's is erased.
class LocalAccountData {
  LocalAccountData(
    this.database, {
    AttachmentFiles? files,
    CaptureStore? captures,
    MeetingStore? meetings,
  }) : files = files ?? AttachmentFiles(),
       captures = captures ?? CaptureStore(database),
       meetings = meetings ?? MeetingStore(database);
  final TaskDatabase database;
  final AttachmentFiles files;
  final CaptureStore captures;
  final MeetingStore meetings;

  static const _ownedTables = [
    'tasks',
    'task_attachments',
    'task_lists',
    'list_imports',
    'archive_imports',
    'captures',
    'reminder_state',
    'reminder_snoozes',
    'meetings',
    'meeting_pieces',
    'meeting_leases',
  ];

  /// Erases everything [owner] left here: tasks and notes, projects, file
  /// records with the app's copies of the files and its downloads, captures
  /// with their audio, recorded meetings with their audio, reminder records,
  /// import receipts and the account's preferences. Other accounts, and what was kept before signing in, stay;
  /// a person's own files outside the app are never touched.
  Future<void> erase(String owner) async {
    if (!owner.contains('/users/')) {
      throw ArgumentError('Only a signed-in account is erased.');
    }
    final db = await database.database;
    final paths = <String>{};
    final captureIds = <String>[];
    final meetingIds = <String>{};
    await db.transaction((tx) async {
      for (final row in await tx.query(
        'tasks',
        columns: ['filePaths', 'imagePaths'],
        where: 'owner_key = ?',
        whereArgs: [owner],
      )) {
        for (final field in ['filePaths', 'imagePaths']) {
          paths.addAll(
            (row[field] as String? ?? '')
                .split('|')
                .where((path) => path.isNotEmpty),
          );
        }
      }
      for (final row in await tx.query(
        'task_attachments',
        columns: ['local_path', 'source_path'],
        where: 'owner_key = ?',
        whereArgs: [owner],
      )) {
        paths.addAll(
          [row['local_path'], row['source_path']].whereType<String>(),
        );
      }
      captureIds.addAll(
        (await tx.query(
          'captures',
          columns: ['id'],
          where: 'owner_key = ?',
          whereArgs: [owner],
        )).map((row) => row['id'] as String),
      );
      // Pieces are read too: a piece's folder is its meeting's, even with
      // the meeting's row gone.
      for (final table in ['meetings', 'meeting_pieces']) {
        meetingIds.addAll(
          (await tx.query(
            table,
            columns: [table == 'meetings' ? 'id' : 'meeting_id'],
            where: 'owner_key = ?',
            whereArgs: [owner],
          )).map((row) => row.values.single as String),
        );
      }
      for (final table in _ownedTables) {
        await tx.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      // Per-account preferences are scoped `<kind>:<owner>`.
      await tx.delete(
        'app_preferences',
        where: "substr(scope, instr(scope, ':') + 1) = ?",
        whereArgs: [owner],
      );
    });
    // Files go once nothing refers to them: only the app's own copies, and
    // only those no other account still uses.
    await AttachmentStore(
      database,
      owner,
      files: files,
    ).cleanRemovedPaths(paths);
    // The account's downloads folder, with anything left in it.
    final downloads = Directory(
      p.join(
        (await files.root).path,
        'cache',
        sha256.convert(utf8.encode(owner)).toString(),
      ),
    );
    try {
      if (await downloads.exists()) await downloads.delete(recursive: true);
    } on FileSystemException {
      /* The records are gone; nothing opens these copies again. */
    }
    for (final id in captureIds) {
      await captures.removeAudioFile(id);
    }
    // The audio of its meetings: recordings of conversations go with it,
    // and no uploader runs for this account again.
    if (meetingIds.isNotEmpty) await meetings.removeFolders(meetingIds);
  }
}
