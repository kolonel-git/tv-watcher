import 'package:path/path.dart' as p;

import 'filename_parser.dart';

/// One unsorted file, with its path relative to its library folder.
class UnsortedItem {
  const UnsortedItem({
    required this.id,
    required this.folderId,
    required this.path,
    required this.relativePath,
    this.rootName,
  });
  final int id;
  final int folderId;
  final String path;
  final String relativePath;

  /// Name of the library folder (fallback show-name hint).
  final String? rootName;
}

class GroupEntry {
  const GroupEntry(this.item, this.number);
  final UnsortedItem item;

  /// Episode number: from the filename, or position in file order for
  /// groups whose names carry no number.
  final int number;
}

class UnsortedGroup {
  UnsortedGroup({
    required this.key,
    required this.label,
    required this.numberedByName,
    this.showHint,
  });

  final String key;
  final String label;

  /// true: numbers come from filenames. false: numbered by file order.
  final bool numberedByName;
  final String? showHint;
  final List<GroupEntry> entries = [];

  int get minNumber =>
      entries.map((e) => e.number).reduce((a, b) => a < b ? a : b);
  int get maxNumber =>
      entries.map((e) => e.number).reduce((a, b) => a > b ? a : b);
}

class UnsortedGrouping {
  const UnsortedGrouping(this.groups, this.singles);
  final List<UnsortedGroup> groups;

  /// Files that did not fit any group of two or more.
  final List<UnsortedItem> singles;
}

/// Compares strings with embedded numbers numerically ("ep2" < "ep10").
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// Groups unsorted files so a whole season can be assigned at once.
///
/// 1. Files numbered like `Show - Arc - 07` or `Show 07` share a group per
///    name prefix (per library folder).
/// 2. Remaining files group by the folder they sit in, numbered by file order.
/// 3. Groups of one file are returned as singles.
UnsortedGrouping groupUnsorted(List<UnsortedItem> items) {
  final byKey = <String, UnsortedGroup>{};

  for (final it in items) {
    final guess = parseAbsolutePath(it.relativePath);
    final hint =
        suggestShowNameFromFolder(it.relativePath, rootName: it.rootName);
    if (guess != null) {
      final key = '${it.folderId}|n|${guess.groupKey}';
      byKey
          .putIfAbsent(
              key,
              () => UnsortedGroup(
                  key: key,
                  label: guess.groupLabel,
                  numberedByName: true,
                  showHint: hint))
          .entries
          .add(GroupEntry(it, guess.number));
    } else {
      final dir = p.dirname(it.relativePath.replaceAll('\\', '/'));
      final key = '${it.folderId}|f|${dir.toLowerCase()}';
      final label = dir == '.' ? '(library root)' : dir;
      byKey
          .putIfAbsent(
              key,
              () => UnsortedGroup(
                  key: key,
                  label: label,
                  numberedByName: false,
                  showHint: hint))
          .entries
          .add(GroupEntry(it, 0));
    }
  }

  final groups = <UnsortedGroup>[];
  final singles = <UnsortedItem>[];
  for (final g in byKey.values) {
    if (g.entries.length < 2) {
      singles.addAll(g.entries.map((e) => e.item));
      continue;
    }
    if (g.numberedByName) {
      g.entries.sort((a, b) => a.number.compareTo(b.number));
    } else {
      g.entries.sort(
          (a, b) => naturalCompare(a.item.relativePath, b.item.relativePath));
      for (var i = 0; i < g.entries.length; i++) {
        g.entries[i] = GroupEntry(g.entries[i].item, i + 1);
      }
    }
    groups.add(g);
  }
  groups.sort((a, b) => naturalCompare(a.label, b.label));
  singles.sort((a, b) => naturalCompare(a.relativePath, b.relativePath));
  return UnsortedGrouping(groups, singles);
}
