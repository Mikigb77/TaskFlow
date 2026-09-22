import 'package:agenda/models/archive_diagnostic.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';

class ArchiveFile {
  final String name;
  final String contents;
  const ArchiveFile(this.name, this.contents);
}

class ArchiveFiles {
  final String? fileName;
  ArchiveFiles({this.fileName});
  Future<ArchiveFile?> choose() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: false,
        withReadStream: true);
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > TaskArchive.maxBytes) {
      throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
    }
    final stream = file.readStream ??
        (file.path == null ? null : File(file.path!).openRead());
    if (stream == null) {
      throw const ArchiveDiagnostic(ArchiveCode.fileUnreadable);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > TaskArchive.maxBytes) {
        throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
      }
      bytes.add(chunk);
    }
    return ArchiveFile(file.name, utf8.decode(bytes.takeBytes()));
  }

  Future<bool> save(String contents) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    final selected = await FilePicker.platform.saveFile(
        fileName: fileName ?? 'taskflow-${Task.dateKey(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes);
    if (selected == null) return false;
    // The plugin writes mobile document-provider content itself. Desktop save
    // dialogs return a path; they do not write the bytes.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(selected).writeAsBytes(bytes, flush: true);
    }
    return true;
  }
}
