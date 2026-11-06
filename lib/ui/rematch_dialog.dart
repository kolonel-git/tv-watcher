import 'package:flutter/material.dart';

import '../data/database.dart';
import '../metadata/metadata_service.dart';
import '../metadata/tmdb_client.dart';

class RematchDialog extends StatefulWidget {
  const RematchDialog({super.key, required this.meta, required this.show});
  final MetadataService meta;
  final Show show;

  @override
  State<RematchDialog> createState() => _RematchDialogState();
}

class _RematchDialogState extends State<RematchDialog> {
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

