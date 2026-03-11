import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/uk_grammar.dart';

void main() {
  group('dayWord - Ukrainian day declension', () {
    test('1 день', () {
      expect(dayWord(1), 'день');
    });

    test('2-4 дні', () {
      expect(dayWord(2), 'дні');
      expect(dayWord(3), 'дні');
      expect(dayWord(4), 'дні');
    });

    test('5-20 днів', () {
      for (int i = 5; i <= 20; i++) {
        expect(dayWord(i), 'днів', reason: '$i should be "днів"');
      }
    });

    test('11 днів (not "день")', () {
      expect(dayWord(11), 'днів');
    });

    test('12-14 днів (not "дні")', () {
      expect(dayWord(12), 'днів');
      expect(dayWord(13), 'днів');
      expect(dayWord(14), 'днів');
    });

    test('21 день', () {
      expect(dayWord(21), 'день');
    });

    test('22 дні', () {
      expect(dayWord(22), 'дні');
    });

    test('25 днів', () {
      expect(dayWord(25), 'днів');
    });

    test('100 днів', () {
      expect(dayWord(100), 'днів');
    });

    test('101 день', () {
      expect(dayWord(101), 'день');
    });

    test('111 днів (not "день")', () {
      expect(dayWord(111), 'днів');
    });

    test('112 днів (not "дні")', () {
      expect(dayWord(112), 'днів');
    });

    test('0 днів', () {
      expect(dayWord(0), 'днів');
    });
  });
}
