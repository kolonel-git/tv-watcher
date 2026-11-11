
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/ui/image_budget.dart';
import 'package:tv_watcher/ui/play.dart';
import 'package:tv_watcher/library/file_check.dart';
import 'package:tv_watcher/window/window_frame.dart';

void main() {
  group('checkPlayable', () {
    test('null when the file exists', () async {
      final r = await checkPlayable(
        'D:/tv/a.mkv',
        'D:/tv',
        fileExists: (_) async => true,
        dirExists: (_) async => fail('folder must not be checked'),
      );
      expect(r, isNull);
    });

    test('file missing while the folder is there', () async {
      final r = await checkPlayable(
        'D:/tv/a.mkv',
        'D:/tv',
        fileExists: (_) async => false,
        dirExists: (_) async => true,
      );
      expect(r, FileProblem.fileMissing);
    });

    test('folder unreachable when the whole folder is gone', () async {
      final r = await checkPlayable(
        'D:/tv/a.mkv',
        'D:/tv',
        fileExists: (_) async => false,
        dirExists: (_) async => false,
      );
      expect(r, FileProblem.folderUnreachable);
    });
  });

  group('WindowFrame encode/decode', () {
    test('round trip', () {
      const f = WindowFrame(
        x: 10,
        y: 20,
        width: 1280,
        height: 720,
        maximized: true,
      );
      expect(WindowFrame.decode(f.encode()), f);
    });

    test('garbage decodes to null', () {
      for (final bad in [
        null,
        '',
        'nope',
        '[]',
        '{}',
        '{"x":1,"y":2,"w":0,"h":5}',
        '{"x":"a","y":2,"w":10,"h":5}',
        '{"x":1,"y":2,"w":1e99,"h":5}',
        '{"x":1,"y":2,"w":-4,"h":5}',
      ]) {
        expect(WindowFrame.decode(bad), isNull, reason: '$bad');
      }
    });

    test('oversized text is refused', () {
      expect(WindowFrame.decode('{"pad":"${'x' * 600}"}'), isNull);
    });
  });

  group('WindowFrame.fitTo', () {
    const screen = Rect.fromLTWH(0, 0, 1920, 1040);
    const second = Rect.fromLTWH(1920, 0, 1920, 1040);

    test('a frame already on screen is unchanged', () {
      const f = WindowFrame(x: 100, y: 80, width: 1200, height: 700);
      expect(f.fitTo([screen]), f);
    });

    test('tiny size is raised to the minimum', () {
      const f = WindowFrame(x: 100, y: 80, width: 50, height: 50);
      final r = f.fitTo([screen]);
      expect(r.width, WindowFrame.minSize.width);
      expect(r.height, WindowFrame.minSize.height);
    });

    test('frame on a monitor that is gone is centered on what is left', () {
      const f = WindowFrame(x: 2500, y: 100, width: 1000, height: 600);
      final r = f.fitTo([screen]);
      expect(r.rect.overlaps(screen), isTrue);
      expect(r.x, (1920 - 1000) / 2);
      expect(r.y, (1040 - 600) / 2);
    });

    test('frame on the second monitor stays when it is still there', () {
      const f = WindowFrame(x: 2000, y: 50, width: 1000, height: 600);
      expect(f.fitTo([screen, second]), f);
    });

    test('too big for the screen is shrunk to it', () {
      const f = WindowFrame(x: 0, y: 0, width: 5000, height: 4000);
      final r = f.fitTo([screen]);
      expect(r.width, 1920);
      expect(r.height, 1040);
    });

    test('barely visible sliver counts as off screen', () {
      const f = WindowFrame(x: 1900, y: 1030, width: 1000, height: 600);
      final r = f.fitTo([screen]);
      expect(r.rect.intersect(screen).width, greaterThan(500));
    });

    test('no display info: only the size floor applies', () {
      const f = WindowFrame(x: -9000, y: 5, width: 100, height: 100);
      final r = f.fitTo(const []);
      expect(r.x, -9000);
      expect(r.width, WindowFrame.minSize.width);
    });

    test('maximized flag survives', () {
      const f = WindowFrame(
        x: 100,
        y: 80,
        width: 1200,
        height: 700,
        maximized: true,
      );
      expect(f.fitTo([screen]).maximized, isTrue);
    });
  });

  group('ImageBudget', () {
    test('applies explicit limits', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final c = ImageCache();
      ImageBudget.apply(c);
      expect(c.maximumSizeBytes, ImageBudget.maxBytes);
      expect(c.maximumSize, ImageBudget.maxImages);
    });
  });

  group('openEpisode with an unplayable file', () {
    late AppDatabase db;
    late Show show;
    late Episode ep;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final folderId = await db.addFolder('C:/tv');
      final showId = await db.upsertShow('Show', 'show', null);
      final id = await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(
              filePath: 'C:/tv/Show/S01E01.mkv',
              folderId: folderId,
              showId: Value(showId),
              season: const Value(1),
              episode: const Value(1),
            ),
          );
      show = await (db.select(
        db.shows,
      )..where((s) => s.id.equals(showId))).getSingle();
      ep = await (db.select(
        db.episodes,
      )..where((e) => e.id.equals(id))).getSingle();
    });
    tearDown(() => db.close());

    Future<void> open(WidgetTester t, FileProblem problem) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openEpisode(
                context,
                db,
                show,
                ep,
                check: (_, _) async => problem,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('missing file: explains and offers a rescan', (t) async {
      await open(t, FileProblem.fileMissing);
      expect(find.text('File not found'), findsOneWidget);
      expect(find.text('Rescan'), findsOneWidget);
      expect(find.textContaining('S01E01.mkv'), findsOneWidget);
    });

    testWidgets('unreachable folder: no rescan, says to reconnect', (t) async {
      await open(t, FileProblem.folderUnreachable);
      expect(find.text('Folder not reachable'), findsOneWidget);
      expect(find.text('Rescan'), findsNothing);
      expect(find.textContaining('Reconnect'), findsOneWidget);
    });
  });
}
