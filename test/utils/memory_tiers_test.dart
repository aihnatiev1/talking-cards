import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/memory_tiers.dart';

/// The board grows on confidence, not on wins (memory_match_redesign §6).
/// A win in a memory game is inevitable; misses and hints are what say
/// whether the child coped.
void main() {
  group('confidence of a round', () {
    test('few misses and no hint is calm', () {
      expect(
        MemoryTiers.confidenceOf(pairs: 3, misses: 3, hints: 0),
        RoundConfidence.calm,
      );
    });

    test('twice the pairs in misses is a struggle', () {
      expect(
        MemoryTiers.confidenceOf(pairs: 3, misses: 6, hints: 0),
        RoundConfidence.struggle,
      );
    });

    test('two hints is a struggle however few the misses', () {
      expect(
        MemoryTiers.confidenceOf(pairs: 3, misses: 0, hints: 2),
        RoundConfidence.struggle,
      );
    });

    test('in between is neutral — the board does not move', () {
      expect(
        MemoryTiers.confidenceOf(pairs: 3, misses: 4, hints: 0),
        RoundConfidence.neutral,
      );
    });
  });

  group('the ladder', () {
    test('level 1 starts on two pairs and stops at three', () {
      expect(MemoryTiers.startFor(1), 2);
      expect(MemoryTiers.ceilingFor(1), 3);
    });

    test('two calm rounds grow a little board', () {
      final d = MemoryDifficulty(level: 2);
      expect(d.pairs, 3);
      expect(d.applyRound(misses: 1, hints: 0), TierChange.stay);
      expect(d.applyRound(misses: 1, hints: 0), TierChange.up);
      expect(d.pairs, 4);
    });

    test('an older child moves on the first calm round', () {
      final d = MemoryDifficulty(level: 3);
      expect(d.pairs, 4);
      expect(d.applyRound(misses: 2, hints: 0), TierChange.up);
      expect(d.pairs, 6);
    });

    test('a neutral round breaks the calm run without moving the board', () {
      final d = MemoryDifficulty(level: 2);
      d.applyRound(misses: 1, hints: 0);
      expect(d.applyRound(misses: 4, hints: 0), TierChange.stay);
      expect(d.calmRun, 0);
      expect(d.applyRound(misses: 1, hints: 0), TierChange.stay);
      expect(d.pairs, 3);
    });

    test('a hard round keeps the board the child has just managed', () {
      final d = MemoryDifficulty(level: 2);
      expect(d.applyRound(misses: 9, hints: 0), TierChange.stay);
      expect(d.pairs, 3);
    });

    test('two hard rounds on a board we raised to hand the smaller back', () {
      final d = MemoryDifficulty(level: 2);
      d.applyRound(misses: 1, hints: 0);
      expect(d.applyRound(misses: 1, hints: 0), TierChange.up);
      expect(d.pairs, 4);
      expect(d.applyRound(misses: 8, hints: 0), TierChange.stay);
      expect(d.applyRound(misses: 8, hints: 0), TierChange.back);
      expect(d.pairs, 3);
    });

    test('never below the board the level starts on', () {
      final d = MemoryDifficulty(level: 2);
      for (var i = 0; i < 6; i++) {
        expect(d.applyRound(misses: 20, hints: 0), TierChange.stay);
      }
      expect(d.pairs, 3);
    });

    test('never above the level ceiling', () {
      final d = MemoryDifficulty(level: 1);
      d.applyRound(misses: 0, hints: 0);
      expect(d.applyRound(misses: 0, hints: 0), TierChange.up);
      expect(d.pairs, 3);
      d.applyRound(misses: 0, hints: 0);
      expect(d.applyRound(misses: 0, hints: 0), TierChange.stay);
      expect(d.pairs, 3);
    });

    test('an explicit pair count pins the board for the session', () {
      final d = MemoryDifficulty(level: 3, fixedPairs: 6);
      expect(d.isFixed, isTrue);
      expect(d.applyRound(misses: 0, hints: 0), TierChange.stay);
      expect(d.pairs, 6);
    });
  });
}
