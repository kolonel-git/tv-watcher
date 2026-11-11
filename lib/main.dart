import 'package:flutter/material.dart';

import 'ui/image_budget.dart';
import 'ui/theme.dart';
import 'window/window_memory.dart';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'config/env_config.dart';
import 'data/database.dart';
import 'settings/settings_controller.dart';
import 'ui/home_page.dart';
import 'metadata/metadata_service.dart';
import 'metadata/tmdb_client.dart';

import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  ImageBudget.apply();
  final db = AppDatabase();
  await WindowMemory.start(db);
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
  final settings = await SettingsController.load(
    db,
    meta: meta,
    envLanguage: env.language,
  );
  runApp(TvWatcherApp(db: db, meta: meta, settings: settings));
}

class TvWatcherApp extends StatelessWidget {
  const TvWatcherApp({
    super.key,
    required this.db,
    this.meta,
    required this.settings,
  });
  final AppDatabase db;
  final MetadataService? meta;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: settings,
      child: MaterialApp(
        title: 'TV Watcher',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomePage(db: db, meta: meta),
      ),
    );
  }
}
