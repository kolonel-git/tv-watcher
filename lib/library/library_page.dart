import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../player/player_page.dart';
import 'filename_parser.dart';
import 'scanner.dart';

/// Sprint 2 library UI: simple lists. Netflix-style UI comes in Sprint 4.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.db});
  final AppDatabase db;

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
    if (!quiet && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Scan done: $added new, $missing missing'
            '${offline > 0 ? ', $offline folder(s) unreachable' : ''}'),
      ));
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
        body: TabBarView(children: [
          _ShowsTab(db: db),
          _UnsortedTab(db: db),
          _FoldersTab(db: db, onAdd: _addFolder),
        ]),
      ),
    );
  }
}

class _ShowsTab extends StatelessWidget {
  const _ShowsTab({required this.db});
  final AppDatabase db;

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
                title: Text(s.show.name),
                subtitle: Text('${s.episodeCount} episodes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ShowPage(db: db, show: s.show)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ShowPage extends StatelessWidget {
  const ShowPage({super.key, required this.db, required this.show});
  final AppDatabase db;
  final Show show;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(show.name)),
      body: StreamBuilder<List<Episode>>(
        stream: db.watchEpisodesOfShow(show.id),
        builder: (context, snap) {
          final eps = snap.data ?? const [];
          int? lastSeason = -1;
          final children = <Widget>[];
          for (final e in eps) {
            if (e.season != lastSeason) {
              lastSeason = e.season;
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Season ${e.season}',
                    style: Theme.of(context).textTheme.titleMedium),
              ));
            }
            final range = e.endEpisode != null
                ? 'E${e.episode}-${e.endEpisode}'
                : 'E${e.episode}';
            children.add(ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(e.title == null ? range : '$range · ${e.title}'),
              subtitle: Text(p.basename(e.filePath)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlayerPage(
                        initialPath: e.filePath,
                        title: '${show.name} S${e.season} $range')),
              ),
            ));
          }
          return ListView(children: children);
        },
      ),
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
