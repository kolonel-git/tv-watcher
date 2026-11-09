import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'theme.dart';
import '../data/database.dart';
import '../library/filename_parser.dart';
import '../library/unsorted_grouping.dart';
import '../player/player_page.dart';

class UnsortedPage extends StatelessWidget {
  const UnsortedPage({super.key, required this.db, this.onAssigned});
  final AppDatabase db;

  /// Called after assignments so metadata can be fetched for new shows.
  final VoidCallback? onAssigned;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Unsorted files')),
    body: _UnsortedTab(db: db, onAssigned: onAssigned),
  );
}

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key, required this.db, required this.onAdd});
  final AppDatabase db;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Library folders')),
    body: _FoldersTab(db: db, onAdd: onAdd),
  );
}

class _UnsortedTab extends StatefulWidget {
  const _UnsortedTab({required this.db, this.onAssigned});
  final AppDatabase db;
  final VoidCallback? onAssigned;

  @override
  State<_UnsortedTab> createState() => _UnsortedTabState();
}

class _UnsortedTabState extends State<_UnsortedTab> {
  final Set<String> _selected = {};

  AppDatabase get db => widget.db;

  void _play(String path) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PlayerPage(initialPath: path, title: p.basename(path), db: db),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LibraryFolder>>(
      future: db.select(db.libraryFolders).get(),
      builder: (context, folderSnap) {
        final roots = {
          for (final f in folderSnap.data ?? const <LibraryFolder>[])
            f.id: f.path,
        };
        return StreamBuilder<List<Episode>>(
          stream: db.watchUnsorted(),
          builder: (context, snap) {
            final eps = snap.data ?? const <Episode>[];
            if (eps.isEmpty) {
              return const Center(child: Text('Nothing unsorted.'));
            }
            final items = [
              for (final e in eps)
                UnsortedItem(
                  id: e.id,
                  folderId: e.folderId,
                  path: e.filePath,
                  relativePath: roots[e.folderId] == null
                      ? e.filePath
                      : p.relative(e.filePath, from: roots[e.folderId]!),
                  rootName: roots[e.folderId] == null
                      ? null
                      : p.basename(roots[e.folderId]!),
                ),
            ];
            final grouping = groupUnsorted(items);
            final groups = grouping.groups;
            final titleStyle = Theme.of(context).textTheme.titleMedium;

            // Drop selections of groups that no longer exist.
            _selected.removeWhere((k) => !groups.any((g) => g.key == k));
            final selectedGroups = groups
                .where((g) => _selected.contains(g.key))
                .toList();
            final selectedFiles = selectedGroups.fold<int>(
              0,
              (n, g) => n + g.entries.length,
            );

            return Column(
              children: [
                if (selectedGroups.isNotEmpty)
                  Container(
                    color: Ui.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selectedGroups.length} group(s) selected · $selectedFiles files',
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _assign(selectedGroups),
                          child: const Text('Assign selected'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      if (groups.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            'Similar files: assign a whole season at once, or tick several groups for the same season',
                            style: titleStyle,
                          ),
                        ),
                      for (final g in groups) _groupTile(g),
                      if (grouping.singles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text('Single files', style: titleStyle),
                        ),
                      for (final it in grouping.singles)
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: Text(p.basename(it.path)),
                          subtitle: Text(p.dirname(it.path)),
                          onTap: () => _play(it.path),
                          trailing: TextButton(
                            onPressed: () => _assignOne(it),
                            child: const Text('Assign'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _groupTile(UnsortedGroup g) {
    final range = g.numberedByName
        ? 'episodes ${g.minNumber}-${g.maxNumber}'
        : 'no numbers in names, numbered by file order';
    return ExpansionTile(
      key: PageStorageKey(g.key),
      leading: Checkbox(
        value: _selected.contains(g.key),
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(g.key);
          } else {
            _selected.remove(g.key);
          }
        }),
      ),
      title: Text(g.label),
      subtitle: Text('${g.entries.length} files · $range'),
      trailing: FilledButton(
        onPressed: () => _assign([g]),
        child: const Text('Assign group'),
      ),
      children: [
        for (final e in g.entries)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            leading: SizedBox(
              width: 36,
              child: Text(
                '#${e.number}',
                style: const TextStyle(color: Ui.dim),
              ),
            ),
            title: Text(
              p.basename(e.item.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _play(e.item.path),
          ),
      ],
    );
  }

  Future<void> _assign(List<UnsortedGroup> groups) async {
    final existing = await db.select(db.shows).get();
    if (!mounted) return;
    final files = groups.fold<int>(0, (n, g) => n + g.entries.length);
    final hint = groups.map((g) => g.showHint).whereType<String>().firstOrNull;
    final r = await showDialog<_GroupAssignment>(
      context: context,
      builder: (_) => _AssignGroupDialog(
        label: groups.length == 1
            ? groups.first.label
            : '${groups.length} groups',
        count: files,
        hint: hint,
        knownShows: [for (final s in existing) s.name],
      ),
    );
    if (r == null) return;
    for (final g in groups) {
      for (final e in g.entries) {
        await db.assignEpisode(
          e.item.id,
          showName: r.show,
          showKey: ParsedEpisode.showKeyFor(r.show),
          season: r.season,
          episode: e.number,
        );
      }
    }
    if (mounted) setState(_selected.clear);
    widget.onAssigned?.call();
  }

  Future<void> _assignOne(UnsortedItem it) async {
    final existing = await db.select(db.shows).get();
    if (!mounted) return;
    final result = await showDialog<_Assignment>(
      context: context,
      builder: (_) => _AssignDialog(
        fileName: p.basename(it.path),
        knownShows: [for (final s in existing) s.name],
      ),
    );
    if (result == null) return;
    await db.assignEpisode(
      it.id,
      showName: result.show,
      showKey: ParsedEpisode.showKeyFor(result.show),
      season: result.season,
      episode: result.episode,
    );
    widget.onAssigned?.call();
  }
}

class _GroupAssignment {
  _GroupAssignment(this.show, this.season);
  final String show;
  final int season;
}

class _AssignGroupDialog extends StatefulWidget {
  const _AssignGroupDialog({
    required this.label,
    required this.count,
    required this.hint,
    required this.knownShows,
  });
  final String label;
  final int count;
  final String? hint;
  final List<String> knownShows;

  @override
  State<_AssignGroupDialog> createState() => _AssignGroupDialogState();
}

class _AssignGroupDialogState extends State<_AssignGroupDialog> {
  late final _show = TextEditingController(text: widget.hint ?? '');
  final _season = TextEditingController(text: '1');

  @override
  void dispose() {
    _show.dispose();
    _season.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final season = int.tryParse(_season.text);
    final ok = _show.text.trim().isNotEmpty && season != null && season >= 0;
    final small = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(
      title: const Text('Assign group'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.count} files: ${widget.label}', style: small),
            const SizedBox(height: 4),
            Text(
              'Episode numbers come from the filenames. Use the show name as it appears on TMDB, and the season this group belongs to.',
              style: small,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _show,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Show name'),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.knownShows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in widget.knownShows)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _show.text = s),
                    ),
                ],
              ),
            ],
            TextField(
              controller: _season,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Season (0 = specials)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ok
              ? () => Navigator.pop(
                  context,
                  _GroupAssignment(_show.text.trim(), season),
                )
              : null,
          child: const Text('Assign all'),
        ),
      ],
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
    final ok =
        _show.text.trim().isNotEmpty &&
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
                (s) => s.toLowerCase().contains(v.text.toLowerCase()),
              ),
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
            Row(
              children: [
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
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ok
              ? () => Navigator.pop(
                  context,
                  _Assignment(_show.text.trim(), season, episode),
                )
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
