import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/library/scanner.dart';

void main() {
  late AppDatabase db;
  late LibraryFolder folder;
  const root = r'C:\media';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.addFolder(root);
    folder = (await db.select(db.libraryFolders).get()).single;
  });
  tearDown(() => db.close());

  Future<ScanResult> scan(List<String> rel) => scanFolder(
        db,
        folder,
        listFiles: (_) async => [for (final r in rel) '$root\\$r'],
      );

  test('groups files into shows and unsorted', () async {
    final r = await scan([
      r'Breaking Bad\Season 1\Episode 1.mkv',
      r'Breaking Bad\Season 1\Episode 2.mkv',
      r'The.Office.US.S01E01.mkv',
      r'holiday.mp4',
    ]);
    expect(r.added, 4);
    expect(r.unsorted, 1);
    final shows = await db.watchShows().first;
    expect(shows.map((s) => s.show.name).toList(),
        ['Breaking Bad', 'The Office US']);
    expect(shows.first.episodeCount, 2);
  });

  test('rescan is idempotent', () async {
    final files = [r'Show S01E01.mkv', r'Show S01E02.mkv'];
    await scan(files);
    final r2 = await scan(files);
    expect(r2.added, 0);
    expect(r2.missing, 0);
    expect((await db.select(db.episodes).get()).length, 2);
  });

  test('rescan picks up new files', () async {
    await scan([r'Show S01E01.mkv']);
    final r = await scan([r'Show S01E01.mkv', r'Show S01E02.mkv']);
    expect(r.added, 1);
  });

  test('vanished file marked missing, row kept, returns if back', () async {
    await scan([r'Show S01E01.mkv', r'Show S01E02.mkv']);
    final r = await scan([r'Show S01E01.mkv']);
    expect(r.missing, 1);
    expect((await db.select(db.episodes).get()).length, 2);
    expect((await db.watchShows().first).single.episodeCount, 1);

    await scan([r'Show S01E01.mkv', r'Show S01E02.mkv']);
    expect((await db.watchShows().first).single.episodeCount, 2);
  });

  test('manual assignment survives rescan', () async {
    await scan([r'holiday.mp4']);
    final ep = (await db.select(db.episodes).get()).single;
    expect(ep.showId, isNull);
    await db.assignEpisode(ep.id,
        showName: 'Holiday Show', showKey: 'holidayshow', season: 1, episode: 4);

    await scan([r'holiday.mp4']);
    final after = (await db.select(db.episodes).get()).single;
    expect(after.showId, isNotNull);
    expect(after.season, 1);
    expect(after.episode, 4);
    expect(after.manual, isTrue);
  });

  test('unsorted stream excludes assigned', () async {
    await scan([r'a.mkv', r'b.mkv']);
    expect((await db.watchUnsorted().first).length, 2);
    final first = (await db.watchUnsorted().first).first;
    await db.assignEpisode(first.id,
        showName: 'X', showKey: 'x', season: 1, episode: 1);
    expect((await db.watchUnsorted().first).length, 1);
  });

  test('removing folder deletes its rows and empty shows', () async {
    await scan([r'Show S01E01.mkv']);
    await db.removeFolder(folder.id);
    expect(await db.select(db.episodes).get(), isEmpty);
    expect(await db.select(db.shows).get(), isEmpty);
  });
}
