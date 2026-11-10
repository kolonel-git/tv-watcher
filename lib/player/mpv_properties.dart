import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Thin wrapper over libmpv properties. Isolates the one platform-specific
/// cast and the failure policy (log, never crash playback) so the rest of
/// the player never touches `NativePlayer` directly.
class MpvProperties {
  const MpvProperties(this._player);
  final Player _player;

  Future<void> set(String name, String value) async {
    final p = _player.platform;
    if (p is! NativePlayer) return;
    try {
      await p.setProperty(name, value);
    } catch (e) {
      debugPrint('mpv set $name failed: $e');
    }
  }
}
