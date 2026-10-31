import 'package:agenda/models/task_list_info.dart';

class TaskGroupInfo {
  const TaskGroupInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.version,
    required this.role,
    this.archived = false,
    this.people = const [],
    this.projectCount = 0,
  });
  final String id;
  final String name;
  final int ownerId;
  final int version;
  final String role;
  final bool archived;
  final List<ProjectMember> people;
  final int projectCount;
  bool get canManage => role == 'owner' || role == 'admin';
  factory TaskGroupInfo.fromJson(Map<String, dynamic> json) => TaskGroupInfo(
    id: json['id'],
    name: json['name'],
    ownerId: json['owner_id'],
    version: json['version'],
    role: json['role'],
    archived: json['archived'] == true,
    people: (json['people'] as List? ?? [])
        .map((p) => ProjectMember.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
    projectCount: json['project_count'] ?? 0,
  );
}
