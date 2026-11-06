import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';

void main() {
  late AppDatabase db;
  late int showId;
  late List<int> ids; // S1E1, S1E2, S1E3, S2E1

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final folderId = await db.addFolder(r'C:\m');
    showId = await db.upsertShow('Show', 'show', null);
    ids = [];
    for (final (s, e) in [(1, 1), (1, 2), (1, 3), (2, 1)]) {
      ids.add(await db.into(db.episodes).insert(EpisodesCompanion.insert(
            filePath: r'C:\m\S' '${s}E$e.mkv',
            folderId: folderId,
            showId: Value(showId),
            season: Value(s),
            episode: Value(e),
          )));
    }
  });
  tearDown(() => db.close());

  Future<Episode> ep(int id) =>
      (db.select(db.episodes)..where((e) => e.id.equals(id))).getSingle();

  test('saveProgress stores exact position and duration', () async {
    await db.saveProgress(ids[0], positionMs: 123456, durationMs: 1000000);
    final e = await ep(ids[0]);
    expect(e.positionMs, 123456);
    expect(e.durationMs, 1000000);
    expect(e.watched, isFalse);
    expect(e.lastPlayedAt, isNotNull);
  });

  test('crossing 90% marks watched and clears the resume point', () async {
    await db.saveProgress(ids[0], positionMs: 500000, durationMs: 1000000);
    await db.saveProgress(ids[0], positionMs: 950000, durationMs: 1000000);
    final e = await ep(ids[0]);
    expect(e.watched, isTrue);
    expect(e.positionMs, 0);
  });

  test('opening and closing within 5s does not touch history', () async {
    await db.saveProgress(ids[1], positionMs: 2000, durationMs: 1000000);
    final e = await ep(ids[1]);
    expect(e.positionMs, 0);
    expect(e.lastPlayedAt, isNull);
    expect(e.durationMs, 1000000);
  });

  test('setWatched on a season and back', () async {
    await db.setSeasonWatched(showId, 1, true);
    expect((await ep(ids[0])).watched, isTrue);
    expect((await ep(ids[2])).watched, isTrue);
    expect((await ep(ids[3])).watched, isFalse);

    await db.setSeasonWatched(showId, 1, false);
    final e = await ep(ids[0]);
    expect(e.watched, isFalse);
    expect(e.lastPlayedAt, isNull);
  });

  test('mark show watched clears resume points', () async {
    await db.saveProgress(ids[1], positionMs: 400000, durationMs: 1000000);
    await db.setShowWatched(showId, true);
    final e = await ep(ids[1]);
    expect(e.watched, isTrue);
    expect(e.positionMs, 0);
  });

  test('rescan-style updates do not erase watch state', () async {
    await db.saveProgress(ids[0], positionMs: 400000, durationMs: 1000000);
    await (db.update(db.episodes)..where((e) => e.id.equals(ids[0])))
        .write(const EpisodesCompanion(title: Value('New title')));
    expect((await ep(ids[0])).positionMs, 400000);
  });

  group('continue watching stream', () {
    test('empty before anything is played', () async {
      expect(await db.watchContinueWatching().first, isEmpty);
    });

    test('resumes in-progress episode at exact position', () async {
      await db.saveProgress(ids[1], positionMs: 321000, durationMs: 1000000);
      final items = await db.watchContinueWatching().first;
      expect(items.single.episode.id, ids[1]);
      expect(items.single.resumeMs, 321000);
    });

    test('after finishing an episode, offers the next one from the start',
        () async {
      await db.saveProgress(ids[0], positionMs: 990000, durationMs: 1000000);
      final items = await db.watchContinueWatching().first;
      expect(items.single.episode.id, ids[1]);
      expect(items.single.resumeMs, 0);
    });

    test('season rollover and finished show disappears', () async {
      await db.setSeasonWatched(showId, 1, true);
      var items = await db.watchContinueWatching().first;
      expect(items.single.episode.id, ids[3]);

      await db.setShowWatched(showId, true);
      items = await db.watchContinueWatching().first;
      expect(items, isEmpty);
    });

    test('mark unwatched removes the show from the row', () async {
      await db.saveProgress(ids[1], positionMs: 321000, durationMs: 1000000);
      await db.setShowWatched(showId, false);
      expect(await db.watchContinueWatching().first, isEmpty);
    });

    test('most recently watched show first', () async {
      final other = await db.upsertShow('Other', 'other', null);
      final folder = (await db.select(db.libraryFolders).get()).single.id;
      final oid = await db.into(db.episodes).insert(EpisodesCompanion.insert(
            filePath: r'C:\m\other.mkv',
            folderId: folder,
            showId: Value(other),
            season: const Value(1),
            episode: const Value(1),
          ));
      await db.saveProgress(ids[1], positionMs: 100000, durationMs: 1000000);
      await db.saveProgress(oid, positionMs: 100000, durationMs: 1000000);
      // Drift stores whole seconds; make the order explicit.
      await (db.update(db.episodes)..where((e) => e.id.equals(ids[1])))
          .write(EpisodesCompanion(
              lastPlayedAt: Value(DateTime.now().subtract(const Duration(minutes: 5)))));
      final items = await db.watchContinueWatching().first;
      expect(items.map((i) => i.show.name), ['Other', 'Show']);
    });
  });
}
