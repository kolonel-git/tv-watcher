import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../tracks/track_prefs.dart';
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

  /// User cleared this episode's TMDB data; metadata fetches skip it until
  /// it is explicitly re-fetched.
  BoolColumn get metaSkip => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  // --- Watch state (Sprint 5) ---
  /// Resume point in ms. 0 = none / start over.
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
}

const settingVolume = 'player.volume';
const settingSubBottom = 'player.subBottom';
const settingSubDx = 'player.subDx';
const settingSubStyle = 'player.subStyle';

/// Small key/value store for app settings (e.g. player volume).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Audio/subtitle choice remembered per show (Sprint 8).
class TrackPrefs extends Table {
  IntColumn get showId => integer().references(Shows, #id)();

  /// auto | track
  TextColumn get audioMode => text().withDefault(const Constant('auto'))();
  TextColumn get audioLang => text().nullable()();
  TextColumn get audioTitle => text().nullable()();

  /// auto | off | track
  TextColumn get subMode => text().withDefault(const Constant('auto'))();
  TextColumn get subLang => text().nullable()();
  TextColumn get subTitle => text().nullable()();
  BoolColumn get subExternal => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {showId};
}

@DriftDatabase(
  tables: [LibraryFolders, Shows, Episodes, TrackPrefs, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tv_watcher'));

  /// For tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

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
      if (from < 6) {
        await m.createTable(appSettings);
        await m.addColumn(episodes, episodes.metaSkip);
      }
      if (from < 5) {
        await m.createTable(trackPrefs);
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
  Stream<List<LibraryFolder>> watchFolders() => select(libraryFolders).watch();

  Future<int> addFolder(String path) => into(libraryFolders).insert(
    LibraryFoldersCompanion.insert(path: path),
    mode: InsertMode.insertOrIgnore,
  );

  Future<void> removeFolder(int id) async {
    await (delete(episodes)..where((e) => e.folderId.equals(id))).go();
    await (delete(libraryFolders)..where((f) => f.id.equals(id))).go();
    await _deleteEmptyShows();
  }

  // ---- shows / episodes ----
  Future<int> upsertShow(String name, String key, int? year) async {
    final existing = await (select(
      shows,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(shows)
        .insert(ShowsCompanion.insert(name: name, key: key, year: Value(year)));
  }

  Stream<List<ShowWithCount>> watchShows() {
    final count = episodes.id.count();
    final added = episodes.addedAt.min();
    final played = episodes.lastPlayedAt.max();
    final q =
        select(shows)
            .join([innerJoin(episodes, episodes.showId.equalsExp(shows.id))])
          ..where(episodes.missing.equals(false))
          ..addColumns([count, added, played])
          ..groupBy([shows.id])
          ..orderBy([OrderingTerm.asc(shows.name)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          ShowWithCount(
            r.readTable(shows),
            r.read(count) ?? 0,
            addedAt: r.read(added),
            lastPlayedAt: r.read(played),
          ),
      ],
    );
  }

  /// Episodes of a show in order. Files that went missing are left out
  /// unless [includeMissing] (the 'Show missing files' setting).
  Stream<List<Episode>> watchEpisodesOfShow(
    int showId, {
    bool includeMissing = false,
  }) =>
      (select(episodes)
            ..where(
              (e) =>
                  e.showId.equals(showId) &
                  (includeMissing
                      ? const Constant(true)
                      : e.missing.equals(false)),
            )
            ..orderBy([
              (e) => OrderingTerm.asc(e.season),
              (e) => OrderingTerm.asc(e.episode),
            ]))
          .watch();

  Stream<List<Episode>> watchUnsorted() =>
      (select(episodes)
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
    final ep = await (select(
      episodes,
    )..where((e) => e.id.equals(episodeId))).getSingleOrNull();
    if (ep == null) return;
    final u = computeProgress(
      positionMs: positionMs,
      durationMs: durationMs,
      wasWatched: ep.watched,
      threshold: watchedFraction,
    );
    final becameWatched = u.watched && !ep.watched;
    final meaningful = u.positionMs > 0 || becameWatched;
    await (update(episodes)..where((e) => e.id.equals(episodeId))).write(
      EpisodesCompanion(
        positionMs: Value(u.positionMs),
        durationMs: durationMs > 0 ? Value(durationMs) : const Value.absent(),
        watched: Value(u.watched),
        lastPlayedAt: meaningful ? Value(DateTime.now()) : const Value.absent(),
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
    final rows =
        await (select(episodes)..where(
              (e) =>
                  e.showId.equals(showId) &
                  e.season.equals(season) &
                  e.missing.equals(false),
            ))
            .get();
    await setWatched(rows.map((e) => e.id), watched);
  }

  Future<void> setShowWatched(int showId, bool watched) async {
    final rows = await (select(
      episodes,
    )..where((e) => e.showId.equals(showId) & e.missing.equals(false))).get();
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
        final target = continueTarget(
          entry.value.map(episodeRef),
          threshold: watchedFraction,
        );
        if (target == null) continue;
        final ep = entry.value.firstWhere((e) => e.id == target.episode.id);
        final show = await (select(
          shows,
        )..where((s) => s.id.equals(entry.key))).getSingleOrNull();
        if (show == null) continue;
        items.add(ContinueItem(show, ep, target.resumeMs, target.lastPlayed));
      }
      items.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      return items.take(limit).toList();
    });
  }

  Future<Episode?> getEpisode(int id) =>
      (select(episodes)..where((e) => e.id.equals(id))).getSingleOrNull();

  // ---- bulk edits with undo ----

  Future<List<Episode>> episodesByIds(Iterable<int> ids) {
    final list = ids.toList();
    return (select(episodes)..where((e) => e.id.isIn(list))).get();
  }

  /// Puts back the user-editable state of [rows] as captured earlier
  /// (assignment, watch state, metadata). Used by Undo.
  Future<void> restoreEpisodes(List<Episode> rows) => batch((b) {
    for (final r in rows) {
      b.update(
        episodes,
        EpisodesCompanion(
          showId: Value(r.showId),
          season: Value(r.season),
          episode: Value(r.episode),
          endEpisode: Value(r.endEpisode),
          title: Value(r.title),
          manual: Value(r.manual),
          watched: Value(r.watched),
          positionMs: Value(r.positionMs),
          lastPlayedAt: Value(r.lastPlayedAt),
          tmdbTitle: Value(r.tmdbTitle),
          overview: Value(r.overview),
          runtime: Value(r.runtime),
          airDate: Value(r.airDate),
          stillFile: Value(r.stillFile),
          metaSkip: Value(r.metaSkip),
        ),
        where: (e) => e.id.equals(r.id),
      );
    }
  });

  /// Restores a show row's match/metadata (undo of Clear show metadata).
  Future<void> restoreShow(Show s) =>
      (update(shows)..where((x) => x.id.equals(s.id))).write(
        ShowsCompanion(
          tmdbId: Value(s.tmdbId),
          tmdbName: Value(s.tmdbName),
          overview: Value(s.overview),
          posterFile: Value(s.posterFile),
          backdropFile: Value(s.backdropFile),
          metaStatus: Value(s.metaStatus),
          metaLocked: Value(s.metaLocked),
        ),
      );

  /// Detaches episodes from their show so they land in Unsorted again
  /// (undo a wrong assignment). Marked manual so a rescan keeps them there.
  Future<void> unassignEpisodes(Iterable<int> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(episodes)..where((e) => e.id.isIn(list))).write(
      const EpisodesCompanion(
        showId: Value(null),
        season: Value(null),
        episode: Value(null),
        endEpisode: Value(null),
        title: Value(null),
        manual: Value(true),
        tmdbTitle: Value(null),
        overview: Value(null),
        runtime: Value(null),
        airDate: Value(null),
        stillFile: Value(null),
        metaSkip: Value(false),
      ),
    );
    await _deleteEmptyShows();
  }

  /// Ids of regular episodes that come before [e] in its show (same season
  /// earlier episodes and all earlier real seasons). Specials only count when
  /// [e] is a special.
  Future<List<int>> episodesBefore(Episode e) async {
    final showId = e.showId;
    if (showId == null) return const [];
    final rows = await (select(
      episodes,
    )..where((x) => x.showId.equals(showId) & x.missing.equals(false))).get();
    final s = e.season ?? 0, n = e.episode ?? 0;
    return [
      for (final r in rows)
        if (r.id != e.id &&
            (s == 0
                ? (r.season ?? 0) == 0 && (r.episode ?? 0) < n
                : (r.season ?? 0) > 0 &&
                      ((r.season ?? 0) < s ||
                          ((r.season ?? 0) == s && (r.episode ?? 0) < n))))
          r.id,
    ];
  }

  Future<Show?> getShow(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// All present (not missing) episodes of a show, unordered.
  Future<List<Episode>> episodesOfShow(int showId) => (select(
    episodes,
  )..where((e) => e.showId.equals(showId) & e.missing.equals(false))).get();

  // ---- settings ----

  /// Share of an episode that counts as watched. Set from the user's
  /// settings; progress saving and Continue Watching read it.
  double watchedFraction = watchedThreshold;

  /// All stored settings whose key starts with [prefix], keyed without it.
  Future<Map<String, String>> settingsWithPrefix(String prefix) async {
    final rows = await (select(
      appSettings,
    )..where((t) => t.key.like('$prefix%'))).get();
    return {for (final r in rows) r.key.substring(prefix.length): r.value};
  }

  Future<void> deleteSettingsWithPrefix(String prefix) =>
      (delete(appSettings)..where((t) => t.key.like('$prefix%'))).go();

  Future<String?> getSetting(String key) async => (await (select(
    appSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => into(
    appSettings,
  ).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  // ---- undo metadata ----

  static const _noEpisodeMeta = EpisodesCompanion(
    tmdbTitle: Value(null),
    overview: Value(null),
    runtime: Value(null),
    airDate: Value(null),
    stillFile: Value(null),
    metaSkip: Value(true),
  );

  /// Removes TMDB data from one episode (local filename title is used again)
  /// and stops metadata fetches from refilling it.
  Future<void> clearEpisodeMeta(int episodeId) => (update(
    episodes,
  )..where((e) => e.id.equals(episodeId))).write(_noEpisodeMeta);

  Future<void> clearSeasonMeta(int showId, int season) =>
      (update(episodes)
            ..where((e) => e.showId.equals(showId) & e.season.equals(season)))
          .write(_noEpisodeMeta);

  /// Lets metadata fetches fill the episode(s) again.
  Future<void> allowEpisodeMeta(int episodeId) =>
      (update(episodes)..where((e) => e.id.equals(episodeId))).write(
        const EpisodesCompanion(metaSkip: Value(false)),
      );

  Future<void> allowSeasonMeta(int showId, int season) =>
      (update(episodes)
            ..where((e) => e.showId.equals(showId) & e.season.equals(season)))
          .write(const EpisodesCompanion(metaSkip: Value(false)));

  Future<void> allowShowMeta(int showId) =>
      (update(episodes)..where((e) => e.showId.equals(showId))).write(
        const EpisodesCompanion(metaSkip: Value(false)),
      );

  /// Drops the TMDB match and all fetched data for the show and its
  /// episodes. The show is locked so it is not auto-matched again; use
  /// Re-match to pick a new one.
  Future<void> clearShowMeta(int showId) async {
    await (update(shows)..where((s) => s.id.equals(showId))).write(
      const ShowsCompanion(
        tmdbId: Value(null),
        tmdbName: Value(null),
        overview: Value(null),
        posterFile: Value(null),
        backdropFile: Value(null),
        metaStatus: Value('nomatch'),
        metaLocked: Value(true),
      ),
    );
    await (update(
      episodes,
    )..where((e) => e.showId.equals(showId))).write(_noEpisodeMeta);
  }

  // ---- per-show audio / subtitle choice ----

  Future<TrackPref?> getTrackPrefs(int showId) => (select(
    trackPrefs,
  )..where((t) => t.showId.equals(showId))).getSingleOrNull();

  Future<void> saveAudioChoice(int showId, TrackChoice c) =>
      into(trackPrefs).insert(
        TrackPrefsCompanion(
          showId: Value(showId),
          audioMode: Value(c.mode.name),
          audioLang: Value(c.language),
          audioTitle: Value(c.title),
        ),
        onConflict: DoUpdate(
          (old) => TrackPrefsCompanion(
            audioMode: Value(c.mode.name),
            audioLang: Value(c.language),
            audioTitle: Value(c.title),
          ),
        ),
      );

  Future<void> saveSubtitleChoice(int showId, TrackChoice c) =>
      into(trackPrefs).insert(
        TrackPrefsCompanion(
          showId: Value(showId),
          subMode: Value(c.mode.name),
          subLang: Value(c.language),
          subTitle: Value(c.title),
          subExternal: Value(c.external),
        ),
        onConflict: DoUpdate(
          (old) => TrackPrefsCompanion(
            subMode: Value(c.mode.name),
            subLang: Value(c.language),
            subTitle: Value(c.title),
            subExternal: Value(c.external),
          ),
        ),
      );

  Stream<Show> watchShow(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).watchSingle();

  Future<void> _deleteEmptyShows() async {
    await customStatement(
      'DELETE FROM shows WHERE id NOT IN (SELECT DISTINCT show_id FROM episodes WHERE show_id IS NOT NULL)',
    );
    await customStatement(
      'DELETE FROM track_prefs WHERE show_id NOT IN (SELECT id FROM shows)',
    );
  }

  Future<void> deleteEmptyShows() => _deleteEmptyShows();
}

class ShowWithCount {
  ShowWithCount(
    this.show,
    this.episodeCount, {
    this.addedAt,
    this.lastPlayedAt,
  });
  final Show show;
  final int episodeCount;

  /// When the show's first episode was added; for the 'Recently added' sort.
  final DateTime? addedAt;

  /// Latest play of any episode; for the 'Recently watched' sort.
  final DateTime? lastPlayedAt;
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

ChoiceMode _mode(String s) => ChoiceMode.values.firstWhere(
  (m) => m.name == s,
  orElse: () => ChoiceMode.auto,
);

extension TrackPrefChoices on TrackPref {
  TrackChoice get audioChoice => TrackChoice(
    mode: _mode(audioMode),
    language: audioLang,
    title: audioTitle,
  );

  TrackChoice get subtitleChoice => TrackChoice(
    mode: _mode(subMode),
    language: subLang,
    title: subTitle,
    external: subExternal,
  );
}
