import 'dart:convert';
import 'dart:ui' show Rect, Size;

/// Where the app window was last: position, size and maximized state.
///
/// Pure data plus validation, so it can be tested without a window. The
/// stored text is untrusted (hand-edited file, other machine): decoding is
/// tolerant and [fitTo] repairs frames that would be off-screen or tiny.
class WindowFrame {
  const WindowFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.maximized = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final bool maximized;

  static const minSize = Size(640, 400);
  static const maxDimension = 20000.0;

  /// Settings key the frame is stored under. Not in the whitelisted backup
  /// prefixes on purpose: window geometry belongs to one computer.
  static const storageKey = 'window.frame';

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  String encode() =>
      jsonEncode({'x': x, 'y': y, 'w': width, 'h': height, 'max': maximized});

  /// Returns null for anything that is not a sane frame.
  static WindowFrame? decode(String? text) {
    if (text == null || text.length > 500) return null;
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (raw is! Map) return null;
    double? num_(Object? v) =>
        v is num && v.isFinite && v.abs() <= maxDimension ? v.toDouble() : null;
    final x = num_(raw['x']),
        y = num_(raw['y']),
        w = num_(raw['w']),
        h = num_(raw['h']);
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 0 || h <= 0) return null;
    return WindowFrame(
      x: x,
      y: y,
      width: w,
      height: h,
      maximized: raw['max'] == true,
    );
  }

  /// A frame that is safe to apply on a machine whose screens are
  /// [displays]: never smaller than [minSize], never larger than the screen
  /// it lands on, and moved onto a screen when it would be (nearly) off all
  /// of them, e.g. after unplugging a monitor.
  ///
  /// With no display information the frame is returned with only the size
  /// floor applied.
  WindowFrame fitTo(List<Rect> displays) {
    var w = width < minSize.width ? minSize.width : width;
    var h = height < minSize.height ? minSize.height : height;
    if (displays.isEmpty) {
      return WindowFrame(x: x, y: y, width: w, height: h, maximized: maximized);
    }
    // The screen holding most of the window; the first one if none does.
    Rect best = displays.first;
    var bestArea = -1.0;
    for (final d in displays) {
      final i = rect.intersect(d);
      final area = i.width > 0 && i.height > 0 ? i.width * i.height : 0.0;
      if (area > bestArea) {
        bestArea = area;
        best = d;
      }
    }
    if (w > best.width) w = best.width;
    if (h > best.height) h = best.height;
    var nx = x, ny = y;
    final visible = Rect.fromLTWH(nx, ny, w, h).intersect(best);
    // Needs a grabbable part of the title bar on screen.
    final onScreen = visible.width >= 120 && visible.height >= 60;
    if (!onScreen) {
      nx = best.left + (best.width - w) / 2;
      ny = best.top + (best.height - h) / 2;
    }
    return WindowFrame(x: nx, y: ny, width: w, height: h, maximized: maximized);
  }

  @override
  bool operator ==(Object other) =>
      other is WindowFrame &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.maximized == maximized;

  @override
  int get hashCode => Object.hash(x, y, width, height, maximized);
}
