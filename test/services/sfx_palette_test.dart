import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/bloom_state.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/utils/sfx.dart';

/// The SFX palette contract (docs/design/sound_palette.md §4.5, §7 tests).
///
/// Three things have to stay true while the studio files arrive one by
/// one: every role can sound *today* (its own WAV or the v1 placeholder it
/// names), the enum and the filenames cannot drift apart (`success_medium`
/// ↔ `KidSound.successMedium`, so `content` can check code ↔ folder ↔
/// `sources.json`), and no screen may name a sound file — a role is the
/// only way in, otherwise the day a file is renamed one game keeps
/// playing `'ding'` into the void.
void main() {
  group('every role can sound today', () {
    for (final s in KidSound.values) {
      test('$s → ${s.file}.wav or its placeholder', () {
        final own = s.variants == 1
            ? File(s.assetPath).existsSync()
            : List.generate(s.variants, (i) => s.variantPath(i + 1))
                .every((p) => File(p).existsSync());
        final standIn = File(s.fallbackPath).existsSync();
        expect(KidSound.placeholders, contains(s.fallback),
            reason: 'a fallback must be one of the three v1 files');
        expect(standIn, isTrue,
            reason: '${s.fallbackPath} is the safety net and must exist');
        expect(own || standIn, isTrue);
      });
    }

    test('a multi-take role has every take on disk, or none of them', () {
      // A gap in the middle is the worst case: the cursor walks onto a
      // missing take, silently falls back to the placeholder, and one pop
      // in three sounds like the old synthesised one.
      for (final s in KidSound.values.where((s) => s.variants > 1)) {
        final present = List.generate(s.variants, (i) => s.variantPath(i + 1))
            .where((p) => File(p).existsSync())
            .length;
        expect(present, anyOf(0, s.variants),
            reason: '$s has $present of ${s.variants} takes on disk');
      }
    });

    test('the warm set is wave 1', () {
      expect(
        KidSound.warm.map((s) => s.file),
        containsAll([
          'tap',
          'card_touch',
          'card_land',
          'pack_open',
          'success_small',
          'success_large',
        ]),
      );
    });
  });

  group('enum ↔ file name', () {
    String snake(String camel) => camel.replaceAllMapped(
          RegExp('[A-Z]'),
          (m) => '_${m[0]!.toLowerCase()}',
        );

    for (final s in KidSound.values) {
      test('${s.name} is spelled ${s.file}', () {
        expect(s.file, snake(s.name));
        expect(s.file, matches(RegExp(r'^[a-z][a-z0-9_]*$')),
            reason: 'snake_case, no screen, no version, no date (§4.5)');
      });
    }

    test('one role, one file', () {
      final files = KidSound.values.map((s) => s.file).toSet();
      expect(files.length, KidSound.values.length);
    });

    test('mix stays under the word and inside the pitch clamp', () {
      for (final s in KidSound.values) {
        expect(s.volume, inExclusiveRange(0.0, 1.0), reason: '$s');
        expect(s.pitch - s.spread, greaterThanOrEqualTo(0.5), reason: '$s');
        expect(s.pitch + s.spread, lessThanOrEqualTo(2.0), reason: '$s');
        expect(s.fallbackPitch, inInclusiveRange(0.5, 2.0), reason: '$s');
      }
    });

    test('transients are the class-A roles of §3.1, nothing tonal', () {
      final transient = KidSound.values.where((s) => s.transient).toSet();
      expect(transient, {
        KidSound.tap,
        KidSound.cardTouch,
        KidSound.tapSoft,
        KidSound.cardLand,
        KidSound.flip,
        KidSound.pop,
        KidSound.tick,
      });
    });
  });

  group('never over a word', () {
    final played = <(String, double, double)>[];
    final audio = AudioService.instance;

    setUp(() {
      played.clear();
      AudioService.debugFxSink = (f, p, v) => played.add((f, p, v));
      audio.isSpeaking.value = false;
    });
    tearDown(() {
      AudioService.debugFxSink = null;
      audio.isSpeaking.value = false;
    });

    test('a tonal role asked to wait is dropped, not queued', () async {
      audio.isSpeaking.value = true;
      await audio.play(KidSound.successMedium, dropIfSpeaking: true);
      expect(played, isEmpty);
      audio.isSpeaking.value = false;
      await Future<void>.delayed(Duration.zero);
      expect(played, isEmpty, reason: 'and not later either');
    });

    test('a transient plays under the word — shorter than a syllable', () async {
      audio.isSpeaking.value = true;
      await audio.play(KidSound.cardTouch, dropIfSpeaking: true);
      await audio.play(KidSound.tap);
      expect(played.map((e) => e.$1), ['card_touch', 'tap']);
    });

    test('a tonal role plays once the word is over, at its own mix', () async {
      await audio.play(KidSound.successMedium, dropIfSpeaking: true);
      expect(played, [
        ('success_medium', KidSound.successMedium.pitch,
            KidSound.successMedium.volume),
      ]);
    });

    test('Bloom is dropped under a word, in AudioService too', () async {
      audio.isSpeaking.value = true;
      await audio.playBloom(BloomSound.yay.file, volume: BloomSound.yay.volume);
      expect(played, isEmpty);
      audio.isSpeaking.value = false;
      await audio.playBloom(BloomSound.yay.file, volume: BloomSound.yay.volume);
      expect(played.single.$1, 'bloom_yay');
    });

    test('playing an SFX never touches the narrator state', () async {
      audio.isSpeaking.value = true;
      await audio.play(KidSound.tap);
      expect(audio.isSpeaking.value, isTrue);
    });
  });

  group('source: sounds are roles, not strings', () {
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    List<String> offenders(
      Pattern p, {
      required Set<String> allowed,
    }) =>
        [
          for (final f in dart)
            if (!allowed.contains(f.path) &&
                f.readAsStringSync().contains(p))
              f.path,
        ];

    test('no playSfx(\'literal\') outside audio_service.dart', () {
      expect(
        offenders(
          RegExp(r'''playSfx(Varied)?\(\s*['"]'''),
          allowed: const {'lib/services/audio_service.dart'},
        ),
        isEmpty,
        reason: 'Name a KidSound role through FeedbackService instead of a '
            'file stem. The table is the only place a sound has a name.',
      );
    });

    test('AudioService.play(KidSound) is called only by FeedbackService', () {
      expect(
        offenders(
          RegExp(r'AudioService\.instance\.play\('),
          allowed: const {
            'lib/services/feedback_service.dart',
            'lib/services/audio_service.dart',
          },
        ),
        isEmpty,
        reason: 'Screens go through FeedbackService.event / .play so Bloom '
            'hears the same stream and the mix lives in one table.',
      );
    });

    test('playBloom( is called only by its owners', () {
      expect(
        offenders(
          'playBloom(',
          allowed: const {
            'lib/services/feedback_service.dart',
            'lib/services/audio_service.dart',
            'lib/providers/bloom_reactions_provider.dart',
          },
        ),
        isEmpty,
      );
    });

    test('the old KidSound.none spelling is gone', () {
      expect(
        offenders(RegExp(r'KidSound\.none\b'), allowed: const {}),
        isEmpty,
        reason: 'A silent KidTap is `sound: null`; a button is the default.',
      );
    });
  });
}
