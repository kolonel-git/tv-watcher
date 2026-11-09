import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Volume control drawn as a row of rounded bars that grow taller from left
/// (quiet) to right (loud), centred vertically so the bars form a symmetric
/// cone that opens away from the volume button. Bars up to the current
/// volume are lit yellow-to-red; the rest are dim.
class ConeVolumeSlider extends StatelessWidget {
  const ConeVolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 100,
    this.width = 120,
    this.height = 32,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final double width;
  final double height;

  void _setFromDx(double dx) => onChanged(((dx / width).clamp(0.0, 1.0)) * max);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Volume ${value.round()}%',
      child: Listener(
        // Mouse wheel adjusts volume.
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            onChanged((value - e.scrollDelta.dy.sign * 5).clamp(0, max));
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFromDx(d.localPosition.dx),
          onHorizontalDragStart: (d) => _setFromDx(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => _setFromDx(d.localPosition.dx),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CustomPaint(
              size: Size(width, height),
              painter: ConeVolumePainter(fraction: (value / max).clamp(0, 1)),
            ),
          ),
        ),
      ),
    );
  }
}

class ConeVolumePainter extends CustomPainter {
  ConeVolumePainter({required this.fraction});
  final double fraction;

  static const barCount = 16;
  static const _lowLit = Color(0xFFFFC21A); // small bars: yellow
  static const _highLit = Color(0xFFE50914); // big bars: red
  static const _unlit = Color(0x2EFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / barCount;
    final barW = slot * 0.62;
    final minH = size.height * 0.16;
    final cy = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final t = i / (barCount - 1);
      final h = minH + (size.height - minH) * t;
      final cx = slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: barW, height: h),
        Radius.circular(barW / 2),
      );
      // A bar is lit when the volume reaches the middle of its slot.
      final lit = fraction > 0 && (i + 0.5) / barCount <= fraction + 1e-9;
      canvas.drawRRect(
        rect,
        Paint()..color = lit ? Color.lerp(_lowLit, _highLit, t)! : _unlit,
      );
    }
  }

  @override
  bool shouldRepaint(ConeVolumePainter old) => old.fraction != fraction;
}
