import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/streak_provider.dart';

void main() {
  group('StreakState', () {
    test('default values', () {
      const state = StreakState();
      expect(state.currentStreak, 0);
      expect(state.lastActiveDate, '');
      expect(state.unlockedRewards, isEmpty);
    });
  });

  group('Milestone', () {
    test('milestones list has 4 entries', () {
      expect(milestones.length, 4);
    });

    test('milestones are in ascending order', () {
      for (int i = 1; i < milestones.length; i++) {
        expect(milestones[i].days, greaterThan(milestones[i - 1].days));
      }
    });

    test('milestone days are 3, 7, 14, 30', () {
      expect(milestones.map((m) => m.days).toList(), [3, 7, 14, 30]);
    });
  });

  group('StreakNotifier', () {
    String todayKey() {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    String yesterdayKey() {
      final y = DateTime.now().subtract(const Duration(days: 1));
      return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    }

    test('fresh start sets streak to 1', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.debugState.currentStreak, 1);
      expect(notifier.debugState.lastActiveDate, todayKey());
    });

    test('consecutive day increments streak', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 5,
        'streak_last_date': yesterdayKey(),
        'streak_rewards': <String>[],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.debugState.currentStreak, 6);
      expect(notifier.debugState.lastActiveDate, todayKey());
    });

    test('missed day resets streak to 1', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final oldKey =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'streak_current': 10,
        'streak_last_date': oldKey,
        'streak_rewards': <String>[],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.debugState.currentStreak, 1);
    });

    test('same day does not double-count', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 3,
        'streak_last_date': todayKey(),
        'streak_rewards': <String>[],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      // Streak should remain 3, not increment
      expect(notifier.debugState.currentStreak, 3);
    });

    test('reaching milestone 3 unlocks reward', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 2,
        'streak_last_date': yesterdayKey(),
        'streak_rewards': <String>[],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.debugState.currentStreak, 3);
      expect(notifier.debugState.unlockedRewards, contains('🦄'));
    });

    test('reaching milestone 7 unlocks both 3 and 7 rewards', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 6,
        'streak_last_date': yesterdayKey(),
        'streak_rewards': ['🦄'],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.debugState.currentStreak, 7);
      expect(notifier.debugState.unlockedRewards, containsAll(['🦄', '🐉']));
    });

    test('nextMilestone returns first unreached milestone', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 4,
        'streak_last_date': todayKey(),
        'streak_rewards': ['🦄'],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.nextMilestone?.days, 7);
    });

    test('nextMilestone returns null when all milestones reached', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 30,
        'streak_last_date': todayKey(),
        'streak_rewards': ['🦄', '🐉', '🌈', '🦋'],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.nextMilestone, isNull);
    });

    test('daysToNext calculates remaining days', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 5,
        'streak_last_date': todayKey(),
        'streak_rewards': ['🦄'],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.daysToNext, 2); // 7 - 5 = 2
    });

    test('daysToNext is 0 when all milestones completed', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 31,
        'streak_last_date': todayKey(),
        'streak_rewards': ['🦄', '🐉', '🌈', '🦋'],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.daysToNext, 0);
    });

    test('persists updated streak', () async {
      SharedPreferences.setMockInitialValues({
        'streak_current': 2,
        'streak_last_date': yesterdayKey(),
        'streak_rewards': <String>[],
      });

      final notifier = StreakNotifier();
      await Future.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak_current'), 3);
      expect(prefs.getString('streak_last_date'), todayKey());
    });
  });
}
