import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/curriculum.dart';
import 'language_provider.dart';
import 'packs_provider.dart';

/// The teaching plan for the current language, or null where there is not
/// one yet.
///
/// Only Ukrainian has a plan today: the English recordings are being
/// redone, and a curriculum is only as good as the voice behind it. The
/// English app keeps the library — it loses nothing it had.
final curriculumProvider = FutureProvider<Curriculum?>((ref) async {
  final lang = ref.watch(languageProvider);
  if (lang != 'uk') return null;
  final raw = await rootBundle.loadString('assets/data/uk_curriculum.json');
  return Curriculum.fromJson(json.decode(raw) as Map<String, dynamic>);
});

/// The plan with its cards resolved against the catalogue, in plan order.
///
/// A card the catalogue no longer has (pulled for a bad recording, hidden
/// pending new art) simply drops out — the plan shrinks, nothing throws,
/// and the guard test in `test/models/curriculum_test.dart` is what keeps
/// the list honest in the first place.
final curriculumUnitsProvider = FutureProvider<List<ResolvedUnit>>((ref) async {
  final plan = await ref.watch(curriculumProvider.future);
  if (plan == null) return const [];
  final packs = await ref.watch(packsProvider.future);

  final byId = <String, CardModel>{
    for (final pack in packs)
      for (final card in pack.cards) card.id: card,
  };

  return [
    for (final unit in plan.units)
      ResolvedUnit(
        unit: unit,
        cards: [
          for (final id in unit.cardIds)
            if (byId[id] != null) byId[id]!,
        ],
      ),
  ];
});
