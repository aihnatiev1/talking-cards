import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../utils/quiz_tiers.dart';

class QuizState {
  final CardModel correctCard;
  final List<CardModel> options;
  final int score;
  final int round;
  final int totalRounds;
  final bool? lastAnswerCorrect;
  final bool finished;

  /// Misses after which the right tile starts to glow on this question.
  /// Normally 2; after repeated difficulty the help comes on the first
  /// miss (see [QuizTiers]). The screen reads it — `MissTracker` only
  /// counts.
  final int hintAfterMisses;

  const QuizState({
    required this.correctCard,
    required this.options,
    this.score = 0,
    this.round = 1,
    this.totalRounds = 10,
    this.lastAnswerCorrect,
    this.finished = false,
    this.hintAfterMisses = QuizTiers.hintAfterMisses,
  });

  QuizState copyWith({
    CardModel? correctCard,
    List<CardModel>? options,
    int? score,
    int? round,
    int? totalRounds,
    bool? lastAnswerCorrect,
    bool? finished,
    int? hintAfterMisses,
  }) {
    return QuizState(
      correctCard: correctCard ?? this.correctCard,
      options: options ?? this.options,
      score: score ?? this.score,
      round: round ?? this.round,
      totalRounds: totalRounds ?? this.totalRounds,
      lastAnswerCorrect: lastAnswerCorrect,
      finished: finished ?? this.finished,
      hintAfterMisses: hintAfterMisses ?? this.hintAfterMisses,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState?> {
  /// [level] is the profile's age band — it only sets where the board of
  /// pictures starts and how high it may go; [QuizDifficulty] does the
  /// rest from the answers themselves (experience audit §19).
  ///
  /// [groups] maps a card id to the set it belongs to (the pack it came
  /// from, which is how this app spells "animals", "food", "clothes").
  /// With it, a three- or four-picture question is a real question —
  /// a cat among animals — instead of a cat among a bus and a spoon.
  QuizNotifier(
    this._allCards, {
    int level = 2,
    Map<String, String> groups = const {},
    int? fixedOptions,
  }) : _groups = groups,
       _difficulty = QuizDifficulty(level: level, fixedOptions: fixedOptions),
       super(null);

  final List<CardModel> _allCards;
  final Map<String, String> _groups;
  final QuizDifficulty _difficulty;
  final _random = Random();

  int _mistakesThisQuestion = 0;
  bool _hintShownThisQuestion = false;
  int _lastAnswerQuality = 0;
  int get lastAnswerQuality => _lastAnswerQuality;

  /// Pictures the current question shows. Grows and shrinks with the
  /// child's own answers, never with the round number.
  int get optionCount => _difficulty.optionCount;

  /// Cards already shown as correct answer in current session (across restarts).
  final Set<String> _globalUsedIds = {};

  /// Cards used in current round only.
  final Set<String> _roundUsedIds = {};

  /// Cards the child got wrong — prioritized in next rounds.
  final Set<String> _mistakeIds = {};

  List<CardModel> get _playableCards =>
      _allCards.where((c) => c.image != null).toList();

  void start() {
    final playable = _playableCards;
    if (playable.length < 4) return;
    _roundUsedIds.clear();
    final totalRounds = playable.length.clamp(1, 10);
    _nextQuestion(score: 0, round: 1, totalRounds: totalRounds);
  }

  /// Restart with fresh cards, but prioritize previous mistakes. The
  /// difficulty ladder is *not* reset: "ще раз" is the same session for the
  /// same child, and a board that just fit should not shrink back to two.
  void restart() {
    final playable = _playableCards;
    if (playable.length < 4) return;
    _roundUsedIds.clear();
    // Don't clear _mistakeIds or _globalUsedIds — they persist across restarts
    final totalRounds = playable.length.clamp(1, 10);
    _nextQuestion(score: 0, round: 1, totalRounds: totalRounds);
  }

  void _nextQuestion({
    required int score,
    required int round,
    required int totalRounds,
  }) {
    final playable = _playableCards;

    // Priority 1: mistakes not yet re-asked this round
    final mistakeCards = playable
        .where(
          (c) => _mistakeIds.contains(c.id) && !_roundUsedIds.contains(c.id),
        )
        .toList();

    // Priority 2: never seen globally and not used this round
    final freshCards = playable
        .where(
          (c) =>
              !_globalUsedIds.contains(c.id) && !_roundUsedIds.contains(c.id),
        )
        .toList();

    // Priority 3: anything not used this round
    final anyAvailable = playable
        .where((c) => !_roundUsedIds.contains(c.id))
        .toList();

    List<CardModel> pool;
    if (mistakeCards.isNotEmpty) {
      pool = mistakeCards;
    } else if (freshCards.isNotEmpty) {
      pool = freshCards;
    } else if (anyAvailable.isNotEmpty) {
      pool = anyAvailable;
    } else {
      // Everything exhausted — finish
      state =
          state?.copyWith(finished: true) ??
          QuizState(
            correctCard: playable.first,
            options: [],
            score: score,
            round: round,
            totalRounds: totalRounds,
            finished: true,
          );
      return;
    }

    pool.shuffle(_random);
    final correct = pool.first;
    _roundUsedIds.add(correct.id);
    _globalUsedIds.add(correct.id);

    final wanted = _difficulty.optionCount.clamp(2, playable.length);
    final options = [correct, ..._distractorsFor(correct, playable, wanted - 1)]
      ..shuffle(_random);

    _mistakesThisQuestion = 0;
    _hintShownThisQuestion = false;
    state = QuizState(
      correctCard: correct,
      options: options,
      score: score,
      round: round,
      totalRounds: totalRounds,
      hintAfterMisses: _difficulty.hintAfterMisses,
    );
  }

  /// The pictures the right one stands among.
  ///
  /// * **Two pictures** — the distractor comes from *another* set, so the
  ///   pair reads as obviously different and the youngest child can win by
  ///   pointing at the one that looks like the word they just heard.
  /// * **Three or four** — the distractors come from the *same* set as the
  ///   answer (animals against animals), so the question is about the word
  ///   and not about which picture looks out of place.
  ///
  /// Either way, a pool too small to satisfy the preference is topped up
  /// from whatever is left rather than leaving the board short.
  List<CardModel> _distractorsFor(
    CardModel correct,
    List<CardModel> playable,
    int count,
  ) {
    if (count <= 0) return const [];
    final rest = playable.where((c) => c.id != correct.id).toList();
    final group = _groups[correct.id];
    final sameSet = <CardModel>[];
    final otherSet = <CardModel>[];
    for (final c in rest) {
      if (group != null && _groups[c.id] == group) {
        sameSet.add(c);
      } else {
        otherSet.add(c);
      }
    }
    sameSet.shuffle(_random);
    otherSet.shuffle(_random);

    final preferred = count == 1
        ? [...otherSet, ...sameSet]
        : [...sameSet, ...otherSet];
    return preferred.take(count).toList();
  }

  void answer(String cardId) {
    if (state == null || state!.finished) return;
    final isCorrect = cardId == state!.correctCard.id;
    _lastAnswerQuality = isCorrect ? (_mistakesThisQuestion == 0 ? 5 : 3) : 2;
    if (!isCorrect) {
      _mistakesThisQuestion++;
      if (_mistakesThisQuestion >= state!.hintAfterMisses) {
        _hintShownThisQuestion = true;
      }
    }

    if (isCorrect) {
      // Remove from mistakes if child got it right on retry
      _mistakeIds.remove(state!.correctCard.id);
      state = state!.copyWith(score: state!.score + 1, lastAnswerCorrect: true);
    } else {
      // Remember the mistake for future rounds
      _mistakeIds.add(state!.correctCard.id);
      state = state!.copyWith(lastAnswerCorrect: false);
    }
  }

  void next() {
    if (state == null) return;
    // The finished question is what sizes the following one.
    _difficulty.applyQuestion(
      misses: _mistakesThisQuestion,
      hintShown: _hintShownThisQuestion,
    );
    final nextRound = state!.round + 1;
    if (nextRound > state!.totalRounds) {
      state = state!.copyWith(finished: true);
      return;
    }
    _nextQuestion(
      score: state!.score,
      round: nextRound,
      totalRounds: state!.totalRounds,
    );
  }

  void reset() {
    _roundUsedIds.clear();
    _globalUsedIds.clear();
    _mistakeIds.clear();
    state = null;
  }
}
