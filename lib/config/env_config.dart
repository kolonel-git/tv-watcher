import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads KEY=VALUE pairs from a `.env` file. Never logs values.
class EnvConfig {
  EnvConfig(this._values);

  final Map<String, String> _values;

  String? get tmdbToken => _nonEmpty(_values['TMDB_READ_TOKEN']);
  String get language => _nonEmpty(_values['TMDB_LANGUAGE']) ?? 'en-US';

  static String? _nonEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  static Map<String, String> parse(String content) {
    final out = <String, String>{};
    for (var line in content.split(RegExp(r'\r?\n'))) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final i = line.indexOf('=');
      if (i <= 0) continue;
      var v = line.substring(i + 1).trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) ||
              (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      out[line.substring(0, i).trim()] = v;
    }
    return out;
  }

  /// Looks for `.env` in the working directory (dev), then next to the exe.
  static Future<EnvConfig> load() async {
    final candidates = [
      p.join(Directory.current.path, '.env'),
      p.join(p.dirname(Platform.resolvedExecutable), '.env'),
    ];
    for (final path in candidates) {
      final f = File(path);
      if (await f.exists()) return EnvConfig(parse(await f.readAsString()));
    }
    return EnvConfig({});
  }
}
