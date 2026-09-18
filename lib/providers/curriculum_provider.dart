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
/// Both languages have one. English is 59 words rather than 60: its SIT
/// card is one of the six pulled for a bad AI take, and a plan must not
/// teach a word the app cannot say properly. It comes back the day that
/// recording is redone — the plan is a list of ids over the library, so
/// the fix is one line of JSON and no code at all.
final curriculumProvider = FutureProvider<Curriculum?>((ref) async {
  final lang = ref.watch(languageProvider);
  final asset = switch (lang) {
    'uk' => 'assets/data/uk_curriculum.json',
    'en' => 'assets/data/en_curriculum.json',
    _ => null,
  };
  if (asset == null) return null;
  final raw = await rootBundle.loadString(asset);
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
