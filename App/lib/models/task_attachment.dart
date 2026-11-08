class TaskAttachment {
  const TaskAttachment(
      {required this.id,
      required this.taskId,
      required this.name,
      required this.size,
      required this.sha256,
      this.localPath,
      this.sourcePath,
      this.remote = false,
      this.uploadPending = false,
      this.deletePending = false,
      this.deleted = false,
      this.error});
  static const maxBytes = 6 * 1024 * 1024;

  /// Stable [error] tokens for an upload the server refused because the
  /// uploads allowance is used up: the user's own without Pro, this month's
  /// with Pro, or a shared project owner's. Sync doesn't re-send these until
  /// Retry, a removal, or Pro turning on.
  static const storageFull = 'attachment_problem:storage_full';
  static const storageMonthFull = 'attachment_problem:storage_month_full';
  static const storageFullShared = 'attachment_problem:storage_full_shared';
  final String id;
  final String taskId;
  final String name;
  final int size;
  final String sha256;
  final String? localPath;

  /// A legacy/editor path in Task.filePaths; remote downloads have no source.
  final String? sourcePath;
  final bool remote;
  final bool uploadPending;
  final bool deletePending;
  final bool deleted;
  final String? error;

  bool get refused =>
      error == storageFull ||
      error == storageMonthFull ||
      error == storageFullShared;

  factory TaskAttachment.fromMap(Map<String, dynamic> row) => TaskAttachment(
      id: row['id'] as String,
      taskId: row['task_id'] as String,
      name: row['name'] as String,
      size: row['size'] as int,
      sha256: row['sha256'] as String,
      localPath: row['local_path'] as String?,
      sourcePath: row['source_path'] as String?,
      remote: row['remote'] == 1,
      uploadPending: row['upload_pending'] == 1,
      deletePending: row['delete_pending'] == 1,
      deleted: row['is_deleted'] == 1,
      error: row['error'] as String?);

  factory TaskAttachment.fromApi(Map<String, dynamic> data) {
    final id = data['id'];
    final taskId = data['task_id'];
    final size = data['size'];
    final name = data['name'];
    final hash = data['sha256'];
    final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (id is! String ||
        !uuid.hasMatch(id) ||
        taskId is! String ||
        !uuid.hasMatch(taskId) ||
        size is! int ||
        size < 1 ||
        size > maxBytes ||
        name is! String ||
        name.isEmpty ||
        name.length > 180 ||
        name.contains(RegExp(r'[/\\\x00-\x1f]')) ||
        name == '.' ||
        name == '..' ||
        hash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException(
          'The server returned invalid attachment information.');
    }
    return TaskAttachment(
        id: id,
        taskId: taskId,
        name: name,
        size: size,
        sha256: hash,
        remote: true,
        deleted: data['is_deleted'] == true);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'name': name,
        'size': size,
        'sha256': sha256,
        'local_path': localPath,
        'source_path': sourcePath,
        'remote': remote ? 1 : 0,
        'upload_pending': uploadPending ? 1 : 0,
        'delete_pending': deletePending ? 1 : 0,
        'is_deleted': deleted ? 1 : 0,
        'error': error
      };
}
