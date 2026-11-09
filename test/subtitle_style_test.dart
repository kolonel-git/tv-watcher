import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/player/subtitle_style.dart';

void main() {
  test('encode/decode round trip', () {
    const s = SubtitleStyle(
      size: 40,
      colorValue: 0xFFFFE066,
      backgroundOpacity: 0.7,
      bold: false,
      outline: false,
    );
    expect(SubtitleStyle.decode(s.encode()), s);
  });

  test('bad input gives defaults', () {
    expect(SubtitleStyle.decode(null), SubtitleStyle.defaults);
    expect(SubtitleStyle.decode('nope'), SubtitleStyle.defaults);
    expect(SubtitleStyle.decode('[1]'), SubtitleStyle.defaults);
  });

  test('out-of-range values are clamped, wrong types ignored', () {
    final s = SubtitleStyle.decode(
      '{"size":500,"bg":5,"bold":"x","color":"red"}',
    );
    expect(s.size, SubtitleStyle.maxSize);
    expect(s.backgroundOpacity, 0.9);
    expect(s.bold, SubtitleStyle.defaults.bold);
    expect(s.colorValue, SubtitleStyle.defaults.colorValue);
  });

  test('outline off drops shadows, bold off lightens weight', () {
    final t = SubtitleStyle.defaults
        .copyWith(outline: false, bold: false)
        .textStyle;
    expect(t.shadows, isNull);
    expect(t.fontWeight, FontWeight.w400);
  });

  testWidgets('panel edits call onChanged and reset restores defaults', (
    t,
  ) async {
    SubtitleStyle? last;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SubtitleSettingsPanel(
              initial: SubtitleStyle.defaults,
              onChanged: (s) => last = s,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(Key('sub-color-${SubtitleStyle.colors[1]}')));
    await t.pump();
    expect(last!.colorValue, SubtitleStyle.colors[1]);
    await t.tap(find.byKey(const Key('sub-bold')));
    await t.pump();
    expect(last!.bold, isFalse);
    await t.tap(find.text('Reset'));
    await t.pump();
    expect(last, SubtitleStyle.defaults);
  });

  testWidgets('panel reset-position button calls back', (t) async {
    var resets = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SubtitleSettingsPanel(
              initial: SubtitleStyle.defaults,
              onChanged: (_) {},
              onResetPosition: () => resets++,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('sub-reset-pos')));
    await t.pump();
    expect(resets, 1);
  });
}
