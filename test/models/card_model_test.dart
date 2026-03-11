import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';

void main() {
  group('CardModel.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'cat_1',
        'sound': 'МЯУ',
        'text': 'Кішка каже мяу',
        'emoji': '🐱',
        'colorBg': '#FFE0B2',
        'colorAccent': '#E65100',
        'image': 'киця',
        'audio': 'kotik',
      };

      final card = CardModel.fromJson(json);

      expect(card.id, 'cat_1');
      expect(card.sound, 'МЯУ');
      expect(card.text, 'Кішка каже мяу');
      expect(card.emoji, '🐱');
      expect(card.colorBg, const Color(0xFFFFE0B2));
      expect(card.colorAccent, const Color(0xFFE65100));
      expect(card.image, 'киця');
      expect(card.audioKey, 'kotik');
    });

    test('audioKey falls back to image when audio is null', () {
      final json = {
        'id': 'dog_1',
        'sound': 'ГАВ',
        'text': 'Собака каже гав',
        'emoji': '🐶',
        'colorBg': '#BBDEFB',
        'colorAccent': '#1565C0',
        'image': 'песик',
      };

      final card = CardModel.fromJson(json);

      expect(card.audioKey, 'песик');
    });

    test('audioKey is null when both audio and image are null', () {
      final json = {
        'id': 'test_1',
        'sound': 'ТЕ',
        'text': 'Тест',
        'emoji': '🔵',
        'colorBg': '#FFFFFF',
        'colorAccent': '#000000',
      };

      final card = CardModel.fromJson(json);

      expect(card.image, isNull);
      expect(card.audioKey, isNull);
    });

    test('handles hex color without hash prefix', () {
      final json = {
        'id': 'no_hash',
        'sound': 'X',
        'text': 'Test',
        'emoji': '⚪',
        'colorBg': 'FF5733',
        'colorAccent': '000000',
      };

      final card = CardModel.fromJson(json);

      expect(card.colorBg, const Color(0xFFFF5733));
      expect(card.colorAccent, const Color(0xFF000000));
    });
  });
}
