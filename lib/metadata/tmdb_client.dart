import 'dart:convert';

import 'package:http/http.dart' as http;

class TmdbException implements Exception {
  TmdbException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'TmdbException($statusCode): $message';
}

class TmdbSearchResult {
  const TmdbSearchResult({
    required this.id,
    required this.name,
    this.year,
    this.overview,
    this.posterPath,
  });
  final int id;
  final String name;
  final int? year;
  final String? overview;
  final String? posterPath;
}

class TmdbShow {
  const TmdbShow({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
  });
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
}

class TmdbEpisode {
  const TmdbEpisode({
    required this.number,
    this.name,
    this.overview,
    this.runtime,
    this.stillPath,
    this.airDate,
  });
  final int number;
  final String? name;
  final String? overview;
  final int? runtime;
  final String? stillPath;
  final String? airDate;
}

String? _s(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? _yearOf(Object? date) {
  final s = _s(date);
  if (s == null || s.length < 4) return null;
  return int.tryParse(s.substring(0, 4));
}

/// Thin TMDB v3 client using a Read Access Token (Bearer).
class TmdbClient {
  TmdbClient({required this.token, required this.language, http.Client? client})
    : _http = client ?? http.Client();

  final String token;
  final String language;
  final http.Client _http;

  static const _host = 'api.themoviedb.org';

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(_host, '/3$path', query);
    final res = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw TmdbException('GET $path failed', statusCode: res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<TmdbSearchResult>> searchShow(
    String query, {
    int? year,
    String? lang,
  }) async {
    final json = await _get('/search/tv', {
      'query': query,
      'language': lang ?? language,
      if (year != null) 'first_air_date_year': '$year',
    });
    return [
      for (final r in (json['results'] as List? ?? const []))
        TmdbSearchResult(
          id: r['id'] as int,
          name: _s(r['name']) ?? '',
          year: _yearOf(r['first_air_date']),
          overview: _s(r['overview']),
          posterPath: _s(r['poster_path']),
        ),
    ];
  }

  Future<TmdbShow> showDetails(int id, {String? lang}) async {
    final r = await _get('/tv/$id', {'language': lang ?? language});
    return TmdbShow(
      id: r['id'] as int,
      name: _s(r['name']) ?? '',
      overview: _s(r['overview']),
      posterPath: _s(r['poster_path']),
      backdropPath: _s(r['backdrop_path']),
    );
  }

  Future<List<TmdbEpisode>> seasonEpisodes(
    int showId,
    int season, {
    String? lang,
  }) async {
    final r = await _get('/tv/$showId/season/$season', {
      'language': lang ?? language,
    });
    return [
      for (final e in (r['episodes'] as List? ?? const []))
        TmdbEpisode(
          number: e['episode_number'] as int,
          name: _s(e['name']),
          overview: _s(e['overview']),
          runtime: e['runtime'] as int?,
          stillPath: _s(e['still_path']),
          airDate: _s(e['air_date']),
        ),
    ];
  }

  void close() => _http.close();
}
