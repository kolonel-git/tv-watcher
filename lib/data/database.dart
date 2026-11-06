import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../watch/watch_logic.dart';

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

  // --- TMDB metadata (Sprint 3) ---
  IntColumn get tmdbId => integer().nullable()();
  TextColumn get tmdbName => text().nullable()();
  TextColumn get overview => text().nullable()();

  /// Local cached artwork file paths.
  TextColumn get posterFile => text().nullable()();
  TextColumn get backdropFile => text().nullable()();

  /// none | matched | ambiguous | nomatch
  TextColumn get metaStatus => text().withDefault(const Constant('none'))();

  /// User picked the match by hand; never auto-rematched.
  BoolColumn get metaLocked => boolean().withDefault(const Constant(false))();
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

  // --- TMDB metadata (Sprint 3) ---
  TextColumn get tmdbTitle => text().nullable()();
  TextColumn get overview => text().nullable()();
  IntColumn get runtime => integer().nullable()();
  TextColumn get airDate => text().nullable()();
  TextColumn get stillFile => text().nullable()();

  /// File no longer found on disk at last scan. Row kept to preserve data.
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  /// User assigned show/season/episode by hand; rescans never overwrite it.
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  // --- Watch state (Sprint 5) ---
  /// Resume point in ms. 0 = none / start over.
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [LibraryFolders, Shows, Episodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tv_watcher'));

  /// For tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(episodes, episodes.title);
          if (from < 3) {
            await m.addColumn(shows, shows.tmdbId);
            await m.addColumn(shows, shows.tmdbName);
            await m.addColumn(shows, shows.overview);
            await m.addColumn(shows, shows.posterFile);
            await m.addColumn(shows, shows.backdropFile);
            await m.addColumn(shows, shows.metaStatus);
            await m.addColumn(shows, shows.metaLocked);
            await m.addColumn(episodes, episodes.tmdbTitle);
            await m.addColumn(episodes, episodes.overview);
            await m.addColumn(episodes, episodes.runtime);
            await m.addColumn(episodes, episodes.airDate);
            await m.addColumn(episodes, episodes.stillFile);
          }
          if (from < 4) {
            await m.addColumn(episodes, episodes.positionMs);
            await m.addColumn(episodes, episodes.durationMs);
            await m.addColumn(episodes, episodes.watched);
            await m.addColumn(episodes, episodes.lastPlayedAt);
          }
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


  // ---- watch state ----

  /// Stores progress for [episodeId] using [computeProgress] rules.
  Future<void> saveProgress(
    int episodeId, {
    required int positionMs,
    required int durationMs,
  }) async {
    final ep = await (select(episodes)..where((e) => e.id.equals(episodeId)))
        .getSingleOrNull();
    if (ep == null) return;
    final u = computeProgress(
        positionMs: positionMs, durationMs: durationMs, wasWatched: ep.watched);
    final becameWatched = u.watched && !ep.watched;
    final meaningful = u.positionMs > 0 || becameWatched;
    await (update(episodes)..where((e) => e.id.equals(episodeId))).write(
      EpisodesCompanion(
        positionMs: Value(u.positionMs),
        durationMs: durationMs > 0 ? Value(durationMs) : const Value.absent(),
        watched: Value(u.watched),
        lastPlayedAt:
            meaningful ? Value(DateTime.now()) : const Value.absent(),
      ),
    );
  }

  /// Manual or bulk mark. Watched also clears the resume point; unwatched
  /// clears resume point and play history.
  Future<void> setWatched(Iterable<int> episodeIds, bool watched) async {
    final ids = episodeIds.toList();
    if (ids.isEmpty) return;
    await (update(episodes)..where((e) => e.id.isIn(ids))).write(
      EpisodesCompanion(
        watched: Value(watched),
        positionMs: const Value(0),
        lastPlayedAt: watched ? Value(DateTime.now()) : const Value(null),
      ),
    );
  }

  Future<void> setSeasonWatched(int showId, int season, bool watched) async {
    final rows = await (select(episodes)
          ..where((e) =>
              e.showId.equals(showId) &
              e.season.equals(season) &
              e.missing.equals(false)))
        .get();
    await setWatched(rows.map((e) => e.id), watched);
  }

  Future<void> setShowWatched(int showId, bool watched) async {
    final rows = await (select(episodes)
          ..where((e) => e.showId.equals(showId) & e.missing.equals(false)))
        .get();
    await setWatched(rows.map((e) => e.id), watched);
  }

  /// Shows with something to resume or a next episode, most recent first.
  Stream<List<ContinueItem>> watchContinueWatching({int limit = 20}) {
    final q = select(episodes)
      ..where((e) => e.showId.isNotNull() & e.missing.equals(false));
    return q.watch().asyncMap((rows) async {
      final byShow = <int, List<Episode>>{};
      for (final e in rows) {
        byShow.putIfAbsent(e.showId!, () => []).add(e);
      }
      final items = <ContinueItem>[];
      for (final entry in byShow.entries) {
        final target = continueTarget(entry.value.map(episodeRef));
        if (target == null) continue;
        final ep = entry.value.firstWhere((e) => e.id == target.episode.id);
        final show = await (select(shows)..where((s) => s.id.equals(entry.key)))
            .getSingleOrNull();
        if (show == null) continue;
        items.add(ContinueItem(show, ep, target.resumeMs, target.lastPlayed));
      }
      items.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      return items.take(limit).toList();
    });
  }

  Future<Episode?> getEpisode(int id) =>
      (select(episodes)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<Show?> getShow(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// All present (not missing) episodes of a show, unordered.
  Future<List<Episode>> episodesOfShow(int showId) => (select(episodes)
        ..where((e) => e.showId.equals(showId) & e.missing.equals(false)))
      .get();

  Stream<Show> watchShow(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).watchSingle();

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

class ContinueItem {
  ContinueItem(this.show, this.episode, this.resumeMs, this.lastPlayed);
  final Show show;
  final Episode episode;

  /// 0 = starts from the beginning (next episode).
  final int resumeMs;
  final DateTime lastPlayed;
}

EpRef episodeRef(Episode e) => EpRef(
      id: e.id,
      season: e.season ?? 0,
      episode: e.episode ?? 0,
      watched: e.watched,
      positionMs: e.positionMs,
      durationMs: e.durationMs,
      lastPlayedAt: e.lastPlayedAt,
    );
