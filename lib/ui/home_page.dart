import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import '../data/database.dart';
import '../settings/settings_controller.dart';
import '../settings/user_settings.dart';
import '../library/scanner.dart';
import '../metadata/metadata_service.dart';
import '../player/player_page.dart';
import 'continue_row.dart';
import 'manage_pages.dart';
import 'poster_card.dart';
import 'settings_page.dart';
import 'show_page.dart';

export '../settings/user_settings.dart' show ShowSort;

/// Home: poster grid of all shows. Owns scan + metadata sync orchestration.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db, this.meta});
  final AppDatabase db;

  /// Null when no TMDB token is configured: library works without artwork.
  final MetadataService? meta;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _scanning = false;
  String? _note;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Used only when there is no settings scope (widget tests).
  ShowSort _fallbackSort = ShowSort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AppDatabase get db => widget.db;

  late final Stream<List<Episode>> _unsorted = db.watchUnsorted();
  late final Stream<List<ShowWithCount>> _shows = db.watchShows();

  @override
  void initState() {
    super.initState();
    _rescan(quiet: true);
  }

  Future<void> _addFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    await db.addFolder(dir);
    await _rescan();
  }

  Future<void> _rescan({bool quiet = false}) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    var added = 0, missing = 0, offline = 0;
    try {
      for (final f in await db.select(db.libraryFolders).get()) {
        final r = await scanFolder(db, f);
        added += r.added;
        missing += r.missing;
        if (r.skippedOffline) offline++;
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    await _syncMetadata();
    if (!quiet && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scan done: $added new, $missing missing'
            '${offline > 0 ? ', $offline folder(s) unreachable' : ''}',
          ),
        ),
      );
    }
  }

  Future<void> _syncMetadata() async {
    final meta = widget.meta;
    if (meta == null) {
      if (mounted) {
        setState(
          () => _note = 'No TMDB token: add TMDB_READ_TOKEN to .env for posters and descriptions.',
        );
      }
      return;
    }
    if (mounted) setState(() => _note = 'Fetching metadata...');
    try {
      final r = await meta.syncAll();
      if (mounted) {
        setState(
          () => _note = r.offline
              ? 'Offline: showing cached metadata.'
              : (r.ambiguous + r.noMatch > 0
                    ? '${r.ambiguous + r.noMatch} show(s) need a manual match: open the show, menu, Re-match.'
                    : null),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Metadata fetch failed.');
    }
  }

  void _setSort(ShowSort v) {
    final c = SettingsScope.controllerOf(context);
    if (c == null) {
      setState(() => _fallbackSort = v);
    } else {
      c.update(c.value.copyWith(homeSort: v));
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final hasScope = SettingsScope.controllerOf(context) != null;
    final sort = hasScope ? settings.homeSort : _fallbackSort;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: Ui.s5,
        title: Text(
          'TV Watcher',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search shows',
                hintStyle: const TextStyle(color: Ui.dim),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
                filled: true,
                fillColor: Ui.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Ui.rMd),
                  borderSide: const BorderSide(color: Ui.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Ui.rMd),
                  borderSide: const BorderSide(color: Ui.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Ui.rMd),
                  borderSide: const BorderSide(color: Ui.muted),
                ),
              ),
            ),
          ),
          const SizedBox(width: Ui.s2),
          PopupMenuButton<ShowSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.swap_vert_rounded),
            initialValue: sort,
            onSelected: _setSort,
            itemBuilder: (_) => [
              for (final o in ShowSort.values)
                CheckedPopupMenuItem(
                  value: o,
                  checked: o == sort,
                  child: Text(o.label),
                ),
            ],
          ),
          StreamBuilder<List<Episode>>(
            stream: _unsorted,
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: Ui.s1),
                child: TextButton.icon(
                  onPressed: () =>
                      _push(UnsortedPage(db: db, onAssigned: _syncMetadata)),
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: Text('$n unsorted'),
                ),
              );
            },
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Library',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'unsorted':
                    _push(UnsortedPage(db: db, onAssigned: _syncMetadata));
                  case 'folders':
                    _push(FoldersPage(db: db, onAdd: _addFolder));
                  case 'rescan':
                    _rescan();
                  case 'file':
                    _push(PlayerPage(db: db));
                  case 'settings':
                    _push(const SettingsPage());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rescan',
                  child: _MenuRow(Icons.refresh_rounded, 'Rescan library'),
                ),
                PopupMenuItem(
                  value: 'folders',
                  child: _MenuRow(Icons.folder_outlined, 'Library folders'),
                ),
                PopupMenuItem(
                  value: 'unsorted',
                  child: _MenuRow(Icons.help_outline_rounded, 'Unsorted files'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'file',
                  child: _MenuRow(
                    Icons.play_circle_outline_rounded,
                    'Play a single file',
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: _MenuRow(Icons.settings_outlined, 'Settings'),
                ),
              ],
            ),
          const SizedBox(width: Ui.s3),
        ],
      ),
      body: Column(
        children: [
          if (_note != null)
            Container(
              width: double.infinity,
              color: Ui.surface,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Text(_note!, style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: StreamBuilder<List<ShowWithCount>>(
              stream: _shows,
              builder: (context, snap) {
                final shows = snap.data;
                if (shows == null) return const SizedBox.shrink();
                if (shows.isEmpty) return _Empty(onAdd: _addFolder);
                final visible = filterAndSortShows(shows, _query, sort);
                if (visible.isEmpty) {
                  return _NoMatches(
                    query: _query,
                    onClear: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  );
                }
                return _ShowGrid(
                  db: db,
                  showContinue: _query.isEmpty,
                  total: shows.length,
                  posterWidth: settings.posterSize.maxWidth,
                  shows: visible,
                  onOpen: (s) => _push(
                    ShowPage(db: db, meta: widget.meta, showId: s.show.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowGrid extends StatelessWidget {
  const _ShowGrid({
    required this.db,
    required this.shows,
    required this.onOpen,
    required this.showContinue,
    required this.total,
    required this.posterWidth,
  });
  final double posterWidth;
  final AppDatabase db;
  final bool showContinue;
  final int total;
  final List<ShowWithCount> shows;
  final ValueChanged<ShowWithCount> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (showContinue) SliverToBoxAdapter(child: ContinueRow(db: db)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  showContinue ? 'All shows' : 'Results',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: Ui.s2),
                Text(
                  shows.length == total
                      ? '$total'
                      : '${shows.length} of $total',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Ui.dim),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: posterWidth,
              mainAxisSpacing: 24,
              crossAxisSpacing: 20,
              childAspectRatio: 2 / 3.5,
            ),
            itemCount: shows.length,
            itemBuilder: (context, i) {
              final s = shows[i];
              final needs =
                  s.show.metaStatus == 'ambiguous' ||
                  s.show.metaStatus == 'nomatch';
              return PosterCard(
                title: s.show.tmdbName ?? s.show.name,
                posterFile: s.show.posterFile,
                subtitle: '${s.episodeCount} episodes',
                badge: needs ? 'Needs match' : null,
                onTap: () => onOpen(s),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.video_library_outlined,
          size: 56,
          color: Colors.white24,
        ),
        const SizedBox(height: 12),
        Text(
          'Your library is empty',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Add a folder'),
        ),
      ],
    ),
  );
}

/// Case-insensitive name filter plus sort. Pure, for the home grid.
List<ShowWithCount> filterAndSortShows(
  List<ShowWithCount> shows,
  String query,
  ShowSort sort,
) {
  final q = query.trim().toLowerCase();
  String name(ShowWithCount s) =>
      (s.show.tmdbName ?? s.show.name).toLowerCase();
  final out = [
    for (final s in shows)
      if (q.isEmpty ||
          name(s).contains(q) ||
          s.show.name.toLowerCase().contains(q))
        s,
  ];
  out.sort((a, b) {
    switch (sort) {
      case ShowSort.name:
        return name(a).compareTo(name(b));
      case ShowSort.nameDesc:
        return name(b).compareTo(name(a));
      case ShowSort.episodes:
        final c = b.episodeCount.compareTo(a.episodeCount);
        return c != 0 ? c : name(a).compareTo(name(b));
      case ShowSort.recentlyAdded:
        return _newestFirst(a.addedAt, b.addedAt, name(a), name(b));
      case ShowSort.recentlyWatched:
        return _newestFirst(a.lastPlayedAt, b.lastPlayedAt, name(a), name(b));
    }
  });
  return out;
}

/// Newest date first; shows with no date go last; ties by name.
int _newestFirst(DateTime? a, DateTime? b, String nameA, String nameB) {
  if (a == null && b == null) return nameA.compareTo(nameB);
  if (a == null) return 1;
  if (b == null) return -1;
  final c = b.compareTo(a);
  return c != 0 ? c : nameA.compareTo(nameB);
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Ui.muted),
      const SizedBox(width: Ui.s3),
      Text(label),
    ],
  );
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off_rounded, size: 48, color: Ui.dim),
        const SizedBox(height: Ui.s3),
        Text(
          'No shows match "$query"',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Ui.s3),
        TextButton(onPressed: onClear, child: const Text('Clear search')),
      ],
    ),
  );
}
