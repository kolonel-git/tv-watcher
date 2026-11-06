import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../metadata/metadata_service.dart';
import '../player/player_page.dart';
import 'artwork.dart';
import 'rematch_dialog.dart';

/// First real season if present, else specials (0).
int defaultSeason(List<int> seasons) =>
    seasons.firstWhere((s) => s > 0, orElse: () => seasons.first);

/// Show page: backdrop hero, synopsis, season selector, episode cards.
class ShowPage extends StatefulWidget {
  const ShowPage(
      {super.key, required this.db, required this.meta, required this.showId});
  final AppDatabase db;
  final MetadataService? meta;
  final int showId;

  @override
  State<ShowPage> createState() => _ShowPageState();
}

class _ShowPageState extends State<ShowPage> {
  int? _season; // user's choice; null = default

  AppDatabase get db => widget.db;

  void _play(Show show, Episode e) {
    final name = e.tmdbTitle ?? e.title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          initialPath: e.filePath,
          title:
              '${show.tmdbName ?? show.name}  S${e.season}E${e.episode}${name != null ? ' · $name' : ''}',
        ),
      ),
    );
  }

  Future<void> _menu(String v, Show show) async {
    final meta = widget.meta!;
    if (v == 'rematch') {
      await showDialog(
          context: context,
          builder: (_) => RematchDialog(meta: meta, show: show));
    } else if (v == 'refresh') {
      try {
        await meta.refresh(show.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refresh failed (offline?)')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Show>(
      stream: db.watchShow(widget.showId),
      builder: (context, showSnap) {
        final show = showSnap.data;
        if (show == null) return const Scaffold();
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (widget.meta != null)
                PopupMenuButton<String>(
                  onSelected: (v) => _menu(v, show),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rematch', child: Text('Re-match...')),
                    PopupMenuItem(
                        value: 'refresh', child: Text('Refresh metadata')),
                  ],
                ),
            ],
          ),
          body: StreamBuilder<List<Episode>>(
            stream: db.watchEpisodesOfShow(widget.showId),
            builder: (context, snap) {
              final eps = snap.data ?? const <Episode>[];
              final seasons =
                  ({for (final e in eps) e.season ?? 0}.toList()..sort());
              final season = seasons.isEmpty
                  ? null
                  : (seasons.contains(_season)
                      ? _season!
                      : defaultSeason(seasons));
              final shown = [
                for (final e in eps)
                  if ((e.season ?? 0) == season) e
              ];
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Hero(
                    show: show,
                    episodeCount: eps.length,
                    seasonCount: seasons.where((s) => s > 0).length,
                    onPlay: shown.isEmpty ? null : () => _play(show, shown.first),
                    playLabel: shown.isEmpty
                        ? 'Play'
                        : 'Play S${shown.first.season}E${shown.first.episode}',
                  ),
                  if (seasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
                      child: Row(children: [
                        Text('Episodes',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: season,
                              borderRadius: BorderRadius.circular(6),
                              items: [
                                for (final s in seasons)
                                  DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                          s == 0 ? 'Specials' : 'Season $s')),
                              ],
                              onChanged: (v) => setState(() => _season = v),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  for (final e in shown)
                    _EpisodeCard(episode: e, onTap: () => _play(show, e)),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
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
      child: Stack(fit: StackFit.expand, children: [
        ArtworkImage(
            path: show.backdropFile, cacheWidth: 1600, placeholderIcon: Icons.tv),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg.withValues(alpha: 0.2), bg.withValues(alpha: 0.6), bg],
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
              Text(show.tmdbName ?? show.name,
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(meta,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70)),
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
      ]),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({required this.episode, required this.onTap});
  final Episode episode;
  final VoidCallback onTap;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.episode;
    final theme = Theme.of(context);
    final name = e.tmdbTitle ?? e.title;
    final number = e.endEpisode != null
        ? '${e.episode}-${e.endEpisode}'
        : '${e.episode}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (v) => setState(() => _hover = v),
        child: Container(
          color: _hover ? const Color(0xFF16161D) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 56,
              height: 126,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(number,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 224,
                height: 126,
                child: Stack(fit: StackFit.expand, children: [
                  ArtworkImage(
                      path: e.stillFile,
                      cacheWidth: 448,
                      placeholderIcon: Icons.movie_outlined),
                  AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      color: Colors.black45,
                      child: const Icon(Icons.play_circle_outline, size: 48),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name ?? 'Episode ${e.episode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium),
                    ),
                    if (e.runtime != null)
                      Text('  ${e.runtime} min',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    e.overview ?? p.basename(e.filePath),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
