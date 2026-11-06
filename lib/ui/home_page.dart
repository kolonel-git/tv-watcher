import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../library/scanner.dart';
import '../metadata/metadata_service.dart';
import '../player/player_page.dart';
import 'continue_row.dart';
import 'manage_pages.dart';
import 'poster_card.dart';
import 'show_page.dart';

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

  AppDatabase get db => widget.db;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Scan done: $added new, $missing missing'
            '${offline > 0 ? ', $offline folder(s) unreachable' : ''}'),
      ));
    }
  }

  Future<void> _syncMetadata() async {
    final meta = widget.meta;
    if (meta == null) {
      if (mounted) {
        setState(() => _note =
            'No TMDB token: add TMDB_READ_TOKEN to .env for posters and descriptions.');
      }
      return;
    }
    if (mounted) setState(() => _note = 'Fetching metadata...');
    try {
      final r = await meta.syncAll();
      if (mounted) {
        setState(() => _note = r.offline
            ? 'Offline: showing cached metadata.'
            : (r.ambiguous + r.noMatch > 0
                ? '${r.ambiguous + r.noMatch} show(s) need a manual match: open the show, menu, Re-match.'
                : null));
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Metadata fetch failed.');
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV WATCHER',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Color(0xFFE50914))),
        actions: [
          IconButton(
            tooltip: 'Play a single file',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _push(const PlayerPage()),
          ),
          StreamBuilder<List<Episode>>(
            stream: db.watchUnsorted(),
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              return IconButton(
                tooltip: 'Unsorted files',
                icon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.help_outline),
                ),
                onPressed: () => _push(UnsortedPage(db: db, onAssigned: _syncMetadata)),
              );
            },
          ),
          IconButton(
            tooltip: 'Library folders',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => _push(FoldersPage(db: db, onAdd: _addFolder)),
          ),
          _scanning
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  tooltip: 'Rescan',
                  icon: const Icon(Icons.refresh),
                  onPressed: _rescan,
                ),
        ],
      ),
      body: Column(children: [
        if (_note != null)
          Container(
            width: double.infinity,
            color: const Color(0xFF1C1C24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Text(_note!, style: Theme.of(context).textTheme.bodySmall),
          ),
        Expanded(
          child: StreamBuilder<List<ShowWithCount>>(
            stream: db.watchShows(),
            builder: (context, snap) {
              final shows = snap.data;
              if (shows == null) return const SizedBox.shrink();
              if (shows.isEmpty) return _Empty(onAdd: _addFolder);
              return _ShowGrid(
                db: db,
                shows: shows,
                onOpen: (s) => _push(
                    ShowPage(db: db, meta: widget.meta, showId: s.show.id)),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ShowGrid extends StatelessWidget {
  const _ShowGrid(
      {required this.db, required this.shows, required this.onOpen});
  final AppDatabase db;
  final List<ShowWithCount> shows;
  final ValueChanged<ShowWithCount> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: ContinueRow(db: db)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        sliver: SliverToBoxAdapter(
          child: Text('All shows',
              style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 24,
            crossAxisSpacing: 20,
            childAspectRatio: 2 / 3.5,
          ),
          itemCount: shows.length,
          itemBuilder: (context, i) {
            final s = shows[i];
            final needs =
                s.show.metaStatus == 'ambiguous' || s.show.metaStatus == 'nomatch';
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
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.video_library_outlined,
              size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Text('Your library is empty',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add a folder'),
          ),
        ]),
      );
}
