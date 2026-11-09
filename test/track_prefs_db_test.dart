import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/data/database.dart';
import 'package:tv_watcher/tracks/track_prefs.dart';

void main() {
  late AppDatabase db;
  late int showId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    showId = await db.upsertShow('Show', 'show', null);
  });
  tearDown(() => db.close());

  test('no prefs before anything is chosen', () async {
    expect(await db.getTrackPrefs(showId), isNull);
  });

  test(
    'audio and subtitle choices are stored independently per show',
    () async {
      await db.saveAudioChoice(
        showId,
        const TrackChoice(
          mode: ChoiceMode.track,
          language: 'ja',
          title: 'Japanese',
        ),
      );
      await db.saveSubtitleChoice(
        showId,
        const TrackChoice(
          mode: ChoiceMode.track,
          language: 'en',
          title: 'Forced',
          external: true,
        ),
      );

      final p = (await db.getTrackPrefs(showId))!;
      expect(p.audioChoice.mode, ChoiceMode.track);
      expect(p.audioChoice.language, 'ja');
      expect(p.subtitleChoice.language, 'en');
      expect(p.subtitleChoice.title, 'Forced');
      expect(p.subtitleChoice.external, isTrue);
    },
  );

  test('changing one kind keeps the other', () async {
    await db.saveAudioChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.track, language: 'ja'),
    );
    await db.saveSubtitleChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.off),
    );
    await db.saveSubtitleChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.track, language: 'fr'),
    );

    final p = (await db.getTrackPrefs(showId))!;
    expect(p.audioChoice.language, 'ja');
    expect(p.subtitleChoice.language, 'fr');
  });

  test('subtitles off is remembered', () async {
    await db.saveSubtitleChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.off),
    );
    expect(
      (await db.getTrackPrefs(showId))!.subtitleChoice.mode,
      ChoiceMode.off,
    );
  });

  test('choosing auto clears a previous track choice', () async {
    await db.saveAudioChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.track, language: 'ja'),
    );
    await db.saveAudioChoice(showId, TrackChoice.auto);
    final c = (await db.getTrackPrefs(showId))!.audioChoice;
    expect(c.mode, ChoiceMode.auto);
    expect(c.language, isNull);
  });

  test('prefs are per show', () async {
    final other = await db.upsertShow('Other', 'other', null);
    await db.saveAudioChoice(
      showId,
      const TrackChoice(mode: ChoiceMode.track, language: 'ja'),
    );
    expect(await db.getTrackPrefs(other), isNull);
  });
}
