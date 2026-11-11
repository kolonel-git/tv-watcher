import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import '../data/database.dart';
import '../settings/settings_controller.dart';
import '../metadata/metadata_service.dart';
import '../watch/watch_logic.dart';
import 'play.dart';
import 'episode_card.dart';
import 'rematch_dialog.dart';
import 'show_hero.dart';

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
  // Read once at first build: the settings screen is not reachable from here,
  // so 'Show missing files' cannot change while this page is open.
  late final Stream<List<Episode>> _episodesStream = db.watchEpisodesOfShow(
    widget.showId,
    includeMissing: SettingsScope.of(context).showMissing,
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
            duration: Ui.undoDuration,
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
        duration: Ui.undoDuration,
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
        if (show == null) {
          return const Scaffold(
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
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
                  final settings = SettingsScope.of(context);
                  final eps = [
                    for (final e in snap.data ?? const <Episode>[])
                      if (settings.showSpecials || (e.season ?? 0) != 0) e,
                  ];
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
                  final target = continueTarget(
                    eps.where((e) => !e.missing).map(episodeRef),
                    threshold: settings.watchedFraction,
                  );
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
                      ShowHero(
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
                        EpisodeCard(
                          episode: e,
                          selecting: _selecting,
                          selected: _selected.contains(e.id),
                          onTap: () {
                            if (e.missing && !_selecting) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This file is missing. Rescan from the Library menu once it is back.',
                                  ),
                                ),
                              );
                              return;
                            }
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
