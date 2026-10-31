import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/task_attachment.dart';

class AttachmentFiles {
  AttachmentFiles({this.directory});
  final Directory? directory;
  Future<Directory> get root async =>
      directory ??
      Directory(
          p.join((await getApplicationSupportDirectory()).path, 'attachments'));

  String safeName(String value) {
    var name =
        p.basename(value).replaceAll(RegExp(r'[\x00-\x1f\x7f|<>:"/\\?*]'), '_');
    if (name.isEmpty || name == '.' || name == '..') name = 'attachment';
    if (name.length > 180) name = name.substring(name.length - 180);
    name = name.replaceAll(RegExp(r'[ .]+$'), '');
    if (name.isEmpty ||
        RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
                caseSensitive: false)
            .hasMatch(name)) {
      name = 'file_$name';
    }
    return name;
  }

  Future<bool> owns(String path) async {
    final base = await root;
    if (!await base.exists() || !await File(path).exists()) return false;
    return p.isWithin(await base.resolveSymbolicLinks(),
        await File(path).resolveSymbolicLinks());
  }

  /// Keep a durable snapshot; never move or remove a picker/user source file.
  Future<String> retain(String source) async {
    final input = File(source);
    final size = await input.length();
    if (size < 1 || size > TaskAttachment.maxBytes) {
      throw const FormatException('Choose a non-empty file up to 6 MiB.');
    }
    if (await owns(source)) return source;
    final path =
        p.join((await root).path, 'local', const Uuid().v4(), safeName(source));
    await File(path).parent.create(recursive: true);
    try {
      final copied = await input.copy(path);
      if (await copied.length() != size) {
        throw const FormatException(
            'The file changed while being copied. Choose it again.');
      }
      return copied.path;
    } catch (_) {
      if (await File(path).exists()) await File(path).delete();
      rethrow;
    }
  }

  Future<String> checksum(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();

  Future<String> downloaded(
      String owner, TaskAttachment item, Uint8List bytes) async {
    TaskAttachment.fromApi({
      'id': item.id,
      'task_id': item.taskId,
      'name': item.name,
      'size': item.size,
      'sha256': item.sha256
    });
    if (bytes.length != item.size ||
        sha256.convert(bytes).toString() != item.sha256) {
      throw const FormatException(
          'The downloaded file did not match its saved checksum. Retry the download.');
    }
    final scope = sha256.convert(utf8.encode(owner)).toString();
    final path =
        p.join((await root).path, 'cache', scope, item.id, safeName(item.name));
    final target = File(path);
    await target.parent.create(recursive: true);
    final partial = File('$path.part-${const Uuid().v4()}');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
    return path;
  }

  Future<void> removeOwned(String path) async {
    if (!await owns(path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
    // Only an empty leaf directory is removed; never recursively traverse files.
    if (await file.parent.exists() && await file.parent.list().isEmpty) {
      await file.parent.delete();
    }
  }
}
