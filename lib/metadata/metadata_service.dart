import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../library/filename_parser.dart';
import 'tmdb_client.dart';

typedef ImageDownloader = Future<List<int>?> Function(String url);

Future<List<int>?> defaultImageDownloader(String url) async {
  final res = await http.get(Uri.parse(url));
  return res.statusCode == 200 ? res.bodyBytes : null;
}

class SyncSummary {
  const SyncSummary({
    required this.matched,
    required this.ambiguous,
    required this.noMatch,
    required this.failed,
    this.offline = false,
  });
  final int matched;
  final int ambiguous;
  final int noMatch;
  final int failed;

  /// Network unreachable: remaining shows left untouched for next time.
  final bool offline;
}

/// Matches library shows to TMDB, stores metadata in the DB and caches
/// artwork on disk so the library works offline afterwards.
class MetadataService {
  MetadataService({
    required this.db,
    required this.client,
    required this.artworkDir,
    ImageDownloader? download,
    this.requestDelay = const Duration(milliseconds: 100),
  }) : _download = download ?? defaultImageDownloader;

  final AppDatabase db;
  final TmdbClient client;
  final Directory artworkDir;
  final Duration requestDelay;
  final ImageDownloader _download;

  static const _imgBase = 'https://image.tmdb.org/t/p';
  static const _fallbackLang = 'en-US';

  bool get _needsFallback => !client.language.toLowerCase().startsWith('en');

  Future<void> _pause() =>
      requestDelay == Duration.zero ? Future.value() : Future.delayed(requestDelay);

  /// Processes every show not yet matched. Safe to call repeatedly.
  Future<SyncSummary> syncAll() async {
    final pending = await (db.select(db.shows)
          ..where((s) => s.metaStatus.equals('none')))
        .get();
    var matched = 0, ambiguous = 0, noMatch = 0, failed = 0;
    for (final show in pending) {
      try {
        final status = await syncShow(show.id);
        switch (status) {
          case 'matched':
            matched++;
          case 'ambiguous':
            ambiguous++;
          case 'nomatch':
            noMatch++;
        }
      } on SocketException {
        return SyncSummary(
            matched: matched,
            ambiguous: ambiguous,
            noMatch: noMatch,
            failed: failed,
            offline: true);
      } on http.ClientException {
        return SyncSummary(
            matched: matched,
            ambiguous: ambiguous,
            noMatch: noMatch,
            failed: failed,
            offline: true);
      } on TmdbException {
        failed++;
      }
    }
    return SyncSummary(
        matched: matched,
        ambiguous: ambiguous,
        noMatch: noMatch,
        failed: failed);
  }

  /// Auto-match (if needed) and fetch details. Returns the resulting
  /// metaStatus. Network errors propagate and leave the show unchanged.
  Future<String> syncShow(int showId) async {
    var show = await _show(showId);
    if (show.tmdbId == null) {
      final status = await _autoMatch(show);
      if (status != 'matched') {
        await _setStatus(showId, status);
        return status;
      }
      show = await _show(showId);
    }
    await _fetchAll(show);
    return 'matched';
  }

  /// User chose a match from candidates. Locks it against auto-rematching.
  Future<void> pickMatch(int showId, int tmdbId) async {
    await (db.update(db.shows)..where((s) => s.id.equals(showId))).write(
      ShowsCompanion(
        tmdbId: Value(tmdbId),
        metaLocked: const Value(true),
        metaStatus: const Value('matched'),
      ),
    );
    await _fetchAll(await _show(showId));
  }

  /// Re-download metadata for an already matched show.
  Future<void> refresh(int showId) async {
    final show = await _show(showId);
    if (show.tmdbId == null) {
      await syncShow(showId);
    } else {
      await _fetchAll(show);
    }
  }

  Future<List<TmdbSearchResult>> candidates(String query, {int? year}) =>
      client.searchShow(query, year: year);

  // ---------------------------------------------------------------------

  Future<Show> _show(int id) =>
      (db.select(db.shows)..where((s) => s.id.equals(id))).getSingle();

  Future<void> _setStatus(int id, String status) =>
      (db.update(db.shows)..where((s) => s.id.equals(id)))
          .write(ShowsCompanion(metaStatus: Value(status)));

  Future<String> _autoMatch(Show show) async {
    var results = await client.searchShow(show.name, year: show.year);
    if (results.isEmpty && show.year != null) {
      await _pause();
      results = await client.searchShow(show.name);
    }
    await _pause();
    if (results.isEmpty) return 'nomatch';

    final exact = results
        .where((r) => ParsedEpisode.showKeyFor(r.name) == show.key)
        .toList();
    final TmdbSearchResult? pick = exact.isNotEmpty
        ? exact.first
        : (results.length == 1 ? results.first : null);
    if (pick == null) return 'ambiguous';

    await (db.update(db.shows)..where((s) => s.id.equals(show.id)))
        .write(ShowsCompanion(tmdbId: Value(pick.id)));
    return 'matched';
  }

  Future<void> _fetchAll(Show show) async {
    final id = show.tmdbId!;
    var d = await client.showDetails(id);
    await _pause();
    if (_needsFallback && (d.overview == null || d.name.isEmpty)) {
      final en = await client.showDetails(id, lang: _fallbackLang);
      d = TmdbShow(
        id: d.id,
        name: d.name.isEmpty ? en.name : d.name,
        overview: d.overview ?? en.overview,
        posterPath: d.posterPath ?? en.posterPath,
        backdropPath: d.backdropPath ?? en.backdropPath,
      );
      await _pause();
    }
    final poster = await _cache(d.posterPath, 'w342', 'poster_$id');
    final backdrop = await _cache(d.backdropPath, 'w1280', 'backdrop_$id');
    await (db.update(db.shows)..where((s) => s.id.equals(show.id))).write(
      ShowsCompanion(
        tmdbName: Value(d.name),
        overview: Value(d.overview),
        posterFile: Value(poster ?? show.posterFile),
        backdropFile: Value(backdrop ?? show.backdropFile),
        metaStatus: const Value('matched'),
      ),
    );

    final local = await (db.select(db.episodes)
          ..where((e) => e.showId.equals(show.id) & e.season.isNotNull()))
        .get();
    final seasons = {for (final e in local) e.season!};
    for (final season in seasons) {
      var eps = await client.seasonEpisodes(id, season).catchError(
            (Object e) => e is TmdbException && e.statusCode == 404
                ? <TmdbEpisode>[]
                : throw e,
          );
      await _pause();
      if (_needsFallback &&
          eps.any((e) => e.name == null || e.overview == null)) {
        final en = {
          for (final e in await client.seasonEpisodes(id, season,
              lang: _fallbackLang))
            e.number: e
        };
        eps = [
          for (final e in eps)
            TmdbEpisode(
              number: e.number,
              name: e.name ?? en[e.number]?.name,
              overview: e.overview ?? en[e.number]?.overview,
              runtime: e.runtime ?? en[e.number]?.runtime,
              stillPath: e.stillPath ?? en[e.number]?.stillPath,
              airDate: e.airDate ?? en[e.number]?.airDate,
            ),
        ];
        await _pause();
      }
      final byNumber = {for (final e in eps) e.number: e};
      for (final row in local.where((e) => e.season == season)) {
        final t = byNumber[row.episode];
        if (t == null) continue;
        final still = await _cache(
            t.stillPath, 'w300', 'still_${id}_${season}_${t.number}');
        await (db.update(db.episodes)..where((e) => e.id.equals(row.id))).write(
          EpisodesCompanion(
            tmdbTitle: Value(t.name),
            overview: Value(t.overview),
            runtime: Value(t.runtime),
            airDate: Value(t.airDate),
            stillFile: Value(still ?? row.stillFile),
          ),
        );
      }
    }
  }

  /// Downloads `<size><tmdbPath>` to the artwork dir unless already cached.
  /// Returns local path, or null if there is no image / download failed.
  Future<String?> _cache(String? tmdbPath, String size, String name) async {
    if (tmdbPath == null) return null;
    final ext = p.extension(tmdbPath).isEmpty ? '.jpg' : p.extension(tmdbPath);
    final file = File(p.join(artworkDir.path, '$name$ext'));
    if (await file.exists()) return file.path;
    try {
      final bytes = await _download('$_imgBase/$size$tmdbPath');
      if (bytes == null) return null;
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return file.path;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
  }
}
