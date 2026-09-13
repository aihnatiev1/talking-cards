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
library;

/// The verdict on one round.
enum RoundConfidence { calm, neutral, struggle }

/// What the verdict did to the board.
enum TierChange { up, stay, back }

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
    : _floor = MemoryTiers.startFor(level),
      _ceiling = MemoryTiers.ceilingFor(level),
      _pairs = fixedPairs ?? MemoryTiers.startFor(level),
      _fixed = fixedPairs != null;

  final int level;
  final int _floor;
  final int _ceiling;
  final bool _fixed;

  int _pairs;
  int _calmRun = 0;
  int _struggleRun = 0;

  /// Sizes this session has climbed to — only those may be given back, so
  /// a child never drops below the board their age starts on.
  final Set<int> _raisedTo = {};

  /// Pairs for the next deal.
  int get pairs => _pairs;

  /// An explicit `pairCount` (tests, a parent's choice) turns the ladder
  /// off for the session.
  bool get isFixed => _fixed;

  int get calmRun => _calmRun;

  /// Records a finished round and returns what it did to the board.
  TierChange applyRound({required int misses, required int hints}) {
    final verdict = MemoryTiers.confidenceOf(
      pairs: _pairs,
      misses: misses,
      hints: hints,
    );
    if (_fixed) return TierChange.stay;

    switch (verdict) {
      case RoundConfidence.calm:
        _struggleRun = 0;
        _calmRun++;
        if (_calmRun < MemoryTiers.calmNeeded(level)) return TierChange.stay;
        final next = MemoryTiers.up(_pairs, _ceiling);
        if (next == _pairs) return TierChange.stay;
        _calmRun = 0;
        _pairs = next;
        _raisedTo.add(next);
        return TierChange.up;

      case RoundConfidence.neutral:
        _calmRun = 0;
        _struggleRun = 0;
        return TierChange.stay;

      case RoundConfidence.struggle:
        _calmRun = 0;
        _struggleRun++;
        if (_struggleRun < MemoryTiers.struggleForStepBack ||
            !_raisedTo.contains(_pairs)) {
          return TierChange.stay;
        }
        final back = MemoryTiers.down(_pairs, _floor);
        if (back == _pairs) return TierChange.stay;
        _struggleRun = 0;
        _raisedTo.remove(_pairs);
        _pairs = back;
        return TierChange.back;
    }
  }
}
