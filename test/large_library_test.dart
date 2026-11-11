import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';

/// A big library must stay usable: the streams behind the home screen run
/// on every progress save, so they must stay fast with thousands of rows.
void main() {
  const shows = 400;
  const perShow = 25; // 10,000 episodes
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final folderId = await db.addFolder(r'C:\m');
    await db.batch((b) {
      for (var s = 0; s < shows; s++) {
        b.insert(
          db.shows,
          ShowsCompanion.insert(name: 'Show $s', key: 'show-$s'),
        );
      }
    });
    final ids = (await db.select(db.shows).get()).map((s) => s.id).toList();
    await db.batch((b) {
      for (final id in ids) {
        for (var e = 1; e <= perShow; e++) {
          b.insert(
            db.episodes,
            EpisodesCompanion.insert(
              filePath: 'C:\\m\\$id\\S01E$e.mkv',
              folderId: folderId,
              showId: Value(id),
              season: const Value(1),
              episode: Value(e),
            ),
          );
        }
      }
    });
    // Give a quarter of the shows some progress so they qualify for
    // Continue Watching.
    final eps = await db.select(db.episodes).get();
    for (var i = 0; i < eps.length; i += perShow * 4) {
      await db.saveProgress(eps[i].id, positionMs: 60000, durationMs: 1500000);
    }
  });
  tearDown(() => db.close());

  test('home shows list loads fast with 10,000 episodes', () async {
    final sw = Stopwatch()..start();
    final list = await db.watchShows().first;
    sw.stop();
    expect(list.length, shows);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });

  test('continue watching loads fast with 10,000 episodes', () async {
    final sw = Stopwatch()..start();
    final list = await db.watchContinueWatching().first;
    sw.stop();
    expect(list, isNotEmpty);
    expect(list.length, lessThanOrEqualTo(20));
    expect(sw.elapsedMilliseconds, lessThan(2500));
  });
}
