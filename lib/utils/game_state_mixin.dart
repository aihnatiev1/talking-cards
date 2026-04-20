import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../services/analytics_service.dart';

/// Shared state + lifecycle for round-based game screens.
///
/// Each game screen mixes this in and overrides [gameId]. Defaults fit the
/// common "10 rounds, ⭐ score, quest = playQuiz, record to gameStats" flow.
/// Games that differ on any of these axes override:
///   * [maxRounds] — default 10
///   * [questTask] — default [QuestTask.playQuiz] (null = don't complete a task)
///   * [recordToStats] — default true (set false to skip gameStatsProvider.record)
mixin GameStateMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The analytics / stats key for this game.
  String get gameId;

  /// How many rounds before the game ends.
  int get maxRounds => 10;

  /// Daily-quest task to mark complete on finish. Set null to skip.
  QuestTask? get questTask => QuestTask.playQuiz;

  /// Whether to record the final score into [gameStatsProvider].
  bool get recordToStats => true;

  int score = 0;
  int roundsPlayed = 0;
  bool finished = false;

  /// Call from initState() AFTER super.initState(). Logs game_start.
  void startGame() {
    AnalyticsService.instance.logGameStart(gameId);
  }

  /// Increment the score (typically called after a correct answer).
  void scorePoint() => score++;

  /// Advance to the next round. Returns false if the game just ended
  /// (in which case [finished] is now true and completion hooks fired).
  bool nextRound() {
    roundsPlayed++;
    if (roundsPlayed > maxRounds) {
      _complete();
      return false;
    }
    return true;
  }

  /// Manual completion for games that don't end via [nextRound].
  /// Pass [finalScore] to override [score] before completion hooks fire.
  void completeGame({int? finalScore}) {
    if (finalScore != null) score = finalScore;
    _complete();
  }

  void _complete() {
    AnalyticsService.instance.logGameComplete(gameId, score);
    if (recordToStats) {
      ref.read(gameStatsProvider.notifier).record(gameId, score);
    }
    final task = questTask;
    if (task != null) {
      ref.read(dailyQuestProvider.notifier).completeTask(task);
    }
    if (mounted) setState(() => finished = true);
  }

  /// Reset for "play again" flows. Does not call [startGame] — the caller
  /// typically builds the first round afterwards.
  void resetGame() {
    setState(() {
      score = 0;
      roundsPlayed = 0;
      finished = false;
    });
  }
}
