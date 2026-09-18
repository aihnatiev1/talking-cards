import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/curriculum.dart';
import 'package:talking_cards/models/pack_model.dart';

/// The Core 60 is a promise, and this is what keeps it.
///
/// Every word in the plan must be a card that still exists, still plays,
/// still has a picture and is not one of the ones we pulled. A plan whose
/// third word opens nothing is worse than no plan.
void main() {
  final plan = Curriculum.fromJson(
    json.decode(File('assets/data/uk_curriculum.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final packs = (json.decode(
    File('assets/data/uk_cards.json').readAsStringSync(),
  ) as List<dynamic>)
      .map((p) => PackModel.fromJson(p as Map<String, dynamic>))
      .toList();

  final byId = {
    for (final pack in packs)
      for (final card in pack.cards) card.id: card,
  };

  test('the plan is sixty words in seven units', () {
    expect(plan.units, hasLength(7));
    expect(plan.cardIds, hasLength(60));
    expect(plan.cardIds.toSet(), hasLength(60), reason: 'no word twice');
  });

  test('every word is a card that still exists and is not hidden', () {
    for (final id in plan.cardIds) {
      expect(byId, contains(id), reason: '$id is not in the catalogue');
    }
  });

  test('every word can be heard and seen', () {
    for (final id in plan.cardIds) {
      final card = byId[id]!;
      expect(card.audioKey, isNotNull, reason: '${card.sound} has no audio');
      expect(card.image, isNotNull, reason: '${card.sound} has no picture');
    }
  });

  test('the library is not the plan', () {
    // 471 cards stay browsable; the plan is the small, ordered subset.
    final all = {for (final p in packs) for (final c in p.cards) c.id};
    expect(all.length, greaterThan(400));
    expect(plan.cardIds.length, lessThan(all.length ~/ 4));
  });

  group('the English plan', () {
    final enPlan = Curriculum.fromJson(
      json.decode(File('assets/data/en_curriculum.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    final enPacks = (json.decode(
      File('assets/data/en_cards.json').readAsStringSync(),
    ) as List<dynamic>)
        .map((p) => PackModel.fromJson(p as Map<String, dynamic>))
        .toList();

    final enById = {
      for (final pack in enPacks)
        for (final card in pack.cards) card.id: card,
    };

    test('is the same seven units, word for word where it can be', () {
      expect(enPlan.units, hasLength(7));
      expect(
        enPlan.units.map((u) => u.id).toList(),
        plan.units.map((u) => u.id).toList(),
        reason: 'the two languages teach the same shape',
      );
      // Fifty-nine, not sixty: the English SIT card is one of the six
      // pulled for a bad take. PackModel.fromJson drops hidden cards, so
      // a plan that named it would silently shrink instead of saying so.
      expect(enPlan.cardIds, hasLength(59));
      expect(enPlan.cardIds.toSet(), hasLength(59), reason: 'no word twice');
    });

    test('every word is a card that still exists and is not hidden', () {
      for (final id in enPlan.cardIds) {
        expect(enById, contains(id), reason: '$id is not in the catalogue');
      }
    });

    test('every word can be heard and seen', () {
      for (final id in enPlan.cardIds) {
        final card = enById[id]!;
        expect(card.audioKey, isNotNull, reason: '${card.sound} has no audio');
        expect(card.image, isNotNull, reason: '${card.sound} has no picture');
      }
    });
  });
}
