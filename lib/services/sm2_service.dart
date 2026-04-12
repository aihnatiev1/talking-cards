import '../models/srs_card_state.dart';

/// Pure implementation of the SM-2 spaced repetition algorithm.
///
/// Quality scale used in this app:
///   5 — correct on first attempt in quiz
///   4 — card viewed in swiper (passive reinforcement)
///   2 — wrong answer in quiz (resets interval)
class Sm2Service {
  Sm2Service._();

  /// Returns a new [SrsCardState] after recording a response with [quality].
  /// Quality must be in range 0–5.
  static SrsCardState update(SrsCardState current, int quality) {
    assert(quality >= 0 && quality <= 5,
        'SM-2 quality must be 0–5, got $quality');

    double ef = current.easeFactor;
    int interval = current.interval;
    int reps = current.repetitions;

    if (quality >= 3) {
      // ── Correct response ──────────────────────────────────────────────
      if (reps == 0) {
        interval = 1;
      } else if (reps == 1) {
        interval = 6;
      } else {
        interval = (interval * ef).round().clamp(1, 365);
      }
      ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      ef = ef.clamp(1.3, 4.0);
      reps++;
    } else {
      // ── Wrong response — reset ────────────────────────────────────────
      reps = 0;
      interval = 1;
      // EF is not changed on wrong answer per SM-2 spec
    }

    final now = DateTime.now();
    final nextDate = DateTime(now.year, now.month, now.day)
        .add(Duration(days: interval));

    return SrsCardState(
      cardId: current.cardId,
      easeFactor: ef,
      interval: interval,
      repetitions: reps,
      nextReviewDate: nextDate,
    );
  }
}
