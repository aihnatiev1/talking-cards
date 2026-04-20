import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Analytics and silently no-ops when the SDK isn't
/// initialised (e.g. in unit/widget tests). Analytics must never crash
/// the app or test runner.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeLog(String name, [Map<String, Object>? params]) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) debugPrint('AnalyticsService: log "$name" error: $e');
    }
  }

  FirebaseAnalyticsObserver? get observer {
    final a = _analytics;
    return a == null ? null : FirebaseAnalyticsObserver(analytics: a);
  }

  // --- Card events ---

  Future<void> logCardView(String cardId, String packId) =>
      _safeLog('card_view', {'card_id': cardId, 'pack_id': packId});

  Future<void> logCardListen(String cardId) =>
      _safeLog('card_listen', {'card_id': cardId});

  // --- Pack events ---

  Future<void> logPackOpen(String packId) =>
      _safeLog('pack_open', {'pack_id': packId});

  Future<void> logPackComplete(String packId) =>
      _safeLog('pack_complete', {'pack_id': packId});

  // --- Card of the day ---

  Future<void> logCardOfDayTap(String cardId) =>
      _safeLog('card_of_day_tap', {'card_id': cardId});

  // --- Quiz events ---

  Future<void> logQuizStart() => _safeLog('quiz_start');

  Future<void> logQuizComplete(int score, int total) =>
      _safeLog('quiz_complete', {'score': score, 'total': total});

  // --- Favorites ---

  Future<void> logFavoriteToggle(String cardId, bool added) => _safeLog(
      'favorite_toggle', {'card_id': cardId, 'added': added.toString()});

  // --- Paywall ---

  Future<void> logPaywallView(String source) =>
      _safeLog('paywall_view', {'source': source});

  Future<void> logPurchaseStart(String productId) =>
      _safeLog('purchase_start', {'product_id': productId});

  Future<void> logPurchaseSuccess(String productId) =>
      _safeLog('purchase_success', {'product_id': productId});

  Future<void> logPurchaseRestore() => _safeLog('purchase_restore');

  // --- Streak ---

  Future<void> logStreakMilestone(int days) =>
      _safeLog('streak_milestone', {'days': days});

  // --- Share ---

  Future<void> logShareProgress() => _safeLog('share_progress');

  // --- Onboarding ---

  Future<void> logOnboardingComplete() => _safeLog('tutorial_complete');

  // --- Games ---

  Future<void> logGameStart(String gameId) =>
      _safeLog('game_start', {'game_id': gameId});

  Future<void> logGameComplete(String gameId, int score) =>
      _safeLog('game_complete', {'game_id': gameId, 'score': score});

  Future<void> logSoundFilterOpen(String letter) =>
      _safeLog('sound_filter_open', {'letter': letter});

  /// Generic event logger for ad-hoc events (e.g. speech_attempt).
  Future<void> logEvent(String name,
          {Map<String, Object>? parameters}) =>
      _safeLog(name, parameters);
}
