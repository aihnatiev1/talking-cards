import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily quest tasks the child can complete.
enum QuestTask {
  listenCardOfDay, // Listen to the card of the day
  viewCards3,      // View 3 cards in any pack
  playQuiz,        // Play the guess game
  viewCards5,      // View 5 total cards (cumulative with viewCards3)
  reviewOldCard,   // Open the review pack or revisit any pack
}

class DailyQuestState {
  final String date; // YYYY-MM-DD
  final Set<QuestTask> completed;
  final bool rewardClaimed;
  final String? rewardCardId;
  final String? rewardPackId;

  const DailyQuestState({
    required this.date,
    this.completed = const {},
    this.rewardClaimed = false,
    this.rewardCardId,
    this.rewardPackId,
  });

  bool get allDone => completed.length == QuestTask.values.length;
  int get doneCount => completed.length;
  int get totalCount => QuestTask.values.length;

  DailyQuestState copyWith({
    String? date,
    Set<QuestTask>? completed,
    bool? rewardClaimed,
    String? rewardCardId,
    String? rewardPackId,
  }) {
    return DailyQuestState(
      date: date ?? this.date,
      completed: completed ?? this.completed,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      rewardCardId: rewardCardId ?? this.rewardCardId,
      rewardPackId: rewardPackId ?? this.rewardPackId,
    );
  }
}

final dailyQuestProvider =
    StateNotifierProvider<DailyQuestNotifier, DailyQuestState>(
  (ref) => DailyQuestNotifier(),
);

class DailyQuestNotifier extends StateNotifier<DailyQuestState> {
  DailyQuestNotifier() : super(DailyQuestState(date: _today())) {
    _load();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static const _keyDate = 'quest_date';
  static const _keyTasks = 'quest_tasks';
  static const _keyReward = 'quest_reward_claimed';
  static const _keyViews = 'quest_views_today';
  static const _keyRewardCard = 'quest_reward_card_id';
  static const _keyRewardPack = 'quest_reward_pack_id';

  int _viewsToday = 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate) ?? '';
    final today = _today();

    if (savedDate != today) {
      // New day — reset quest
      await prefs.setString(_keyDate, today);
      await prefs.setStringList(_keyTasks, []);
      await prefs.setBool(_keyReward, false);
      await prefs.setInt(_keyViews, 0);
      await prefs.remove(_keyRewardCard);
      await prefs.remove(_keyRewardPack);
      _viewsToday = 0;
      state = DailyQuestState(date: today);
      return;
    }

    // Same day — restore progress
    final taskNames = prefs.getStringList(_keyTasks) ?? [];
    final completed = taskNames
        .map((name) {
          try {
            return QuestTask.values.byName(name);
          } catch (_) {
            return null;
          }
        })
        .whereType<QuestTask>()
        .toSet();
    final rewardClaimed = prefs.getBool(_keyReward) ?? false;
    _viewsToday = prefs.getInt(_keyViews) ?? 0;

    state = DailyQuestState(
      date: today,
      completed: completed,
      rewardClaimed: rewardClaimed,
      rewardCardId: prefs.getString(_keyRewardCard),
      rewardPackId: prefs.getString(_keyRewardPack),
    );
  }

  Future<void> completeTask(QuestTask task) async {
    if (state.completed.contains(task)) return;
    final newCompleted = {...state.completed, task};
    state = state.copyWith(completed: newCompleted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyTasks,
      newCompleted.map((t) => t.name).toList(),
    );
  }

  /// Call when a card is viewed. Auto-completes viewCards3 and viewCards5.
  Future<void> recordCardView() async {
    _viewsToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyViews, _viewsToday);

    if (_viewsToday >= 3) await completeTask(QuestTask.viewCards3);
    if (_viewsToday >= 5) await completeTask(QuestTask.viewCards5);
  }

  Future<void> claimReward({String? cardId, String? packId}) async {
    state = state.copyWith(
      rewardClaimed: true,
      rewardCardId: cardId,
      rewardPackId: packId,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReward, true);
    if (cardId != null) await prefs.setString(_keyRewardCard, cardId);
    if (packId != null) await prefs.setString(_keyRewardPack, packId);
  }
}
