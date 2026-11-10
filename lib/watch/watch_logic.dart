// Pure watch-state logic: progress thresholds, resume position, and the
// "what do I watch next" rules. No I/O, no database types.

/// Default share of an episode that counts as watched; the user can change
/// it in settings (the functions below take a `threshold`).
const double watchedThreshold = 0.90;

/// Positions earlier than this are not worth resuming from.
const int minResumeMs = 5000;

/// Minimal view of an episode for watch logic.
class EpRef {
  const EpRef({
    required this.id,
    required this.season,
    required this.episode,
    this.watched = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.lastPlayedAt,
  });

  final int id;
  final int season;
  final int episode;
  final bool watched;
  final int positionMs;
  final int durationMs;
  final DateTime? lastPlayedAt;

  bool get inProgress => positionMs > 0;
}

class ProgressUpdate {
  const ProgressUpdate({required this.positionMs, required this.watched});
  final int positionMs;
  final bool watched;

  @override
  bool operator ==(Object other) =>
      other is ProgressUpdate &&
      other.positionMs == positionMs &&
      other.watched == watched;
  @override
  int get hashCode => Object.hash(positionMs, watched);
  @override
  String toString() => 'ProgressUpdate($positionMs, watched: $watched)';
}

/// Decides what to store when playback stops/pauses/ticks at [positionMs].
///
/// - Unknown duration: nothing worth storing, keep state.
/// - At or past 90%: watched, position reset to 0 (next open starts over).
/// - Under 5s: no resume point (position 0), watched state unchanged.
/// - Otherwise: store the exact position; a rewatch keeps `watched`.
ProgressUpdate computeProgress({
  required int positionMs,
  required int durationMs,
  required bool wasWatched,
  double threshold = watchedThreshold,
}) {
  if (durationMs <= 0) {
    return ProgressUpdate(positionMs: 0, watched: wasWatched);
  }
  if (positionMs / durationMs >= threshold) {
    return const ProgressUpdate(positionMs: 0, watched: true);
  }
  if (positionMs < minResumeMs) {
    return ProgressUpdate(positionMs: 0, watched: wasWatched);
  }
  return ProgressUpdate(positionMs: positionMs, watched: wasWatched);
}

/// Position to start playback from for a stored value.
int resumePositionMs(
  int positionMs,
  int durationMs, {
  double threshold = watchedThreshold,
}) {
  if (positionMs < minResumeMs) return 0;
  if (durationMs > 0 && positionMs / durationMs >= threshold) return 0;
  return positionMs;
}

/// Episodes ordered by season then episode. Specials (season 0) go last.
List<EpRef> sortEpisodes(Iterable<EpRef> eps) {
  final list = eps.toList();
  list.sort((a, b) {
    final sa = a.season == 0 ? 1 << 30 : a.season;
    final sb = b.season == 0 ? 1 << 30 : b.season;
    final c = sa.compareTo(sb);
    return c != 0 ? c : a.episode.compareTo(b.episode);
  });
  return list;
}

/// The episode that plays after [current]: next in the season, otherwise the
/// first episode of the next season. Specials are skipped. Null at the end.
EpRef? nextInOrder(Iterable<EpRef> all, EpRef current) {
  final regular = sortEpisodes(all.where((e) => e.season != 0)).toList();
  if (current.season == 0) return null;
  final i = regular.indexWhere((e) => e.id == current.id);
  if (i < 0 || i + 1 >= regular.length) return null;
  return regular[i + 1];
}

class ContinueTarget {
  const ContinueTarget(this.episode, this.resumeMs, this.lastPlayed);
  final EpRef episode;

  /// 0 = start from the beginning.
  final int resumeMs;
  final DateTime lastPlayed;
}

/// What "Continue Watching" should play for one show, or null when the show
/// has no activity or is finished.
///
/// 1. An episode with a saved position wins (most recently played).
/// 2. Otherwise the first unwatched regular episode after the most recently
///    watched one (rolling over into the next season).
ContinueTarget? continueTarget(
  Iterable<EpRef> episodes, {
  double threshold = watchedThreshold,
}) {
  final all = episodes.toList();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final inProgress = all.where((e) => e.inProgress).toList();
  if (inProgress.isNotEmpty) {
    final order = sortEpisodes(all);
    inProgress.sort((a, b) {
      final c = (a.lastPlayedAt ?? epoch).compareTo(b.lastPlayedAt ?? epoch);
      return c != 0 ? c : order.indexOf(a).compareTo(order.indexOf(b));
    });
    final e = inProgress.last;
    return ContinueTarget(
      e,
      resumePositionMs(e.positionMs, e.durationMs, threshold: threshold),
      e.lastPlayedAt ?? epoch,
    );
  }

  final watched = all.where((e) => e.watched).toList();
  if (watched.isEmpty) return null;

  final order = sortEpisodes(all);
  watched.sort((a, b) {
    final c = (a.lastPlayedAt ?? epoch).compareTo(b.lastPlayedAt ?? epoch);
    return c != 0 ? c : order.indexOf(a).compareTo(order.indexOf(b));
  });
  final last = watched.last;

  final regular = sortEpisodes(all.where((e) => e.season != 0)).toList();
  final start = last.season == 0
      ? 0
      : regular.indexWhere((e) => e.id == last.id) + 1;
  for (var i = start; i < regular.length; i++) {
    if (!regular[i].watched) {
      return ContinueTarget(regular[i], 0, last.lastPlayedAt ?? epoch);
    }
  }
  return null;
}
