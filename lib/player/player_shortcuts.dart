import 'package:flutter/services.dart';

/// What the keyboard can ask the player to do. The page implements this; the
/// key map below depends only on this interface (easy to test with a fake).
abstract interface class PlayerCommands {
  void playPause();
  void seek(int direction); // -1 back, +1 forward
  void changeVolume(int direction); // -1 down, +1 up
  void toggleFullscreen();
  void toggleMute();
  void openFile();
  void cycleSubtitles();
  void cycleAudio();
  void nextEpisode();
  void toggleShortcutHelp();
  void speedDown();
  void speedUp();
  void subtitleDelay(int direction); // -1 earlier, +1 later

  /// Esc: close the panel, else leave fullscreen, else go back.
  void escape();
}

/// Maps keys to [PlayerCommands]. One place to change or rebind shortcuts.
class PlayerShortcuts {
  const PlayerShortcuts();

  /// Runs the command for [key]. Returns false when the key is not ours.
  bool dispatch(LogicalKeyboardKey key, String? character, PlayerCommands c) {
    if (character == '?') {
      c.toggleShortcutHelp();
      return true;
    }
    final action = _keys[key];
    if (action == null) return false;
    action(c);
    return true;
  }

  static final Map<LogicalKeyboardKey, void Function(PlayerCommands)> _keys = {
    LogicalKeyboardKey.space: (c) => c.playPause(),
    LogicalKeyboardKey.arrowLeft: (c) => c.seek(-1),
    LogicalKeyboardKey.arrowRight: (c) => c.seek(1),
    LogicalKeyboardKey.arrowUp: (c) => c.changeVolume(1),
    LogicalKeyboardKey.arrowDown: (c) => c.changeVolume(-1),
    LogicalKeyboardKey.keyF: (c) => c.toggleFullscreen(),
    LogicalKeyboardKey.escape: (c) => c.escape(),
    LogicalKeyboardKey.keyM: (c) => c.toggleMute(),
    LogicalKeyboardKey.keyO: (c) => c.openFile(),
    LogicalKeyboardKey.keyV: (c) => c.cycleSubtitles(),
    LogicalKeyboardKey.keyB: (c) => c.cycleAudio(),
    LogicalKeyboardKey.keyN: (c) => c.nextEpisode(),
    LogicalKeyboardKey.bracketLeft: (c) => c.speedDown(),
    LogicalKeyboardKey.bracketRight: (c) => c.speedUp(),
    LogicalKeyboardKey.keyZ: (c) => c.subtitleDelay(-1),
    LogicalKeyboardKey.keyX: (c) => c.subtitleDelay(1),
  };
}
