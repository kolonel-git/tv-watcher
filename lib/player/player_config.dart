/// Every tunable number of the player in one immutable place, so nothing is
/// buried in widget code. Sprint 9b's settings screen will build one of these
/// from the database instead of using [defaults].
class PlayerConfig {
  const PlayerConfig({
    this.seekStep = const Duration(seconds: 10),
    this.volumeStep = 5,
    this.controlsHideDelay = const Duration(seconds: 3),
    this.controlsFade = const Duration(milliseconds: 200),
    this.progressSaveInterval = const Duration(seconds: 5),
    this.volumeSaveDebounce = const Duration(milliseconds: 400),
    this.startGuard = const Duration(seconds: 10),
    this.startTolerance = const Duration(seconds: 3),
    this.armedBelowFraction = 0.9,
    this.subBaseBottom = 28,
    this.barClearance = 84,
    this.bitmapSubPosVisible = 88,
    this.bitmapSubPosHidden = 100,
    this.subMaxWidthFraction = 0.8,
    this.nextCardBottomWithBar = 112,
    this.nextCardBottomNoBar = 32,
    this.defaultVolume = 100,
  });

  static const defaults = PlayerConfig();

  /// Arrow-key and button skip size.
  final Duration seekStep;

  /// Arrow-key volume change, in volume points (0-100).
  final double volumeStep;

  /// Idle time before the control bar hides.
  final Duration controlsHideDelay;
  final Duration controlsFade;

  /// How often the resume point is written while playing.
  final Duration progressSaveInterval;
  final Duration volumeSaveDebounce;

  /// Give up waiting for the resume seek to report after this long.
  final Duration startGuard;

  /// The resume point counts as reached within this distance.
  final Duration startTolerance;

  /// Media is "armed" (safe to save and autoplay) once its position is below
  /// this fraction of the duration, i.e. it is not stale from the last file.
  final double armedBelowFraction;

  /// Default distance of subtitles from the bottom edge, and the extra lift
  /// that keeps them above the control bar.
  final double subBaseBottom;
  final double barClearance;

  /// mpv `sub-pos` (percent of height) for picture subtitles, with the bar
  /// visible and hidden.
  final int bitmapSubPosVisible;
  final int bitmapSubPosHidden;
  final double subMaxWidthFraction;

  /// Position of the next-episode card above the bottom edge.
  final double nextCardBottomWithBar;
  final double nextCardBottomNoBar;

  /// Volume used when unmuting with nothing remembered.
  final double defaultVolume;
}
