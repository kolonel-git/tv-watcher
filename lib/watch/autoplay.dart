// Pure state machine for the "Next episode" card: when it appears, how the
// countdown runs, and when it is cancelled. The player feeds it position
// updates and one tick per second; it holds no timers itself.

class AutoplayState {
  AutoplayState({
    this.leadMs = 30000,
    this.countdownSeconds = 10,
    this.minDurationMs = 120000,
  });

  /// The card appears when this much (or less) of the episode remains.
  int leadMs;

  /// Seconds shown on the countdown before the next episode starts.
  final int countdownSeconds;

  /// Shorter media never offers a next episode (clips, trailers).
  final int minDurationMs;

  bool cancelled = false;
  int? secondsLeft;

  bool get showing => secondsLeft != null;

  void reset() {
    cancelled = false;
    secondsLeft = null;
  }

  /// User dismissed the card: no autoplay for the rest of this episode.
  void cancel() {
    cancelled = true;
    secondsLeft = null;
  }

  /// Feed playback position. Returns true if the card visibility changed.
  bool onPosition({
    required int positionMs,
    required int durationMs,
    required bool hasNext,
  }) {
    if (!hasNext || cancelled || durationMs < minDurationMs) {
      if (showing) {
        secondsLeft = null;
        return true;
      }
      return false;
    }
    final remaining = durationMs - positionMs;
    if (remaining <= leadMs) {
      if (!showing) {
        secondsLeft = countdownSeconds;
        return true;
      }
      return false;
    }
    // User sought back well before the lead window: hide the card again.
    if (showing && remaining > leadMs + 5000) {
      secondsLeft = null;
      return true;
    }
    return false;
  }

  /// Call once per second while playing. Returns true when the countdown
  /// has finished and the next episode should start now.
  bool tick() {
    final s = secondsLeft;
    if (s == null) return false;
    if (s <= 1) {
      secondsLeft = 0;
      return true;
    }
    secondsLeft = s - 1;
    return false;
  }
}
