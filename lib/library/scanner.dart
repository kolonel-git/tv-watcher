import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import 'filename_parser.dart';

class ScanResult {
  const ScanResult({
    required this.added,
    required this.missing,
    required this.unsorted,
    this.skippedOffline = false,
  });
  final int added;
  final int missing;
  final int unsorted;

  /// Folder not reachable (e.g. drive missing): nothing was changed.
  final bool skippedOffline;
}

/// Lists video files under [root] (read-only). Returns absolute paths.
Future<List<String>> listVideoFiles(String root) async {
  final out = <String>[];
  await for (final e in Directory(root).list(recursive: true, followLinks: false)) {
    if (e is File && isVideoFile(e.path)) out.add(e.path);
  }
  return out;
}

/// Reconciles the DB with the files in [folder]. Never touches the files.
///
/// [listFiles] is injectable for tests.
Future<ScanResult> scanFolder(
  AppDatabase db,
  LibraryFolder folder, {
  Future<List<String>> Function(String root)? listFiles,
}) async {
  final root = folder.path;
  if (listFiles == null && !await Directory(root).exists()) {
    return const ScanResult(
        added: 0, missing: 0, unsorted: 0, skippedOffline: true);
  }
  final files = await (listFiles ?? listVideoFiles)(root);
  final found = files.toSet();

  final existing = await (db.select(db.episodes)
        ..where((e) => e.folderId.equals(folder.id)))
      .get();
  final byPath = {for (final e in existing) e.filePath: e};

  var added = 0;
  var missing = 0;

  await db.transaction(() async {
    for (final path in files) {
      final row = byPath[path];
      if (row != null) {
        if (row.manual) {
          if (row.missing) {
            await (db.update(db.episodes)..where((e) => e.id.equals(row.id)))
                .write(const EpisodesCompanion(missing: Value(false)));
          }
          continue;
        }
        await _applyParse(db, row.id, root, path, markPresent: true);
        continue;
      }
      final id = await db.into(db.episodes).insert(
            EpisodesCompanion.insert(filePath: path, folderId: folder.id),
          );
      await _applyParse(db, id, root, path);
      added++;
    }

    for (final row in existing) {
      if (!found.contains(row.filePath) && !row.missing) {
        await (db.update(db.episodes)..where((e) => e.id.equals(row.id)))
            .write(const EpisodesCompanion(missing: Value(true)));
        missing++;
      }
    }
  });

  final totalUnsorted = await (db.select(db.episodes)
        ..where((e) =>
            e.folderId.equals(folder.id) &
            e.showId.isNull() &
            e.missing.equals(false)))
      .get();
  await db.deleteEmptyShows();
  return ScanResult(
      added: added, missing: missing, unsorted: totalUnsorted.length);
}

Future<bool> _applyParse(
  AppDatabase db,
  int episodeId,
  String root,
  String path, {
  bool markPresent = false,
}) async {
  final rel = p.relative(path, from: root);
  final parsed = parseEpisodePath(rel);
  if (parsed == null) {
    await (db.update(db.episodes)..where((e) => e.id.equals(episodeId))).write(
      EpisodesCompanion(
        showId: const Value(null),
        season: const Value(null),
        episode: const Value(null),
        endEpisode: const Value(null),
        title: const Value(null),
        missing: markPresent ? const Value(false) : const Value.absent(),
      ),
    );
    return false;
  }
  final showId = await db.upsertShow(parsed.showName, parsed.showKey, parsed.year);
  await (db.update(db.episodes)..where((e) => e.id.equals(episodeId))).write(
    EpisodesCompanion(
      showId: Value(showId),
      season: Value(parsed.season),
      episode: Value(parsed.episode),
      endEpisode: Value(parsed.endEpisode),
      title: Value(parsed.title),
      missing: markPresent ? const Value(false) : const Value.absent(),
    ),
  );
  return true;
}
