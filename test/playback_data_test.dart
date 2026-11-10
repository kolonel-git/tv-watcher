import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/app_info.dart';
import 'package:tv_watcher/data/backup_service.dart';
import 'package:tv_watcher/data/data_actions.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/player/playback_options.dart';
import 'package:tv_watcher/player/playback_page.dart';
import 'package:tv_watcher/player/player_panel.dart';
import 'package:tv_watcher/player/subtitle_style.dart';
import 'package:tv_watcher/settings/settings_controller.dart';
import 'package:tv_watcher/settings/user_settings.dart';
import 'package:tv_watcher/ui/settings_page.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

class FakeActions implements DataActions {
  Uint8List? saved;
  String? savedName;
  String? toPick;
  bool cancel = false;
  String? opened;

  @override
  Future<bool> saveBackup(String fileName, Uint8List bytes) async {
    if (cancel) return false;
    saved = bytes;
    savedName = fileName;
    return true;
  }

  @override
  Future<String?> pickBackup() async => toPick;

  @override
  Future<String> dataFolder() async => r'C:\data';

  @override
  Future<void> openFolder(String path) async => opened = path;
}

void main() {
  group('PlaybackOptions', () {
    test('speed ladder moves one step and stops at the ends', () {
      var o = PlaybackOptions.defaults;
      expect(o.faster().speed, 1.25);
      expect(o.slower().speed, 0.75);
      o = const PlaybackOptions(speed: 2.0);
      expect(o.faster().speed, 2.0);
      o = const PlaybackOptions(speed: 0.5);
      expect(o.slower().speed, 0.5);
    });

    test('an off-ladder speed still steps to the nearest rung', () {
      const o = PlaybackOptions(speed: 1.1);
      expect(o.faster().speed, 1.25);
      expect(o.slower().speed, 1.0);
    });

    test('delays are clamped to 30 seconds', () {
      final o = PlaybackOptions.defaults.copyWith(
        subtitleDelayMs: 99999,
        audioDelayMs: -99999,
      );
      expect(o.subtitleDelayMs, 30000);
      expect(o.audioDelayMs, -30000);
    });

    test('a new file keeps the speed but resets delays and aspect', () {
      const o = PlaybackOptions(
        speed: 1.5,
        subtitleDelayMs: 400,
        audioDelayMs: -200,
        aspect: AspectMode.zoom,
      );
      expect(o.forNewFile(), const PlaybackOptions(speed: 1.5));
      expect(o.isDefault, isFalse);
      expect(PlaybackOptions.defaults.isDefault, isTrue);
    });

    test('labels', () {
      expect(PlaybackOptions.speedLabel(1.0), '1x');
      expect(PlaybackOptions.speedLabel(1.25), '1.25x');
      expect(PlaybackOptions.delayLabel(0), '0 s');
      expect(PlaybackOptions.delayLabel(300), '+0.3 s');
      expect(PlaybackOptions.delayLabel(-1200), '-1.2 s');
      expect(PlaybackOptions.delaySeconds(-1200), '-1.200');
    });

    test('aspect modes map to mpv values and fits', () {
      expect(AspectMode.auto.mpvValue, '-1');
      expect(AspectMode.wide16x9.mpvValue, '16:9');
      expect(AspectMode.zoom.fit, BoxFit.cover);
      expect(AspectMode.classic4x3.fit, BoxFit.contain);
    });
  });

  group('player panel: playback page', () {
    Widget host(Widget child) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('root lists Playback with the current speed', (t) async {
      PanelPage? went;
      await t.pumpWidget(
        host(
          PlayerPanel(
            page: PanelPage.root,
            onPage: (p) => went = p,
            onClose: () {},
            subtitleOptions: const [],
            audioOptions: const [],
            currentSubtitle: 'Off',
            currentAudio: 'Auto',
            onLoadSubtitleFile: () {},
            subtitleStyle: SubtitleStyle.defaults,
            onStyleChanged: (_) {},
            onResetPosition: () {},
            playbackOptions: const PlaybackOptions(speed: 1.5),
          ),
        ),
      );
      expect(find.text('1.5x'), findsOneWidget);
      await t.tap(find.text('Playback'));
      expect(went, PanelPage.playback);
    });

    testWidgets('chips, steppers, reset and hardware switch call back', (
      t,
    ) async {
      var opts = PlaybackOptions.defaults;
      bool? hw;
      late StateSetter set;
      await t.pumpWidget(
        host(
          StatefulBuilder(
            builder: (c, s) {
              set = s;
              return PlaybackPanelPage(
                options: opts,
                onOptions: (o) => set(() => opts = o),
                hardwareDecoding: true,
                onHardwareDecoding: (v) => hw = v,
              );
            },
          ),
        ),
      );
      await t.tap(find.text('1.5x'));
      await t.pump();
      expect(opts.speed, 1.5);

      await t.tap(find.text('Zoom to fill (crops)'));
      await t.pump();
      expect(opts.aspect, AspectMode.zoom);

      await t.tap(find.byKey(const Key('sub-delay-plus')));
      await t.pump();
      await t.tap(find.byKey(const Key('sub-delay-plus')));
      await t.pump();
      expect(opts.subtitleDelayMs, 200);
      expect(find.text('+0.2 s'), findsOneWidget);
      await t.tap(find.byKey(const Key('sub-delay-value'))); // tap = zero
      await t.pump();
      expect(opts.subtitleDelayMs, 0);

      await t.tap(find.byKey(const Key('audio-delay-minus')));
      await t.pump();
      expect(opts.audioDelayMs, -100);

      await t.tap(find.byType(Switch));
      expect(hw, isFalse);

      await t.tap(find.text('Reset speed, aspect and delays'));
      await t.pump();
      expect(opts, PlaybackOptions.defaults);
    });

    testWidgets('shortcut list mentions the new keys', (t) async {
      await t.pumpWidget(
        host(
          PlayerPanel(
            page: PanelPage.shortcuts,
            onPage: (_) {},
            onClose: () {},
            subtitleOptions: const [],
            audioOptions: const [],
            currentSubtitle: 'Off',
            currentAudio: 'Auto',
            onLoadSubtitleFile: () {},
            subtitleStyle: SubtitleStyle.defaults,
            onStyleChanged: (_) {},
            onResetPosition: () {},
          ),
        ),
      );
      expect(find.text('Speed down / up'), findsOneWidget);
      expect(find.text('Subtitle delay earlier / later'), findsOneWidget);
    });
  });

  group('UserSettings hardware decoding', () {
    test('defaults on, round-trips, bad value falls back', () {
      expect(UserSettings.defaults.hardwareDecoding, isTrue);
      const off = UserSettings(hardwareDecoding: false);
      expect(UserSettings.fromMap(off.toMap()).hardwareDecoding, isFalse);
      expect(
        UserSettings.fromMap({'hardwareDecoding': 'x'}).hardwareDecoding,
        isTrue,
      );
    });
  });

  group('BackupFile.parse', () {
    String good({Object? settings, Object? episodes}) => jsonEncode({
      'format': 'tv-watcher-backup',
      'formatVersion': 1,
      'settings': settings ?? {},
      'episodes': episodes ?? [],
    });

    test('rejects text that is not JSON', () {
      expect(
        () => BackupFile.parse('hello'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects other JSON and newer formats', () {
      expect(
        () => BackupFile.parse('{"a":1}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupFile.parse(
          '{"format":"tv-watcher-backup","formatVersion":2}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('keeps only whitelisted settings keys and sane values', () {
      final f = BackupFile.parse(
        good(
          settings: {
            'settings.skipStep': '30',
            'player.volume': '55',
            'tmdb.token': 'secret',
            'other': 'x',
            'settings.big': 'x' * 5000,
            'settings.num': 5,
          },
        ),
      );
      expect(f.settings, {'settings.skipStep': '30', 'player.volume': '55'});
    });

    test('skips malformed episode entries instead of failing', () {
      final f = BackupFile.parse(
        good(
          episodes: [
            {'path': 'a.mkv', 'positionMs': 10, 'durationMs': 100},
            {'path': '', 'positionMs': 1, 'durationMs': 1},
            {'path': 'b.mkv', 'positionMs': -5, 'durationMs': 1},
            {'path': 'c.mkv', 'positionMs': 'x', 'durationMs': 1},
            'junk',
            {
              'path': 'd.mkv',
              'positionMs': 0,
              'durationMs': 9,
              'watched': true,
            },
          ],
        ),
      );
      expect([for (final e in f.episodes) e.path], ['a.mkv', 'd.mkv']);
      expect(f.episodes.last.watched, isTrue);
    });
  });

  group('BackupService', () {
    late AppDatabase db;
    late int folderId;
    late int showId;

    setUp(() async {
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      folderId = await db.addFolder(r'C:\m');
      showId = await db.upsertShow('Show', 'show', null);
    });
    tearDown(() => db.close());

    Future<int> ep(String path, {int? n}) => db
        .into(db.episodes)
        .insert(
          EpisodesCompanion.insert(
            filePath: path,
            folderId: folderId,
            showId: Value(showId),
            season: const Value(1),
            episode: Value(n ?? 1),
          ),
        );

    test(
      'export has progress and whitelisted settings, nothing else',
      () async {
        final a = await ep('a.mkv');
        await ep('untouched.mkv', n: 2);
        await db.saveProgress(a, positionMs: 60000, durationMs: 1000000);
        await db.setSetting('settings.skipStep', '30');
        await db.setSetting('player.volume', '70');
        await db.setSetting('weird.key', 'nope');

        final json = jsonDecode(await BackupService(db).exportJson());
        expect(json['format'], 'tv-watcher-backup');
        expect(json['appVersion'], appVersion);
        expect(json['settings'], {
          'settings.skipStep': '30',
          'player.volume': '70',
        });
        final eps = json['episodes'] as List;
        expect(eps, hasLength(1));
        expect(eps.single['path'], 'a.mkv');
        expect(eps.single['positionMs'], 60000);
        expect(jsonEncode(json).toLowerCase().contains('token'), isFalse);
      },
    );

    test('round trip into an empty-progress library restores it', () async {
      final a = await ep('a.mkv');
      await db.saveProgress(a, positionMs: 60000, durationMs: 1000000);
      await db.setSetting('settings.autoplay', 'false');
      final json = await BackupService(db).exportJson();

      await db.restoreProgress(
        a,
        positionMs: 0,
        durationMs: 0,
        watched: false,
        lastPlayedAt: null,
      );
      await db.deleteSettingsWithPrefix('settings.');

      final report = await BackupService(db).restore(BackupFile.parse(json));
      expect(report.restored, 1);
      expect(report.settings, 1);
      final back = await db.getEpisode(a);
      expect(back!.positionMs, 60000);
      expect(back.durationMs, 1000000);
      expect(await db.getSetting('settings.autoplay'), 'false');
    });

    test('newer local progress is kept, older is replaced', () async {
      final a = await ep('a.mkv');
      final b = await ep('b.mkv', n: 2);
      final c = await ep('c.mkv', n: 3);
      final old = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final recent = DateTime(2026, 6, 1).millisecondsSinceEpoch;
      await db.restoreProgress(
        a,
        positionMs: 111,
        durationMs: 1000,
        watched: false,
        lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(recent),
      );
      await db.restoreProgress(
        b,
        positionMs: 222,
        durationMs: 1000,
        watched: false,
        lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(old),
      );
      final file = BackupFile.parse(
        jsonEncode({
          'format': 'tv-watcher-backup',
          'formatVersion': 1,
          'episodes': [
            for (final p in ['a.mkv', 'b.mkv', 'c.mkv', 'gone.mkv'])
              {
                'path': p,
                'positionMs': 999,
                'durationMs': 1000,
                'watched': false,
                'lastPlayedMs': DateTime(2026, 3, 1).millisecondsSinceEpoch,
              },
          ],
        }),
      );
      final r = await BackupService(db).restore(file);
      expect((r.restored, r.keptLocal, r.notInLibrary), (2, 1, 1));
      expect((await db.getEpisode(a))!.positionMs, 111); // local newer
      expect((await db.getEpisode(b))!.positionMs, 999); // backup newer
      expect((await db.getEpisode(c))!.positionMs, 999); // local had none
    });

    test('a backup entry without a play time only fills blanks', () async {
      final a = await ep('a.mkv');
      final b = await ep('b.mkv', n: 2);
      await db.saveProgress(b, positionMs: 5000, durationMs: 100000);
      final file = BackupFile.parse(
        jsonEncode({
          'format': 'tv-watcher-backup',
          'formatVersion': 1,
          'episodes': [
            for (final p in ['a.mkv', 'b.mkv'])
              {'path': p, 'positionMs': 0, 'durationMs': 0, 'watched': true},
          ],
        }),
      );
      final r = await BackupService(db).restore(file);
      expect(r.restored, 1);
      expect((await db.getEpisode(a))!.watched, isTrue);
      expect((await db.getEpisode(b))!.watched, isFalse);
    });
  });

  group('settings page: data and about', () {
    late AppDatabase db;
    late int folderId;
    late FakeActions actions;
    late SettingsController controller;

    setUp(() async {
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      folderId = await db.addFolder(r'C:\m');
      actions = FakeActions();
      controller = SettingsController.memory(db);
    });
    tearDown(() => db.close());

    Future<void> open(WidgetTester t) async {
      t.view.physicalSize = const Size(1400, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        SettingsScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: SettingsPage(db: db, actions: actions),
          ),
        ),
      );
      await settle(t);
    }

    testWidgets('About shows name and version', (t) async {
      await open(t);
      expect(
        find.text('$appName $appVersion (build $appBuild)'),
        findsOneWidget,
      );
      expect(find.textContaining('no telemetry'), findsOneWidget);
    });

    testWidgets('hardware decoding switch is a saved setting', (t) async {
      await open(t);
      expect(find.text('Hardware decoding'), findsOneWidget);
      await t.ensureVisible(find.text('Hardware decoding'));
      await t.tap(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('Hardware decoding'),
                matching: find.byType(Row),
              ),
              matching: find.byType(Switch),
            )
            .first,
      );
      await settle(t);
      expect(controller.value.hardwareDecoding, isFalse);
    });

    testWidgets('export saves a JSON file with today in the name', (t) async {
      final id = await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(filePath: 'x.mkv', folderId: folderId),
          );
      await db.saveProgress(id, positionMs: 70000, durationMs: 900000);
      await open(t);
      await t.ensureVisible(find.text('Export...'));
      await t.tap(find.text('Export...'));
      await settle(t);
      expect(actions.savedName, startsWith('tv-watcher-backup-'));
      expect(actions.savedName, endsWith('.json'));
      final json = jsonDecode(utf8.decode(actions.saved!));
      expect((json['episodes'] as List).single['path'], 'x.mkv');
      expect(find.text('Backup saved.'), findsOneWidget);
    });

    testWidgets('cancelling the export says nothing', (t) async {
      actions.cancel = true;
      await open(t);
      await t.ensureVisible(find.text('Export...'));
      await t.tap(find.text('Export...'));
      await settle(t);
      expect(find.text('Backup saved.'), findsNothing);
    });

    testWidgets('import: confirm, restore, settings reload', (t) async {
      final id = await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(filePath: 'x.mkv', folderId: folderId),
          );
      actions.toPick = jsonEncode({
        'format': 'tv-watcher-backup',
        'formatVersion': 1,
        'settings': {'settings.skipStep': '30'},
        'episodes': [
          {
            'path': 'x.mkv',
            'positionMs': 42000,
            'durationMs': 900000,
            'watched': false,
            'lastPlayedMs': 1000,
          },
        ],
      });
      await open(t);
      await t.ensureVisible(find.text('Import...'));
      await t.tap(find.text('Import...'));
      await settle(t);
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.textContaining('1 episodes'), findsOneWidget);
      await t.tap(find.text('Restore'));
      await settle(t);
      expect((await t.runAsync(() => db.getEpisode(id)))!.positionMs, 42000);
      expect(controller.value.skipStepSeconds, 30);
      expect(find.textContaining('Restored 1 episodes'), findsOneWidget);
    });

    testWidgets('import: cancel at the dialog changes nothing', (t) async {
      final id = await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(filePath: 'x.mkv', folderId: folderId),
          );
      actions.toPick = jsonEncode({
        'format': 'tv-watcher-backup',
        'formatVersion': 1,
        'episodes': [
          {
            'path': 'x.mkv',
            'positionMs': 42000,
            'durationMs': 9,
            'lastPlayedMs': 5,
          },
        ],
      });
      await open(t);
      await t.ensureVisible(find.text('Import...'));
      await t.tap(find.text('Import...'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect((await t.runAsync(() => db.getEpisode(id)))!.positionMs, 0);
    });

    testWidgets('import: a bad file shows a message', (t) async {
      actions.toPick = 'not json';
      await open(t);
      await t.ensureVisible(find.text('Import...'));
      await t.tap(find.text('Import...'));
      await settle(t);
      expect(find.text('This is not a valid backup file.'), findsOneWidget);
    });

    testWidgets('open data folder passes the folder to Explorer', (t) async {
      await open(t);
      await t.ensureVisible(find.text('Open'));
      await t.tap(find.text('Open'));
      await settle(t);
      expect(actions.opened, r'C:\data');
    });
  });

  test('app_info version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*(\S+)\+(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m, isNotNull);
    expect(m!.group(1), appVersion);
    expect(m.group(2), appBuild);
  });
}
