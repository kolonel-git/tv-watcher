import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import 'artwork.dart';
import 'theme.dart';

/// One episode row: still, title, progress, watched toggle and menu.
class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    super.key,
    required this.episode,
    required this.onTap,
    required this.onPlayFromStart,
    required this.onToggleWatched,
    required this.onClearMeta,
    required this.onMarkPreviousWatched,
    required this.onUnsort,
    required this.onLongPress,
    required this.selecting,
    required this.selected,
    this.onRefetchMeta,
  });
  final Episode episode;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback onMarkPreviousWatched;
  final VoidCallback onUnsort;
  final VoidCallback onTap;
  final VoidCallback onPlayFromStart;
  final VoidCallback onToggleWatched;
  final VoidCallback onClearMeta;
  final VoidCallback? onRefetchMeta;

  @override
  State<EpisodeCard> createState() => EpisodeCardState();
}

class EpisodeCardState extends State<EpisodeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.episode;
    final theme = Theme.of(context);
    final name = e.tmdbTitle ?? e.title;
    final progress = (e.positionMs > 0 && e.durationMs > 0)
        ? (e.positionMs / e.durationMs).clamp(0.0, 1.0)
        : 0.0;
    final number = e.endEpisode != null
        ? '${e.episode}-${e.endEpisode}'
        : '${e.episode}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (v) => setState(() => _hover = v),
        child: Container(
          color: widget.selected
              ? Ui.selected
              : (_hover ? Ui.surfaceHover : Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                height: 126,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.selecting
                      ? Checkbox(
                          value: widget.selected,
                          onChanged: (_) => widget.onTap(),
                        )
                      : Text(
                          number,
                          maxLines: 1,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Ui.dim,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 224,
                  height: 126,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: e.watched ? 0.55 : 1,
                        child: ArtworkImage(
                          path: e.stillFile,
                          cacheWidth: 448,
                          placeholderIcon: Icons.movie_outlined,
                        ),
                      ),
                      if (e.watched)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: Colors.white,
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
                      AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          color: Colors.black45,
                          child: const Icon(
                            Icons.play_circle_outline,
                            size: 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name ?? 'Episode ${e.episode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (e.runtime != null)
                          Text(
                            '  ${e.runtime} min',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Ui.dim,
                            ),
                          ),
                        IconButton(
                          tooltip: e.watched
                              ? 'Mark unwatched'
                              : 'Mark watched',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            e.watched
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 20,
                            color: e.watched ? Ui.text : Ui.dim,
                          ),
                          onPressed: widget.onToggleWatched,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Episode actions',
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (v) {
                            if (v == 'toggle') widget.onToggleWatched();
                            if (v == 'previous') widget.onMarkPreviousWatched();
                            if (v == 'unsort') widget.onUnsort();
                            if (v == 'select') widget.onLongPress();
                            if (v == 'start') widget.onPlayFromStart();
                            if (v == 'clear') widget.onClearMeta();
                            if (v == 'refetch') widget.onRefetchMeta?.call();
                          },
                          itemBuilder: (_) => [
                            if (e.positionMs > 0)
                              const PopupMenuItem(
                                value: 'start',
                                child: Text('Play from start'),
                              ),
                            if (e.positionMs > 0) const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'previous',
                              child: Text('Mark all previous watched'),
                            ),
                            const PopupMenuItem(
                              value: 'select',
                              child: Text('Select'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Clear metadata'),
                            ),
                            if (widget.onRefetchMeta != null)
                              const PopupMenuItem(
                                value: 'refetch',
                                child: Text('Re-fetch metadata'),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'unsort',
                              child: Text('Move to Unsorted'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.overview ?? p.basename(e.filePath),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Ui.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
