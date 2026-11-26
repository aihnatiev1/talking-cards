import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

class StreakState {
  final int currentStreak;
  final String lastActiveDate;
  final Set<String> unlockedRewards;

  /// Milestone emojis the user has already seen the celebration overlay for.
  /// Used to fire `pendingCelebration` exactly once per new milestone.
  final Set<String> celebratedRewards;

  const StreakState({
    this.currentStreak = 0,
    this.lastActiveDate = '',
    this.unlockedRewards = const {},
    this.celebratedRewards = const {},
  });

  /// What the parent screens print for the rewards: the guests' emoji, not
  /// the old sticker keys the rewards are stored under.
  Set<String> get badges => {
    for (final m in milestones)
      if (unlockedRewards.contains(m.id)) m.badge,
  };

  StreakState copyWith({
    int? currentStreak,
    String? lastActiveDate,
    Set<String>? unlockedRewards,
    Set<String>? celebratedRewards,
  }) => StreakState(
    currentStreak: currentStreak ?? this.currentStreak,
    lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    unlockedRewards: unlockedRewards ?? this.unlockedRewards,
    celebratedRewards: celebratedRewards ?? this.celebratedRewards,
  );
}

/// One streak milestone: the day count that earns it, the farm guest it
/// brings and its name in both languages.
///
/// [id] is the persisted key. It stays the old sticker emoji because it is
/// what is already in `SharedPreferences` under `streak_rewards` for every
/// installed user: a child who had the unicorn now has the hedgehog.
/// [badge] is what the celebration prints.
///
/// The stickers were a dead end — a picture that hopped and played a note.
/// A guest comes to the farm: it says its word, the child puts it where it
/// likes, and it can be asked for in a riddle when it has a voice.
class Milestone {
  final int days;
  final String id;

  /// The farm animal it brings (`assets/images/friends/<guest>.webp`).
  final String guest;
  final String badge;
  final String label;
  final String labelEn;

  const Milestone(
    this.days,
    this.id,
    this.guest,
    this.badge,
    this.label,
    this.labelEn,
  );

  /// The guest's name in [isEn]'s language — the one word of text the
  /// album shows under it.
  String name(bool isEn) => isEn ? labelEn : label;
}

const milestones = [
  Milestone(3, '🦄', 'hedgehog', '🦔', 'Їжачок', 'Hedgehog'),
  Milestone(7, '🐉', 'fox', '🦊', 'Лисиця', 'Fox'),
  Milestone(14, '🌈', 'bear', '🐻', 'Ведмідь', 'Bear'),
  Milestone(30, '🦋', 'squirrel', '🐿️', 'Білочка', 'Squirrel'),
];

/// Testing builds (`--dart-define=UNLOCK_ALL=true`) have every guest.
const _unlockAll = bool.fromEnvironment('UNLOCK_ALL');

/// The farm guests this streak has brought.
Set<String> farmGuestsOf(StreakState streak) => {
  for (final m in milestones)
    if (_unlockAll || streak.unlockedRewards.contains(m.id)) m.guest,
};

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>(
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
    final celebrated = (prefs.getStringList('${_p}streak_celebrated') ?? [])
        .toSet();
    state = StreakState(
      currentStreak: streak,
      lastActiveDate: lastDate,
      unlockedRewards: rewards,
      celebratedRewards: celebrated,
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
        newRewards.add(m.id);
      }
    }

    state = state.copyWith(
      currentStreak: newStreak,
      lastActiveDate: today,
      unlockedRewards: newRewards,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_p}streak_current', newStreak);
    await prefs.setString('${_p}streak_last_date', today);
    await prefs.setStringList('${_p}streak_rewards', newRewards.toList());
  }

  /// Highest unlocked milestone the user hasn't seen the celebration for yet.
  /// Returns null when nothing pending.
  Milestone? get pendingCelebration {
    for (final m in milestones.reversed) {
      if (state.unlockedRewards.contains(m.id) &&
          !state.celebratedRewards.contains(m.id)) {
        return m;
      }
    }
    return null;
  }

  Future<void> markCelebrated(String emoji) async {
    if (state.celebratedRewards.contains(emoji)) return;
    final next = {...state.celebratedRewards, emoji};
    state = state.copyWith(celebratedRewards: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_p}streak_celebrated', next.toList());
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
