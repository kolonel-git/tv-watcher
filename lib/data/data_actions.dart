import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// The operating-system side of backup and "open data folder": file
/// dialogs and Explorer. An interface so the settings screen can be tested
/// without real dialogs.
abstract interface class DataActions {
  /// Asks where to save [bytes]; returns false when the user cancels.
  Future<bool> saveBackup(String fileName, Uint8List bytes);

  /// Asks for a backup file; returns its text, or null on cancel.
  Future<String?> pickBackup();

  /// Folder holding the database.
  Future<String> dataFolder();

  Future<void> openFolder(String path);
}

/// Largest backup read into memory (a real one is well under 1 MB).
const maxBackupBytes = 20 * 1024 * 1024;

class PlatformDataActions implements DataActions {
  const PlatformDataActions();

  @override
  Future<bool> saveBackup(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return saved != null;
  }

  @override
  Future<String?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a backup file',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.path;
    if (path == null) return null;
    final file = File(path);
    if (await file.length() > maxBackupBytes) {
      throw const FileSystemException('That file is too large to be a backup.');
    }
    return file.readAsString();
  }

  /// The database lives in the documents folder (drift_flutter default).
  @override
  Future<String> dataFolder() async =>
      (await getApplicationDocumentsDirectory()).path;

  @override
  Future<void> openFolder(String path) async {
    // Explorer exits with 1 even on success, so the code is ignored.
    await Process.run('explorer.exe', [path]);
  }
}
