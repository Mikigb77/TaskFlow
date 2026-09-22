import 'dart:convert';
import 'package:uuid/uuid.dart';

class TaskListInfo {
  final String id;
  final String name;
  final String color;
  final bool archived;
  final int version;
  final Map<String, dynamic>? conflict;
  TaskListInfo(
      {String? id,
      required this.name,
      this.color = 'teal',
      this.archived = false,
      this.version = 0,
      this.conflict})
      : id = id ?? const Uuid().v4();

  TaskListInfo copyWith({String? name, String? color, bool? archived}) =>
      TaskListInfo(
          id: id,
          name: name ?? this.name,
          color: color ?? this.color,
          archived: archived ?? this.archived,
          version: version,
          conflict: conflict);

  Map<String, dynamic> toApi() =>
      {'name': name, 'color': color, 'archived': archived, 'version': version};
  factory TaskListInfo.fromApi(Map<String, dynamic> json) => TaskListInfo(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      archived: json['archived'] == true,
      version: json['version']);
  factory TaskListInfo.fromRow(Map<String, dynamic> row) => TaskListInfo(
      id: row['id'],
      name: row['name'],
      color: row['color'],
      archived: row['archived'] == 1,
      version: row['remote_version'],
      conflict: row['conflict'] == null ? null : jsonDecode(row['conflict']));
}
