import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/language_ladder.dart';

/// The ladder climbs on one signal only — a grown-up saying the word came
/// out — and it never climbs onto a rung the recording cannot say.
void main() {
  CardModel card({required String sound, required String text}) => CardModel(
    id: 'c',
    sound: sound,
    text: text,
    emoji: '🃏',
    colorBg: const Color(0xFFFFFFFF),
    colorAccent: const Color(0xFF000000),
    image: 'c',
  );

  final mama = card(sound: 'мама', text: 'Мама йде до нас');

  test('a new word is asked for on its own', () {
    final step = ladderStepFor(mama, 0);
    expect(step.rung, LadderRung.word);
    expect(step.prompt, 'мама');
    expect(step.playsSentence, isFalse);
  });

  test('two marks is not enough to climb', () {
    expect(ladderStepFor(mama, kRungUpAtMarks - 1).rung, LadderRung.word);
  });

  test('three grown-up marks move the word to its phrase', () {
    final step = ladderStepFor(mama, kRungUpAtMarks);
    expect(step.rung, LadderRung.sentence);
    expect(step.prompt, 'Мама йде до нас');
    expect(step.playsSentence, isTrue);
  });

  test('a card whose sentence is just the word again never climbs', () {
    // Sound packs and one-word cards: there is no phrase in the take, so
    // asking for one would ask for silence.
    final bare = card(sound: 'кіт', text: 'кіт');
    expect(ladderStepFor(bare, 10).rung, LadderRung.word);

    final empty = card(sound: 'кіт', text: '  ');
    expect(ladderStepFor(empty, 10).rung, LadderRung.word);
  });
}
