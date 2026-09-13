/// How hard «Вгадай звук» is right now, and what makes it change
/// (experience audit 2026-09-13 §19).
///
/// The game used to deal four pictures at every level of every age, with
/// the three distractors drawn at random from the whole pool. That made
/// difficulty a lottery: "cat" against a dog, a bus and a spoon is a
/// different task every round, and a one-in-four guess is right often
/// enough that a child can finish a session without ever hearing the word.
///
/// So the board starts at **two clearly different pictures** and grows to
/// three and four on the child's own evidence — the same
/// [ConfidenceLadder] the memory board climbs, fed with what a calm *quiz*
/// question is: answered first time, with no hint. Age only decides where
/// the session starts and how high it may go; the climbing is done by the
/// child in front of the screen.
///
/// Nothing about this is spoken or shown: the next question simply has one
/// more picture on it.
library;

import 'confidence_ladder.dart';

export 'confidence_ladder.dart' show RoundConfidence, TierChange;

abstract final class QuizTiers {
  /// 2 → 3 → 4 pictures. Four is the ceiling: a 2×2 board is the largest
  /// set of illustrations a three-year-old can scan before the word fades
  /// from memory.
  static const steps = <int>[2, 3, 4];

  /// Where a child of [level] starts (1: 1–2 y, 2: 2–3, 3: 3–4, 4: 4–5).
  /// Two pictures is a real question — it is the choice a speech therapist
  /// starts with — and it is winnable by pointing, which is what an
  /// eighteen-month-old has instead of words.
  static int startFor(int level) => level <= 2 ? 2 : 3;

  /// The biggest board a level may reach in one session.
  static int ceilingFor(int level) => level <= 1 ? 3 : 4;

  /// Calm questions in a row needed to add a picture.
  static int calmNeeded(int level) => level <= 2 ? 2 : 1;

  /// Two hard questions in a row take the added picture away again.
  static const struggleForStepBack = 2;

  /// Misses before the right tile starts to glow, normally…
  static const hintAfterMisses = 2;

  /// …and once the last [hardRunForEarlyHint] questions were hard: the
  /// child who is struggling gets the nudge on the first miss instead of
  /// tapping their way around the board.
  static const hintAfterMissesWhenStruggling = 1;
  static const hardRunForEarlyHint = 2;

  /// A question answered first time, with no hint, is calm; two misses (or
  /// a hint, which means two misses happened) is a struggle.
  static RoundConfidence confidenceOf({
    required int misses,
    required bool hintShown,
  }) {
    if (hintShown || misses >= 2) return RoundConfidence.struggle;
    if (misses == 0) return RoundConfidence.calm;
    return RoundConfidence.neutral;
  }
}

/// One session's worth of quiz sizing: how many pictures the next question
/// shows, and how soon the right one starts to glow.
class QuizDifficulty {
  QuizDifficulty({required this.level, int? fixedOptions})
    : _ladder = ConfidenceLadder(
        steps: QuizTiers.steps,
        floor: QuizTiers.startFor(level),
        ceiling: QuizTiers.ceilingFor(level),
        calmNeeded: QuizTiers.calmNeeded(level),
        struggleForStepBack: QuizTiers.struggleForStepBack,
        value: fixedOptions,
        fixed: fixedOptions != null,
      );

  final int level;
  final ConfidenceLadder _ladder;
  int _hardRun = 0;

  /// Pictures on the next question.
  int get optionCount => _ladder.value;

  bool get isFixed => _ladder.fixed;

  int get calmRun => _ladder.calmRun;

  /// Hard questions in a row, including ones the ladder has already
  /// answered by stepping back.
  int get hardRun => _hardRun;

  /// Misses after which the right tile starts to glow on *this* question.
  int get hintAfterMisses => _hardRun >= QuizTiers.hardRunForEarlyHint
      ? QuizTiers.hintAfterMissesWhenStruggling
      : QuizTiers.hintAfterMisses;

  /// Records a finished question and returns what it did to the board.
  TierChange applyQuestion({required int misses, required bool hintShown}) {
    final verdict = QuizTiers.confidenceOf(misses: misses, hintShown: hintShown);
    switch (verdict) {
      case RoundConfidence.struggle:
        _hardRun++;
      case RoundConfidence.calm:
        _hardRun = 0;
      case RoundConfidence.neutral:
        break;
    }
    return _ladder.apply(verdict);
  }
}
