import 'package:flutter/material.dart';

import '../data/database.dart';
import 'artwork.dart';
import 'theme.dart';

/// Backdrop, title, meta line, synopsis and the main Play button.
class ShowHero extends StatelessWidget {
  const ShowHero({
    super.key,
    required this.show,
    required this.episodeCount,
    required this.seasonCount,
    required this.onPlay,
    required this.playLabel,
  });
  final Show show;
  final int episodeCount;
  final int seasonCount;
  final VoidCallback? onPlay;
  final String playLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final meta = [
      if (show.year != null) '${show.year}',
      if (seasonCount > 0) '$seasonCount season${seasonCount == 1 ? '' : 's'}',
      '$episodeCount episodes',
    ].join('  ·  ');
    return SizedBox(
      height: 420,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtworkImage(
            path: show.backdropFile,
            cacheWidth: 1600,
            placeholderIcon: Icons.tv,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.2),
                  bg.withValues(alpha: 0.6),
                  bg,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [bg.withValues(alpha: 0.85), Colors.transparent],
                stops: const [0, 0.7],
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  show.tmdbName ?? show.name,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Ui.muted),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(
                    show.overview ??
                        (show.metaStatus == 'matched'
                            ? 'No synopsis available.'
                            : 'No metadata yet. Menu, Re-match, to pick the right show.'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(playLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
