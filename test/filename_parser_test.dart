import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/library/filename_parser.dart';

ParsedEpisode e(String show, int s, int ep, {int? end, int? year}) =>
    ParsedEpisode(
      showName: show,
      season: s,
      episode: ep,
      endEpisode: end,
      year: year,
    );

void main() {
  titleTests();
  absoluteTests();
  group('parses (path -> show/season/episode)', () {
    final cases = <String, ParsedEpisode>{
      // SxxExx variants
      'Breaking Bad S01E01.mkv': e('Breaking Bad', 1, 1),
      'Breaking.Bad.S01E02.720p.BluRay.x264-GRP.mkv': e('Breaking Bad', 1, 2),
      'breaking_bad_s1e3.avi': e('breaking bad', 1, 3),
      'Show.Name.s01e04.mp4': e('Show Name', 1, 4),
      'Show Name - S02E10 - Episode Title.mkv': e('Show Name', 2, 10),
      'Show Name S02 E11.mkv': e('Show Name', 2, 11),
      'Show Name S02.E12.mkv': e('Show Name', 2, 12),
      'Show Name - s10e100.mkv': e('Show Name', 10, 100),
      'The.Office.US.S03E05.HDTV.mkv': e('The Office US', 3, 5),
      // multi episode
      'Show S01E01E02.mkv': e('Show', 1, 1, end: 2),
      'Show S01E01-E03.mkv': e('Show', 1, 1, end: 3),
      'Show S01E05-06.mkv': e('Show', 1, 5, end: 6),
      // NxNN
      'Show Name 1x01.mkv': e('Show Name', 1, 1),
      'Show.Name.2x13.avi': e('Show Name', 2, 13),
      'Show Name - 01x07 - Title.mkv': e('Show Name', 1, 7),
      'Show 1x01 1920x1080.mkv': e('Show', 1, 1),
      // Year
      'Doctor Who (2005) S01E01.mkv': e('Doctor Who', 1, 1, year: 2005),
      'Doctor.Who.2005.S02E03.mkv': e('Doctor Who', 2, 3, year: 2005),
      // Release group brackets
      '[Group] Show Name S01E01 [1080p].mkv': e('Show Name', 1, 1),
      // Folder structures
      'Breaking Bad/Season 1/S01E01.mkv': e('Breaking Bad', 1, 1),
      'Breaking Bad/Season 1/Episode 3.mkv': e('Breaking Bad', 1, 3),
      'Breaking Bad/Season 02/Ep 04.mkv': e('Breaking Bad', 2, 4),
      'Breaking Bad/Season 2/E05.mkv': e('Breaking Bad', 2, 5),
      'Breaking Bad/S03/Episode.06.mkv': e('Breaking Bad', 3, 6),
      'Breaking Bad/Series 4/Ep.07.mkv': e('Breaking Bad', 4, 7),
      'Some Show/Season 1/Some Show - S01E01 - Pilot.mkv': e('Some Show', 1, 1),
      'Some Show Season 2/Episode 1.mkv': e('Some Show', 2, 1),
      'Some Show - S02/Episode 2.mkv': e('Some Show', 2, 2),
      'TV/Some Show/Season 1/Episode 3.mkv': e('Some Show', 1, 3),
      'Some Show/01x05.mkv': e('Some Show', 1, 5),
      'Some Show/S01E06.mkv': e('Some Show', 1, 6),
      'Some.Show.S01.1080p/Some.Show.S01E07.mkv': e('Some Show', 1, 7),
      // Windows separators
      'Some Show\\Season 1\\Episode 8.mkv': e('Some Show', 1, 8),
      // extensions
      'Show S01E01.MKV': e('Show', 1, 1),
      'Show S01E01.m4v': e('Show', 1, 1),
      'Show S01E01.webm': e('Show', 1, 1),
      // Mixed case / spacing
      'SHOW NAME S01E01.mkv': e('SHOW NAME', 1, 1),
      '  Show Name  - S01E01.mkv': e('Show Name', 1, 1),
      'Show_Name_S01E01.mkv': e('Show Name', 1, 1),
      // Names with digits
      '24 S01E01.mkv': e('24', 1, 1),
      '9-1-1 S02E03.mkv': e('9-1-1', 2, 3),
      'Show 2 S01E01.mkv': e('Show 2', 1, 1),
      // Folder gives show, filename only marker
      'Fargo/Fargo.S04E01.mkv': e('Fargo', 4, 1),
      'Fargo/S04E02.mkv': e('Fargo', 4, 2),
    };

    cases.forEach((path, expected) {
      test(path, () {
        expect(parseEpisodePath(path), expected);
      });
    });
  });

  group('unmatched -> null (Unsorted)', () {
    const unmatched = [
      'random video.mkv',
      'holiday.mp4',
      'Show Name.mkv',
      'Movie (2019) 1080p.mkv',
      'Season 1/Episode 3.mkv', // no show name anywhere
      'Show/Episode 3.mkv', // episode without season
      'trailer.mp4',
    ];
    for (final path in unmatched) {
      test(path, () => expect(parseEpisodePath(path), isNull));
    }
  });

  test('showKey ignores case, punctuation', () {
    expect(
      e('The Office (US)', 1, 1).showKey,
      e('the.office.us', 1, 1).showKey,
    );
  });

  test('isVideoFile', () {
    expect(isVideoFile('a/b.MKV'), isTrue);
    expect(isVideoFile('a/b.srt'), isFalse);
    expect(isVideoFile('a/b.nfo'), isFalse);
  });
}

void titleTests() {
  group('episode title from filename', () {
    final cases = <String, String?>{
      'Rick and Morty (2013) - S01E01 - Pilot [Bluray-1080p][Opus 5.1][x265]-FraMeSToR.mkv':
          'Pilot',
      'Rick and Morty (2013) - S01E06 - Rick Potion #9 [Bluray-1080p][Opus 5.1][x265]-GRP.mkv':
          'Rick Potion #9',
      'Show - S01E04 - M. Night Shaym-Aliens! [Bluray-1080p]-GRP.mkv':
          'M. Night Shaym-Aliens!',
      'Show.S01E02.Lawnmower.Dog.1080p.BluRay.x264-GRP.mkv': 'Lawnmower Dog',
      'Show S01E01.mkv': null,
      'Show S01E01 720p.mkv': null,
      'Show - S01E03 - Anatomy Park.mkv': 'Anatomy Park',
      'Show/Season 1/Episode 3 - The Title.mkv': 'The Title',
    };
    cases.forEach((path, title) {
      test(path, () => expect(parseEpisodePath(path)?.title, title));
    });
  });
}

void absoluteTests() {
  group('absolute numbering', () {
    test('DeadFish style', () {
      final g = parseAbsolutePath(
        r"D:\TV\JoJo\[DeadFish] JoJo no Kimyou na Bouken (2012) - 07 [BD][720p][AAC].mp4",
      )!;
      expect(g.groupLabel, 'JoJo no Kimyou na Bouken');
      expect(g.number, 7);
    });
    test('HorribleSubs arc', () {
      final g = parseAbsolutePath(
        "[HorribleSubs] JoJo's Bizarre Adventure - Stardust Crusaders - 12 [480p].mkv",
      )!;
      expect(g.groupLabel, "JoJo's Bizarre Adventure - Stardust Crusaders");
      expect(g.number, 12);
    });
    test('same arc shares group key', () {
      final a = parseAbsolutePath('[X] Show - Arc - 01 [480p].mkv')!;
      final b = parseAbsolutePath('[X] Show - Arc - 24 [480p].mkv')!;
      expect(a.groupKey, b.groupKey);
    });
    test('version suffix and no tags', () {
      final g = parseAbsolutePath('Show Name - 05v2.mkv')!;
      expect(g.number, 5);
      expect(g.groupLabel, 'Show Name');
    });
    test('not matched', () {
      expect(parseAbsolutePath('Movie (2019) 1080p.mkv'), isNull);
      expect(parseAbsolutePath('holiday.mp4'), isNull);
      expect(parseAbsolutePath('Show - 2019.mkv'), isNull);
    });
    test('suggest show name from folder', () {
      expect(
        suggestShowNameFromFolder(
          "JoJo's Bizarre Adventure Complete (2012-2016)/Watched/x - 01.mp4",
        ),
        "JoJo's Bizarre Adventure",
      );
      expect(suggestShowNameFromFolder('x - 01.mp4'), isNull);
    });
  });
}
