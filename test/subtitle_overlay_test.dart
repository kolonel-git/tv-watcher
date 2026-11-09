import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/player/subtitle_overlay.dart';
import 'package:tv_watcher/player/subtitle_style.dart';

Widget host({
  required double bottom,
  double dx = 0,
  void Function(Offset)? onUpdate,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 1000,
      height: 600,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SubtitleLayer(
            text: 'Hello there',
            style: SubtitleStyle.defaults,
            bottom: bottom,
            dx: dx,
            dragging: false,
            maxWidth: 800,
            onDragStart: () {},
            onDragUpdate: onUpdate ?? (_) {},
            onDragEnd: () {},
            onReset: () {},
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'text sits exactly `bottom` above the bottom edge, not mid-screen',
    (t) async {
      await t.pumpWidget(host(bottom: 28));
      await t.pump(const Duration(milliseconds: 300));
      final box = t.getRect(find.byKey(const Key('subtitle-box')));
      final stack = t.getRect(find.byType(Stack).first);
      expect(stack.bottom - box.bottom, closeTo(28, 0.5));
      expect(box.center.dy, greaterThan(stack.height * 0.8));
    },
  );

  testWidgets('bottom 0 puts the text at the very bottom', (t) async {
    await t.pumpWidget(host(bottom: 0));
    await t.pump(const Duration(milliseconds: 300));
    final box = t.getRect(find.byKey(const Key('subtitle-box')));
    final stack = t.getRect(find.byType(Stack).first);
    expect(stack.bottom - box.bottom, closeTo(0, 0.5));
  });

  testWidgets(
    'wrapped like the player (Positioned.fill > builders), drag moves it in x and y',
    (t) async {
      var bottom = 28.0, dx = 0.0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: StatefulBuilder(
                builder: (context, set) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) => StreamBuilder<String>(
                          stream: const Stream<String>.empty(),
                          initialData: 'Hello there',
                          builder: (context, snap) => SubtitleLayer(
                            text: snap.data!,
                            style: SubtitleStyle.defaults,
                            bottom: bottom,
                            dx: dx,
                            dragging: false,
                            maxWidth: 800,
                            onDragStart: () {},
                            onDragUpdate: (d) => set(() {
                              bottom -= d.dy;
                              dx += d.dx;
                            }),
                            onDragEnd: () {},
                            onReset: () {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      final start = t.getRect(find.byKey(const Key('subtitle-box')));
      // starts near the bottom, not mid-screen
      expect(start.center.dy, greaterThan(600 * 0.8));

      await t.drag(
        find.byKey(const Key('subtitle-box')),
        const Offset(60, -200),
      );
      await t.pumpAndSettle();
      final end = t.getRect(find.byKey(const Key('subtitle-box')));
      expect(end.center.dx - start.center.dx, greaterThan(30));
      expect(start.center.dy - end.center.dy, greaterThan(100));

      // and back down, below where it began
      await t.drag(find.byKey(const Key('subtitle-box')), const Offset(0, 400));
      await t.pumpAndSettle();
      final low = t.getRect(find.byKey(const Key('subtitle-box')));
      expect(low.center.dy, greaterThan(end.center.dy + 100));
    },
  );

  testWidgets('dragging reports pointer deltas', (t) async {
    var total = Offset.zero;
    await t.pumpWidget(host(bottom: 100, onUpdate: (d) => total += d));
    await t.pump(const Duration(milliseconds: 300));
    await t.drag(find.byKey(const Key('subtitle-box')), const Offset(0, 80));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500)); // double-tap timer
    expect(total.dy, greaterThan(40));
  });
}
