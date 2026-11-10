import 'dart:async';

/// Decides when a freshly opened file's position may be trusted.
///
/// After opening, the player briefly reports stale values (the previous
/// episode's end, or 0 before the resume seek lands). Saving those would
/// overwrite real progress and could trigger autoplay for the wrong file.
/// A file is *armed* once it reports a position in its first part, and the
/// resume point is *reached* once playback is near the requested start.
class ProgressGate {
  ProgressGate({
    required this.startTolerance,
    required this.startGuard,
    required this.armedBelowFraction,
  });

  final Duration startTolerance;
  final Duration startGuard;
  final double armedBelowFraction;

  bool _armed = false;
  bool _reachedStart = true;
  Duration? _pendingStart;
  Timer? _guard;

  bool get armed => _armed;
  bool get reachedStart => _reachedStart;

  /// Safe to write progress or start autoplay.
  bool get trusted => _armed && _reachedStart;

  /// Call when a file is opened. [start] is the resume point, if any.
  void begin(Duration? start) {
    final resume = start != null && start > Duration.zero;
    _armed = false;
    _reachedStart = !resume;
    _pendingStart = resume ? start : null;
    _guard?.cancel();
    if (resume) {
      // Fallback if the seek never reports (e.g. unusual container).
      _guard = Timer(startGuard, () => _reachedStart = true);
    }
  }

  /// Feed every position update. Returns true the moment the file becomes
  /// armed (so the caller can apply remembered tracks).
  bool onPosition(Duration position, Duration duration) {
    final pending = _pendingStart;
    if (!_reachedStart &&
        pending != null &&
        position >= pending - startTolerance) {
      _reachedStart = true;
    }
    final durMs = duration.inMilliseconds;
    if (!_armed &&
        durMs > 0 &&
        position.inMilliseconds < durMs * armedBelowFraction) {
      _armed = true;
      return true;
    }
    return false;
  }

  void dispose() => _guard?.cancel();
}
