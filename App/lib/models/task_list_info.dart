import 'dart:convert';
import 'package:uuid/uuid.dart';

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.name,
    required this.role,
    this.voiceName = '',
  });
  final int id;
  final String name;
  final String role;
  final String voiceName;
  bool get canEdit => role != 'viewer';
  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
    id: json['user_id'],
    name: json['name'],
    role: json['role'],
    voiceName: json['voice_name'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'user_id': id,
    'name': name,
    'role': role,
    'voice_name': voiceName,
  };
}

class TaskListInfo {
  final String id;
  final String name;
  final String color;
  final bool archived;
  final int version;
  final String role;
  final bool shared;
  final String? groupId;
  final String? groupName;
  final bool groupArchived;
  bool get inactive => archived || groupArchived;
  final int? ownerId;
  final List<ProjectMember> people;
  final bool pinned;
  final String notifications;
  bool get canEdit => ['owner', 'admin', 'editor'].contains(role);
  bool get canManage => role == 'owner' || (groupId != null && role == 'admin');
  final Map<String, dynamic>? conflict;
  TaskListInfo({
    String? id,
    required this.name,
    this.color = 'teal',
    this.archived = false,
    this.version = 0,
    this.role = 'owner',
    this.shared = false,
    this.groupId,
    this.groupName,
    this.groupArchived = false,
    this.ownerId,
    this.people = const [],
    this.pinned = false,
    this.notifications = 'assigned',
    this.conflict,
  }) : id = id ?? const Uuid().v4();

  TaskListInfo copyWith({
    String? name,
    String? color,
    bool? archived,
    bool? pinned,
    String? notifications,
  }) => TaskListInfo(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    archived: archived ?? this.archived,
    version: version,
    role: role,
    shared: shared,
    groupId: groupId,
    groupName: groupName,
    groupArchived: groupArchived,
    ownerId: ownerId,
    people: people,
    pinned: pinned ?? this.pinned,
    notifications: notifications ?? this.notifications,
    conflict: conflict,
  );

  Map<String, dynamic> toApi() => {
    'name': name,
    'color': color,
    'archived': archived,
    'version': version,
    if (groupId != null) 'group_id': groupId,
  };
  factory TaskListInfo.fromApi(Map<String, dynamic> json) => TaskListInfo(
    id: json['id'],
    name: json['name'],
    color: json['color'],
    archived: json['archived'] == true,
    role: json['role'] ?? 'owner',
    shared: json['shared'] == true,
    groupId: json['group_id'],
    groupName: json['group_name'],
    groupArchived: json['group_archived'] == true,
    ownerId: json['owner_id'],
    people: (json['people'] as List? ?? [])
        .map(
          (value) => ProjectMember.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
    pinned: json['pinned'] == true,
    notifications: json['notifications'] ?? 'assigned',
    version: json['version'],
  );
  factory TaskListInfo.fromRow(Map<String, dynamic> row) => TaskListInfo(
    id: row['id'],
    name: row['name'],
    color: row['color'],
    archived: row['archived'] == 1,
    role: row['role'] ?? 'owner',
    shared: row['shared'] == 1,
    groupId: row['group_id'],
    groupName: row['group_name'],
    groupArchived: row['group_archived'] == 1,
    ownerId: row['owner_id'],
    people: (jsonDecode(row['people'] ?? '[]') as List)
        .map(
          (value) => ProjectMember.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
    pinned: row['pinned'] == 1,
    notifications: row['notifications'] ?? 'assigned',
    version: row['remote_version'],
    conflict: row['conflict'] == null ? null : jsonDecode(row['conflict']),
  );
}
