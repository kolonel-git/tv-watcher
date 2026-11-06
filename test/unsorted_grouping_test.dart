import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/library/filename_parser.dart';
import 'package:tv_watcher/library/unsorted_grouping.dart';

UnsortedItem item(int id, String rel, {int folder = 1, String? root}) =>
    UnsortedItem(
        id: id,
        folderId: folder,
        path: 'C:/lib/$rel',
        relativePath: rel,
        rootName: root);

void main() {
  group('parseAbsolutePath without dash', () {
    test('trailing number', () {
      final g = parseAbsolutePath('Show Name 07.mkv')!;
      expect(g.groupLabel, 'Show Name');
      expect(g.number, 7);
    });
    test('episode word', () {
      expect(parseAbsolutePath('Show Name Episode 7.mkv')!.groupLabel,
          'Show Name');
      expect(parseAbsolutePath('Show.Name.Ep.07.mkv')!.number, 7);
      expect(parseAbsolutePath('Show Name E12.mkv')!.number, 12);
    });
    test('brackets ignored', () {
      final g = parseAbsolutePath('[Grp] Show Name 03 [720p][x265].mkv')!;
      expect(g.groupLabel, 'Show Name');
      expect(g.number, 3);
    });
    test('years and long numbers are not episode numbers', () {
      expect(parseAbsolutePath('Movie 2019.mkv'), isNull);
      expect(parseAbsolutePath('Movie (2019) 1080p.mkv'), isNull);
      expect(parseAbsolutePath('Holiday Video.mkv'), isNull);
    });
  });

  group('show name hint', () {
    test('skips generic folders', () {
      expect(suggestShowNameFromFolder('Watched/x - 01.mp4'), isNull);
      expect(
          suggestShowNameFromFolder('Watched/x - 01.mp4',
              rootName: "JoJo's Bizarre Adventure Complete (2012-2016)"),
          "JoJo's Bizarre Adventure");
      expect(suggestShowNameFromFolder('Naruto/Season 2/x - 01.mkv'), 'Naruto');
    });
    test('generic library name gives no hint', () {
      expect(suggestShowNameFromFolder('x - 01.mkv', rootName: 'TV Shows'),
          isNull);
    });
  });

  group('groupUnsorted', () {
    test('numbered files group by name prefix, ordered by number', () {
      final r = groupUnsorted([
        item(3, '[A] Show - Arc One - 03 [480p].mkv'),
        item(1, '[A] Show - Arc One - 01 [480p].mkv'),
        item(2, '[A] Show - Arc One - 02 [480p].mkv'),
        item(4, '[A] Show - Arc Two - 25 [480p].mkv'),
        item(5, '[A] Show - Arc Two - 26 [480p].mkv'),
      ]);
      expect(r.groups.length, 2);
      final one = r.groups.firstWhere((g) => g.label.endsWith('Arc One'));
      expect(one.entries.map((e) => e.number), [1, 2, 3]);
      expect(one.numberedByName, isTrue);
      final two = r.groups.firstWhere((g) => g.label.endsWith('Arc Two'));
      expect(two.minNumber, 25);
      expect(two.maxNumber, 26);
      expect(r.singles, isEmpty);
    });

    test('Watched subfolder joins the same group', () {
      final r = groupUnsorted([
        item(1, 'Watched/[A] Show - 01.mp4', root: 'My Show'),
        item(2, '[A] Show - 02.mp4', root: 'My Show'),
      ]);
      expect(r.groups.length, 1);
      expect(r.groups.single.showHint, 'My Show');
    });

    test('numbered by name, leftovers become singles', () {
      final r = groupUnsorted([
        item(10, 'Trip/clip 10.mkv'),
        item(2, 'Trip/clip 2.mkv'),
        item(1, 'Trip/intro.mkv'),
        item(9, 'Other/lonely.mkv'),
      ]);
      expect(r.groups.length, 1);
      expect(r.groups.single.label, 'clip');
      expect(r.groups.single.entries.map((e) => e.number), [2, 10]);
      expect(r.singles.length, 2);
    });

    test('separate library folders never merge', () {
      final r = groupUnsorted([
        item(1, 'Show - 01.mkv', folder: 1),
        item(2, 'Show - 02.mkv', folder: 2),
      ]);
      expect(r.groups, isEmpty);
      expect(r.singles.length, 2);
    });

    test('folder fallback numbers files by order', () {
      final r = groupUnsorted([
        item(1, 'Holiday/alpha.mkv'),
        item(2, 'Holiday/beta.mkv'),
        item(3, 'Holiday/gamma.mkv'),
      ]);
      expect(r.groups.single.entries.map((e) => e.number), [1, 2, 3]);
      expect(r.groups.single.entries.first.item.id, 1);
    });
  });

  test('naturalCompare', () {
    final l = ['ep10', 'ep2', 'ep1']..sort(naturalCompare);
    expect(l, ['ep1', 'ep2', 'ep10']);
  });
}
