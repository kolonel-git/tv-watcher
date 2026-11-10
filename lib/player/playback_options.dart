import 'package:flutter/painting.dart' show BoxFit;

/// How the picture is fitted to the window.
enum AspectMode {
  auto('Auto (original)', '-1', BoxFit.contain),
  wide16x9('16:9', '16:9', BoxFit.contain),
  classic4x3('4:3', '4:3', BoxFit.contain),
  ultra21x9('21:9', '21:9', BoxFit.contain),
  zoom('Zoom to fill (crops)', '-1', BoxFit.cover);

  const AspectMode(this.label, this.mpvValue, this.fit);
  final String label;

  /// mpv `video-aspect-override`; `-1` leaves the file's own ratio.
  final String mpvValue;

  /// How the video widget scales the picture into the window.
  final BoxFit fit;
}

/// Per-session playback tweaks: speed, subtitle and audio delay, aspect.
///
/// Pure and immutable so the rules (ladder, limits, formatting) are unit
/// tested without a player. Not saved: speed carries over between episodes
/// of one viewing, while delays and aspect are per file and reset on open
/// (see DECISIONS D20).
class PlaybackOptions {
  const PlaybackOptions({
    this.speed = 1.0,
    this.subtitleDelayMs = 0,
    this.audioDelayMs = 0,
    this.aspect = AspectMode.auto,
  });

  static const defaults = PlaybackOptions();

  /// Speeds offered by `[` and `]` and the panel.
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// Step of the Z / X keys and the panel steppers.
  static const delayStepMs = 100;

  /// Delays are limited to +-30 s: beyond that the file is wrong, not the
  /// timing.
  static const maxDelayMs = 30000;

  final double speed;
  final int subtitleDelayMs;
  final int audioDelayMs;
  final AspectMode aspect;

  bool get isDefault =>
      speed == 1.0 &&
      subtitleDelayMs == 0 &&
      audioDelayMs == 0 &&
      aspect == AspectMode.auto;

  PlaybackOptions copyWith({
    double? speed,
    int? subtitleDelayMs,
    int? audioDelayMs,
    AspectMode? aspect,
  }) => PlaybackOptions(
    speed: speed ?? this.speed,
    subtitleDelayMs: _clampDelay(subtitleDelayMs ?? this.subtitleDelayMs),
    audioDelayMs: _clampDelay(audioDelayMs ?? this.audioDelayMs),
    aspect: aspect ?? this.aspect,
  );

  static int _clampDelay(int v) => v.clamp(-maxDelayMs, maxDelayMs);

  /// Next speed on the ladder above the current one (stays at the top).
  PlaybackOptions faster() {
    for (final s in speeds) {
      if (s > speed + 1e-9) return copyWith(speed: s);
    }
    return this;
  }

  /// Next speed on the ladder below the current one (stays at the bottom).
  PlaybackOptions slower() {
    for (final s in speeds.reversed) {
      if (s < speed - 1e-9) return copyWith(speed: s);
    }
    return this;
  }

  /// Per-file options after opening a new file: speed is kept, the rest
  /// returns to default.
  PlaybackOptions forNewFile() => PlaybackOptions(speed: speed);

  /// `1.25x`, `1x`.
  static String speedLabel(double s) =>
      '${s == s.roundToDouble() ? s.toStringAsFixed(0) : s}x';

  /// `+0.3 s`, `-1.2 s`, `0 s`.
  static String delayLabel(int ms) {
    if (ms == 0) return '0 s';
    final sign = ms > 0 ? '+' : '-';
    return '$sign${(ms.abs() / 1000).toStringAsFixed(1)} s';
  }

  /// mpv wants seconds.
  static String delaySeconds(int ms) => (ms / 1000).toStringAsFixed(3);

  @override
  bool operator ==(Object other) =>
      other is PlaybackOptions &&
      other.speed == speed &&
      other.subtitleDelayMs == subtitleDelayMs &&
      other.audioDelayMs == audioDelayMs &&
      other.aspect == aspect;

  @override
  int get hashCode => Object.hash(speed, subtitleDelayMs, audioDelayMs, aspect);
}
