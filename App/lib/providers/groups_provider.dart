import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_group.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';

final groupsProvider = FutureProvider<List<TaskGroupInfo>>((ref) async {
  final accountId = ref.watch(
    authProvider.select((state) => state.account?.id),
  );
  if (accountId == null) return [];
  final api = ref.watch(apiClientProvider);
  final scope = 'groups:${api.baseUrl}/users/$accountId';
  final db = await TaskDatabase().database;
  List<Map<String, dynamic>> values;
  try {
    values = await collaborationPages(api, 'groups/', accountId);
    await db.rawInsert(
      'INSERT OR REPLACE INTO app_preferences(scope,data) VALUES(?,?)',
      [scope, jsonEncode(values)],
    );
  } on ApiException catch (error) {
    if (error.status != 0 && error.status < 500) rethrow;
    final cached = await db.query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    if (cached.isEmpty) rethrow;
    values = (jsonDecode(cached.single['data'] as String) as List)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }
  return values.map(TaskGroupInfo.fromJson).toList();
});

Future<List<Map<String, dynamic>>> collaborationPages(
  ApiClient api,
  String path,
  int accountId,
) async {
  final items = <Map<String, dynamic>>[];
  for (var page = 1; ; page++) {
    final result =
        await api.request('GET', '$path?page=$page', accountId: accountId)
            as Map;
    items.addAll(
      (result['results'] as List).map((p) => Map<String, dynamic>.from(p)),
    );
    if (result['next'] == null) return items;
  }
}

final groupDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      final accountId = ref.watch(
        authProvider.select((state) => state.account?.id),
      );
      if (accountId == null) {
        throw ApiException(401, 'Sign in to manage groups.');
      }
      return Map<String, dynamic>.from(
        await ref
            .watch(apiClientProvider)
            .request('GET', 'groups/$id/sharing/', accountId: accountId),
      );
    });

final groupInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final accountId = ref.watch(
        authProvider.select((state) => state.account?.id),
      );
      if (accountId == null) return [];
      final result =
          await ref
                  .watch(apiClientProvider)
                  .request('GET', 'group-invitations/', accountId: accountId)
              as Map;
      return (result['invitations'] as List)
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
    });

final collaborationActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final accountId = ref.watch(
        authProvider.select((state) => state.account?.id),
      );
      if (accountId == null) return [];
      return collaborationPages(
        ref.watch(apiClientProvider),
        'notifications/',
        accountId,
      );
    });

final collaborationUnreadProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final accountId = ref.watch(
    authProvider.select((state) => state.account?.id),
  );
  if (accountId == null) return 0;
  final result =
      await ref
              .watch(apiClientProvider)
              .request('GET', 'notifications/unread/', accountId: accountId)
          as Map;
  return result['count'] as int;
});
