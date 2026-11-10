import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/player/control_bar.dart';
import 'package:tv_watcher/player/player_config.dart';
import 'package:tv_watcher/settings/settings_controller.dart';
import 'package:tv_watcher/settings/user_settings.dart';
import 'package:tv_watcher/ui/home_page.dart';
import 'package:tv_watcher/ui/play.dart';
import 'package:tv_watcher/ui/settings_page.dart';
import 'package:tv_watcher/ui/show_page.dart';
import 'package:tv_watcher/watch/watch_logic.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('UserSettings', () {
    test('defaults match the behaviour before settings existed', () {
      const s = UserSettings.defaults;
      expect(s.autoplay, isTrue);
      expect(s.autoplayLeadSeconds, 30);
      expect(s.autoplayCountdownSeconds, 10);
      expect(s.skipStepSeconds, 10);
      expect(s.controlsHideSeconds, 3);
      expect(s.watchedFraction, 0.9);
      expect(s.resume, ResumeBehavior.always);
      expect(s.volumeMode, VolumeMode.remember);
      expect(s.showSpecials, isTrue);
      expect(s.showMissing, isFalse);
    });

    test('round-trips through the string map', () {
      const s = UserSettings(
        autoplay: false,
        autoplayLeadSeconds: 45,
        skipStepSeconds: 30,
        watchedPercent: 85,
        resume: ResumeBehavior.ask,
        volumeMode: VolumeMode.fixed,
        fixedVolume: 40,
        metadataLanguage: 'fr-FR',
        homeSort: ShowSort.recentlyWatched,
        posterSize: PosterSize.large,
        showSpecials: false,
        showMissing: true,
      );
      expect(UserSettings.fromMap(s.toMap()), s);
    });

    test('bad, missing and out-of-range stored values fall back', () {
      final s = UserSettings.fromMap({
        'autoplayLead': '9999',
        'skipStep': '7',
        'watchedPercent': 'abc',
        'resume': 'nope',
        'metadataLanguage': 'xx-YY',
        'homeSort': '',
        'showSpecials': 'maybe',
      });
      expect(s, UserSettings.defaults);
    });

    test('copyWith can clear the language back to the .env default', () {
      final s = const UserSettings(metadataLanguage: 'de-DE')
          .copyWith(clearMetadataLanguage: true);
      expect(s.metadataLanguage, isNull);
    });
  });

  group('SettingsController', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('loads defaults, saves only what changed, reloads', () async {
      final c = await SettingsController.load(db);
      expect(c.value, UserSettings.defaults);
      await c.update(c.value.copyWith(skipStepSeconds: 30, autoplay: false));
      final stored = await db.settingsWithPrefix(SettingsController.keyPrefix);
      expect(stored, {'skipStep': '30', 'autoplay': 'false'});

      final again = await SettingsController.load(db);
      expect(again.value.skipStepSeconds, 30);
      expect(again.value.autoplay, isFalse);
    });

    test('notifies listeners and ignores identical updates', () async {
      final c = await SettingsController.load(db);
      var n = 0;
      c.addListener(() => n++);
      await c.update(c.value);
      expect(n, 0);
      await c.update(c.value.copyWith(posterSize: PosterSize.small));
      expect(n, 1);
    });

    test('watched threshold reaches the database', () async {
      final c = await SettingsController.load(db);
      expect(db.watchedFraction, 0.9);
      await c.update(c.value.copyWith(watchedPercent: 75));
      expect(db.watchedFraction, 0.75);
    });

    test('reset restores defaults and deletes stored values', () async {
      final c = await SettingsController.load(db);
      await c.update(c.value.copyWith(watchedPercent: 80, showMissing: true));
      await c.reset();
      expect(c.value, UserSettings.defaults);
      expect(db.watchedFraction, 0.9);
      expect(
        await db.settingsWithPrefix(SettingsController.keyPrefix),
        isEmpty,
      );
    });

    test('does not touch other settings keys on reset', () async {
      await db.setSetting(settingVolume, '55');
      final c = await SettingsController.load(db);
      await c.update(c.value.copyWith(autoplay: false));
      await c.reset();
      expect(await db.getSetting(settingVolume), '55');
    });
  });

  group('watch logic with a custom threshold', () {
    test('computeProgress marks watched at the chosen share', () {
      final at80 = computeProgress(
        positionMs: 800,
        durationMs: 1000,
        wasWatched: false,
        threshold: 0.8,
      );
      expect(at80.watched, isTrue);
      final at90 = computeProgress(
        positionMs: 800,
        durationMs: 1000,
        wasWatched: false,
      );
      expect(at90.watched, isFalse);
    });

    test('resumePositionMs honours the threshold', () {
      expect(resumePositionMs(850000, 1000000, threshold: 0.8), 0);
      expect(resumePositionMs(850000, 1000000), 850000);
    });
  });

  group('database support', () {
    late AppDatabase db;
    late int folderId;
    setUp(() async {
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      folderId = await db.addFolder(r'C:\m');
    });
    tearDown(() => db.close());

    Future<int> ep(int show, int season, int n, {bool missing = false}) => db
        .into(db.episodes)
        .insert(
          EpisodesCompanion.insert(
            filePath: 'f-$show-$season-$n.mkv',
            folderId: folderId,
            showId: Value(show),
            season: Value(season),
            episode: Value(n),
            missing: Value(missing),
          ),
        );

    test('saveProgress uses the configured watched fraction', () async {
      final show = await db.upsertShow('A', 'a', null);
      final id = await ep(show, 1, 1);
      db.watchedFraction = 0.75;
      await db.saveProgress(id, positionMs: 800, durationMs: 1000);
      final e = await db.getEpisode(id);
      expect(e!.watched, isTrue);
    });

    test('missing episodes are listed only when asked', () async {
      final show = await db.upsertShow('A', 'a', null);
      await ep(show, 1, 1);
      await ep(show, 1, 2, missing: true);
      expect((await db.watchEpisodesOfShow(show).first).length, 1);
      expect(
        (await db.watchEpisodesOfShow(show, includeMissing: true).first).length,
        2,
      );
    });

    test('watchShows reports added and last played dates', () async {
      final show = await db.upsertShow('A', 'a', null);
      final id = await ep(show, 1, 1);
      var shows = await db.watchShows().first;
      expect(shows.single.addedAt, isNotNull);
      expect(shows.single.lastPlayedAt, isNull);
      await db.saveProgress(id, positionMs: 60000, durationMs: 1000000);
      shows = await db.watchShows().first;
      expect(shows.single.lastPlayedAt, isNotNull);
    });
  });

  group('home sorts', () {
    ShowWithCount sw(
      String name, {
      DateTime? added,
      DateTime? played,
      int n = 1,
    }) => ShowWithCount(
      Show(
        id: name.hashCode,
        name: name,
        key: name,
        metaStatus: 'none',
        metaLocked: false,
      ),
      n,
      addedAt: added,
      lastPlayedAt: played,
    );

    test('recently added: newest first, undated last', () {
      final out = filterAndSortShows(
        [
          sw('B', added: DateTime(2026, 1, 1)),
          sw('A'),
          sw('C', added: DateTime(2026, 6, 1)),
        ],
        '',
        ShowSort.recentlyAdded,
      );
      expect([for (final s in out) s.show.name], ['C', 'B', 'A']);
    });

    test('recently watched: never-watched shows go last, by name', () {
      final out = filterAndSortShows(
        [sw('Z'), sw('A'), sw('M', played: DateTime(2026, 3, 3))],
        '',
        ShowSort.recentlyWatched,
      );
      expect([for (final s in out) s.show.name], ['M', 'A', 'Z']);
    });
  });

  group('player', () {
    test('PlayerConfig follows skip step and hide delay', () {
      final c = PlayerConfig.fromSettings(
        const UserSettings(skipStepSeconds: 30, controlsHideSeconds: 7),
      );
      expect(c.seekStep, const Duration(seconds: 30));
      expect(c.controlsHideDelay, const Duration(seconds: 7));
    });

    testWidgets('SeekIcon shows the real step', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              SeekIcon(seconds: 30, forward: false),
              SeekIcon(seconds: 15, forward: true),
            ],
          ),
        ),
      );
      expect(find.text('30'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });
  });

  group('screens', () {
    late AppDatabase db;
    late int folderId;
    setUp(() async {
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      folderId = await db.addFolder(r'C:\media');
    });
    tearDown(() => db.close());

    void bigScreen(WidgetTester t) {
      t.view.physicalSize = const Size(1400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget scoped(SettingsController c, Widget home) => SettingsScope(
      controller: c,
      child: MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: home),
    );

    testWidgets('settings page toggles and persists a switch', (t) async {
      bigScreen(t);
      final c = SettingsController.memory(db);
      await t.pumpWidget(scoped(c, const SettingsPage()));
      await settle(t);
      expect(find.text('Autoplay next episode'), findsOneWidget);
      expect(c.value.autoplay, isTrue);

      await t.tap(find.byType(Switch).first);
      await settle(t);
      expect(c.value.autoplay, isFalse);
    });

    testWidgets('autoplay sliders are disabled while autoplay is off', (
      t,
    ) async {
      bigScreen(t);
      final c = SettingsController.memory(
        db,
        const UserSettings(autoplay: false),
      );
      await t.pumpWidget(scoped(c, const SettingsPage()));
      await settle(t);
      final ignore = t.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('Countdown length'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('reset asks first, then restores defaults', (t) async {
      bigScreen(t);
      final c = SettingsController.memory(
        db,
        const UserSettings(watchedPercent: 80, showMissing: true),
      );
      await t.pumpWidget(scoped(c, const SettingsPage()));
      await settle(t);

      await t.ensureVisible(find.text('Reset all settings'));
      await t.tap(find.text('Reset all settings'));
      await settle(t);
      expect(find.text('Reset all settings?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(c.value.watchedPercent, 80);

      await t.tap(find.text('Reset all settings'));
      await settle(t);
      await t.tap(find.text('Reset'));
      await settle(t);
      expect(c.value, UserSettings.defaults);
    });

    testWidgets('without a scope the page says settings are unavailable', (
      t,
    ) async {
      await t.pumpWidget(const MaterialApp(home: SettingsPage()));
      expect(find.text('Settings are not available.'), findsOneWidget);
    });

    Future<int> seedShow() async {
      final id = await db.upsertShow('Omega', 'omega', null);
      Future<void> add(int s, int e, {bool missing = false}) => db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(
              filePath: 'o-$s-$e.mkv',
              folderId: folderId,
              showId: Value(id),
              season: Value(s),
              episode: Value(e),
              tmdbTitle: Value('Ep $s.$e'),
              missing: Value(missing),
            ),
          );
      await add(0, 1); // special
      await add(1, 1);
      await add(1, 2, missing: true);
      return id;
    }

    testWidgets('show page hides specials and missing files by default', (
      t,
    ) async {
      bigScreen(t);
      final id = await seedShow();
      final c = SettingsController.memory(db);
      await t.pumpWidget(scoped(c, ShowPage(db: db, meta: null, showId: id)));
      await settle(t);
      expect(find.text('Ep 1.1'), findsOneWidget);
      expect(find.text('Ep 1.2'), findsNothing);
      expect(find.text('Ep 0.1'), findsNothing); // special season not offered
    });

    testWidgets('show page lists missing files greyed when enabled', (t) async {
      bigScreen(t);
      final id = await seedShow();
      final c = SettingsController.memory(
        db,
        const UserSettings(showMissing: true, showSpecials: false),
      );
      await t.pumpWidget(scoped(c, ShowPage(db: db, meta: null, showId: id)));
      await settle(t);
      expect(find.text('Ep 1.2'), findsOneWidget);
      expect(find.byKey(const Key('missing-badge')), findsOneWidget);
      await t.tap(find.text('Ep 1.2'));
      await settle(t);
      expect(find.textContaining('This file is missing'), findsOneWidget);
    });

    testWidgets('home grid uses the poster size setting', (t) async {
      bigScreen(t);
      final id = await db.upsertShow('Solo', 'solo', null);
      await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(
              filePath: 's.mkv',
              folderId: folderId,
              showId: Value(id),
            ),
          );
      Future<double> width(PosterSize size) async {
        final c = SettingsController.memory(db, UserSettings(posterSize: size));
        await t.pumpWidget(scoped(c, HomePage(db: db)));
        await settle(t);
        final grid = t.widget<SliverGrid>(find.byType(SliverGrid));
        return (grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent)
            .maxCrossAxisExtent;
      }

      expect(await width(PosterSize.small), 160);
      expect(await width(PosterSize.large), 250);
    });

    testWidgets('home: sort menu change is saved in settings', (t) async {
      bigScreen(t);
      final c = SettingsController.memory(db);
      await t.pumpWidget(scoped(c, HomePage(db: db)));
      await settle(t);
      await t.tap(find.byTooltip('Sort'));
      await settle(t);
      await t.tap(find.text('Recently added'));
      await settle(t);
      expect(c.value.homeSort, ShowSort.recentlyAdded);
    });

    testWidgets('home: Library menu opens Settings', (t) async {
      bigScreen(t);
      // The test font (Ahem) is far wider than the real one; shrink text so
      // the existing menu rows do not overflow and mask what is tested here.
      t.platformDispatcher.textScaleFactorTestValue = 0.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final c = SettingsController.memory(db);
      await t.pumpWidget(scoped(c, HomePage(db: db)));
      await settle(t);
      await t.tap(find.byTooltip('Library'));
      await settle(t);
      await t.tap(find.text('Settings'));
      await settle(t);
      expect(find.text('Playback'.toUpperCase()), findsOneWidget);
    });

    testWidgets('resume dialog: Start over and dismiss', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final over = askResume(ctx, const Duration(minutes: 12, seconds: 5));
      await t.pumpAndSettle();
      expect(find.text('You stopped at 12:05.'), findsOneWidget);
      await t.tap(find.text('Start over'));
      await t.pumpAndSettle();
      expect(await over, isFalse);

      final res = askResume(ctx, const Duration(minutes: 1));
      await t.pumpAndSettle();
      await t.tap(find.text('Resume'));
      await t.pumpAndSettle();
      expect(await res, isTrue);
    });
  });
}
