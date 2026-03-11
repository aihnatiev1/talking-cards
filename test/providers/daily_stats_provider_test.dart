import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/daily_stats_provider.dart';

void main() {
  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  group('DailyStatsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () async {
      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.debugState, isEmpty);
    });

    test('recordView increments today count', () async {
      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      await notifier.recordView();
      expect(notifier.debugState[todayKey()], 1);

      await notifier.recordView();
      expect(notifier.debugState[todayKey()], 2);
    });

    test('totalViews sums all days', () async {
      final now = DateTime.now();
      final yesterday =
          '${now.subtract(const Duration(days: 1)).year}-${now.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'daily_views_$yesterday': 10,
      });

      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      await notifier.recordView();
      await notifier.recordView();
      await notifier.recordView();

      expect(notifier.totalViews, 13); // 10 + 3
    });

    test('last7Days returns 7 entries oldest first', () async {
      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      await notifier.recordView();

      final last7 = notifier.last7Days();
      expect(last7.length, 7);
      // Last entry should be today with count 1
      expect(last7.last.key, todayKey());
      expect(last7.last.value, 1);
      // Other days should be 0
      for (int i = 0; i < 6; i++) {
        expect(last7[i].value, 0);
      }
    });

    test('last7Days oldest entry is 6 days ago', () async {
      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      final last7 = notifier.last7Days();
      final sixDaysAgo = DateTime.now().subtract(const Duration(days: 6));
      final expectedKey =
          '${sixDaysAgo.year}-${sixDaysAgo.month.toString().padLeft(2, '0')}-${sixDaysAgo.day.toString().padLeft(2, '0')}';
      expect(last7.first.key, expectedKey);
    });

    test('persists view count', () async {
      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      await notifier.recordView();
      await notifier.recordView();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('daily_views_${todayKey()}'), 2);
    });

    test('loads existing data from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'daily_views_${todayKey()}': 5,
      });

      final notifier = DailyStatsNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState[todayKey()], 5);
      expect(notifier.totalViews, 5);
    });
  });
}
