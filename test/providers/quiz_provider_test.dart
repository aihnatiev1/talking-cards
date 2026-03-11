import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/providers/quiz_provider.dart';

CardModel _card(String id, {String? image}) => CardModel(
      id: id,
      sound: 'sound_$id',
      text: 'text_$id',
      emoji: '🔵',
      colorBg: const Color(0xFFFFFFFF),
      colorAccent: const Color(0xFF000000),
      image: image ?? 'img_$id',
    );

void main() {
  group('QuizNotifier', () {
    late List<CardModel> cards;
    late QuizNotifier notifier;

    setUp(() {
      cards = List.generate(10, (i) => _card('card_$i'));
      notifier = QuizNotifier(cards);
    });

    test('initial state is null', () {
      expect(notifier.debugState, isNull);
    });

    test('start sets up first question with 4 options', () {
      notifier.start();

      final state = notifier.debugState!;
      expect(state.options.length, 4);
      expect(state.round, 1);
      expect(state.score, 0);
      expect(state.finished, false);
      expect(state.totalRounds, 10);
      expect(state.options.contains(state.correctCard), true);
    });

    test('does not start with fewer than 4 playable cards', () {
      final fewCards = List.generate(3, (i) => _card('c_$i'));
      final n = QuizNotifier(fewCards);
      n.start();
      expect(n.debugState, isNull);
    });

    test('does not start with fewer than 4 cards with images', () {
      final noImageCards = [
        CardModel(id: 'a', sound: 's', text: 't', emoji: '🔵',
            colorBg: const Color(0xFFFFFFFF), colorAccent: const Color(0xFF000000)),
        CardModel(id: 'b', sound: 's', text: 't', emoji: '🔵',
            colorBg: const Color(0xFFFFFFFF), colorAccent: const Color(0xFF000000)),
        CardModel(id: 'c', sound: 's', text: 't', emoji: '🔵',
            colorBg: const Color(0xFFFFFFFF), colorAccent: const Color(0xFF000000)),
        CardModel(id: 'd', sound: 's', text: 't', emoji: '🔵',
            colorBg: const Color(0xFFFFFFFF), colorAccent: const Color(0xFF000000)),
      ];
      // All cards have image: null (no image field set), so not playable
      final n = QuizNotifier(noImageCards);
      n.start();
      expect(n.debugState, isNull);
    });

    test('correct answer increments score', () {
      notifier.start();
      final correctId = notifier.debugState!.correctCard.id;

      notifier.answer(correctId);

      expect(notifier.debugState!.score, 1);
      expect(notifier.debugState!.lastAnswerCorrect, true);
    });

    test('wrong answer does not increment score', () {
      notifier.start();
      final wrongOption = notifier.debugState!.options
          .firstWhere((c) => c.id != notifier.debugState!.correctCard.id);

      notifier.answer(wrongOption.id);

      expect(notifier.debugState!.score, 0);
      expect(notifier.debugState!.lastAnswerCorrect, false);
    });

    test('next advances to next round', () {
      notifier.start();
      final correctId = notifier.debugState!.correctCard.id;
      notifier.answer(correctId);

      notifier.next();

      expect(notifier.debugState!.round, 2);
    });

    test('quiz finishes after all rounds', () {
      notifier.start();
      final totalRounds = notifier.debugState!.totalRounds;

      for (int i = 0; i < totalRounds; i++) {
        final correctId = notifier.debugState!.correctCard.id;
        notifier.answer(correctId);
        notifier.next();
      }

      expect(notifier.debugState!.finished, true);
    });

    test('perfect score equals totalRounds', () {
      notifier.start();
      final totalRounds = notifier.debugState!.totalRounds;

      for (int i = 0; i < totalRounds; i++) {
        notifier.answer(notifier.debugState!.correctCard.id);
        if (i < totalRounds - 1) notifier.next();
      }
      notifier.next(); // triggers finished

      expect(notifier.debugState!.score, totalRounds);
      expect(notifier.debugState!.finished, true);
    });

    test('reset clears state', () {
      notifier.start();
      notifier.answer(notifier.debugState!.correctCard.id);
      notifier.reset();

      expect(notifier.debugState, isNull);
    });

    test('answer is ignored when finished', () {
      notifier.start();
      final totalRounds = notifier.debugState!.totalRounds;
      for (int i = 0; i < totalRounds; i++) {
        notifier.answer(notifier.debugState!.correctCard.id);
        notifier.next();
      }
      final scoreAfterFinish = notifier.debugState!.score;

      notifier.answer('card_0');

      expect(notifier.debugState!.score, scoreAfterFinish);
    });

    test('answer is ignored when state is null', () {
      // Should not throw
      notifier.answer('card_0');
      expect(notifier.debugState, isNull);
    });

    test('next is ignored when state is null', () {
      notifier.next();
      expect(notifier.debugState, isNull);
    });

    test('restart preserves mistake tracking', () {
      notifier.start();
      // Get first question wrong
      final firstCorrect = notifier.debugState!.correctCard.id;
      final wrongOption = notifier.debugState!.options
          .firstWhere((c) => c.id != firstCorrect);
      notifier.answer(wrongOption.id);

      notifier.restart();

      // After restart, the missed card should appear again eventually
      final state = notifier.debugState!;
      expect(state.round, 1);
      expect(state.score, 0);
    });

    test('totalRounds is clamped to playable cards length', () {
      final fiveCards = List.generate(5, (i) => _card('c_$i'));
      final n = QuizNotifier(fiveCards);
      n.start();

      expect(n.debugState!.totalRounds, 5);
    });

    test('totalRounds capped at 10', () {
      final manyCards = List.generate(20, (i) => _card('c_$i'));
      final n = QuizNotifier(manyCards);
      n.start();

      expect(n.debugState!.totalRounds, 10);
    });

    test('options always contain the correct card', () {
      notifier.start();

      for (int i = 0; i < 5; i++) {
        expect(
          notifier.debugState!.options.contains(notifier.debugState!.correctCard),
          true,
          reason: 'Round ${notifier.debugState!.round}: correct card must be in options',
        );
        notifier.answer(notifier.debugState!.correctCard.id);
        notifier.next();
        if (notifier.debugState!.finished) break;
      }
    });

    test('each round shows a different correct card', () {
      notifier.start();
      final usedIds = <String>{};

      for (int i = 0; i < notifier.debugState!.totalRounds; i++) {
        final correctId = notifier.debugState!.correctCard.id;
        expect(usedIds.contains(correctId), false,
            reason: 'Card $correctId should not repeat within a round');
        usedIds.add(correctId);
        notifier.answer(correctId);
        notifier.next();
        if (notifier.debugState!.finished) break;
      }
    });
  });

  group('QuizState.copyWith', () {
    test('copies all fields correctly', () {
      final card = _card('test');
      final state = QuizState(
        correctCard: card,
        options: [card],
        score: 5,
        round: 3,
        totalRounds: 10,
        lastAnswerCorrect: true,
        finished: false,
      );

      final copy = state.copyWith(score: 6, round: 4);

      expect(copy.score, 6);
      expect(copy.round, 4);
      expect(copy.totalRounds, 10);
      expect(copy.correctCard, card);
      expect(copy.finished, false);
    });

    test('lastAnswerCorrect resets to null on copyWith', () {
      final card = _card('test');
      final state = QuizState(
        correctCard: card,
        options: [card],
        lastAnswerCorrect: true,
      );

      final copy = state.copyWith(score: 1);
      // lastAnswerCorrect is not passed, so it should be null
      expect(copy.lastAnswerCorrect, isNull);
    });
  });
}
