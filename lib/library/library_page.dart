import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../metadata/metadata_service.dart';
import '../metadata/tmdb_client.dart';
import '../player/player_page.dart';
import 'filename_parser.dart';
import 'scanner.dart';

/// Sprint 2 library UI: simple lists. Netflix-style UI comes in Sprint 4.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.db, this.meta});
  final AppDatabase db;

  /// Null when no TMDB token is configured: library works without artwork.
  final MetadataService? meta;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _rescan(quiet: true);
  }

  AppDatabase get db => widget.db;
  String? _metaNote;

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
      final folders = await db.select(db.libraryFolders).get();
      for (final f in folders) {
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
        setState(() => _metaNote =
            'No TMDB token: add TMDB_READ_TOKEN to .env for posters and descriptions.');
      }
      return;
    }
    if (mounted) setState(() => _metaNote = 'Fetching metadata...');
    try {
      final r = await meta.syncAll();
      if (mounted) {
        setState(() => _metaNote = r.offline
            ? 'Offline: showing cached metadata.'
            : (r.ambiguous + r.noMatch > 0
                ? '${r.ambiguous + r.noMatch} show(s) need a manual match (open the show, menu, Re-match).'
                : null));
      }
    } catch (_) {
      if (mounted) setState(() => _metaNote = 'Metadata fetch failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TV Watcher'),
          actions: [
            IconButton(
              tooltip: 'Open a single file',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlayerPage())),
            ),
            IconButton(
              tooltip: 'Add library folder',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _addFolder,
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
          bottom: const TabBar(tabs: [
            Tab(text: 'Shows'),
            Tab(text: 'Unsorted'),
            Tab(text: 'Folders'),
          ]),
        ),
        body: Column(children: [
          if (_metaNote != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF1C1C24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(_metaNote!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: TabBarView(children: [
              _ShowsTab(db: db, meta: widget.meta),
              _UnsortedTab(db: db),
              _FoldersTab(db: db, onAdd: _addFolder),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget _poster(String? file, {double w = 48, double h = 72}) {
  final f = file != null && File(file).existsSync() ? File(file) : null;
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox(
      width: w,
      height: h,
      child: f != null
          ? Image.file(f, fit: BoxFit.cover, cacheWidth: (w * 3).round())
          : Container(
              color: const Color(0xFF1C1C24),
              child: const Icon(Icons.tv, color: Colors.white24)),
    ),
  );
}

class _ShowsTab extends StatelessWidget {
  const _ShowsTab({required this.db, required this.meta});
  final AppDatabase db;
  final MetadataService? meta;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShowWithCount>>(
      stream: db.watchShows(),
      builder: (context, snap) {
        final shows = snap.data ?? const [];
        if (shows.isEmpty) {
          return const Center(
              child: Text('No shows yet. Add a library folder (top right).'));
        }
        return ListView(
          children: [
            for (final s in shows)
              ListTile(
                leading: _poster(s.show.posterFile),
                title: Text(s.show.tmdbName ?? s.show.name),
                subtitle: Text(
                    '${s.episodeCount} episodes${s.show.metaStatus == 'ambiguous' || s.show.metaStatus == 'nomatch' ? '  ·  needs match' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ShowPage(db: db, meta: meta, showId: s.show.id)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ShowPage extends StatelessWidget {
  const ShowPage(
      {super.key, required this.db, required this.meta, required this.showId});
  final AppDatabase db;
  final MetadataService? meta;
  final int showId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Show>(
      stream: db.watchShow(showId),
      builder: (context, showSnap) {
        final show = showSnap.data;
        if (show == null) return const Scaffold();
        final title = show.tmdbName ?? show.name;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (meta != null)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rematch') {
                      await showDialog(
                          context: context,
                          builder: (_) =>
                              _RematchDialog(meta: meta!, show: show));
                    } else if (v == 'refresh') {
                      try {
                        await meta!.refresh(show.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Refresh failed (offline?)')));
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rematch', child: Text('Re-match...')),
                    PopupMenuItem(
                        value: 'refresh', child: Text('Refresh metadata')),
                  ],
                ),
            ],
          ),
          body: StreamBuilder<List<Episode>>(
            stream: db.watchEpisodesOfShow(showId),
            builder: (context, snap) {
              final eps = snap.data ?? const [];
              int? lastSeason = -1;
              final children = <Widget>[
                _ShowHeader(show: show),
              ];
              for (final e in eps) {
                if (e.season != lastSeason) {
                  lastSeason = e.season;
                  children.add(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                        e.season == 0 ? 'Specials' : 'Season ${e.season}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ));
                }
                final range = e.endEpisode != null
                    ? 'E${e.episode}-${e.endEpisode}'
                    : 'E${e.episode}';
                final name = e.tmdbTitle ?? e.title;
                final label = name == null ? range : '$range · $name';
                children.add(ListTile(
                  leading: _thumb(e.stillFile),
                  title: Text(label),
                  subtitle: Text(
                    [
                      if (e.runtime != null) '${e.runtime} min',
                      if (e.overview != null) e.overview!,
                      if (e.overview == null) p.basename(e.filePath),
                    ].join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerPage(
                            initialPath: e.filePath,
                            title: '$title S${e.season} $label')),
                  ),
                ));
              }
              return ListView(children: children);
            },
          ),
        );
      },
    );
  }

  Widget _thumb(String? file) {
    final f = file != null && File(file).existsSync() ? File(file) : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 120,
        height: 68,
        child: f != null
            ? Image.file(f, fit: BoxFit.cover, cacheWidth: 360)
            : Container(
                color: const Color(0xFF1C1C24),
                child: const Icon(Icons.play_arrow, color: Colors.white38)),
      ),
    );
  }
}

class _ShowHeader extends StatelessWidget {
  const _ShowHeader({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final backdrop =
        show.backdropFile != null && File(show.backdropFile!).existsSync()
            ? File(show.backdropFile!)
            : null;
    return Stack(children: [
      if (backdrop != null)
        Positioned.fill(
          child: Opacity(
              opacity: 0.35,
              child: Image.file(backdrop, fit: BoxFit.cover, cacheWidth: 1280)),
        ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _poster(show.posterFile, w: 120, h: 180),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(show.tmdbName ?? show.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    show.overview ??
                        (show.metaStatus == 'matched'
                            ? 'No synopsis available.'
                            : 'No metadata yet. Use the menu > Re-match to pick the right show.'),
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
          ),
        ]),
      ),
    ]);
  }
}

class _RematchDialog extends StatefulWidget {
  const _RematchDialog({required this.meta, required this.show});
  final MetadataService meta;
  final Show show;

  @override
  State<_RematchDialog> createState() => _RematchDialogState();
}

class _RematchDialogState extends State<_RematchDialog> {
  late final _query = TextEditingController(text: widget.show.name);
  List<TmdbSearchResult>? _results;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.meta.candidates(_query.text.trim());
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _error = 'Search failed (offline?)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(TmdbSearchResult r) async {
    setState(() => _busy = true);
    try {
      await widget.meta.pickMatch(widget.show.id, r.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not fetch that show (offline?)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick the right show'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(children: [
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: 'Search TMDB',
              suffixIcon: IconButton(
                  icon: const Icon(Icons.search), onPressed: _search),
            ),
            onSubmitted: (_) => _search(),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(
            child: ListView(children: [
              for (final r in _results ?? const <TmdbSearchResult>[])
                ListTile(
                  title:
                      Text('${r.name}${r.year != null ? ' (${r.year})' : ''}'),
                  subtitle: Text(r.overview ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: _busy ? null : () => _pick(r),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class _UnsortedTab extends StatelessWidget {
  const _UnsortedTab({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Episode>>(
      stream: db.watchUnsorted(),
      builder: (context, snap) {
        final eps = snap.data ?? const [];
        if (eps.isEmpty) {
          return const Center(child: Text('Nothing unsorted.'));
        }
        return ListView(
          children: [
            for (final e in eps)
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(p.basename(e.filePath)),
                subtitle: Text(p.dirname(e.filePath)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlayerPage(
                          initialPath: e.filePath,
                          title: p.basename(e.filePath))),
                ),
                trailing: TextButton(
                  onPressed: () => _assign(context, e),
                  child: const Text('Assign'),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _assign(BuildContext context, Episode e) async {
    final existing = await db.select(db.shows).get();
    if (!context.mounted) return;
    final result = await showDialog<_Assignment>(
      context: context,
      builder: (_) => _AssignDialog(
          fileName: p.basename(e.filePath),
          knownShows: [for (final s in existing) s.name]),
    );
    if (result == null) return;
    await db.assignEpisode(
      e.id,
      showName: result.show,
      showKey: ParsedEpisode.showKeyFor(result.show),
      season: result.season,
      episode: result.episode,
    );
  }
}

class _Assignment {
  _Assignment(this.show, this.season, this.episode);
  final String show;
  final int season;
  final int episode;
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.fileName, required this.knownShows});
  final String fileName;
  final List<String> knownShows;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final _show = TextEditingController();
  final _season = TextEditingController(text: '1');
  final _episode = TextEditingController(text: '1');

  @override
  void dispose() {
    _show.dispose();
    _season.dispose();
    _episode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final season = int.tryParse(_season.text);
    final episode = int.tryParse(_episode.text);
    final ok = _show.text.trim().isNotEmpty &&
        season != null &&
        season >= 0 &&
        episode != null &&
        episode > 0;
    return AlertDialog(
      title: const Text('Assign episode'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (v) => widget.knownShows.where(
                  (s) => s.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => setState(() => _show.text = v),
              fieldViewBuilder: (context, ctrl, focus, _) {
                ctrl.addListener(() {
                  if (_show.text != ctrl.text) {
                    setState(() => _show.text = ctrl.text);
                  }
                });
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Show name'),
                );
              },
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _season,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Season'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _episode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Episode'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: ok
              ? () => Navigator.pop(
                  context, _Assignment(_show.text.trim(), season, episode))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FoldersTab extends StatelessWidget {
  const _FoldersTab({required this.db, required this.onAdd});
  final AppDatabase db;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LibraryFolder>>(
      stream: db.watchFolders(),
      builder: (context, snap) {
        final folders = snap.data ?? const [];
        return ListView(
          children: [
            for (final f in folders)
              ListTile(
                leading: const Icon(Icons.folder),
                title: Text(f.path),
                trailing: IconButton(
                  tooltip: 'Remove from library (files untouched)',
                  icon: const Icon(Icons.close),
                  onPressed: () => db.removeFolder(f.id),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add folder'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
