import 'package:flutter/material.dart';

import '../data/database.dart';
import '../player/player_page.dart';
import '../settings/settings_controller.dart';
import '../settings/user_settings.dart';
import '../watch/watch_logic.dart';

/// Opens the player for [e], resuming from the saved position unless
/// [fromStart] is set. Progress is saved back to the database.
Future<void> openEpisode(
  BuildContext context,
  AppDatabase db,
  Show show,
  Episode e, {
  bool fromStart = false,
}) async {
  final settings = SettingsScope.of(context);
  var resumeMs = fromStart || settings.resume == ResumeBehavior.restart
      ? 0
      : resumePositionMs(
          e.positionMs,
          e.durationMs,
          threshold: settings.watchedFraction,
        );
  if (resumeMs > 0 && settings.resume == ResumeBehavior.ask) {
    final resume = await askResume(context, Duration(milliseconds: resumeMs));
    if (resume == null) return; // dismissed: do not play
    if (!resume) resumeMs = 0;
  }
  if (!context.mounted) return;
  await Navigator.push(
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

/// 'Ask each time' resume behaviour. True = resume, false = start over,
/// null = dismissed (nothing plays).
Future<bool?> askResume(BuildContext context, Duration at) => showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Resume playback?'),
    content: Text('You stopped at ${formatDurationMs(at.inMilliseconds)}.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Start over'),
      ),
      FilledButton(
        autofocus: true,
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Resume'),
      ),
    ],
  ),
);

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
