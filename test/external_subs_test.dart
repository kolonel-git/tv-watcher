import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tv_watcher/tracks/external_subs.dart';

ExternalSub? m(String video, String sub) =>
    matchSubtitleName(videoBase: video, path: '/x/$sub');

void main() {
  group('matchSubtitleName', () {
    const v = 'Show.S01E01.1080p';

    test('exact name, no language', () {
      final s = m(v, 'Show.S01E01.1080p.srt')!;
      expect(s.language, isNull);
      expect(s.title, isNull);
    });
    test('language suffix', () {
      expect(m(v, 'Show.S01E01.1080p.en.srt')!.language, 'en');
      expect(m(v, 'Show.S01E01.1080p.eng.srt')!.language, 'en');
      expect(m(v, 'Show.S01E01.1080p.English.srt')!.language, 'en');
      expect(m(v, 'Show.S01E01.1080p.jpn.ass')!.language, 'ja');
    });
    test('flags become the title', () {
      final s = m(v, 'Show.S01E01.1080p.en.forced.srt')!;
      expect(s.language, 'en');
      expect(s.title, 'Forced');
      expect(m(v, 'Show.S01E01.1080p.en.sdh.srt')!.title, 'SDH');
    });
    test('separators and brackets', () {
      expect(m(v, 'Show.S01E01.1080p_fr.srt')!.language, 'fr');
      expect(m(v, 'Show.S01E01.1080p [German].srt')!.language, 'de');
    });
    test('another episode does not match', () {
      expect(m(v, 'Show.S01E02.1080p.en.srt'), isNull);
      expect(m('Show S01E1', 'Show S01E10.srt'), isNull);
    });
    test('non-subtitle files are ignored', () {
      expect(m(v, 'Show.S01E01.1080p.nfo'), isNull);
      expect(m(v, 'Show.S01E01.1080p.mkv'), isNull);
    });
    test('case-insensitive', () {
      expect(m('show s01e01', 'SHOW S01E01.EN.SRT')!.language, 'en');
    });
  });

  test('loose names inside Subs/<video>/', () {
    expect(matchLooseSubtitleName('/x/2_English.srt')!.language, 'en');
    expect(matchLooseSubtitleName('/x/Spanish.srt')!.language, 'es');
    expect(matchLooseSubtitleName('/x/readme.txt'), isNull);
  });

  group('findExternalSubtitles (real folder, read-only)', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('tvw_subs_'));
    tearDown(() => tmp.delete(recursive: true));

    Future<void> touch(String rel) async {
      final f = File(p.join(tmp.path, rel));
      await f.create(recursive: true);
      await f.writeAsString('1\n00:00:01,000 --> 00:00:02,000\nhi\n');
    }

    test(
      'finds beside-the-video, Subs folder and Subs/<name> folder',
      () async {
        await touch('Show.S01E01.mkv');
        await touch('Show.S01E01.en.srt');
        await touch('Show.S01E01.fr.srt');
        await touch('Show.S01E02.en.srt'); // other episode
        await touch('Subs/Show.S01E01.de.srt');
        await touch('Subs/Show.S01E01/3_Spanish.srt');
        await touch('Subs/Show.S01E02/2_English.srt'); // other episode
        await touch('notes.txt');

        final subs = await findExternalSubtitles(
          p.join(tmp.path, 'Show.S01E01.mkv'),
        );
        expect(subs.map((s) => s.language).toSet(), {'en', 'fr', 'de', 'es'});
        expect(subs.length, 4);
      },
    );

    test('does not modify or create files', () async {
      await touch('A.mkv');
      await touch('A.en.srt');
      final before = tmp.listSync(recursive: true).map((e) => e.path).toList()
        ..sort();
      await findExternalSubtitles(p.join(tmp.path, 'A.mkv'));
      final after = tmp.listSync(recursive: true).map((e) => e.path).toList()
        ..sort();
      expect(after, before);
    });

    test('missing folder gives empty list', () async {
      expect(
        await findExternalSubtitles(p.join(tmp.path, 'nope', 'x.mkv')),
        isEmpty,
      );
    });
  });
}
