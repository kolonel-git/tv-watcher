import 'languages.dart';

/// Player-independent description of one audio or subtitle track.
class TrackInfo {
  const TrackInfo({
    required this.id,
    this.title,
    this.language,
    this.isExternal = false,
    this.isDefault = false,
  });

  final String id;
  final String? title;
  final String? language;
  final bool isExternal;
  final bool isDefault;

  /// "English", "English · Commentary", "Track 3".
  String label(int index) {
    final lang = languageName(language);
    final t = title?.trim();
    final parts = <String>[
      ?lang,
      if (t != null && t.isNotEmpty && t.toLowerCase() != lang?.toLowerCase())
        t,
    ];
    final base = parts.isEmpty ? 'Track ${index + 1}' : parts.join(' · ');
    return isExternal ? '$base (external)' : base;
  }
}

enum ChoiceMode { auto, off, track }

/// What the user last picked for a show, kind by kind (audio / subtitles).
class TrackChoice {
  const TrackChoice({
    this.mode = ChoiceMode.auto,
    this.language,
    this.title,
    this.external = false,
  });

  /// auto: leave the player default. off: subtitles off. track: match below.
  final ChoiceMode mode;
  final String? language;
  final String? title;
  final bool external;

  static const auto = TrackChoice();

  static TrackChoice fromTrack(TrackInfo t) => TrackChoice(
    mode: ChoiceMode.track,
    language: normalizeLang(t.language),
    title: t.title,
    external: t.isExternal,
  );

  @override
  String toString() => 'TrackChoice($mode, $language, $title, ext: $external)';
}

/// Finds the track in [available] that best matches [choice] (used to carry a
/// per-show pick over to the next episode). Null when nothing matches or the
/// choice is not a specific track.
///
/// Same language is required when the choice has one. Among those, an exact
/// title match wins, then the same embedded/external kind, then the first.
TrackInfo? pickTrack(List<TrackInfo> available, TrackChoice choice) {
  if (choice.mode != ChoiceMode.track) return null;
  final lang = normalizeLang(choice.language);
  final title = choice.title?.trim().toLowerCase();

  var candidates = available;
  if (lang != null) {
    candidates = available
        .where((t) => normalizeLang(t.language) == lang)
        .toList();
  } else if (title == null || title.isEmpty) {
    return null; // nothing to match on
  } else {
    candidates = available
        .where((t) => t.title?.trim().toLowerCase() == title)
        .toList();
  }
  if (candidates.isEmpty) return null;

  // Rank: exact title + same kind > exact title > same kind > first.
  int score(TrackInfo t) {
    var n = 0;
    if (title != null &&
        title.isNotEmpty &&
        t.title?.trim().toLowerCase() == title) {
      n += 2;
    }
    if (t.isExternal == choice.external) n += 1;
    return n;
  }

  TrackInfo best = candidates.first;
  for (final t in candidates) {
    if (score(t) > score(best)) best = t;
  }
  return best;
}

/// Subtitle codecs that are pictures, not text (Blu-ray PGS, DVD VobSub,
/// DVB). They can't be drawn as text, so mpv must render them itself.
bool isBitmapSubtitleCodec(String? codec) {
  final c = codec?.toLowerCase();
  if (c == null || c.isEmpty) return false;
  const bitmap = {
    'hdmv_pgs_subtitle',
    'pgssub',
    'pgs',
    'dvd_subtitle',
    'dvdsub',
    'vobsub',
    'dvb_subtitle',
    'dvbsub',
    'dvb_teletext',
    'xsub',
  };
  return bitmap.contains(c);
}
