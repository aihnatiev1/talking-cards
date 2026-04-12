import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Daily quest tasks the child can complete.
enum QuestTask {
  listenCardOfDay, // Listen to the card of the day
  viewCards3,      // View 3 cards in any pack
  playQuiz,        // Play the guess game (quiz or memory match)
  viewCards5,      // View 5 total cards (cumulative with viewCards3)
  reviewOldCard,   // Open the review pack or revisit any pack
  reviewSRSCards,  // Review 5+ SRS-due cards (bonus — does not block reward)
  speakWords,      // Say 3 words correctly via mic (bonus — does not block reward)
}

/// The 5 core tasks required to unlock the daily reward.
/// reviewSRSCards is bonus and never blocks the reward.
const _coreTasks = {
  QuestTask.listenCardOfDay,
  QuestTask.viewCards3,
  QuestTask.playQuiz,
  QuestTask.viewCards5,
  QuestTask.reviewOldCard,
};

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

  /// True when all 5 core tasks are done (reviewSRSCards does not count).
  bool get allDone => _coreTasks.every(completed.contains);

  /// Progress through core tasks only (used by the quest map UI).
  int get doneCount => completed.where(_coreTasks.contains).length;
  int get totalCount => _coreTasks.length; // always 5

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

  String get _p => ProfileService.prefix;
  String get _kDate => '$_p$_keyDate';
  String get _kTasks => '$_p$_keyTasks';
  String get _kReward => '$_p$_keyReward';
  String get _kViews => '$_p$_keyViews';
  String get _kRewardCard => '$_p$_keyRewardCard';
  String get _kRewardPack => '$_p$_keyRewardPack';

  int _viewsToday = 0;
  int _srsReviewsToday = 0;
  int _speechCorrectToday = 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kDate) ?? '';
    final today = _today();

    if (savedDate != today) {
      // New day — reset quest
      await prefs.setString(_kDate, today);
      await prefs.setStringList(_kTasks, []);
      await prefs.setBool(_kReward, false);
      await prefs.setInt(_kViews, 0);
      await prefs.remove(_kRewardCard);
      await prefs.remove(_kRewardPack);
      _viewsToday = 0;
      state = DailyQuestState(date: today);
      return;
    }

    // Same day — restore progress
    final taskNames = prefs.getStringList(_kTasks) ?? [];
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
    final rewardClaimed = prefs.getBool(_kReward) ?? false;
    _viewsToday = prefs.getInt(_kViews) ?? 0;

    state = DailyQuestState(
      date: today,
      completed: completed,
      rewardClaimed: rewardClaimed,
      rewardCardId: prefs.getString(_kRewardCard),
      rewardPackId: prefs.getString(_kRewardPack),
    );
  }

  Future<void> completeTask(QuestTask task) async {
    if (state.completed.contains(task)) return;
    final newCompleted = {...state.completed, task};
    state = state.copyWith(completed: newCompleted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kTasks,
      newCompleted.map((t) => t.name).toList(),
    );
  }

  /// Call when a card is viewed. Auto-completes viewCards3 and viewCards5.
  Future<void> recordCardView() async {
    _viewsToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kViews, _viewsToday);

    if (_viewsToday >= 3) await completeTask(QuestTask.viewCards3);
    if (_viewsToday >= 5) await completeTask(QuestTask.viewCards5);
  }

  /// Call each time a card is reviewed in the SRS session.
  /// Completes the bonus [QuestTask.reviewSRSCards] after 5 reviews.
  Future<void> recordSrsReview() async {
    _srsReviewsToday++;
    if (_srsReviewsToday >= 5) {
      await completeTask(QuestTask.reviewSRSCards);
    }
  }

  /// Call each time the child correctly pronounces a word via speech recognition.
  /// Completes the bonus [QuestTask.speakWords] after 3 correct words.
  Future<void> recordSpeechCorrect() async {
    _speechCorrectToday++;
    if (_speechCorrectToday >= 3) {
      await completeTask(QuestTask.speakWords);
    }
  }

  Future<void> claimReward({String? cardId, String? packId}) async {
    state = state.copyWith(
      rewardClaimed: true,
      rewardCardId: cardId,
      rewardPackId: packId,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReward, true);
    if (cardId != null) await prefs.setString(_kRewardCard, cardId);
    if (packId != null) await prefs.setString(_kRewardPack, packId);
  }
}
