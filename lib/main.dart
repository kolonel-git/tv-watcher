import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'data/database.dart';
import 'library/library_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(TvWatcherApp(db: AppDatabase()));
}

class TvWatcherApp extends StatelessWidget {
  const TvWatcherApp({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Watcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE50914)),
      ),
      home: LibraryPage(db: db),
    );
  }
}
