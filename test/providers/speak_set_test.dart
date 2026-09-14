import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/curriculum.dart';
import 'package:talking_cards/providers/curriculum_progress_provider.dart';
import 'package:talking_cards/providers/curriculum_provider.dart';

/// The Core 60 has to come round in order, or it is not a plan — it is the
/// library with extra steps.
void main() {
  CardModel card(String id) => CardModel(
    id: id,
    sound: id,
    text: id,
    emoji: '🃏',
    colorBg: const Color(0xFFFFFFFF),
    colorAccent: const Color(0xFF000000),
    image: id,
  );

  ResolvedUnit unit(String id, List<String> ids) => ResolvedUnit(
    unit: CurriculumUnit(id: id, title: id, titleEn: id, cardIds: ids),
    cards: [for (final i in ids) card(i)],
  );

  final units = [
    unit('people', ['mama', 'tato', 'baba']),
    unit('animals', ['kit', 'pes']),
  ];

  ProviderContainer containerWith() => ProviderContainer(
    overrides: [
      curriculumUnitsProvider.overrideWith((ref) async => units),
    ],
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an untouched plan starts at the first word of the first unit',
      () async {
    final c = containerWith();
    addTearDown(c.dispose);
    await c.read(curriculumUnitsProvider.future);

    expect(
      c.read(speakSetProvider).map((e) => e.id).toList(),
      ['mama', 'tato', 'baba', 'kit', 'pes'],
    );
  });

  test('practised words go to the back, plan order breaks ties', () async {
    final c = containerWith();
    addTearDown(c.dispose);
    await c.read(curriculumUnitsProvider.future);

    final progress = c.read(curriculumProgressProvider.notifier);
    await progress.record('mama');
    await progress.record('baba');

    expect(
      c.read(speakSetProvider).map((e) => e.id).toList(),
      // Untouched first, in plan order; then the two once-seen, also in
      // plan order — so a second pass restarts at the beginning.
      ['tato', 'kit', 'pes', 'mama', 'baba'],
    );
  });

  test('no plan for this language means no set, not a broken one', () async {
    final c = ProviderContainer(
      overrides: [
        curriculumUnitsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(c.dispose);
    await c.read(curriculumUnitsProvider.future);

    expect(c.read(speakSetProvider), isEmpty);
  });
}
