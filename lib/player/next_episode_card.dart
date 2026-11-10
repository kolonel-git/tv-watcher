import 'package:flutter/material.dart';

import '../data/database.dart';
import '../ui/artwork.dart';
import '../ui/theme.dart';

/// Autoplay card: what plays next, a countdown, Play now and Cancel.
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.episode,
    required this.show,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onPlayNow,
    required this.onCancel,
  });

  final Episode episode;
  final Show? show;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = episode.tmdbTitle ?? episode.title;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Ui.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Ui.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT EPISODE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 104,
                  height: 58,
                  child: ArtworkImage(
                    path: episode.stillFile,
                    cacheWidth: 208,
                    placeholderIcon: Icons.movie_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S${episode.season}E${episode.episode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      name ?? 'Episode ${episode.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: totalSeconds == 0 ? 0 : secondsLeft / totalSeconds,
              minHeight: 3,
              backgroundColor: Colors.white12,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Starting in ${secondsLeft}s',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlayNow,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play now'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}
