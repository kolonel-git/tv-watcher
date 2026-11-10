import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/player/player_config.dart';
import 'package:tv_watcher/player/player_shortcuts.dart';
import 'package:tv_watcher/player/progress_gate.dart';
import 'package:tv_watcher/player/subtitle_placement.dart';

class _Fake implements PlayerCommands {
  final calls = <String>[];
  @override
  void playPause() => calls.add('playPause');
  @override
  void seek(int d) => calls.add('seek$d');
  @override
  void changeVolume(int d) => calls.add('vol$d');
  @override
  void toggleFullscreen() => calls.add('fs');
  @override
  void toggleMute() => calls.add('mute');
  @override
  void openFile() => calls.add('open');
  @override
  void cycleSubtitles() => calls.add('subs');
  @override
  void cycleAudio() => calls.add('audio');
  @override
  void nextEpisode() => calls.add('next');
  @override
  void toggleShortcutHelp() => calls.add('help');
  @override
  void escape() => calls.add('esc');
  @override
  void speedDown() => calls.add('slower');
  @override
  void speedUp() => calls.add('faster');
  @override
  void subtitleDelay(int d) => calls.add('subdelay$d');
}

void main() {
  group('PlayerShortcuts', () {
    const s = PlayerShortcuts();
    test('maps keys to commands', () {
      final f = _Fake();
      for (final k in [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.keyO,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyN,
      ]) {
        expect(s.dispatch(k, null, f), isTrue);
      }
      expect(f.calls, [
        'playPause',
        'seek-1',
        'seek1',
        'vol1',
        'vol-1',
        'fs',
        'esc',
        'mute',
        'open',
        'subs',
        'audio',
        'next',
      ]);
    });

    test('speed and subtitle delay keys', () {
      final f = _Fake();
      s.dispatch(LogicalKeyboardKey.bracketLeft, '[', f);
      s.dispatch(LogicalKeyboardKey.bracketRight, ']', f);
      s.dispatch(LogicalKeyboardKey.keyZ, 'z', f);
      s.dispatch(LogicalKeyboardKey.keyX, 'x', f);
      expect(f.calls, ['slower', 'faster', 'subdelay-1', 'subdelay1']);
    });

    test('? opens help; unknown keys are not handled', () {
      final f = _Fake();
      expect(s.dispatch(LogicalKeyboardKey.slash, '?', f), isTrue);
      expect(s.dispatch(LogicalKeyboardKey.keyQ, 'q', f), isFalse);
      expect(f.calls, ['help']);
    });
  });

  group('SubtitlePlacement', () {
    SubtitlePlacement make() =>
        SubtitlePlacement(baseBottom: 28, barClearance: 84);

    test('default position lifts above the bar only while it is shown', () {
      final p = make();
      expect(p.effectiveBottom(controlsVisible: true), 84);
      expect(p.effectiveBottom(controlsVisible: false), 28);
    });

    test('a moved position is never lifted or snapped back', () {
      final p = make()..restore(bottom: 40);
      expect(p.moved, isTrue);
      expect(p.effectiveBottom(controlsVisible: true), 40);
    });

    test('drag follows the pointer on both axes and clamps', () {
      final p = make();
      p.startDrag(shownBottom: 84);
      expect(p.dragging, isTrue);
      p.dragBy(const Offset(30, -100), area: const Size(1000, 600));
      expect(p.bottom, 184);
      expect(p.dx, 30);
      p.dragBy(const Offset(0, 5000), area: const Size(1000, 600));
      expect(p.bottom, 0);
      p.dragBy(const Offset(9000, 0), area: const Size(1000, 600));
      expect(p.dx, 500);
      p.endDrag();
      expect(p.dragging, isFalse);
    });

    test('reset returns to the default and notifies', () {
      final p = make()..restore(bottom: 300, dx: 50);
      var n = 0;
      p.addListener(() => n++);
      p.reset();
      expect(p.moved, isFalse);
      expect(n, 1);
    });
  });

  group('ProgressGate', () {
    ProgressGate make() => ProgressGate(
      startTolerance: const Duration(seconds: 3),
      startGuard: const Duration(seconds: 10),
      armedBelowFraction: 0.9,
    );
    const total = Duration(minutes: 40);

    test('not trusted until armed; arming reported once', () {
      final g = make()..begin(null);
      expect(g.trusted, isFalse);
      expect(g.onPosition(const Duration(seconds: 1), total), isTrue);
      expect(g.onPosition(const Duration(seconds: 2), total), isFalse);
      expect(g.trusted, isTrue);
    });

    test('stale end-of-file position does not arm', () {
      final g = make()..begin(null);
      expect(g.onPosition(const Duration(minutes: 39), total), isFalse);
      expect(g.armed, isFalse);
    });

    test('resume: position 0 is not trusted until the seek lands', () {
      final g = make()..begin(const Duration(minutes: 10));
      g.onPosition(Duration.zero, total);
      expect(g.armed, isTrue);
      expect(g.trusted, isFalse);
      g.onPosition(const Duration(minutes: 10), total);
      expect(g.trusted, isTrue);
      g.dispose();
    });
  });

  test('PlayerConfig defaults', () {
    const c = PlayerConfig.defaults;
    expect(c.seekStep, const Duration(seconds: 10));
    expect(c.barClearance, greaterThan(c.subBaseBottom));
  });
}
