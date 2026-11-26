import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/word_evidence_provider.dart';
import 'package:talking_cards/screens/kid_word_wall_screen.dart';

import '../helpers/motion.dart';

/// «Слова» in the treasure box: the words the child found by their name.
/// It used to fill only from «Вгадай» after two right answers on the same
/// card, so it stayed empty and said nothing about which words it meant.
void main() {
  const cat = CardModel(
    id: 'a01',
    sound: 'КОТИК',
    text: '',
    emoji: '',
    image: 'cat',
    audioKey: 'kotik',
    colorBg: Colors.white,
    colorAccent: Colors.teal,
  );
  const dog = CardModel(
    id: 'a02',
    sound: 'СОБАЧКА',
    text: '',
    emoji: '',
    image: 'dog',
    audioKey: 'sobachka',
    colorBg: Colors.white,
    colorAccent: Colors.teal,
  );
  const pack = PackModel(
    id: 'animals',
    title: 'Тваринки',
    icon: '',
    color: Colors.teal,
    isLocked: false,
    isFree: true,
    cards: [cat, dog],
  );

  Future<void> pump(WidgetTester tester) async {
    setGoldenSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [packsProvider.overrideWith((ref) async => [pack])],
        child: const MaterialApp(home: KidWordWallScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a word found in a lesson or game is in the box', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'word_evidence_v1': json.encode({
        'a01': const WordEvidence(recognized: 1, recognizedDay: 1).toJson(),
      }),
    });
    await pump(tester);
    expect(find.text('КОТИК'), findsOneWidget);
    expect(find.text('СОБАЧКА'), findsNothing);
  });

  testWidgets('the empty box says which words it collects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.text('Тут живуть слова, які ти знайшов'), findsOneWidget);
    expect(find.textContaining('знайди її'), findsOneWidget);
  });
}
