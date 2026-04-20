import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/ukrainian_phonetics.dart';

void main() {
  group('countSyllables', () {
    test('single-syllable words', () {
      expect(countSyllables('КІТ'), 1);
      expect(countSyllables('СОН'), 1);
      expect(countSyllables('ЛЕВ'), 1);
    });

    test('two-syllable words', () {
      expect(countSyllables('КОНИК'), 2);
      expect(countSyllables('МАМА'), 2);
      expect(countSyllables('ВОВЧИК'), 2);
    });

    test('multi-syllable words', () {
      expect(countSyllables('ЧЕРЕПАХА'), 4);
      expect(countSyllables('ПОЛУНИЦЯ'), 4);
    });

    test('lowercase normalised', () {
      expect(countSyllables('кіт'), 1);
      expect(countSyllables('черепаха'), 4);
    });

    test('multi-word phrases — vowels per word', () {
      // "ОП ОП ОП" → 3 vowels (О, О, О)
      expect(countSyllables('ОП ОП ОП'), 3);
    });

    test('Ukrainian-specific vowels Є, Ї, Ю, Я', () {
      expect(countSyllables('ЇЖАК'), 2); // Ї + А
      expect(countSyllables('ЮЛА'), 2);   // Ю + А
      expect(countSyllables('ЯЛИНА'), 3); // Я + И + А
      expect(countSyllables('ЄВРО'), 2);  // Є + О
    });

    test('non-vowel chars ignored', () {
      expect(countSyllables('А-А-А'), 3);
      expect(countSyllables('!?КІТ.'), 1);
    });

    test('empty string → 0', () {
      expect(countSyllables(''), 0);
    });
  });

  group('ukrainianVowels constant', () {
    test('contains all 10 Ukrainian vowels', () {
      expect(ukrainianVowels.length, 10);
      for (final v in ['А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я']) {
        expect(ukrainianVowels.contains(v), isTrue, reason: '$v missing');
      }
    });

    test('does not contain consonants', () {
      for (final c in ['Б', 'В', 'Г', 'Д', 'К', 'М']) {
        expect(ukrainianVowels.contains(c), isFalse, reason: '$c is consonant');
      }
    });
  });
}
