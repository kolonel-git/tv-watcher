import 'dart:convert';

import '../app_info.dart';
import 'database.dart';

/// The backup file is not valid or not ours.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One episode's progress as stored in a backup. Episodes are identified by
/// file path, not database id, so a backup survives a rebuilt library.
class BackupEpisode {
  const BackupEpisode({
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.watched,
    this.lastPlayedMs,
  });
  final String path;
  final int positionMs;
  final int durationMs;
  final bool watched;

  /// Epoch milliseconds of the last play, if any.
  final int? lastPlayedMs;
}

/// A parsed, validated backup. Parsing never touches the database.
///
/// The file is untrusted input (it can be edited or come from anywhere), so
/// every field is type-checked, sizes are capped, and only whitelisted
/// settings keys are kept.
class BackupFile {
  const BackupFile({
    required this.exportedAt,
    required this.appVersion,
    required this.settings,
    required this.episodes,
  });

  static const format = 'tv-watcher-backup';
  static const formatVersion = 1;

  /// Only these settings key prefixes are ever read or written.
  static const settingPrefixes = ['settings.', 'player.'];
  static const _maxEpisodes = 200000;
  static const _maxKey = 100;
  static const _maxValue = 4000;

  final DateTime? exportedAt;
  final String? appVersion;
  final Map<String, String> settings;
  final List<BackupEpisode> episodes;

  static bool allowedKey(String k) =>
      k.length <= _maxKey && settingPrefixes.any(k.startsWith);

  factory BackupFile.parse(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw BackupFormatException('This is not a valid backup file.');
    }
    if (raw is! Map || raw['format'] != format) {
      throw BackupFormatException('This is not a TV Watcher backup.');
    }
    final version = raw['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw BackupFormatException(
        'This backup was made by a newer version of the app.',
      );
    }

    final settings = <String, String>{};
    final rawSettings = raw['settings'];
    if (rawSettings is Map) {
      for (final e in rawSettings.entries) {
        final k = e.key, v = e.value;
        if (k is String &&
            v is String &&
            allowedKey(k) &&
            v.length <= _maxValue) {
          settings[k] = v;
        }
      }
    }

    final episodes = <BackupEpisode>[];
    final rawEpisodes = raw['episodes'];
    if (rawEpisodes is List) {
      for (final e in rawEpisodes.take(_maxEpisodes)) {
        if (e is! Map) continue;
        final path = e['path'], pos = e['positionMs'], dur = e['durationMs'];
        if (path is! String || path.isEmpty || pos is! int || dur is! int) {
          continue;
        }
        if (pos < 0 || dur < 0) continue;
        final last = e['lastPlayedMs'];
        episodes.add(
          BackupEpisode(
            path: path,
            positionMs: pos,
            durationMs: dur,
            watched: e['watched'] == true,
            lastPlayedMs: last is int ? last : null,
          ),
        );
      }
    }

    final at = raw['exportedAt'];
    final ver = raw['appVersion'];
    return BackupFile(
      exportedAt: at is String ? DateTime.tryParse(at) : null,
      appVersion: ver is String ? ver : null,
      settings: settings,
      episodes: episodes,
    );
  }
}

/// What a restore did, for the confirmation message.
class RestoreReport {
  const RestoreReport({
    required this.restored,
    required this.keptLocal,
    required this.notInLibrary,
    required this.settings,
  });

  /// Episodes whose progress was taken from the backup.
  final int restored;

  /// Episodes where this computer's progress was the same or newer.
  final int keptLocal;

  /// Backup entries whose file is not in this library.
  final int notInLibrary;

  /// Settings values written.
  final int settings;
}

/// Exports and restores watch progress and settings as JSON.
///
/// Never includes the TMDB token (it lives in `.env`, not the database) and
/// never touches media files.
class BackupService {
  BackupService(this._db);
  final AppDatabase _db;

  Future<String> exportJson({DateTime? now}) async {
    final rows = await _db.episodesWithProgress();
    final all = await _db.settingsWithPrefix('');
    final data = <String, Object?>{
      'format': BackupFile.format,
      'formatVersion': BackupFile.formatVersion,
      'appVersion': appVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'settings': {
        for (final e in all.entries)
          if (BackupFile.allowedKey(e.key)) e.key: e.value,
      },
      'episodes': [
        for (final e in rows)
          {
            'path': e.filePath,
            'positionMs': e.positionMs,
            'durationMs': e.durationMs,
            'watched': e.watched,
            'lastPlayedMs': e.lastPlayedAt?.millisecondsSinceEpoch,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Applies [file]. Per episode the newer play wins, so restoring an old
  /// backup cannot wipe progress made since. Settings in the backup replace
  /// the current ones.
  Future<RestoreReport> restore(BackupFile file) async {
    var restored = 0, keptLocal = 0, missing = 0;
    for (final b in file.episodes) {
      final local = await _db.episodeByPath(b.path);
      if (local == null) {
        missing++;
        continue;
      }
      if (!_backupIsNewer(b, local)) {
        keptLocal++;
        continue;
      }
      await _db.restoreProgress(
        local.id,
        positionMs: b.positionMs,
        durationMs: b.durationMs,
        watched: b.watched,
        lastPlayedAt: b.lastPlayedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(b.lastPlayedMs!),
      );
      restored++;
    }
    for (final e in file.settings.entries) {
      await _db.setSetting(e.key, e.value);
    }
    return RestoreReport(
      restored: restored,
      keptLocal: keptLocal,
      notInLibrary: missing,
      settings: file.settings.length,
    );
  }

  static bool _backupIsNewer(BackupEpisode b, Episode local) {
    final localMs = local.lastPlayedAt?.millisecondsSinceEpoch;
    final backupMs = b.lastPlayedMs;
    if (backupMs != null) return localMs == null || backupMs > localMs;
    // No play time in the backup (marked watched by hand): only fill in
    // an episode this computer has no progress for.
    return localMs == null && !local.watched && local.positionMs == 0;
  }
}
