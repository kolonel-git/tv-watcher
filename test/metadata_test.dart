import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tv_watcher/config/env_config.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/metadata/metadata_service.dart';
import 'package:tv_watcher/metadata/tmdb_client.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('EnvConfig', () {
    test('parses values, comments, quotes', () {
      final m = EnvConfig.parse(
        '# c\nTMDB_READ_TOKEN="abc"\n\nTMDB_LANGUAGE=fr-FR\nbad line\n',
      );
      final c = EnvConfig(m);
      expect(c.tmdbToken, 'abc');
      expect(c.language, 'fr-FR');
    });
    test('defaults', () {
      final c = EnvConfig(EnvConfig.parse('TMDB_READ_TOKEN=\n'));
      expect(c.tmdbToken, isNull);
      expect(c.language, 'en-US');
    });
  });

  group('TmdbClient', () {
    test('sends bearer token and language, parses search', () async {
      late http.Request seen;
      final c = TmdbClient(
        token: 'tok',
        language: 'en-US',
        client: MockClient((req) async {
          seen = req;
          return json({
            'results': [
              {
                'id': 60625,
                'name': 'Rick and Morty',
                'first_air_date': '2013-12-02',
                'overview': 'x',
                'poster_path': '/p.jpg',
              },
            ],
          });
        }),
      );
      final r = await c.searchShow('Rick and Morty', year: 2013);
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.url.queryParameters['language'], 'en-US');
      expect(seen.url.queryParameters['first_air_date_year'], '2013');
      expect(r.single.id, 60625);
      expect(r.single.year, 2013);
    });

    test('non-200 throws TmdbException', () async {
      final c = TmdbClient(
        token: 't',
        language: 'en-US',
        client: MockClient((_) async => json({}, 401)),
      );
      expect(
        () => c.showDetails(1),
        throwsA(isA<TmdbException>().having((e) => e.statusCode, 'code', 401)),
      );
    });
  });

  group('MetadataService', () {
    late AppDatabase db;
    late Directory tmp;
    late int showId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('tvw_art_');
      final folderId = await db.addFolder(r'C:\media');
      showId = await db.upsertShow('Rick and Morty', 'rickandmorty', 2013);
      for (final n in [1, 2]) {
        await db
            .into(db.episodes)
            .insert(
              EpisodesCompanion.insert(
                filePath: 'C:\\media\\s01e0$n.mkv',
                folderId: folderId,
                showId: Value(showId),
                season: Value(1),
                episode: Value(n),
              ),
            );
      }
    });
    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    MetadataService service(
      Future<http.Response> Function(http.Request) handler, {
      String lang = 'en-US',
      List<String>? downloads,
    }) => MetadataService(
      db: db,
      client: TmdbClient(
        token: 't',
        language: lang,
        client: MockClient(handler),
      ),
      artworkDir: tmp,
      requestDelay: Duration.zero,
      download: (url) async {
        downloads?.add(url);
        return [1, 2, 3];
      },
    );

    Future<http.Response> happy(http.Request r) async {
      final path = r.url.path;
      if (path == '/3/search/tv') {
        return json({
          'results': [
            {'id': 1, 'name': 'Rick and Morty', 'first_air_date': '2013-12-02'},
            {'id': 2, 'name': 'Rick and Morty Shorts'},
          ],
        });
      }
      if (path == '/3/tv/1') {
        return json({
          'id': 1,
          'name': 'Rick and Morty',
          'overview': 'Scientist and grandson.',
          'poster_path': '/poster.jpg',
          'backdrop_path': '/back.jpg',
        });
      }
      if (path == '/3/tv/1/season/1') {
        return json({
          'episodes': [
            {
              'episode_number': 1,
              'name': 'Pilot',
              'overview': 'First.',
              'runtime': 22,
              'still_path': '/s1.jpg',
              'air_date': '2013-12-02',
            },
            {
              'episode_number': 2,
              'name': 'Lawnmower Dog',
              'overview': 'Second.',
              'runtime': 22,
              'still_path': null,
            },
          ],
        });
      }
      return json({}, 404);
    }

    test(
      'auto-matches exact name, stores show + episode data, caches art',
      () async {
        final downloads = <String>[];
        final s = service(happy, downloads: downloads);
        final summary = await s.syncAll();
        expect(summary.matched, 1);

        final show = await (db.select(db.shows)).getSingle();
        expect(show.tmdbId, 1);
        expect(show.metaStatus, 'matched');
        expect(show.overview, 'Scientist and grandson.');
        expect(File(show.posterFile!).existsSync(), isTrue);
        expect(File(show.backdropFile!).existsSync(), isTrue);

        final eps = await (db.select(
          db.episodes,
        )..orderBy([(e) => OrderingTerm.asc(e.episode)])).get();
        expect(eps[0].tmdbTitle, 'Pilot');
        expect(eps[0].runtime, 22);
        expect(File(eps[0].stillFile!).existsSync(), isTrue);
        expect(eps[1].tmdbTitle, 'Lawnmower Dog');
        expect(eps[1].stillFile, isNull);
        expect(downloads.any((u) => u.contains('/w342/poster.jpg')), isTrue);
      },
    );

    test('artwork not re-downloaded when cached', () async {
      final downloads = <String>[];
      final s = service(happy, downloads: downloads);
      await s.syncAll();
      final first = downloads.length;
      await s.refresh(showId);
      expect(downloads.length, first);
    });

    test('ambiguous when no exact name and several results', () async {
      final s = service(
        (r) async => r.url.path == '/3/search/tv'
            ? json({
                'results': [
                  {'id': 5, 'name': 'Something Else'},
                  {'id': 6, 'name': 'Another'},
                ],
              })
            : json({}, 404),
      );
      final summary = await s.syncAll();
      expect(summary.ambiguous, 1);
      expect((await db.select(db.shows).getSingle()).metaStatus, 'ambiguous');
    });

    test('nomatch when search empty', () async {
      final s = service((r) async => json({'results': []}));
      final summary = await s.syncAll();
      expect(summary.noMatch, 1);
    });

    test('user pick locks match and fetches', () async {
      final s = service(happy);
      await s.pickMatch(showId, 1);
      final show = await db.select(db.shows).getSingle();
      expect(show.metaLocked, isTrue);
      expect(show.tmdbName, 'Rick and Morty');
    });

    test('network down leaves show untouched and reports offline', () async {
      final s = service((_) async => throw const SocketException('offline'));
      final summary = await s.syncAll();
      expect(summary.offline, isTrue);
      expect((await db.select(db.shows).getSingle()).metaStatus, 'none');
    });

    test('API error counts as failed, other shows continue', () async {
      final s = service((_) async => json({}, 500));
      final summary = await s.syncAll();
      expect(summary.failed, 1);
      expect((await db.select(db.shows).getSingle()).metaStatus, 'none');
    });

    test(
      'non-English language falls back to English for missing text',
      () async {
        final langs = <String>[];
        final s = service((r) async {
          langs.add(r.url.queryParameters['language'] ?? '');
          final lang = r.url.queryParameters['language'];
          final path = r.url.path;
          if (path == '/3/search/tv') {
            return json({
              'results': [
                {'id': 1, 'name': 'Rick and Morty'},
              ],
            });
          }
          if (path == '/3/tv/1') {
            return json({
              'id': 1,
              'name': 'Rick et Morty',
              'overview': lang == 'fr-FR' ? '' : 'English overview',
            });
          }
          if (path == '/3/tv/1/season/1') {
            return json({
              'episodes': [
                {
                  'episode_number': 1,
                  'name': lang == 'fr-FR' ? 'Pilote' : 'Pilot',
                  'overview': lang == 'fr-FR' ? '' : 'English ep overview',
                },
              ],
            });
          }
          return json({}, 404);
        }, lang: 'fr-FR');
        await s.syncAll();
        final show = await db.select(db.shows).getSingle();
        expect(show.tmdbName, 'Rick et Morty'); // localised kept
        expect(show.overview, 'English overview'); // fallback filled
        final ep = await (db.select(
          db.episodes,
        )..where((e) => e.episode.equals(1))).getSingle();
        expect(ep.tmdbTitle, 'Pilote');
        expect(ep.overview, 'English ep overview');
        expect(langs, contains('en-US'));
      },
    );
  });
}
