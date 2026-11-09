import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'theme.dart';
import '../data/database.dart';
import '../metadata/metadata_service.dart';
import '../watch/watch_logic.dart';
import 'artwork.dart';
import 'play.dart';
import 'rematch_dialog.dart';

/// First real season if present, else specials (0).
int defaultSeason(List<int> seasons) =>
    seasons.firstWhere((s) => s > 0, orElse: () => seasons.first);

/// Show page: backdrop hero, synopsis, season selector, episode cards.
class ShowPage extends StatefulWidget {
  const ShowPage({
    super.key,
    required this.db,
    required this.meta,
    required this.showId,
  });
  final AppDatabase db;
  final MetadataService? meta;
  final int showId;

  @override
  State<ShowPage> createState() => _ShowPageState();
}

class _ShowPageState extends State<ShowPage> {
  int? _season; // user's choice; null = default

  // --- multi-select ---
  bool _selecting = false;
  final Set<int> _selected = {};
  int? _anchorId;
  bool _hideWatched = false;
  List<Episode> _eps = const []; // latest episodes of this show
  List<Episode> _shown = const []; // episodes visible in the current view

  AppDatabase get db => widget.db;

  // Created once; creating streams inside build resubscribes on every setState.
  late final Stream<Show> _showStream = db.watchShow(widget.showId);
  late final Stream<List<Episode>> _episodesStream = db.watchEpisodesOfShow(
    widget.showId,
  );

  void _play(Show show, Episode e, {bool fromStart = false}) =>
      openEpisode(context, db, show, e, fromStart: fromStart);

  Future<void> _menu(String v, Show show) async {
    if (v == 'show_watched' || v == 'show_unwatched') {
      final on = v == 'show_watched';
      await _undoable(
        on ? 'Marked whole show watched' : 'Marked whole show unwatched',
        _eps.map((e) => e.id),
        () => db.setShowWatched(show.id, on),
      );
      return;
    }
    if (v == 'select') {
      setState(() => _selecting = true);
      return;
    }
    if (v == 'clear_meta') {
      if (await _confirm(
        'Clear metadata?',
        'Removes the TMDB match, artwork, and episode details for this show. Your files and watch progress are untouched. Use Re-match to pick a match again.',
      )) {
        final snapShow = show;
        final snapEps = await db.episodesByIds(_eps.map((e) => e.id));
        await db.clearShowMeta(show.id);
        if (!mounted) return;
        final m = ScaffoldMessenger.of(context);
        m.clearSnackBars();
        m.showSnackBar(
          SnackBar(
            content: const Text('Cleared show metadata'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await db.restoreShow(snapShow);
                await db.restoreEpisodes(snapEps);
              },
            ),
          ),
        );
      }
      return;
    }
    final meta = widget.meta!;
    if (v == 'rematch') {
      await showDialog(
        context: context,
        builder: (_) => RematchDialog(meta: meta, show: show),
      );
    } else if (v == 'refresh') {
      try {
        await meta.refresh(show.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refresh failed (offline?)')),
          );
        }
      }
    }
  }

  /// Runs [action], then offers Undo that restores [ids] to how they were.
  Future<void> _undoable(
    String message,
    Iterable<int> ids,
    Future<void> Function() action,
  ) async {
    final snap = await db.episodesByIds(ids);
    await action();
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => db.restoreEpisodes(snap),
        ),
      ),
    );
  }

  void _exitSelect() => setState(() {
    _selecting = false;
    _selected.clear();
    _anchorId = null;
  });

  /// Click in select mode. Shift extends from the last clicked episode.
  void _toggleSelect(Episode e) {
    setState(() {
      _selecting = true;
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final anchor = _anchorId == null
          ? -1
          : _shown.indexWhere((x) => x.id == _anchorId);
      final here = _shown.indexWhere((x) => x.id == e.id);
      if (shift && anchor >= 0 && here >= 0) {
        final lo = anchor < here ? anchor : here;
        final hi = anchor < here ? here : anchor;
        for (var i = lo; i <= hi; i++) {
          _selected.add(_shown[i].id);
        }
      } else if (!_selected.remove(e.id)) {
        _selected.add(e.id);
      }
      _anchorId = e.id;
    });
  }

  Future<void> _bulk(String v, Show show) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final n = ids.length;
    final label = '$n episode${n == 1 ? '' : 's'}';
    switch (v) {
      case 'watched':
        await _undoable(
          'Marked $label watched',
          ids,
          () => db.setWatched(ids, true),
        );
      case 'unwatched':
        await _undoable(
          'Marked $label unwatched',
          ids,
          () => db.setWatched(ids, false),
        );
      case 'clear':
        await _undoable('Cleared metadata on $label', ids, () async {
          for (final id in ids) {
            await db.clearEpisodeMeta(id);
          }
        });
      case 'refetch':
        await _refetch(() async {
          for (final id in ids) {
            await db.allowEpisodeMeta(id);
          }
          await widget.meta!.refresh(show.id);
        });
      case 'unsort':
        await _undoable(
          'Moved $label to Unsorted',
          ids,
          () => db.unassignEpisodes(ids),
        );
    }
    if (v != 'refetch') _exitSelect();
  }

  Widget _selectionBar(Show show) {
    Widget btn(IconData icon, String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: _selected.isEmpty ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
    return Material(
      color: Ui.surfaceHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${_selected.length} selected',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _selected.addAll(_shown.map((e) => e.id));
                }),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => setState(_selected.clear),
                child: const Text('None'),
              ),
              const SizedBox(height: 24, child: VerticalDivider(width: 16)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      btn(
                        Icons.check_circle_outline,
                        'Watched',
                        () => _bulk('watched', show),
                      ),
                      btn(
                        Icons.radio_button_unchecked,
                        'Unwatched',
                        () => _bulk('unwatched', show),
                      ),
                      btn(
                        Icons.layers_clear_outlined,
                        'Clear metadata',
                        () => _bulk('clear', show),
                      ),
                      if (widget.meta != null)
                        btn(
                          Icons.cloud_download_outlined,
                          'Re-fetch',
                          () => _bulk('refetch', show),
                        ),
                      btn(
                        Icons.drive_file_move_outline,
                        'Move to Unsorted',
                        () => _bulk('unsort', show),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Done (Esc)',
                icon: const Icon(Icons.close),
                onPressed: _exitSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _refetch(Future<void> Function() job) async {
    try {
      await job();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fetch failed (offline?)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Show>(
      stream: _showStream,
      builder: (context, showSnap) {
        final show = showSnap.data;
        if (show == null) return const Scaffold();
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_selecting) _exitSelect();
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              extendBodyBehindAppBar: true,
              bottomNavigationBar: _selecting ? _selectionBar(show) : null,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (v) => _menu(v, show),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'select',
                        child: Text('Select episodes...'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'show_watched',
                        child: Text('Mark whole show watched'),
                      ),
                      const PopupMenuItem(
                        value: 'show_unwatched',
                        child: Text('Mark whole show unwatched'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear_meta',
                        child: Text('Clear metadata...'),
                      ),
                      if (widget.meta != null) ...const [
                        PopupMenuItem(
                          value: 'rematch',
                          child: Text('Re-match...'),
                        ),
                        PopupMenuItem(
                          value: 'refresh',
                          child: Text('Refresh metadata'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              body: StreamBuilder<List<Episode>>(
                stream: _episodesStream,
                builder: (context, snap) {
                  final eps = snap.data ?? const <Episode>[];
                  final seasons = ({for (final e in eps) e.season ?? 0}.toList()
                    ..sort());
                  final season = seasons.isEmpty
                      ? null
                      : (seasons.contains(_season)
                            ? _season!
                            : defaultSeason(seasons));
                  _eps = eps;
                  final shown = [
                    for (final e in eps)
                      if ((e.season ?? 0) == season &&
                          !(_hideWatched &&
                              e.watched &&
                              !_selected.contains(e.id)))
                        e,
                  ];
                  _shown = shown;
                  final target = continueTarget(eps.map(episodeRef));
                  final targetEp = target == null
                      ? null
                      : eps.firstWhere((e) => e.id == target.episode.id);
                  final firstShown = shown.isEmpty ? null : shown.first;
                  final playEp = targetEp ?? firstShown;
                  final playLabel = targetEp != null
                      ? (target!.resumeMs > 0
                            ? 'Resume S${targetEp.season}E${targetEp.episode}'
                            : 'Play S${targetEp.season}E${targetEp.episode}')
                      : (firstShown == null
                            ? 'Play'
                            : 'Play S${firstShown.season}E${firstShown.episode}');
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _Hero(
                        show: show,
                        episodeCount: eps.length,
                        seasonCount: seasons.where((s) => s > 0).length,
                        onPlay: playEp == null
                            ? null
                            : () => _play(show, playEp),
                        playLabel: playLabel,
                      ),
                      if (seasons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
                          child: Row(
                            children: [
                              Text(
                                'Episodes',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 16),
                              FilterChip(
                                label: const Text('Hide watched'),
                                selected: _hideWatched,
                                onSelected: (v) =>
                                    setState(() => _hideWatched = v),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _selecting
                                    ? _exitSelect
                                    : () => setState(() => _selecting = true),
                                icon: Icon(
                                  _selecting
                                      ? Icons.close_rounded
                                      : Icons.checklist_rounded,
                                  size: 18,
                                ),
                                label: Text(_selecting ? 'Done' : 'Select'),
                              ),
                              const Spacer(),
                              if (season != null)
                                PopupMenuButton<String>(
                                  tooltip: 'Season actions',
                                  icon: const Icon(Icons.more_horiz_rounded),
                                  onSelected: (v) async {
                                    final seasonIds = [
                                      for (final e in eps)
                                        if ((e.season ?? 0) == season) e.id,
                                    ];
                                    if (v == 'w' || v == 'u') {
                                      await _undoable(
                                        v == 'w'
                                            ? 'Marked season watched'
                                            : 'Marked season unwatched',
                                        seasonIds,
                                        () => db.setSeasonWatched(
                                          show.id,
                                          season,
                                          v == 'w',
                                        ),
                                      );
                                    } else if (v == 'select') {
                                      setState(() {
                                        _selecting = true;
                                        _selected.addAll(seasonIds);
                                      });
                                    } else if (v == 'clear') {
                                      if (await _confirm(
                                        'Clear season metadata?',
                                        'Removes TMDB titles, descriptions and images from every episode in this season. Files and progress are untouched.',
                                      )) {
                                        await _undoable(
                                          'Cleared season metadata',
                                          seasonIds,
                                          () => db.clearSeasonMeta(
                                            show.id,
                                            season,
                                          ),
                                        );
                                      }
                                    } else if (v == 'refetch') {
                                      await _refetch(
                                        () => widget.meta!.refetchSeason(
                                          show.id,
                                          season,
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'select',
                                      child: Text('Select this season'),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'w',
                                      child: Text('Mark season watched'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'u',
                                      child: Text('Mark season unwatched'),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'clear',
                                      child: Text('Clear season metadata...'),
                                    ),
                                    if (widget.meta != null)
                                      const PopupMenuItem(
                                        value: 'refetch',
                                        child: Text('Re-fetch season metadata'),
                                      ),
                                  ],
                                ),
                              if (seasons.length > 6) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Ui.surface,
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
                                              s == 0 ? 'Specials' : 'Season $s',
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _season = v),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (seasons.length > 1 && seasons.length <= 6)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final sn in seasons)
                                ChoiceChip(
                                  label: Text(
                                    sn == 0 ? 'Specials' : 'Season $sn',
                                  ),
                                  selected: sn == season,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _season = sn),
                                ),
                            ],
                          ),
                        ),
                      for (final e in shown)
                        _EpisodeCard(
                          episode: e,
                          selecting: _selecting,
                          selected: _selected.contains(e.id),
                          onTap: () {
                            if (_selecting ||
                                HardwareKeyboard.instance.isControlPressed ||
                                HardwareKeyboard.instance.isShiftPressed) {
                              _toggleSelect(e);
                            } else {
                              _play(show, e);
                            }
                          },
                          onLongPress: () => _toggleSelect(e),
                          onPlayFromStart: () =>
                              _play(show, e, fromStart: true),
                          onToggleWatched: () => _undoable(
                            e.watched ? 'Marked unwatched' : 'Marked watched',
                            [e.id],
                            () => db.setWatched([e.id], !e.watched),
                          ),
                          onMarkPreviousWatched: () async {
                            final ids = await db.episodesBefore(e);
                            await _undoable(
                              'Marked ${ids.length} earlier episodes watched',
                              ids,
                              () => db.setWatched(ids, true),
                            );
                          },
                          onUnsort: () => _undoable('Moved to Unsorted', [
                            e.id,
                          ], () => db.unassignEpisodes([e.id])),
                          onClearMeta: () => _undoable('Cleared metadata', [
                            e.id,
                          ], () => db.clearEpisodeMeta(e.id)),
                          onRefetchMeta: widget.meta == null
                              ? null
                              : () => _refetch(
                                  () => widget.meta!.refetchEpisode(
                                    show.id,
                                    e.id,
                                  ),
                                ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
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

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
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
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
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
