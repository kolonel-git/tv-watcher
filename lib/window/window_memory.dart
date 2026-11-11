import 'dart:async';
import 'dart:ui' show Offset, Rect;

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../data/database.dart';
import 'window_frame.dart';

/// Remembers the window's position, size and maximized state between runs.
///
/// Restores the saved frame at startup (repaired by [WindowFrame.fitTo] if
/// the screens changed) and saves after the user stops moving or resizing.
/// Does nothing visible when nothing was saved. Only the settings table is
/// written; no files are touched.
class WindowMemory with WindowListener {
  WindowMemory._(this._db);
  final AppDatabase _db;
  Timer? _debounce;

  /// True while the player is fullscreen: that frame must not be remembered.
  static bool suspended = false;

  static const _saveDelay = Duration(milliseconds: 500);

  /// Call once before `runApp`. Failures are swallowed: window memory is a
  /// convenience and must never stop the app from starting.
  static Future<WindowMemory?> start(AppDatabase db) async {
    try {
      await windowManager.ensureInitialized();
      final saved = WindowFrame.decode(
        await db.getSetting(WindowFrame.storageKey),
      );
      if (saved != null) {
        final frame = saved.fitTo(await _displays());
        await windowManager.setBounds(frame.rect);
        if (frame.maximized) await windowManager.maximize();
      }
      final memory = WindowMemory._(db);
      windowManager.addListener(memory);
      return memory;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Rect>> _displays() async {
    final all = await screenRetriever.getAllDisplays();
    return [
      for (final d in all)
        Rect.fromLTWH(
          (d.visiblePosition ?? Offset.zero).dx,
          (d.visiblePosition ?? Offset.zero).dy,
          (d.visibleSize ?? d.size).width,
          (d.visibleSize ?? d.size).height,
        ),
    ];
  }

  void _schedule() {
    if (suspended) return;
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, save);
  }

  Future<void> save() async {
    if (suspended) return;
    try {
      final maximized = await windowManager.isMaximized();
      final minimized = await windowManager.isMinimized();
      if (minimized) return; // Windows reports a bogus off-screen frame.
      final saved = WindowFrame.decode(
        await _db.getSetting(WindowFrame.storageKey),
      );
      // While maximized keep the last normal size so un-maximizing restores
      // something sensible.
      final b = maximized && saved != null
          ? saved.rect
          : await windowManager.getBounds();
      await _db.setSetting(
        WindowFrame.storageKey,
        WindowFrame(
          x: b.left,
          y: b.top,
          width: b.width,
          height: b.height,
          maximized: maximized,
        ).encode(),
      );
    } catch (_) {
      // Best effort.
    }
  }

  @override
  void onWindowResized() => _schedule();
  @override
  void onWindowMoved() => _schedule();
  @override
  void onWindowMaximize() => _schedule();
  @override
  void onWindowUnmaximize() => _schedule();
  @override
  void onWindowRestore() => _schedule();
}
