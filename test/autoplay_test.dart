import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/watch/autoplay.dart';

const dur = 1500000; // 25 min

bool pos(AutoplayState a, int p, {bool next = true, int d = dur}) =>
    a.onPosition(positionMs: p, durationMs: d, hasNext: next);

void main() {
  test('card appears when 30s remain and starts the countdown', () {
    final a = AutoplayState();
    expect(pos(a, 1000000), isFalse);
    expect(a.showing, isFalse);
    expect(pos(a, dur - 30000), isTrue);
    expect(a.showing, isTrue);
    expect(a.secondsLeft, 10);
  });

  test('repeated positions inside the window do not restart the countdown', () {
    final a = AutoplayState();
    pos(a, dur - 29000);
    a.tick();
    a.tick();
    expect(a.secondsLeft, 8);
    expect(pos(a, dur - 20000), isFalse);
    expect(a.secondsLeft, 8);
  });

  test('countdown finishes after 10 ticks', () {
    final a = AutoplayState();
    pos(a, dur - 20000);
    var fired = false;
    var ticks = 0;
    while (!fired && ticks < 20) {
      fired = a.tick();
      ticks++;
    }
    expect(fired, isTrue);
    expect(ticks, 10);
  });

  test('cancel hides the card and stays cancelled for this episode', () {
    final a = AutoplayState();
    pos(a, dur - 20000);
    a.cancel();
    expect(a.showing, isFalse);
    expect(pos(a, dur - 10000), isFalse);
    expect(a.showing, isFalse);
    expect(a.tick(), isFalse);
  });

  test('reset re-arms for the next episode', () {
    final a = AutoplayState();
    pos(a, dur - 20000);
    a.cancel();
    a.reset();
    expect(pos(a, dur - 20000), isTrue);
    expect(a.showing, isTrue);
  });

  test('no next episode: never shows (end of show)', () {
    final a = AutoplayState();
    expect(pos(a, dur - 10000, next: false), isFalse);
    expect(a.showing, isFalse);
  });

  test('losing the next episode hides an open card', () {
    final a = AutoplayState();
    pos(a, dur - 20000);
    expect(pos(a, dur - 19000, next: false), isTrue);
    expect(a.showing, isFalse);
  });

  test('seeking back out of the window hides the card', () {
    final a = AutoplayState();
    pos(a, dur - 20000);
    expect(pos(a, dur - 120000), isTrue);
    expect(a.showing, isFalse);
    // and it comes back when playback reaches the window again
    expect(pos(a, dur - 25000), isTrue);
    expect(a.showing, isTrue);
  });

  test('short clips never offer a next episode', () {
    final a = AutoplayState();
    expect(pos(a, 80000, d: 90000), isFalse);
    expect(a.showing, isFalse);
  });

  test('tick without a card does nothing', () {
    expect(AutoplayState().tick(), isFalse);
  });

  test('custom lead time (credits marker)', () {
    final a = AutoplayState(leadMs: 90000);
    expect(pos(a, dur - 95000), isFalse);
    expect(pos(a, dur - 90000), isTrue);
  });
}
