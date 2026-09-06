import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import 'game_stats_provider.dart';
import '../services/app_review_service.dart';

/// Single entry point for triggering the app-store review flow. Exposed as a
/// plain [Provider] (matching the repo's manual Riverpod style).
final appReviewControllerProvider = Provider<AppReviewController>(
  (ref) => AppReviewController(),
);

/// True when the family has never finished a game before. Read it BEFORE
/// `gameStatsProvider.record` — afterwards the answer is always false. While
/// stats are still loading this says false: no prompt is the safe default.
bool isFirstGame(WidgetRef ref) =>
    !(ref.read(gameStatsProvider).valueOrNull?.any((g) => g.plays > 0) ??
        true);

class AppReviewController {
  AppReviewController();

  /// Set when a first game finishes; spent when the game screen is gone.
  /// The ask must not land on the celebration dialog with a toddler holding
  /// the device — games_tab asks once the parent is back on the games list.
  bool _firstGameAskPending = false;

  void noteFirstGameFinished() => _firstGameAskPending = true;

  Future<void> askIfFirstGamePending() async {
    if (!_firstGameAskPending) return;
    _firstGameAskPending = false;
    await maybeRequestAfterWin('first_game');
  }

  /// At most one automatic ask per this window, whatever the trigger.
  static const _autoCooldown = Duration(days: 45);
  static const _lastAutoKey = 'review_auto_last_ms';

  /// Triggered by an explicit parent tap on the "Rate the app" action.
  ///
  /// Design rationale — the app has NO parental gate (the Parent Dashboard is
  /// reachable by a child via long-press on the About icon):
  ///  * It uses the OS-native, in-app review sheet, which is rate-limited by the
  ///    OS and never leaves the app — child-safe even on an accidental tap.
  ///  * We never navigate out to the external store listing.
  Future<void> requestReview() => _ask('parent_tap');

  /// Asks after a real win, and only after a real win.
  ///
  /// The US listing still shows "not enough ratings" — with no stars on the
  /// search card, impressions convert at ~0% no matter how good the keywords
  /// are. The only automatic ask used to be the very first pack completion,
  /// once per lifetime, which produced 3 prompts in a week. Streak milestones
  /// repeat (3/7/14/30 days) and land on a moment a parent is watching, so
  /// they carry the same "we're proud" tone without nagging: the local
  /// cooldown keeps it to one ask per 45 days on top of the OS quota.
  ///
  /// The first finished *game* joined the triggers on 2026-09-06: in 60 days
  /// no US user had ever seen a prompt — one completed a pack, none hit a
  /// streak — while a few do finish a game.
  Future<void> maybeRequestAfterWin(String trigger) async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastAutoKey);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(last) < _autoCooldown) return;
    }
    // Spend the cooldown only on an ask the OS actually dispatched — an
    // unavailable sheet must not block the next real moment for 45 days.
    if (await _ask(trigger)) {
      await prefs.setInt(_lastAutoKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<bool> _ask(String trigger) async {
    final requested = await AppReviewService.instance.requestReview();
    if (requested) {
      AnalyticsService.instance.logEvent('review_prompt_requested',
          parameters: {'trigger': trigger});
    }
    return requested;
  }
}
