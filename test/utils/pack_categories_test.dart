import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/utils/pack_categories.dart';

CardModel _card(String id) => CardModel(
      id: id,
      sound: id,
      text: id,
      emoji: '🎴',
      colorBg: const Color(0xFFFFFFFF),
      colorAccent: const Color(0xFF000000),
    );

PackModel _pack(String id, List<CardModel> cards, {bool locked = false}) =>
    PackModel(
      id: id,
      title: id,
      icon: '📦',
      color: const Color(0xFF000000),
      isLocked: locked,
      isFree: !locked,
      cards: cards,
    );

void main() {
  group('cardOfTheDay', () {
    test('returns null for empty pack list', () {
      expect(cardOfTheDay([]), isNull);
    });

    test('returns null when all packs are empty', () {
      expect(cardOfTheDay([_pack('a', []), _pack('b', [])]), isNull);
    });

    test('returns a card from one of the packs', () {
      final cards = [_card('one'), _card('two'), _card('three')];
      final result = cardOfTheDay([_pack('p', cards)]);
      expect(result, isNotNull);
      expect(cards.contains(result!.$1), isTrue);
    });

    test('marks card from locked pack as locked', () {
      final result = cardOfTheDay([_pack('p', [_card('x')], locked: true)]);
      expect(result, isNotNull);
      expect(result!.$2, isTrue);
    });

    test('marks card from unlocked pack as unlocked', () {
      final result = cardOfTheDay([_pack('p', [_card('x')], locked: false)]);
      expect(result!.$2, isFalse);
    });

    test('deterministic for the same date — two calls return the same card', () {
      final cards = List.generate(20, (i) => _card('c$i'));
      final packs = [_pack('p', cards)];
      final a = cardOfTheDay(packs);
      final b = cardOfTheDay(packs);
      expect(a!.$1.id, b!.$1.id);
    });
  });

  group('category constants', () {
    test('allCategoriesUk covers all pack ids', () {
      final usedCategories = packCategoriesUk.values.toSet();
      for (final cat in usedCategories) {
        expect(allCategoriesUk.contains(cat), isTrue,
            reason: '"$cat" missing from allCategoriesUk');
      }
    });

    test('allCategoriesEn covers all pack ids', () {
      final usedCategories = packCategoriesEn.values.toSet();
      for (final cat in usedCategories) {
        expect(allCategoriesEn.contains(cat), isTrue,
            reason: '"$cat" missing from allCategoriesEn');
      }
    });

    test('first element of allCategoriesUk is "Мовлення"', () {
      expect(allCategoriesUk.first, 'Мовлення');
    });

    test('first element of allCategoriesEn is "Speaking"', () {
      expect(allCategoriesEn.first, 'Speaking');
    });

    test('both category lists have exactly 3 entries (no "All"/"Все")', () {
      expect(allCategoriesUk.length, 3);
      expect(allCategoriesEn.length, 3);
    });
  });
}
