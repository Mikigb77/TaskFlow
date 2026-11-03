import 'package:agenda/models/archive_diagnostic.dart';
import 'dart:convert';
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
    final file = await FilePicker.pickFile(
        type: FileType.custom, allowedExtensions: ['json', 'csv']);
    if (file == null) return null;
    // A null length means the picker could not read the file at all.
    final size = file.lengthSync() ?? await file.length();
    if (size == null) {
      throw const ArchiveDiagnostic(ArchiveCode.fileUnreadable);
    }
    if (size > TaskArchive.maxBytes) {
      throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > TaskArchive.maxBytes) {
        throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
      }
      bytes.add(chunk);
    }
    return ArchiveFile(file.name, utf8.decode(bytes.takeBytes()));
  }

  Future<bool> save(String contents) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    // Every platform's picker writes the bytes itself, desktop included.
    final selected = await FilePicker.saveFile(
        fileName: fileName ?? 'taskflow-${Task.dateKey(DateTime.now())}.json',
        mimeType: 'application/json',
        bytes: bytes);
    if (selected == null) return false;
    return true;
  }
}
