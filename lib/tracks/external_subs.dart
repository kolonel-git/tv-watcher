import 'dart:io';

import 'package:path/path.dart' as p;

import 'languages.dart';

const subtitleExtensions = {'.srt', '.ass', '.ssa', '.vtt', '.sub'};

/// A subtitle file found next to a video. Read-only: files are never touched.
class ExternalSub {
  const ExternalSub({required this.path, this.language, this.title});
  final String path;
  final String? language;
  final String? title;
}

const _flagWords = {
  'forced': 'Forced',
  'sdh': 'SDH',
  'cc': 'CC',
  'hi': 'HI',
  'commentary': 'Commentary',
  'signs': 'Signs',
  'songs': 'Songs',
};

final _tokenSplit = RegExp(r'[.\-_ \[\]()]+');

bool isSubtitleFile(String path) =>
    subtitleExtensions.contains(p.extension(path).toLowerCase());

({String? language, String? title}) _parseTokens(String text) {
  String? lang;
  final flags = <String>[];
  for (final raw in text.split(_tokenSplit)) {
    final tok = raw.trim();
    if (tok.isEmpty || RegExp(r'^\d+$').hasMatch(tok)) continue;
    final lower = tok.toLowerCase();
    if (_flagWords.containsKey(lower)) {
      flags.add(_flagWords[lower]!);
    } else if (lang == null && isKnownLanguage(tok)) {
      lang = normalizeLang(tok);
    }
  }
  return (language: lang, title: flags.isEmpty ? null : flags.join(' '));
}

/// Matches a subtitle file against a video's base name (no extension).
///
/// A subtitle belongs to the video when its name equals the video's base
/// name or continues it after a separator: `Show.S01E01.en.forced.srt`.
/// Returns null for non-subtitle files and other episodes.
ExternalSub? matchSubtitleName({
  required String videoBase,
  required String path,
}) {
  if (!isSubtitleFile(path)) return null;
  final name = p.basenameWithoutExtension(path);
  final v = videoBase.toLowerCase();
  final n = name.toLowerCase();
  if (!n.startsWith(v)) return null;
  final rest = name.substring(videoBase.length);
  if (rest.isNotEmpty && !RegExp(r'^[.\-_ \[(]').hasMatch(rest)) return null;
  final parsed = _parseTokens(rest);
  return ExternalSub(
    path: path,
    language: parsed.language,
    title: parsed.title,
  );
}

/// For files inside a `Subs/<video name>/` folder: names like `2_English.srt`.
ExternalSub? matchLooseSubtitleName(String path) {
  if (!isSubtitleFile(path)) return null;
  final parsed = _parseTokens(p.basenameWithoutExtension(path));
  return ExternalSub(
    path: path,
    language: parsed.language,
    title: parsed.title,
  );
}

const _subDirNames = {'subs', 'sub', 'subtitles', 'subtitle'};

/// Lists subtitle files for [videoPath]: same folder, plus `Subs`/`Subtitles`
/// folders (and `Subs/<video name>/`). Non-recursive beyond that.
Future<List<ExternalSub>> findExternalSubtitles(String videoPath) async {
  final found = <ExternalSub>[];
  try {
    final dir = File(videoPath).parent;
    final base = p.basenameWithoutExtension(videoPath);

    Future<void> scan(
      Directory d, {
      required bool loose,
      bool nameMustMatch = true,
    }) async {
      await for (final e in d.list(followLinks: false)) {
        if (e is File) {
          final m = loose
              ? matchLooseSubtitleName(e.path)
              : matchSubtitleName(videoBase: base, path: e.path);
          if (m != null) found.add(m);
        }
      }
    }

    await scan(dir, loose: false);

    await for (final e in dir.list(followLinks: false)) {
      if (e is! Directory) continue;
      final dn = p.basename(e.path).toLowerCase();
      if (!_subDirNames.contains(dn)) continue;
      await scan(e, loose: false);
      // Subs/<video name>/*.srt
      await for (final sub in e.list(followLinks: false)) {
        if (sub is Directory &&
            p.basename(sub.path).toLowerCase() == base.toLowerCase()) {
          await scan(sub, loose: true);
        }
      }
    }
  } on FileSystemException {
    // Unreadable folder: just no external subtitles.
  }
  final seen = <String>{};
  found.retainWhere((s) => seen.add(s.path.toLowerCase()));
  found.sort((a, b) {
    final c = (a.language ?? '~').compareTo(b.language ?? '~');
    return c != 0 ? c : a.path.compareTo(b.path);
  });
  return found;
}
