/// A difficulty ladder that listens to confidence, not to wins
/// (docs/design/memory_match_redesign.md §6; experience audit 2026-09-13
/// §19, §20).
///
/// «Знайди пару» was the first game to stop counting wins: a win in a
/// memory game is inevitable and says nothing about whether the child
/// coped. What a game *can* count without showing anything is confidence —
/// misses and hints. «Вгадай звук» needs exactly the same arithmetic on a
/// different quantity (how many pictures are on the board), so the
/// bookkeeping lives here and each game only says what a calm round is.
///
/// Nothing here is announced and nothing is spoken: the next round is
/// simply a different size. No clock is involved — nothing under five
/// years old is measured in seconds.
library;

/// The verdict on one round.
enum RoundConfidence { calm, neutral, struggle }

/// What the verdict did to the ladder.
enum TierChange { up, stay, back }

/// One session's worth of sizing. Pure Dart: no clock, no storage — the
/// game feeds it rounds and asks it for the next [value].
class ConfidenceLadder {
  ConfidenceLadder({
    required this.steps,
    required this.floor,
    required this.ceiling,
    required this.calmNeeded,
    this.struggleForStepBack = 2,
    int? value,
    this.fixed = false,
  }) : _value = value ?? floor;

  /// The rungs, ascending (e.g. 2 → 3 → 4 pairs, or 2 → 3 → 4 pictures).
  final List<int> steps;

  /// The rung this session starts on and may never drop below.
  final int floor;

  /// The highest rung this session may reach.
  final int ceiling;

  /// Calm rounds in a row needed to climb: the little ones get two
  /// chances to prove it, the older ones move on the first.
  final int calmNeeded;

  /// Hard rounds in a row that hand the previous rung back.
  final int struggleForStepBack;

  /// An explicit size (a test, a parent's choice) turns the ladder off.
  final bool fixed;

  int _value;
  int _calmRun = 0;
  int _struggleRun = 0;

  /// Rungs this session has climbed to — only those may be given back, so
  /// a child never drops below where they started.
  final Set<int> _raisedTo = {};

  /// The size of the next round.
  int get value => _value;

  int get calmRun => _calmRun;

  /// Hard rounds in a row right now — a game may use it to soften
  /// something else (an earlier hint, a longer look) before the ladder
  /// itself moves.
  int get struggleRun => _struggleRun;

  /// The next rung up from [from], never past [ceiling].
  int up(int from) {
    for (final s in steps) {
      if (s > from && s <= ceiling) return s;
    }
    return from;
  }

  /// The next rung down from [from], never below [floor].
  int down(int from) {
    for (final s in steps.reversed) {
      if (s < from && s >= floor) return s;
    }
    return from;
  }

  /// Records a finished round and returns what it did to the ladder.
  TierChange apply(RoundConfidence verdict) {
    if (fixed) return TierChange.stay;

    switch (verdict) {
      case RoundConfidence.calm:
        _struggleRun = 0;
        _calmRun++;
        if (_calmRun < calmNeeded) return TierChange.stay;
        final next = up(_value);
        if (next == _value) return TierChange.stay;
        _calmRun = 0;
        _value = next;
        _raisedTo.add(next);
        return TierChange.up;

      case RoundConfidence.neutral:
        _calmRun = 0;
        _struggleRun = 0;
        return TierChange.stay;

      case RoundConfidence.struggle:
        _calmRun = 0;
        _struggleRun++;
        if (_struggleRun < struggleForStepBack || !_raisedTo.contains(_value)) {
          return TierChange.stay;
        }
        final back = down(_value);
        if (back == _value) return TierChange.stay;
        _struggleRun = 0;
        _raisedTo.remove(_value);
        _value = back;
        return TierChange.back;
    }
  }
}
