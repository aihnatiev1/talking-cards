/// Per-card state for the SM-2 spaced repetition algorithm.
class SrsCardState {
  final String cardId;
  final double easeFactor;  // starts at 2.5
  final int interval;        // days until next review
  final int repetitions;     // successful reviews in a row
  final DateTime nextReviewDate;

  const SrsCardState({
    required this.cardId,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReviewDate,
  });

  /// First time a card enters the SRS system.
  factory SrsCardState.initial(String cardId) => SrsCardState(
        cardId: cardId,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        nextReviewDate: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
      );

  /// True if this card should be reviewed today or is overdue.
  bool get isDueToday {
    final today = DateTime.now();
    final todayMidnight =
        DateTime(today.year, today.month, today.day);
    return !nextReviewDate.isAfter(todayMidnight);
  }

  Map<String, dynamic> toJson() => {
        'id': cardId,
        'ef': easeFactor,
        'iv': interval,
        'rp': repetitions,
        'nr': nextReviewDate.toIso8601String(),
      };

  factory SrsCardState.fromJson(Map<String, dynamic> j) => SrsCardState(
        cardId: j['id'] as String,
        easeFactor: (j['ef'] as num).toDouble(),
        interval: j['iv'] as int,
        repetitions: j['rp'] as int,
        nextReviewDate: DateTime.parse(j['nr'] as String),
      );
}
