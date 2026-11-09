import 'package:flutter_test/flutter_test.dart';
import 'package:tv_watcher/tracks/languages.dart';
import 'package:tv_watcher/tracks/track_prefs.dart';

TrackInfo t(String id, {String? title, String? lang, bool ext = false}) =>
    TrackInfo(id: id, title: title, language: lang, isExternal: ext);

void main() {
  bitmapCodecTests();
  group('languages', () {
    test('normalizes codes and names', () {
      expect(normalizeLang('eng'), 'en');
      expect(normalizeLang('en'), 'en');
      expect(normalizeLang('English'), 'en');
      expect(normalizeLang('en-US'), 'en');
      expect(normalizeLang('jpn'), 'ja');
      expect(normalizeLang('fre'), 'fr');
      expect(normalizeLang('pt-BR'), 'pt');
    });
    test('unknown and empty', () {
      expect(normalizeLang(null), isNull);
      expect(normalizeLang(''), isNull);
      expect(normalizeLang('und'), isNull);
      expect(normalizeLang('xx'), 'xx');
    });
    test('display names', () {
      expect(languageName('jpn'), 'Japanese');
      expect(languageName(null), isNull);
    });
    test('isKnownLanguage', () {
      expect(isKnownLanguage('en'), isTrue);
      expect(isKnownLanguage('forced'), isFalse);
      expect(isKnownLanguage('English'), isTrue);
    });
  });

  group('TrackInfo.label', () {
    test(
      'language only',
      () => expect(t('1', lang: 'eng').label(0), 'English'),
    );
    test('language and title', () {
      expect(
        t('1', lang: 'jpn', title: 'Commentary').label(0),
        'Japanese · Commentary',
      );
    });
    test('title equal to language is not repeated', () {
      expect(t('1', lang: 'eng', title: 'English').label(0), 'English');
    });
    test('no info', () => expect(t('3').label(2), 'Track 3'));
    test('external suffix', () {
      expect(t('f', lang: 'en', ext: true).label(0), 'English (external)');
    });
  });

  group('pickTrack', () {
    final tracks = [
      t('1', lang: 'jpn'),
      t('2', lang: 'eng', title: 'English'),
      t('3', lang: 'eng', title: 'Commentary'),
      t('4', lang: 'eng', title: 'English', ext: true),
    ];

    test('non-track modes pick nothing', () {
      expect(pickTrack(tracks, TrackChoice.auto), isNull);
      expect(
        pickTrack(tracks, const TrackChoice(mode: ChoiceMode.off)),
        isNull,
      );
    });

    test('same language, picks it across naming styles', () {
      final c = TrackChoice(
        mode: ChoiceMode.track,
        language: normalizeLang('en'),
      );
      expect(pickTrack([t('9', lang: 'eng')], c)!.id, '9');
    });

    test('exact title wins among the same language', () {
      final c = TrackChoice.fromTrack(t('x', lang: 'eng', title: 'Commentary'));
      expect(pickTrack(tracks, c)!.id, '3');
    });

    test('prefers same embedded/external kind', () {
      final emb = TrackChoice.fromTrack(t('x', lang: 'eng', title: 'English'));
      expect(pickTrack(tracks, emb)!.id, '2');
      final ext = TrackChoice.fromTrack(
        t('x', lang: 'eng', title: 'English', ext: true),
      );
      expect(pickTrack(tracks, ext)!.id, '4');
    });

    test('falls back to first same-language track', () {
      final c = TrackChoice.fromTrack(t('x', lang: 'eng', title: 'SDH'));
      expect(pickTrack(tracks, c)!.id, '2');
    });

    test('no track in that language: null', () {
      final c = TrackChoice.fromTrack(t('x', lang: 'fra'));
      expect(pickTrack(tracks, c), isNull);
    });

    test('language-less choice matches by title only', () {
      final c = TrackChoice.fromTrack(t('x', title: 'Dub'));
      expect(
        pickTrack([t('1', title: 'Dub'), t('2', title: 'Sub')], c)!.id,
        '1',
      );
      expect(pickTrack([t('2', title: 'Sub')], c), isNull);
    });

    test('language-less and title-less choice matches nothing', () {
      expect(
        pickTrack(tracks, const TrackChoice(mode: ChoiceMode.track)),
        isNull,
      );
    });
  });
}

void bitmapCodecTests() {
  group('isBitmapSubtitleCodec', () {
    test('picture formats', () {
      for (final c in [
        'hdmv_pgs_subtitle',
        'dvd_subtitle',
        'dvb_subtitle',
        'PGSSUB',
      ]) {
        expect(isBitmapSubtitleCodec(c), isTrue, reason: c);
      }
    });
    test('text formats and unknown', () {
      for (final c in ['subrip', 'ass', 'webvtt', 'mov_text', '', null]) {
        expect(isBitmapSubtitleCodec(c), isFalse, reason: '$c');
      }
    });
  });
}
