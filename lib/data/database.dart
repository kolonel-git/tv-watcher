import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
}

class Shows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Normalised grouping key (lowercase alphanumerics).
  TextColumn get key => text().unique()();
  IntColumn get year => integer().nullable()();
}

class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  IntColumn get folderId => integer().references(LibraryFolders, #id)();
  IntColumn get showId => integer().nullable().references(Shows, #id)();
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();
  IntColumn get endEpisode => integer().nullable()();
  TextColumn get title => text().nullable()();

  /// File no longer found on disk at last scan. Row kept to preserve data.
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  /// User assigned show/season/episode by hand; rescans never overwrite it.
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [LibraryFolders, Shows, Episodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tv_watcher'));

  /// For tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(episodes, episodes.title);
        },
      );

  // ---- folders ----
  Stream<List<LibraryFolder>> watchFolders() =>
      select(libraryFolders).watch();

  Future<int> addFolder(String path) => into(libraryFolders)
      .insert(LibraryFoldersCompanion.insert(path: path),
          mode: InsertMode.insertOrIgnore);

  Future<void> removeFolder(int id) async {
    await (delete(episodes)..where((e) => e.folderId.equals(id))).go();
    await (delete(libraryFolders)..where((f) => f.id.equals(id))).go();
    await _deleteEmptyShows();
  }

  // ---- shows / episodes ----
  Future<int> upsertShow(String name, String key, int? year) async {
    final existing =
        await (select(shows)..where((s) => s.key.equals(key))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(shows).insert(
        ShowsCompanion.insert(name: name, key: key, year: Value(year)));
  }

  Stream<List<ShowWithCount>> watchShows() {
    final count = episodes.id.count();
    final q = select(shows).join([
      innerJoin(episodes, episodes.showId.equalsExp(shows.id)),
    ])
      ..where(episodes.missing.equals(false))
      ..addColumns([count])
      ..groupBy([shows.id])
      ..orderBy([OrderingTerm.asc(shows.name)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            ShowWithCount(r.readTable(shows), r.read(count) ?? 0),
        ]);
  }

  Stream<List<Episode>> watchEpisodesOfShow(int showId) =>
      (select(episodes)
            ..where((e) => e.showId.equals(showId) & e.missing.equals(false))
            ..orderBy([
              (e) => OrderingTerm.asc(e.season),
              (e) => OrderingTerm.asc(e.episode),
            ]))
          .watch();

  Stream<List<Episode>> watchUnsorted() => (select(episodes)
        ..where((e) => e.showId.isNull() & e.missing.equals(false))
        ..orderBy([(e) => OrderingTerm.asc(e.filePath)]))
      .watch();

  Future<void> assignEpisode(
    int episodeId, {
    required String showName,
    required String showKey,
    required int season,
    required int episode,
  }) async {
    final showId = await upsertShow(showName, showKey, null);
    await (update(episodes)..where((e) => e.id.equals(episodeId))).write(
      EpisodesCompanion(
        showId: Value(showId),
        season: Value(season),
        episode: Value(episode),
        endEpisode: const Value(null),
        title: const Value(null),
        manual: const Value(true),
      ),
    );
  }

  Future<void> _deleteEmptyShows() async {
    await customStatement(
        'DELETE FROM shows WHERE id NOT IN (SELECT DISTINCT show_id FROM episodes WHERE show_id IS NOT NULL)');
  }

  Future<void> deleteEmptyShows() => _deleteEmptyShows();
}

class ShowWithCount {
  ShowWithCount(this.show, this.episodeCount);
  final Show show;
  final int episodeCount;
}
