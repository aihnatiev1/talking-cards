import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // --- Card events ---

  Future<void> logCardView(String cardId, String packId) =>
      _analytics.logEvent(name: 'card_view', parameters: {
        'card_id': cardId,
        'pack_id': packId,
      });

  Future<void> logCardListen(String cardId) =>
      _analytics.logEvent(name: 'card_listen', parameters: {
        'card_id': cardId,
      });

  // --- Pack events ---

  Future<void> logPackOpen(String packId) =>
      _analytics.logEvent(name: 'pack_open', parameters: {
        'pack_id': packId,
      });

  Future<void> logPackComplete(String packId) =>
      _analytics.logEvent(name: 'pack_complete', parameters: {
        'pack_id': packId,
      });

  // --- Card of the day ---

  Future<void> logCardOfDayTap(String cardId) =>
      _analytics.logEvent(name: 'card_of_day_tap', parameters: {
        'card_id': cardId,
      });

  // --- Quiz events ---

  Future<void> logQuizStart() =>
      _analytics.logEvent(name: 'quiz_start');

  Future<void> logQuizComplete(int score, int total) =>
      _analytics.logEvent(name: 'quiz_complete', parameters: {
        'score': score,
        'total': total,
      });

  // --- Favorites ---

  Future<void> logFavoriteToggle(String cardId, bool added) =>
      _analytics.logEvent(name: 'favorite_toggle', parameters: {
        'card_id': cardId,
        'added': added.toString(),
      });

  // --- Paywall ---

  Future<void> logPaywallView(String source) =>
      _analytics.logEvent(name: 'paywall_view', parameters: {
        'source': source,
      });

  Future<void> logPurchaseStart(String productId) =>
      _analytics.logEvent(name: 'purchase_start', parameters: {
        'product_id': productId,
      });

  Future<void> logPurchaseSuccess(String productId) =>
      _analytics.logEvent(name: 'purchase_success', parameters: {
        'product_id': productId,
      });

  Future<void> logPurchaseRestore() =>
      _analytics.logEvent(name: 'purchase_restore');

  // --- Streak ---

  Future<void> logStreakMilestone(int days) =>
      _analytics.logEvent(name: 'streak_milestone', parameters: {
        'days': days,
      });

  // --- Share ---

  Future<void> logShareProgress() =>
      _analytics.logEvent(name: 'share_progress');

  // --- Onboarding ---

  Future<void> logOnboardingComplete() =>
      _analytics.logEvent(name: 'tutorial_complete');

  // --- Games ---

  Future<void> logGameStart(String gameId) =>
      _analytics.logEvent(name: 'game_start', parameters: {'game_id': gameId});

  Future<void> logGameComplete(String gameId, int score) =>
      _analytics.logEvent(name: 'game_complete', parameters: {
        'game_id': gameId,
        'score': score,
      });

  Future<void> logSoundFilterOpen(String letter) =>
      _analytics.logEvent(name: 'sound_filter_open', parameters: {
        'letter': letter,
      });

  /// Generic event logger for ad-hoc events (e.g. speech_attempt).
  Future<void> logEvent(String name,
          {Map<String, Object>? parameters}) =>
      _analytics.logEvent(name: name, parameters: parameters);
}
