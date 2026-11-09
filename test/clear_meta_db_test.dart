import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';

void main() {
  late AppDatabase db;
  late int showId;
  late int ep1, ep2, ep3;

  Future<int> addEp(String path, int season, int episode) async {
    await db
        .into(db.episodes)
        .insert(
          EpisodesCompanion.insert(
            filePath: path,
            folderId: 1,
            showId: Value(showId),
            season: Value(season),
            episode: Value(episode),
            title: const Value('local'),
            tmdbTitle: const Value('TMDB title'),
            overview: const Value('desc'),
            runtime: const Value(42),
            airDate: const Value('2020-01-01'),
            stillFile: const Value('still.jpg'),
          ),
        );
    return (await (db.select(
      db.episodes,
    )..where((e) => e.filePath.equals(path))).getSingle()).id;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.addFolder('C:/tv');
    showId = await db.upsertShow('Show', 'show', null);
    await (db.update(db.shows)..where((s) => s.id.equals(showId))).write(
      const ShowsCompanion(
        tmdbId: Value(1),
        tmdbName: Value('Show TMDB'),
        overview: Value('o'),
        posterFile: Value('p.jpg'),
        backdropFile: Value('b.jpg'),
        metaStatus: Value('matched'),
      ),
    );
    ep1 = await addEp('a1', 1, 1);
    ep2 = await addEp('a2', 1, 2);
    ep3 = await addEp('b1', 2, 1);
  });
  tearDown(() => db.close());

  Future<Episode> ep(int id) => db.getEpisode(id).then((e) => e!);

  test('settings round trip and overwrite', () async {
    expect(await db.getSetting(settingVolume), isNull);
    await db.setSetting(settingVolume, '70.0');
    await db.setSetting(settingVolume, '55.0');
    expect(await db.getSetting(settingVolume), '55.0');
  });

  test('clear one episode keeps local title, others untouched', () async {
    await db.clearEpisodeMeta(ep1);
    final a = await ep(ep1);
    expect(a.tmdbTitle, isNull);
    expect(a.overview, isNull);
    expect(a.runtime, isNull);
    expect(a.stillFile, isNull);
    expect(a.title, 'local');
    expect(a.metaSkip, isTrue);
    expect((await ep(ep2)).tmdbTitle, 'TMDB title');
  });

  test('clear season only affects that season', () async {
    await db.clearSeasonMeta(showId, 1);
    expect((await ep(ep1)).tmdbTitle, isNull);
    expect((await ep(ep2)).tmdbTitle, isNull);
    expect((await ep(ep3)).tmdbTitle, 'TMDB title');
  });

  test('allow lifts the skip flag', () async {
    await db.clearSeasonMeta(showId, 1);
    await db.allowEpisodeMeta(ep1);
    expect((await ep(ep1)).metaSkip, isFalse);
    expect((await ep(ep2)).metaSkip, isTrue);
    await db.allowSeasonMeta(showId, 1);
    expect((await ep(ep2)).metaSkip, isFalse);
  });

  test(
    'clear show drops match, locks it, clears episodes, keeps progress',
    () async {
      await db.saveProgress(ep1, positionMs: 60000, durationMs: 1200000);
      await db.clearShowMeta(showId);
      final s = (await db.getShow(showId))!;
      expect(s.tmdbId, isNull);
      expect(s.tmdbName, isNull);
      expect(s.posterFile, isNull);
      expect(s.metaStatus, 'nomatch');
      expect(s.metaLocked, isTrue);
      final a = await ep(ep1);
      expect(a.tmdbTitle, isNull);
      expect(a.positionMs, 60000);
      await db.allowShowMeta(showId);
      expect((await ep(ep3)).metaSkip, isFalse);
    },
  );

  test('restoreEpisodes undoes a clear', () async {
    final before = await db.episodesByIds([ep1, ep2]);
    await db.clearEpisodeMeta(ep1);
    await db.setWatched([ep1, ep2], true);
    await db.restoreEpisodes(before);
    final a = await ep(ep1);
    expect(a.tmdbTitle, 'TMDB title');
    expect(a.metaSkip, isFalse);
    expect(a.watched, isFalse);
    expect((await ep(ep2)).watched, isFalse);
  });

  test('restoreShow undoes clearShowMeta', () async {
    final show = (await db.getShow(showId))!;
    await db.clearShowMeta(showId);
    await db.restoreShow(show);
    final s = (await db.getShow(showId))!;
    expect(s.tmdbId, 1);
    expect(s.tmdbName, 'Show TMDB');
    expect(s.metaStatus, 'matched');
  });

  test('unassign sends episodes to Unsorted and drops empty show', () async {
    await db.unassignEpisodes([ep1, ep2, ep3]);
    final a = await ep(ep1);
    expect(a.showId, isNull);
    expect(a.season, isNull);
    expect(a.manual, isTrue);
    expect(a.tmdbTitle, isNull);
    expect(await db.getShow(showId), isNull);
    final unsorted = await db.watchUnsorted().first;
    expect(unsorted.map((e) => e.id).toSet(), {ep1, ep2, ep3});
  });

  test('undo of unassign puts the episode back in its show', () async {
    final before = await db.episodesByIds([ep1]);
    await db.unassignEpisodes([ep1]);
    await db.restoreEpisodes(before);
    final a = await ep(ep1);
    expect(a.showId, showId);
    expect(a.season, 1);
    expect(a.episode, 1);
  });

  test('episodesBefore: earlier episodes and seasons, not specials', () async {
    final sp = await addEp('sp', 0, 1);
    final s2e2 = await addEp('b2', 2, 2);
    expect(await db.episodesBefore((await ep(ep2))), [ep1]);
    final before = await db.episodesBefore(await ep(s2e2));
    expect(before.toSet(), {ep1, ep2, ep3});
    expect(before.contains(sp), isFalse);
    expect(await db.episodesBefore(await ep(ep1)), isEmpty);
  });
}
