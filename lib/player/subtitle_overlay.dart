import 'package:flutter/material.dart';

import 'subtitle_style.dart';

/// Subtitle text anchored [bottom] pixels above the bottom edge of the
/// surrounding Stack, shifted sideways by [dx], and draggable.
///
/// Must be a direct child of a Stack that fills the video area. The text box
/// hugs its content (`heightFactor: 1`): without that, `Center` stretches to
/// the full height above [bottom] and the text sits mid-screen.
class SubtitleLayer extends StatelessWidget {
  const SubtitleLayer({
    super.key,
    required this.text,
    required this.style,
    required this.bottom,
    required this.dx,
    required this.dragging,
    required this.maxWidth,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onReset,
  });

  final String text;
  final SubtitleStyle style;
  final double bottom;
  final double dx;
  final bool dragging;
  final double maxWidth;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    // Own Stack: the Positioned below must be a direct child of a Stack, so
    // callers can wrap this in LayoutBuilder / StreamBuilder / Positioned.fill
    // without breaking the placement. (A Positioned buried under a builder is
    // silently ignored and the text ends up centred on screen.)
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPositioned(
          duration: dragging
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: bottom,
          child: Center(
            heightFactor: 1,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  onPanStart: (_) => onDragStart(),
                  onPanUpdate: (d) => onDragUpdate(d.delta),
                  onPanEnd: (_) => onDragEnd(),
                  onPanCancel: onDragEnd,
                  onDoubleTap: onReset,
                  child: Container(
                    key: const Key('subtitle-box'),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: style.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: style.textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
