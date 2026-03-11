import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';

void main() {
  final _sampleCardJson = {
    'id': 'c1',
    'sound': 'МЯУ',
    'text': 'Кішка',
    'emoji': '🐱',
    'colorBg': '#FFE0B2',
    'colorAccent': '#E65100',
    'image': 'киця',
  };

  group('PackModel.fromJson', () {
    test('parses free pack correctly', () {
      final json = {
        'id': 'animals',
        'title': 'Тваринки',
        'icon': '🐾',
        'color': '#4CAF50',
        'cards': [_sampleCardJson],
      };

      final pack = PackModel.fromJson(json);

      expect(pack.id, 'animals');
      expect(pack.title, 'Тваринки');
      expect(pack.icon, '🐾');
      expect(pack.color, const Color(0xFF4CAF50));
      expect(pack.isLocked, false);
      expect(pack.isFree, true);
      expect(pack.cards.length, 1);
      expect(pack.cards.first.id, 'c1');
    });

    test('parses locked pack correctly', () {
      final json = {
        'id': 'premium',
        'title': 'Преміум',
        'icon': '⭐',
        'color': '#FF9800',
        'isLocked': true,
        'cards': [_sampleCardJson],
      };

      final pack = PackModel.fromJson(json);

      expect(pack.isLocked, true);
      expect(pack.isFree, false);
    });

    test('isLocked defaults to false when missing', () {
      final json = {
        'id': 'free',
        'title': 'Безкоштовна',
        'icon': '🆓',
        'color': '#2196F3',
        'cards': <Map<String, dynamic>>[],
      };

      final pack = PackModel.fromJson(json);

      expect(pack.isLocked, false);
      expect(pack.isFree, true);
    });
  });

  group('PackModel.copyWith', () {
    test('unlocks pack while preserving isFree', () {
      final json = {
        'id': 'premium',
        'title': 'Преміум',
        'icon': '⭐',
        'color': '#FF9800',
        'isLocked': true,
        'cards': [_sampleCardJson],
      };

      final pack = PackModel.fromJson(json);
      final unlocked = pack.copyWith(isLocked: false);

      expect(unlocked.isLocked, false);
      expect(unlocked.isFree, false); // preserves original status
      expect(unlocked.id, pack.id);
      expect(unlocked.title, pack.title);
      expect(unlocked.cards.length, pack.cards.length);
    });

    test('copyWith without arguments returns identical values', () {
      final json = {
        'id': 'test',
        'title': 'Test',
        'icon': '🔵',
        'color': '#000000',
        'isLocked': false,
        'cards': <Map<String, dynamic>>[],
      };

      final pack = PackModel.fromJson(json);
      final copy = pack.copyWith();

      expect(copy.id, pack.id);
      expect(copy.isLocked, pack.isLocked);
      expect(copy.isFree, pack.isFree);
    });
  });

  test('freePreviewCount is 5', () {
    expect(PackModel.freePreviewCount, 5);
  });
}
