import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'config/env_config.dart';
import 'data/database.dart';
import 'ui/home_page.dart';
import 'metadata/metadata_service.dart';
import 'metadata/tmdb_client.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final db = AppDatabase();
  final env = await EnvConfig.load();
  MetadataService? meta;
  final token = env.tmdbToken;
  if (token != null) {
    final support = await getApplicationSupportDirectory();
    meta = MetadataService(
      db: db,
      client: TmdbClient(token: token, language: env.language),
      artworkDir: Directory(p.join(support.path, 'artwork')),
    );
  }
  runApp(TvWatcherApp(db: db, meta: meta));
}

class TvWatcherApp extends StatelessWidget {
  const TvWatcherApp({super.key, required this.db, this.meta});
  final AppDatabase db;
  final MetadataService? meta;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'TV Watcher',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE50914)),
        textTheme: base.textTheme.apply(fontFamily: 'Poppins'),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Poppins'),
      ),
      home: HomePage(db: db, meta: meta),
    );
  }
}
