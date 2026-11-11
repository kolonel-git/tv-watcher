import 'dart:io';

/// Why an episode file cannot be played right now.
enum FileProblem {
  /// The library folder is there but the file is not: moved, renamed or
  /// deleted. A rescan updates the library.
  fileMissing,

  /// The whole library folder is unreachable (drive unplugged, share
  /// offline). Nothing to rescan; reconnect it.
  folderUnreachable,
}

/// Checks [filePath] inside library folder [folderPath] without touching
/// either. Returns null when the file can be opened.
///
/// [exists] is injectable for tests.
Future<FileProblem?> checkPlayable(
  String filePath,
  String folderPath, {
  Future<bool> Function(String path)? fileExists,
  Future<bool> Function(String path)? dirExists,
}) async {
  final fe = fileExists ?? (p) => File(p).exists();
  final de = dirExists ?? (p) => Directory(p).exists();
  if (await fe(filePath)) return null;
  if (!await de(folderPath)) return FileProblem.folderUnreachable;
  return FileProblem.fileMissing;
}
