/// How a round of «Знайди пару» felt, and what the board does about it
/// (docs/design/memory_match_redesign.md §6).
///
/// The board used to grow "after 2 wins". A win in a memory game is
/// inevitable — it says nothing about whether the child coped. What the
/// game can count without showing anything is *confidence*: misses and
/// hints. A calm round earns a bigger board; a hard one keeps the board the
/// child has just managed; two hard rounds on a size we raised to **in this
/// session** quietly hand the smaller board back. Nothing is announced and
/// nothing is spoken — the next deal is simply a different size. No timer
/// is involved: nothing under five years old is measured in seconds.
///
/// The bookkeeping itself (runs, the ceiling, what may be given back) is
/// [ConfidenceLadder] — «Вгадай звук» sizes its board of pictures with the
/// same arithmetic. This file owns only what a calm *memory* round is.
library;

import 'confidence_ladder.dart';

export 'confidence_ladder.dart' show RoundConfidence, TierChange;

/// The ladder of board sizes and the per-level windows on it.
abstract final class MemoryTiers {
  /// 2 → 3 → 4 → 6 → 8 pairs. 8 needs a four-column board (wave 3), which
  /// is why no level's ceiling reaches it yet.
  static const steps = <int>[2, 3, 4, 6, 8];

  /// Where a child of [level] starts (1: 1–2 y, 2: 2–3, 3: 3–4, 4: 4–5).
  /// Two pairs is not "too little" for eighteen months: four cards is a
  /// win in four flips, and that is the loop they repeat twenty times.
  static int startFor(int level) => switch (level) {
    <= 1 => 2,
    2 => 3,
    3 => 4,
    _ => 6,
  };

  /// The biggest board a level may reach in one session.
  static int ceilingFor(int level) => switch (level) {
    <= 1 => 3,
    2 => 4,
    3 => 6,
    _ => 6,
  };

  /// Calm rounds in a row needed for a bigger board: the little ones get
  /// two chances to prove it, the older ones move on the first.
  static int calmNeeded(int level) => level <= 2 ? 2 : 1;

  /// Two hard rounds in a row give the previous size back.
  static const struggleForStepBack = 2;

  /// A random game on a 2-pair board costs about one miss, so `calm` is
  /// reachable for an eighteen-month-old too — the board still grows.
  static RoundConfidence confidenceOf({
    required int pairs,
    required int misses,
    required int hints,
  }) {
    if (misses >= 2 * pairs || hints >= 2) return RoundConfidence.struggle;
    if (misses <= pairs && hints == 0) return RoundConfidence.calm;
    return RoundConfidence.neutral;
  }

  /// The next size up from [pairs], never past [ceiling].
  static int up(int pairs, int ceiling) {
    for (final s in steps) {
      if (s > pairs && s <= ceiling) return s;
    }
    return pairs;
  }

  /// The next size down from [pairs], never below [floor].
  static int down(int pairs, int floor) {
    for (final s in steps.reversed) {
      if (s < pairs && s >= floor) return s;
    }
    return pairs;
  }
}

/// One session's worth of board sizing. Pure Dart, no clock, no storage —
/// the screen feeds it rounds and asks it how many pairs to deal.
class MemoryDifficulty {
  MemoryDifficulty({required this.level, int? fixedPairs})
    : _ladder = ConfidenceLadder(
        steps: MemoryTiers.steps,
        floor: MemoryTiers.startFor(level),
        ceiling: MemoryTiers.ceilingFor(level),
        calmNeeded: MemoryTiers.calmNeeded(level),
        struggleForStepBack: MemoryTiers.struggleForStepBack,
        value: fixedPairs,
        fixed: fixedPairs != null,
      );

  final int level;
  final ConfidenceLadder _ladder;

  /// Pairs for the next deal.
  int get pairs => _ladder.value;

  /// An explicit `pairCount` (tests, a parent's choice) turns the ladder
  /// off for the session.
  bool get isFixed => _ladder.fixed;

  int get calmRun => _ladder.calmRun;

  /// Records a finished round and returns what it did to the board.
  TierChange applyRound({required int misses, required int hints}) =>
      _ladder.apply(
        MemoryTiers.confidenceOf(pairs: pairs, misses: misses, hints: hints),
      );
}
