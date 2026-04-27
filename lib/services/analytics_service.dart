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

  Future<void> _safeSetUserProperty(String name, String? value) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserProperty(name: name, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsService: setUserProperty "$name" error: $e');
      }
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

  Future<void> logPaywallDismiss(String source) =>
      _safeLog('paywall_dismiss', {'source': source});

  Future<void> logPaywallProductSelect(String productId) =>
      _safeLog('paywall_product_select', {'product_id': productId});

  Future<void> logPurchaseStart(String productId) =>
      _safeLog('purchase_start', {'product_id': productId});

  Future<void> logPurchaseSuccess(String productId) =>
      _safeLog('purchase_success', {'product_id': productId});

  Future<void> logPurchaseCancel(String productId) =>
      _safeLog('purchase_cancel', {'product_id': productId});

  Future<void> logPurchaseError(String productId, String reason) =>
      _safeLog('purchase_error',
          {'product_id': productId, 'reason': reason});

  Future<void> logPurchaseRestore() => _safeLog('purchase_restore');

  // --- Streak ---

  Future<void> logStreakMilestone(int days) =>
      _safeLog('streak_milestone', {'days': days});

  // --- Share ---

  Future<void> logShareProgress() => _safeLog('share_progress');

  // --- Onboarding ---

  Future<void> logOnboardingStart() => _safeLog('onboarding_start');

  Future<void> logOnboardingLangSelected(String lang) =>
      _safeLog('onboarding_lang_selected', {'lang': lang});

  Future<void> logOnboardingNameEntered() =>
      _safeLog('onboarding_name_entered');

  Future<void> logOnboardingAgeSelected(int level) =>
      _safeLog('onboarding_age_selected', {'level': level});

  Future<void> logOnboardingMagicMomentStart() =>
      _safeLog('onboarding_magic_moment_start');

  Future<void> logOnboardingMagicMomentCardTap(int order) =>
      _safeLog('onboarding_magic_moment_card_tap', {'order': order});

  Future<void> logOnboardingMagicMomentComplete() =>
      _safeLog('onboarding_magic_moment_complete');

  Future<void> logOnboardingComplete() => _safeLog('tutorial_complete');

  // --- Home / Today's Plan ---

  Future<void> logContinueHeroTap(String packId) =>
      _safeLog('continue_hero_tap', {'pack_id': packId});

  Future<void> logTodayPlanStoneTap({
    required int stoneId,
    required bool wasDone,
    required bool wasActive,
  }) =>
      _safeLog('today_plan_stone_tap', {
        'stone_id': stoneId,
        'was_done': wasDone.toString(),
        'was_active': wasActive.toString(),
      });

  Future<void> logTodayPlanComplete() => _safeLog('today_plan_complete');

  Future<void> logCategorySwitch(String category) =>
      _safeLog('category_switch', {'category': category});

  // --- Notifications ---

  Future<void> logNotificationOpened(String type) =>
      _safeLog('notification_opened', {'type': type});

  // --- User properties (for cohort slicing) ---

  Future<void> setLanguageProperty(String lang) =>
      _safeSetUserProperty('app_language', lang);

  Future<void> setAgeLevelProperty(int level) =>
      _safeSetUserProperty('age_level', level.toString());

  Future<void> setProProperty(bool isPro) =>
      _safeSetUserProperty('is_pro', isPro.toString());

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
