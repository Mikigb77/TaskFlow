import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';

/// An invitation to a project or a group, waiting for this account.
class PendingInvitation {
  const PendingInvitation({
    required this.kind,
    required this.id,
    required this.name,
    required this.targetId,
    required this.role,
  });

  factory PendingInvitation.fromJson(String kind, Map json) =>
      PendingInvitation(
        kind: kind,
        id: json['id'] as String,
        name: (kind == 'group' ? json['group_name'] : json['list_name'])
            as String,
        targetId: (kind == 'group' ? json['group_id'] : json['list_id'])
            as String?,
        role: json['role'] as String,
      );

  /// `list` (a project) or `group`.
  final String kind;
  final String id;
  final String name;

  /// The project or group joined by accepting.
  final String? targetId;
  final String role;

  bool get group => kind == 'group';
  String get endpoint => group ? 'group-invitations' : 'invitations';
}

/// Every pending invitation for the signed-in account, groups first.
/// Calendar, Projects and Groups all read this one list.
final pendingInvitationsProvider =
    FutureProvider.autoDispose<List<PendingInvitation>>((ref) async {
      final accountId = ref.watch(
        authProvider.select((state) => state.account?.id),
      );
      if (accountId == null) return [];
      final api = ref.watch(apiClientProvider);
      final [groups, lists] = await Future.wait([
        api.request('GET', 'group-invitations/', accountId: accountId),
        api.request('GET', 'invitations/', accountId: accountId),
      ]);
      return [
        for (final item in (groups as Map)['invitations'] as List)
          PendingInvitation.fromJson('group', item as Map),
        for (final item in (lists as Map)['invitations'] as List)
          PendingInvitation.fromJson('list', item as Map),
      ];
    });
