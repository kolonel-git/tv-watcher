import 'package:media_kit/media_kit.dart';

import '../tracks/external_subs.dart';
import '../tracks/track_prefs.dart';

/// Read-only view of the audio and subtitle tracks of the current file.
/// Hides mpv's pseudo tracks ('auto', 'no') and the external-file entries so
/// the page, the settings panel and the V/B shortcuts all agree on what a
/// "real" track is.
class TrackCatalog {
  const TrackCatalog(this._player);
  final Player _player;

  static bool _isReal(String id) => id != 'auto' && id != 'no';

  List<AudioTrack> get audio => [
    for (final t in _player.state.tracks.audio)
      if (_isReal(t.id)) t,
  ];

  /// Embedded subtitle tracks only (external files are listed separately).
  List<SubtitleTrack> get embeddedSubtitles => [
    for (final t in _player.state.tracks.subtitle)
      if (_isReal(t.id) && !t.uri) t,
  ];

  static TrackInfo audioInfo(AudioTrack t) => TrackInfo(
    id: t.id,
    title: t.title,
    language: t.language,
    isDefault: t.isDefault ?? false,
  );

  static TrackInfo subtitleInfo(SubtitleTrack t) => TrackInfo(
    id: t.id,
    title: t.title,
    language: t.language,
    isDefault: t.isDefault ?? false,
  );

  static TrackInfo externalInfo(ExternalSub e) => TrackInfo(
    id: e.path,
    title: e.title,
    language: e.language,
    isExternal: true,
  );

  List<TrackInfo> get audioInfos => [for (final t in audio) audioInfo(t)];
  List<TrackInfo> get subtitleInfos => [
    for (final t in embeddedSubtitles) subtitleInfo(t),
  ];

  /// V key: the track after the current one, or null meaning "turn off"
  /// (after the last one). Null when the file has no subtitle tracks, see
  /// [hasSubtitles].
  bool get hasSubtitles => embeddedSubtitles.isNotEmpty;

  SubtitleTrack? nextSubtitle() {
    final tracks = embeddedSubtitles;
    final cur = _player.state.track.subtitle;
    final i = cur.id == 'no' ? -1 : tracks.indexWhere((t) => t.id == cur.id);
    return i + 1 >= tracks.length ? null : tracks[i + 1];
  }

  /// B key: the next audio track, wrapping. Null with fewer than two.
  AudioTrack? nextAudio() {
    final tracks = audio;
    if (tracks.length < 2) return null;
    final cur = _player.state.track.audio;
    final i = tracks.indexWhere((t) => t.id == cur.id);
    return tracks[(i + 1) % tracks.length];
  }
}
