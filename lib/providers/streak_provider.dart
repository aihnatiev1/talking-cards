import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

class StreakState {
  final int currentStreak;
  final String lastActiveDate;
  final Set<String> unlockedRewards;

  const StreakState({
    this.currentStreak = 0,
    this.lastActiveDate = '',
    this.unlockedRewards = const {},
  });

}

/// Milestones: days required → (badge, bonus emoji, label)
class Milestone {
  final int days;
  final String badge;
  final String bonusEmoji;
  final String label;

  const Milestone(this.days, this.badge, this.bonusEmoji, this.label);
}

const milestones = [
  Milestone(3, '🥉', '🦄', '3 дні'),
  Milestone(7, '🥈', '🐉', '7 днів'),
  Milestone(14, '🥇', '🌈', '14 днів'),
  Milestone(30, '🏆', '🦋', '30 днів'),
];

final streakProvider =
    StateNotifierProvider<StreakNotifier, StreakState>(
  (ref) => StreakNotifier(),
);

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState()) {
    _load();
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  String get _p => ProfileService.prefix;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt('${_p}streak_current') ?? 0;
    final lastDate = prefs.getString('${_p}streak_last_date') ?? '';
    final rewards = (prefs.getStringList('${_p}streak_rewards') ?? []).toSet();
    state = StreakState(
      currentStreak: streak,
      lastActiveDate: lastDate,
      unlockedRewards: rewards,
    );
    // Auto-update on load
    recordActivity();
  }

  Future<void> recordActivity() async {
    final today = _todayKey();
    if (state.lastActiveDate == today) return; // Already recorded today

    int newStreak;
    if (state.lastActiveDate == _yesterdayKey()) {
      newStreak = state.currentStreak + 1;
    } else {
      newStreak = 1; // Reset streak
    }

    // Check for new rewards
    final newRewards = {...state.unlockedRewards};
    for (final m in milestones) {
      if (newStreak >= m.days) {
        newRewards.add(m.bonusEmoji);
      }
    }

    state = StreakState(
      currentStreak: newStreak,
      lastActiveDate: today,
      unlockedRewards: newRewards,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_p}streak_current', newStreak);
    await prefs.setString('${_p}streak_last_date', today);
    await prefs.setStringList('${_p}streak_rewards', newRewards.toList());
  }

  /// Next milestone the user hasn't reached yet
  Milestone? get nextMilestone {
    for (final m in milestones) {
      if (state.currentStreak < m.days) return m;
    }
    return null;
  }

  /// Days remaining to next milestone
  int get daysToNext {
    final next = nextMilestone;
    if (next == null) return 0;
    return next.days - state.currentStreak;
  }
}
