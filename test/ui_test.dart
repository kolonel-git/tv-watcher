import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/ui/continue_row.dart';
import 'package:tv_watcher/ui/home_page.dart';
import 'package:tv_watcher/ui/manage_pages.dart';
import 'package:tv_watcher/ui/poster_card.dart';
import 'package:tv_watcher/ui/show_page.dart';

/// Real I/O (sqlite) needs runAsync; avoid pumpAndSettle (spinners animate).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;
  late int folderId;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    folderId = await db.addFolder(r'C:\media');
  });
  tearDown(() => db.close());

  Future<int> addShow(String name, Map<int, List<String?>> seasons,
      {String status = 'matched'}) async {
    final id = await db.upsertShow(name, name.toLowerCase(), null);
    await (db.update(db.shows)..where((s) => s.id.equals(id)))
        .write(ShowsCompanion(metaStatus: Value(status)));
    for (final entry in seasons.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        await db.into(db.episodes).insert(EpisodesCompanion.insert(
              filePath: '$name-${entry.key}-$i.mkv',
              folderId: folderId,
              showId: Value(id),
              season: Value(entry.key),
              episode: Value(i + 1),
              tmdbTitle: Value(entry.value[i]),
            ));
      }
    }
    return id;
  }

  void bigScreen(WidgetTester t) {
    t.view.physicalSize = const Size(1400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: home);

  testWidgets('home shows empty state with no shows', (t) async {
    await t.pumpWidget(app(HomePage(db: db)));
    await settle(t);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('home shows a poster card per show and opens the show page',
      (t) async {
    bigScreen(t);
    await addShow('Alpha', {
      1: ['Pilot', 'Second']
    });
    await addShow('Beta', {
      1: ['One']
    }, status: 'ambiguous');
    await t.pumpWidget(app(HomePage(db: db)));
    await settle(t);

    expect(find.byType(PosterCard), findsNWidgets(2));
    expect(find.text('Alpha'), findsWidgets); // title (+ placeholder label)
    expect(find.text('Needs match'), findsOneWidget);

    await t.tap(find.text('Alpha').first);
    await settle(t);
    expect(find.text('Pilot'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('show page: season selector switches episode list', (t) async {
    bigScreen(t);
    final id = await addShow('Gamma', {
      1: ['S1 Ep1'],
      2: ['S2 Ep1', 'S2 Ep2'],
    });
    await t.pumpWidget(app(ShowPage(db: db, meta: null, showId: id)));
    await settle(t);

    expect(find.text('S1 Ep1'), findsOneWidget);
    expect(find.text('S2 Ep1'), findsNothing);
    expect(find.text('Play S1E1'), findsOneWidget);

    await t.tap(find.text('Season 1'));
    await settle(t);
    await t.tap(find.text('Season 2').last);
    await settle(t);

    expect(find.text('S2 Ep1'), findsOneWidget);
    expect(find.text('S2 Ep2'), findsOneWidget);
    expect(find.text('S1 Ep1'), findsNothing);
    expect(find.text('Play S2E1'), findsOneWidget);
  });

  testWidgets('show page defaults to first real season, not specials',
      (t) async {
    final id = await addShow('Delta', {
      0: ['Special'],
      1: ['Real'],
    });
    await t.pumpWidget(app(ShowPage(db: db, meta: null, showId: id)));
    await settle(t);
    expect(find.text('Real'), findsOneWidget);
    expect(find.text('Special'), findsNothing);
  });

  testWidgets('unsorted: groups similar files and assigns a group at once',
      (t) async {
    bigScreen(t);
    for (var n = 1; n <= 3; n++) {
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
          filePath: r'C:\media\[G] My Anime - Arc A - 0' '$n [480p].mkv',
          folderId: folderId));
    }
    await db.into(db.episodes).insert(EpisodesCompanion.insert(
        filePath: r'C:\media\random.mkv', folderId: folderId));

    await t.pumpWidget(app(UnsortedPage(db: db)));
    await settle(t);

    expect(find.text('My Anime - Arc A'), findsOneWidget);
    expect(find.textContaining('3 files'), findsOneWidget);
    expect(find.text('Single files'), findsOneWidget);

    await t.tap(find.text('Assign group'));
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'My Anime');
    await t.enterText(find.byType(TextField).last, '2');
    await settle(t);
    await t.tap(find.text('Assign all'));
    await settle(t);

    final rows = (await t.runAsync(() => (db.select(db.episodes)
              ..where((e) => e.showId.isNotNull()))
            .get()))!;
    expect(rows.length, 3);
    expect(rows.every((e) => e.season == 2), isTrue);
    expect(rows.map((e) => e.episode).toSet(), {1, 2, 3});
  });

  testWidgets('home: continue watching row resumes at saved position',
      (t) async {
    bigScreen(t);
    final id = await addShow('Epsilon', {
      1: ['Pilot', 'Second']
    });
    final eps = (await t.runAsync(() => db.watchEpisodesOfShow(id).first))!;
    await db.saveProgress(eps[1].id, positionMs: 754000, durationMs: 1500000);

    await t.pumpWidget(app(HomePage(db: db)));
    await settle(t);

    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.byType(ContinueCard), findsOneWidget);
    expect(find.text('Resume at 12:34'), findsOneWidget);
    expect(find.textContaining('S1E2'), findsOneWidget);
  });

  testWidgets('home: no continue row before anything is played', (t) async {
    bigScreen(t);
    await addShow('Zeta', {
      1: ['One']
    });
    await t.pumpWidget(app(HomePage(db: db)));
    await settle(t);
    expect(find.text('Continue watching'), findsNothing);
  });

  testWidgets('show page: resume button, progress bar, watched check',
      (t) async {
    bigScreen(t);
    final id = await addShow('Eta', {
      1: ['One', 'Two', 'Three']
    });
    final eps = (await t.runAsync(() => db.watchEpisodesOfShow(id).first))!;
    await db.saveProgress(eps[0].id, positionMs: 990000, durationMs: 1000000);
    await db.saveProgress(eps[1].id, positionMs: 400000, durationMs: 1000000);

    await t.pumpWidget(app(ShowPage(db: db, meta: null, showId: id)));
    await settle(t);

    expect(find.text('Resume S1E2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('show page: mark season watched via menu', (t) async {
    bigScreen(t);
    final id = await addShow('Theta', {
      1: ['One', 'Two']
    });
    await t.pumpWidget(app(ShowPage(db: db, meta: null, showId: id)));
    await settle(t);

    await t.tap(find.byTooltip('Season actions'));
    await settle(t);
    await t.tap(find.text('Mark season watched'));
    await settle(t);

    final rows = (await t.runAsync(() => db.watchEpisodesOfShow(id).first))!;
    expect(rows.every((e) => e.watched), isTrue);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
  });

  testWidgets('show page: toggle one episode watched via its menu', (t) async {
    bigScreen(t);
    final id = await addShow('Iota', {
      1: ['One', 'Two']
    });
    await t.pumpWidget(app(ShowPage(db: db, meta: null, showId: id)));
    await settle(t);

    await t.tap(find.byTooltip('Episode actions').first);
    await settle(t);
    await t.tap(find.text('Mark watched'));
    await settle(t);

    final rows = (await t.runAsync(() => db.watchEpisodesOfShow(id).first))!;
    expect(rows.where((e) => e.watched).length, 1);
  });

  test('defaultSeason picks first non-zero season', () {
    expect(defaultSeason([0, 1, 2]), 1);
    expect(defaultSeason([0]), 0);
    expect(defaultSeason([2, 3]), 2);
  });
}
