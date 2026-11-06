import 'package:flutter/material.dart';

import '../data/database.dart';
import '../player/player_page.dart';
import '../watch/watch_logic.dart';

/// Opens the player for [e], resuming from the saved position unless
/// [fromStart] is set. Progress is saved back to the database.
Future<void> openEpisode(
  BuildContext context,
  AppDatabase db,
  Show show,
  Episode e, {
  bool fromStart = false,
}) {
  final resumeMs = fromStart ? 0 : resumePositionMs(e.positionMs, e.durationMs);
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlayerPage(
        initialPath: e.filePath,
        title: episodeTitle(show, e),
        db: db,
        episodeId: e.id,
        startAt: resumeMs > 0 ? Duration(milliseconds: resumeMs) : null,
      ),
    ),
  );
}

String formatDurationMs(int ms) {
  final d = Duration(milliseconds: ms);
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Title line shown in the player: `Show  S1E3 \u00b7 Episode title`.
String episodeTitle(Show show, Episode e) {
  final name = e.tmdbTitle ?? e.title;
  return '${show.tmdbName ?? show.name}  S${e.season}E${e.episode}${name != null ? ' \u00b7 $name' : ''}';
}
