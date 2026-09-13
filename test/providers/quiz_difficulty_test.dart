import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/providers/quiz_provider.dart';
import 'package:talking_cards/utils/quiz_tiers.dart';

/// «Вгадай звук» stops being a lottery (experience audit 2026-09-13 §19).
///
/// Four pictures with three random distractors made every question a
/// different task and a one-in-four guess right often enough that a child
/// could finish a session without ever hearing the word. The board now
/// starts at two clearly different pictures, grows on the child's own calm
/// answers, and — from three pictures up — draws its distractors from the
/// answer's own set. Age only picks the starting rung.
CardModel _card(String id) => CardModel(
  id: id,
  sound: 'sound_$id',
  text: 'text_$id',
  emoji: '🔵',
  colorBg: const Color(0xFFFFFFFF),
  colorAccent: const Color(0xFF000000),
  image: 'img_$id',
);

/// Twelve cards in three sets of four — enough for a four-picture question
/// to be filled from one set alone.
List<CardModel> _catalogue() => [
  for (final set in ['animals', 'food', 'clothes'])
    for (var i = 0; i < 4; i++) _card('${set}_$i'),
];

Map<String, String> _groups() => {
  for (final c in _catalogue()) c.id: c.id.split('_').first,
};

/// The question on the table. One deprecated `debugState` in the file
/// instead of thirty — `state` is protected on a `StateNotifier`.
// ignore: deprecated_member_use
QuizState _now(QuizNotifier n) => n.debugState!;

/// Answers the current question correctly, first try, and deals the next.
void _answerCalmly(QuizNotifier n) {
  n.answer(_now(n).correctCard.id);
  n.next();
}

/// Taps wrong twice, then right — a hard question by any measure. On a
/// two-picture board the only wrong tile is tapped twice, which is exactly
/// what a child who has not understood the word does.
void _struggle(QuizNotifier n) {
  final state = _now(n);
  final wrong = state.options
      .where((c) => c.id != state.correctCard.id)
      .toList();
  for (var i = 0; i < 2; i++) {
    n.answer(wrong[i % wrong.length].id);
  }
  n.answer(state.correctCard.id);
  n.next();
}

void main() {
  group('the board of pictures', () {
    test('starts at two for the youngest bands', () {
      for (final level in [1, 2]) {
        final n = QuizNotifier(_catalogue(), level: level);
        n.start();
        expect(
          _now(n).options.length,
          2,
          reason: 'level $level starts on two pictures',
        );
      }
    });

    test('an older child starts at three, never above four', () {
      expect(QuizTiers.startFor(3), 3);
      expect(QuizTiers.startFor(4), 3);
      expect(QuizTiers.ceilingFor(4), 4);
      expect(QuizTiers.ceilingFor(1), 3);
    });

    test('two calm questions add a third picture, two more add a fourth', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      expect(_now(n).options.length, 2);

      _answerCalmly(n);
      expect(_now(n).options.length, 2, reason: 'one calm round waits');
      _answerCalmly(n);
      expect(_now(n).options.length, 3);

      _answerCalmly(n);
      _answerCalmly(n);
      expect(_now(n).options.length, 4);
    });

    test('an older child moves on the first calm question', () {
      final n = QuizNotifier(_catalogue(), level: 3)..start();
      expect(_now(n).options.length, 3);
      _answerCalmly(n);
      expect(_now(n).options.length, 4);
    });

    test('a hard question never grows the board', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      _struggle(n);
      _struggle(n);
      expect(_now(n).options.length, 2);
    });

    test('two hard questions hand back a picture we added', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      _answerCalmly(n);
      _answerCalmly(n);
      expect(_now(n).options.length, 3);

      _struggle(n);
      expect(_now(n).options.length, 3, reason: 'one hard one is a fluke');
      _struggle(n);
      expect(_now(n).options.length, 2);
    });

    test('«ще раз» keeps the size the session has earned', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      _answerCalmly(n);
      _answerCalmly(n);
      expect(_now(n).options.length, 3);

      n.restart();
      expect(_now(n).round, 1);
      expect(_now(n).options.length, 3);
    });
  });

  group('the distractors', () {
    test('a two-picture question pairs the answer with another set', () {
      final n = QuizNotifier(_catalogue(), level: 1, groups: _groups())..start();
      final groups = _groups();

      for (var i = 0; i < 6; i++) {
        final state = _now(n);
        if (state.finished) break;
        expect(state.options.length, 2);
        final other = state.options.firstWhere(
          (c) => c.id != state.correctCard.id,
        );
        expect(
          groups[other.id],
          isNot(groups[state.correctCard.id]),
          reason: 'the first choice a child makes must be an obvious one',
        );
        // Struggle keeps the board at two for the whole check.
        _struggle(n);
      }
    });

    test('three and four pictures come from the answer\'s own set', () {
      final n = QuizNotifier(_catalogue(), level: 3, groups: _groups())..start();
      final groups = _groups();

      for (var i = 0; i < 5; i++) {
        final state = _now(n);
        if (state.finished) break;
        expect(state.options.length, greaterThanOrEqualTo(3));
        final set = groups[state.correctCard.id];
        expect(
          state.options.map((c) => groups[c.id]).toSet(),
          {set},
          reason: 'round ${state.round}: a question is about a word, not '
              'about which picture looks out of place',
        );
        _answerCalmly(n);
      }
    });

    test('a set too small to fill the board is topped up, never left short', () {
      // "food" has one card only — the question still gets four pictures.
      final cards = [
        for (var i = 0; i < 5; i++) _card('animals_$i'),
        _card('food_0'),
      ];
      final groups = {for (final c in cards) c.id: c.id.split('_').first};
      final n = QuizNotifier(cards, level: 4, groups: groups)..start();

      for (var i = 0; i < 4; i++) {
        final state = _now(n);
        if (state.finished) break;
        expect(state.options.length, greaterThanOrEqualTo(3));
        expect(state.options.map((c) => c.id).toSet().length,
            state.options.length);
        expect(state.options, contains(state.correctCard));
        _answerCalmly(n);
      }
    });

    test('no group map at all still deals a full, distinct board', () {
      final n = QuizNotifier(_catalogue(), level: 4)..start();
      final state = _now(n);
      expect(state.options.length, 3);
      expect(state.options.map((c) => c.id).toSet().length, 3);
    });
  });

  group('the hint', () {
    test('normally waits for the second miss', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      expect(_now(n).hintAfterMisses, QuizTiers.hintAfterMisses);
    });

    test('comes on the first miss after two hard questions in a row', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      _struggle(n);
      expect(_now(n).hintAfterMisses, 2, reason: 'one hard one is a fluke');
      _struggle(n);
      expect(
        _now(n).hintAfterMisses,
        QuizTiers.hintAfterMissesWhenStruggling,
      );
    });

    test('one calm question puts the help back to arm\'s length', () {
      final n = QuizNotifier(_catalogue(), level: 2)..start();
      _struggle(n);
      _struggle(n);
      expect(_now(n).hintAfterMisses, 1);
      _answerCalmly(n);
      expect(_now(n).hintAfterMisses, QuizTiers.hintAfterMisses);
    });
  });

  group('QuizDifficulty on its own', () {
    test('a question answered first time with no hint is calm', () {
      expect(
        QuizTiers.confidenceOf(misses: 0, hintShown: false),
        RoundConfidence.calm,
      );
      expect(
        QuizTiers.confidenceOf(misses: 1, hintShown: false),
        RoundConfidence.neutral,
      );
      expect(
        QuizTiers.confidenceOf(misses: 2, hintShown: false),
        RoundConfidence.struggle,
      );
      expect(
        QuizTiers.confidenceOf(misses: 0, hintShown: true),
        RoundConfidence.struggle,
      );
    });

    test('an explicit option count pins the board for the session', () {
      final d = QuizDifficulty(level: 2, fixedOptions: 4);
      expect(d.isFixed, isTrue);
      expect(
        d.applyQuestion(misses: 0, hintShown: false),
        TierChange.stay,
      );
      expect(d.optionCount, 4);
    });

    test('a neutral question breaks the calm run without moving the board', () {
      final d = QuizDifficulty(level: 2);
      d.applyQuestion(misses: 0, hintShown: false);
      expect(d.applyQuestion(misses: 1, hintShown: false), TierChange.stay);
      expect(d.calmRun, 0);
      expect(d.applyQuestion(misses: 0, hintShown: false), TierChange.stay);
      expect(d.optionCount, 2);
    });
  });
}
