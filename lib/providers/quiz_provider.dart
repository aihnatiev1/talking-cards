import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';

class QuizState {
  final CardModel correctCard;
  final List<CardModel> options;
  final int score;
  final int round;
  final int totalRounds;
  final bool? lastAnswerCorrect;
  final bool finished;

  const QuizState({
    required this.correctCard,
    required this.options,
    this.score = 0,
    this.round = 1,
    this.totalRounds = 10,
    this.lastAnswerCorrect,
    this.finished = false,
  });

  QuizState copyWith({
    CardModel? correctCard,
    List<CardModel>? options,
    int? score,
    int? round,
    int? totalRounds,
    bool? lastAnswerCorrect,
    bool? finished,
  }) {
    return QuizState(
      correctCard: correctCard ?? this.correctCard,
      options: options ?? this.options,
      score: score ?? this.score,
      round: round ?? this.round,
      totalRounds: totalRounds ?? this.totalRounds,
      lastAnswerCorrect: lastAnswerCorrect,
      finished: finished ?? this.finished,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState?> {
  final List<CardModel> _allCards;
  final _random = Random();

  /// Cards already shown as correct answer in current session (across restarts).
  final Set<String> _globalUsedIds = {};

  /// Cards used in current round only.
  final Set<String> _roundUsedIds = {};

  /// Cards the child got wrong — prioritized in next rounds.
  final Set<String> _mistakeIds = {};

  QuizNotifier(this._allCards) : super(null);

  List<CardModel> get _playableCards =>
      _allCards.where((c) => c.image != null).toList();

  void start() {
    final playable = _playableCards;
    if (playable.length < 4) return;
    _roundUsedIds.clear();
    final totalRounds = playable.length.clamp(1, 10);
    _nextQuestion(score: 0, round: 1, totalRounds: totalRounds);
  }

  /// Restart with fresh cards, but prioritize previous mistakes.
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
        .where((c) => _mistakeIds.contains(c.id) && !_roundUsedIds.contains(c.id))
        .toList();

    // Priority 2: never seen globally and not used this round
    final freshCards = playable
        .where((c) =>
            !_globalUsedIds.contains(c.id) && !_roundUsedIds.contains(c.id))
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
      state = state?.copyWith(finished: true) ??
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

    // 3 wrong options (different from correct)
    final wrong = (playable.where((c) => c.id != correct.id).toList()
          ..shuffle(_random))
        .take(3)
        .toList();
    final options = [correct, ...wrong]..shuffle(_random);

    state = QuizState(
      correctCard: correct,
      options: options,
      score: score,
      round: round,
      totalRounds: totalRounds,
    );
  }

  void answer(String cardId) {
    if (state == null || state!.finished) return;
    final isCorrect = cardId == state!.correctCard.id;
    if (isCorrect) {
      // Remove from mistakes if child got it right on retry
      _mistakeIds.remove(state!.correctCard.id);
      state = state!.copyWith(
        score: state!.score + 1,
        lastAnswerCorrect: true,
      );
    } else {
      // Remember the mistake for future rounds
      _mistakeIds.add(state!.correctCard.id);
      state = state!.copyWith(
        lastAnswerCorrect: false,
      );
    }
  }

  void next() {
    if (state == null) return;
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
