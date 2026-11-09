import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/player/cone_volume.dart';

void main() {
  testWidgets('tap sets volume proportional to x position', (t) async {
    double? got;
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConeVolumeSlider(
            value: 50,
            width: 100,
            onChanged: (v) => got = v,
          ),
        ),
      ),
    );
    final box = t.getRect(find.byType(ConeVolumeSlider));
    await t.tapAt(Offset(box.left + 80, box.center.dy));
    expect(got, closeTo(80, 1));
    await t.tapAt(Offset(box.left + 1, box.center.dy));
    expect(got, lessThan(3));
  });

  testWidgets('drag past the ends clamps to 0..max', (t) async {
    final values = <double>[];
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConeVolumeSlider(value: 10, width: 100, onChanged: values.add),
        ),
      ),
    );
    final box = t.getRect(find.byType(ConeVolumeSlider));
    await t.dragFrom(
      Offset(box.left + 50, box.center.dy),
      const Offset(300, 0),
    );
    expect(values.every((v) => v >= 0 && v <= 100), isTrue);
    expect(values.last, 100);
  });
}
