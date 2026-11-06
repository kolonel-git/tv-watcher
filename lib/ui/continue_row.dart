import 'package:flutter/material.dart';

import '../data/database.dart';
import 'artwork.dart';
import 'play.dart';

/// Home row of shows in progress. Each card resumes the right episode.
class ContinueRow extends StatelessWidget {
  const ContinueRow({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContinueItem>>(
      stream: db.watchContinueWatching(),
      builder: (context, snap) {
        final items = snap.data ?? const <ContinueItem>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text('Continue watching',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, i) => ContinueCard(
                  item: items[i],
                  onTap: () => openEpisode(
                      context, db, items[i].show, items[i].episode),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ContinueCard extends StatefulWidget {
  const ContinueCard({super.key, required this.item, required this.onTap});
  final ContinueItem item;
  final VoidCallback onTap;

  @override
  State<ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<ContinueCard> {
  bool _active = false;

  void _set(bool v) {
    if (_active != v) setState(() => _active = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final e = item.episode;
    final resuming = item.resumeMs > 0;
    final progress = (resuming && e.durationMs > 0)
        ? (e.positionMs / e.durationMs).clamp(0.0, 1.0)
        : 0.0;
    final name = e.tmdbTitle ?? e.title;
    final image =
        artworkFile(e.stillFile) != null ? e.stillFile : item.show.backdropFile;

    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: AnimatedScale(
        scale: _active ? 1.04 : 1,
        duration: const Duration(milliseconds: 140),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: _set,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 256,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 144,
                    child: Stack(fit: StackFit.expand, children: [
                      ArtworkImage(
                          path: image,
                          cacheWidth: 512,
                          placeholderLabel: item.show.tmdbName ?? item.show.name),
                      AnimatedOpacity(
                        opacity: _active ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          color: Colors.black45,
                          child:
                              const Icon(Icons.play_circle_outline, size: 52),
                        ),
                      ),
                      if (progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.black54,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.show.tmdbName ?? item.show.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'S${e.season}E${e.episode}${name != null ? ' · $name' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                Text(
                  resuming
                      ? 'Resume at ${formatDurationMs(item.resumeMs)}'
                      : 'Up next',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
