import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/review_provider.dart';

void main() {
  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  group('CardLastSeenNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () async {
      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.debugState, isEmpty);
    });

    test('markSeen records today date for card', () async {
      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markSeen('card_1');

      expect(notifier.debugState['card_1'], todayKey());
    });

    test('markSeen persists to SharedPreferences', () async {
      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markSeen('card_1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('card_last_seen_card_1'), todayKey());
    });

    test('reviewCardIds returns cards seen 3+ days ago', () async {
      final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));
      final oldDate =
          '${fourDaysAgo.year}-${fourDaysAgo.month.toString().padLeft(2, '0')}-${fourDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'card_last_seen_old_card': oldDate,
        'card_last_seen_recent_card': todayKey(),
      });

      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      final review = notifier.reviewCardIds;
      expect(review, contains('old_card'));
      expect(review, isNot(contains('recent_card')));
    });

    test('reviewCardIds empty when all cards seen recently', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'card_last_seen_card_1': todayKey(),
        'card_last_seen_card_2': yesterdayKey,
      });

      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.reviewCardIds, isEmpty);
    });

    test('reviewCardIds handles exactly 3 days threshold', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final key =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'card_last_seen_edge_card': key,
      });

      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      // 3 days ago should be included (isBefore threshold)
      final review = notifier.reviewCardIds;
      expect(review, contains('edge_card'));
    });

    test('loads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'card_last_seen_a': '2026-01-01',
        'card_last_seen_b': '2026-03-10',
      });

      final notifier = CardLastSeenNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState.length, 2);
      expect(notifier.debugState['a'], '2026-01-01');
      expect(notifier.debugState['b'], '2026-03-10');
    });
  });
}
