import 'package:path/path.dart' as p;

/// Result of parsing one media file path. Pure logic, no I/O.
class ParsedEpisode {
  const ParsedEpisode({
    required this.showName,
    required this.season,
    required this.episode,
    this.endEpisode,
    this.year,
    this.title,
  });

  final String showName;
  final int season;
  final int episode;

  /// Set for multi-episode files like S01E01E02 / S01E01-E03.
  final int? endEpisode;
  final int? year;

  /// Episode title found in the filename after the marker, if any.
  /// Not part of equality.
  final String? title;

  /// Grouping key: lowercase alphanumerics, no year.
  String get showKey => showKeyFor(showName);

  static String showKeyFor(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  @override
  String toString() =>
      'ParsedEpisode($showName, S$season E$episode${endEpisode != null ? '-$endEpisode' : ''}'
      '${year != null ? ', $year' : ''})';

  @override
  bool operator ==(Object other) =>
      other is ParsedEpisode &&
      other.showName == showName &&
      other.season == season &&
      other.episode == episode &&
      other.endEpisode == endEpisode &&
      other.year == year;

  @override
  int get hashCode => Object.hash(showName, season, episode, endEpisode, year);
}

const videoExtensions = {
  '.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v', '.webm', '.flv', '.ts',
  '.m2ts', '.mpg', '.mpeg',
};

bool isVideoFile(String path) =>
    videoExtensions.contains(p.extension(path).toLowerCase());

// S01E02, s1e2, S01 E02, S01.E02, S01E02E03, S01E02-E03, S01E02-03
final _sxxexx = RegExp(
  r'(?<![a-z0-9])s(\d{1,2})[ ._-]?e(\d{1,3})(?:[ ._-]?(?:e|-e?)(\d{1,3}))?(?!\d)',
  caseSensitive: false,
);

// 1x01, 01x02 (not 1920x1080)
final _nxnn = RegExp(r'(?<!\d)(\d{1,2})x(\d{2,3})(?!\d)', caseSensitive: false);

// "Episode 3", "Ep 3", "Ep.03", "E03"
final _epOnly = RegExp(
  r'(?<![a-z0-9])(?:episode|ep|e)[ ._-]?(\d{1,3})(?!\d)',
  caseSensitive: false,
);

// Folder that is only a season marker: "Season 1", "Season 01", "S01", "Series 2"
final _seasonFolder = RegExp(
  r'^(?:season|series|s)[ ._-]?(\d{1,2})$',
  caseSensitive: false,
);

// Folder like "Show Name Season 2" / "Show Name - S02"
final _showSeasonFolder = RegExp(
  r'^(.*?)[ ._-]+(?:season|series|s)[ ._-]?(\d{1,2})$',
  caseSensitive: false,
);

final _year = RegExp(r'[\[(. ]((?:19|20)\d{2})[\])]?(?=[ .\])]|$)');

/// Parses [relativePath] (path relative to the library root, using either
/// separator). Returns null when show/season/episode cannot be determined,
/// which sends the file to Unsorted.
ParsedEpisode? parseEpisodePath(String relativePath) {
  final parts = relativePath
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  final fileName = parts.last;
  final base = p.basenameWithoutExtension(fileName);
  final folders = parts.sublist(0, parts.length - 1);

  int? season;
  int? episode;
  int? endEpisode;
  String? namePrefix; // filename text before the episode marker
  String rest = ''; // filename text after the episode marker

  final m1 = _sxxexx.firstMatch(base);
  final m2 = m1 == null ? _nxnn.firstMatch(base) : null;
  if (m1 != null) {
    season = int.parse(m1.group(1)!);
    episode = int.parse(m1.group(2)!);
    endEpisode = m1.group(3) != null ? int.parse(m1.group(3)!) : null;
    namePrefix = base.substring(0, m1.start);
    rest = base.substring(m1.end);
  } else if (m2 != null) {
    season = int.parse(m2.group(1)!);
    episode = int.parse(m2.group(2)!);
    namePrefix = base.substring(0, m2.start);
    rest = base.substring(m2.end);
  }

  // Season/show hints from folders (nearest first).
  int? folderSeason;
  String? folderShow;
  for (var i = folders.length - 1; i >= 0; i--) {
    final f = folders[i];
    final sm = _seasonFolder.firstMatch(f.trim());
    if (sm != null) {
      folderSeason ??= int.parse(sm.group(1)!);
      continue;
    }
    final ssm = _showSeasonFolder.firstMatch(f.trim());
    if (ssm != null && _clean(ssm.group(1)!).isNotEmpty) {
      folderSeason ??= int.parse(ssm.group(2)!);
      folderShow = ssm.group(1);
      break;
    }
    folderShow = f;
    break;
  }

  if (episode == null) {
    // "Season 1/Episode 3.mkv" style: needs season from a folder.
    final me = _epOnly.firstMatch(base);
    if (me != null && folderSeason != null) {
      season = folderSeason;
      episode = int.parse(me.group(1)!);
      namePrefix = base.substring(0, me.start);
      rest = base.substring(me.end);
    } else {
      return null;
    }
  }

  // Filename season marker wins; fall back to folder season.
  season ??= folderSeason;
  if (season == null) return null;

  var rawShow = _clean(namePrefix ?? '');
  if (rawShow.isEmpty) rawShow = _clean(folderShow ?? '');
  if (rawShow.isEmpty) return null;

  final yearMatch = _year.firstMatch(rawShow);
  int? year;
  if (yearMatch != null && yearMatch.start > 0) {
    year = int.parse(yearMatch.group(1)!);
    rawShow = _clean(rawShow.substring(0, yearMatch.start));
    if (rawShow.isEmpty) return null;
  }

  return ParsedEpisode(
    showName: rawShow,
    season: season,
    episode: episode,
    endEpisode: endEpisode,
    year: year,
    title: _title(rest),
  );
}

/// Dots/underscores to spaces, strip release-group brackets and trailing
/// separators.
String _clean(String s) {
  var out = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' '); // [Group] [1080p]
  out = out.replaceAll(RegExp(r'[._]+'), ' ');
  out = out.replaceAll(RegExp(r'\s*-\s*$'), '');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  out = out.replaceAll(RegExp(r'[\s\-]+$'), '');
  return out;
}

final _qualityToken = RegExp(
  r'(?<![a-z0-9])(?:480p|576p|720p|1080p|2160p|4k|web-?rip|web-?dl|blu-?ray|brrip|dvdrip|hdtv|hdrip|x264|x265|h\.?264|h\.?265|hevc|xvid|proper|repack)(?![a-z0-9])',
  caseSensitive: false,
);

/// Episode title from the text after the SxxExx marker, e.g.
/// " - Pilot [Bluray-1080p]-GRP" -> "Pilot".
String? _title(String rest) {
  var t = rest;
  final bracket = t.indexOf('[');
  if (bracket >= 0) t = t.substring(0, bracket);
  // Dotted/underscored names: "Pilot.1080p.BluRay" -> spaces first.
  if (!t.contains(' ')) t = t.replaceAll(RegExp(r'[._]+'), ' ');
  final q = _qualityToken.firstMatch(t);
  if (q != null) t = t.substring(0, q.start);
  t = t.replaceFirst(RegExp(r'^[\s._-]+'), '');
  t = t.replaceFirst(RegExp(r'[\s._-]+$'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.isEmpty ? null : t;
}
