import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/watch/watch_logic.dart';

EpRef ep(int id, int s, int e,
        {bool watched = false,
        int pos = 0,
        int dur = 1000000,
        DateTime? at}) =>
    EpRef(
        id: id,
        season: s,
        episode: e,
        watched: watched,
        positionMs: pos,
        durationMs: dur,
        lastPlayedAt: at);

DateTime t(int minute) => DateTime(2026, 1, 1, 12, minute);

void main() {
  group('computeProgress', () {
    test('stores exact position mid-episode', () {
      expect(
          computeProgress(positionMs: 300000, durationMs: 1000000, wasWatched: false),
          const ProgressUpdate(positionMs: 300000, watched: false));
    });
    test('90% marks watched and resets position', () {
      expect(
          computeProgress(positionMs: 900000, durationMs: 1000000, wasWatched: false),
          const ProgressUpdate(positionMs: 0, watched: true));
      expect(
          computeProgress(positionMs: 1000000, durationMs: 1000000, wasWatched: false),
          const ProgressUpdate(positionMs: 0, watched: true));
    });
    test('just under 90% is not watched', () {
      expect(
          computeProgress(positionMs: 899999, durationMs: 1000000, wasWatched: false)
              .watched,
          isFalse);
    });
    test('first 5 seconds do not create a resume point', () {
      expect(
          computeProgress(positionMs: 4999, durationMs: 1000000, wasWatched: false),
          const ProgressUpdate(positionMs: 0, watched: false));
      expect(
          computeProgress(positionMs: 5000, durationMs: 1000000, wasWatched: false)
              .positionMs,
          5000);
    });
    test('rewatching keeps watched flag', () {
      expect(
          computeProgress(positionMs: 300000, durationMs: 1000000, wasWatched: true),
          const ProgressUpdate(positionMs: 300000, watched: true));
      expect(
          computeProgress(positionMs: 1000, durationMs: 1000000, wasWatched: true)
              .watched,
          isTrue);
    });
    test('unknown duration changes nothing', () {
      expect(
          computeProgress(positionMs: 99999, durationMs: 0, wasWatched: true),
          const ProgressUpdate(positionMs: 0, watched: true));
    });
  });

  group('resumePositionMs', () {
    test('resumes exact position', () => expect(resumePositionMs(123456, 1000000), 123456));
    test('tiny or finished positions start over', () {
      expect(resumePositionMs(2000, 1000000), 0);
      expect(resumePositionMs(950000, 1000000), 0);
    });
  });

  group('nextInOrder', () {
    final eps = [
      ep(1, 1, 1), ep(2, 1, 2), ep(3, 2, 1), ep(4, 2, 2), ep(9, 0, 1),
    ];
    test('next in season', () => expect(nextInOrder(eps, eps[0])!.id, 2));
    test('rolls over to next season', () => expect(nextInOrder(eps, eps[1])!.id, 3));
    test('end of show is null, specials skipped', () {
      expect(nextInOrder(eps, eps[3]), isNull);
    });
    test('from a special is null', () => expect(nextInOrder(eps, eps[4]), isNull));
    test('gaps in numbering: E1, E3 -> E3 follows E1', () {
      final gap = [ep(1, 1, 1), ep(2, 1, 3), ep(3, 2, 2)];
      expect(nextInOrder(gap, gap[0])!.id, 2);
      expect(nextInOrder(gap, gap[1])!.id, 3); // S1E3 -> S2E2 (no S2E1)
    });
    test('multi-season rollover skips an empty season', () {
      final eps2 = [ep(1, 1, 1), ep(2, 3, 1)];
      expect(nextInOrder(eps2, eps2[0])!.id, 2);
    });
    test('order independent of input order', () {
      final shuffled = [eps[3], eps[0], eps[2], eps[1]];
      expect(nextInOrder(shuffled, eps[1])!.id, 3);
    });
  });

  group('continueTarget', () {
    test('never played: not in continue watching', () {
      expect(continueTarget([ep(1, 1, 1), ep(2, 1, 2)]), isNull);
    });

    test('in-progress episode resumes at exact position', () {
      final r = continueTarget([
        ep(1, 1, 1, watched: true, at: t(1)),
        ep(2, 1, 2, pos: 420000, at: t(5)),
        ep(3, 1, 3),
      ])!;
      expect(r.episode.id, 2);
      expect(r.resumeMs, 420000);
    });

    test('most recently played in-progress wins', () {
      final r = continueTarget([
        ep(1, 1, 1, pos: 100000, at: t(1)),
        ep(2, 1, 2, pos: 200000, at: t(9)),
      ])!;
      expect(r.episode.id, 2);
    });

    test('nothing in progress: next unwatched after last watched', () {
      final r = continueTarget([
        ep(1, 1, 1, watched: true, at: t(1)),
        ep(2, 1, 2, watched: true, at: t(2)),
        ep(3, 1, 3),
      ])!;
      expect(r.episode.id, 3);
      expect(r.resumeMs, 0);
    });

    test('season rollover: S1 finished -> S2E1', () {
      final r = continueTarget([
        ep(1, 1, 1, watched: true, at: t(1)),
        ep(2, 1, 2, watched: true, at: t(2)),
        ep(3, 2, 1),
        ep(4, 2, 2),
      ])!;
      expect(r.episode.id, 3);
    });

    test('finished show: null', () {
      expect(
          continueTarget([
            ep(1, 1, 1, watched: true, at: t(1)),
            ep(2, 1, 2, watched: true, at: t(2)),
          ]),
          isNull);
    });

    test('specials are never the target', () {
      final r = continueTarget([
        ep(1, 1, 1, watched: true, at: t(1)),
        ep(9, 0, 1),
        ep(2, 1, 2),
      ])!;
      expect(r.episode.id, 2);
    });

    test('only specials watched: first unwatched regular episode', () {
      final r = continueTarget([
        ep(9, 0, 1, watched: true, at: t(1)),
        ep(1, 1, 1),
      ])!;
      expect(r.episode.id, 1);
    });

    test('skipped episodes: continues after the latest watched', () {
      final r = continueTarget([
        ep(1, 1, 1),
        ep(2, 1, 2),
        ep(3, 1, 3, watched: true, at: t(3)),
        ep(4, 1, 4),
      ])!;
      expect(r.episode.id, 4);
    });

    test('marking a whole season watched at once picks the last in order', () {
      final same = t(7);
      final r = continueTarget([
        ep(1, 1, 1, watched: true, at: same),
        ep(2, 1, 2, watched: true, at: same),
        ep(3, 1, 3, watched: true, at: same),
        ep(4, 2, 1),
      ])!;
      expect(r.episode.id, 4);
    });
  });
}
