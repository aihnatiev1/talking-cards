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

  // `trial` carries what the screen promised at that moment — `offered`,
  // `spent` (the subscription group's introductory offer is used up) or
  // `none` (the one-time unlock). Without it the funnel cannot tell a
  // parent who backed out of a price from one who backed out of a promise
  // the native sheet refused, which is the whole question behind 1.3.8's
  // 21 cancels against 4 sales.
  Future<void> logPaywallView(String source,
          {String variant = 'generic', required String trial}) =>
      _safeLog('paywall_view',
          {'source': source, 'variant': variant, 'trial': trial});

  Future<void> logPaywallDismiss(String source) =>
      _safeLog('paywall_dismiss', {'source': source});

  Future<void> logPaywallProductSelect(String productId) =>
      _safeLog('paywall_product_select', {'product_id': productId});

  Future<void> logPurchaseStart(String productId, String trial) =>
      _safeLog('purchase_start', {'product_id': productId, 'trial': trial});

  Future<void> logPurchaseSuccess(String productId, String trial) =>
      _safeLog('purchase_success', {'product_id': productId, 'trial': trial});

  Future<void> logPurchaseCancel(String productId, String trial) =>
      _safeLog('purchase_cancel', {'product_id': productId, 'trial': trial});

  Future<void> logPurchaseError(String productId, String reason) =>
      _safeLog('purchase_error',
          {'product_id': productId, 'reason': reason});

  /// Ask to Buy / SCA: the sheet closed with neither a sale nor a cancel.
  /// Its own event, so a family waiting on a parent's approval no longer
  /// shows up as an error (or vanishes from the funnel altogether).
  Future<void> logPurchasePending(String productId) =>
      _safeLog('purchase_pending', {'product_id': productId});

  /// The store could not be reached from a screen that sells — the paywall
  /// then shows a retry instead of a Buy button that does nothing.
  Future<void> logStoreUnavailable(String where) =>
      _safeLog('store_unavailable', {'source': where});

  /// A locally-Pro device lost the entitlement on revalidation. Silent
  /// until now, and a family locked out of what they paid for is the most
  /// expensive bug this app can have.
  Future<void> logProRevoked(String reason) =>
      _safeLog('pro_revoked', {'reason': reason});

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

  // --- Startup health ---
  //
  // Added 2026-08-21: ~47 English-side installs in two weeks produced one
  // ~10s session each with zero card_view. We could not tell "app never
  // reached home" from "junk install that bounced", because nothing was
  // logged between session_start and the first card. These two events close
  // that gap: app_ready proves we got to the home screen, splash_timeout
  // names the service that blocked us.

  /// Fired once per cold start, when the home screen's first frame is up.
  ///
  /// `via_onboarding` separates a real cold start from a first install, where
  /// the elapsed time includes the parent tapping through onboarding.
  Future<void> logAppReady(int ms, {required bool viaOnboarding}) =>
      _safeLog('app_ready', {
        'ms': ms,
        'bucket': _msBucket(ms),
        'via_onboarding': viaOnboarding.toString(),
      });

  /// A splash init exceeded its budget and was abandoned.
  Future<void> logSplashTimeout(String service) =>
      _safeLog('splash_timeout', {'service': service});

  // --- Play Asset Delivery ---

  /// The paid-content pack changed state on Android: 'ready' (download
  /// landed), 'failed', 'waiting_for_wifi'. Without this the first PAD
  /// release would be unmeasurable — the emulator's fake Play never fails.
  Future<void> logContentPack(String status) =>
      _safeLog('content_pack', {'status': status});

  /// A paid pack was opened before its content arrived, so the child saw
  /// the "downloading cards" screen instead of cards.
  Future<void> logContentWait(String packId, String status) =>
      _safeLog('content_wait', {'pack_id': packId, 'status': status});

  static String _msBucket(int ms) {
    if (ms < 1500) return 'lt_1_5s';
    if (ms < 3000) return 'lt_3s';
    if (ms < 5000) return 'lt_5s';
    if (ms < 8000) return 'lt_8s';
    return 'gte_8s';
  }

  // --- Notifications ---

  Future<void> logNotificationOpened(String type) =>
      _safeLog('notification_opened', {'type': type});

  /// The in-app pre-prompt was shown instead of ambushing the parent with the
  /// OS dialog during startup.
  Future<void> logNotifOptInShown() => _safeLog('notif_optin_shown');

  /// `accepted` — the parent said yes in the pre-prompt; `granted` — what the
  /// OS dialog answered afterwards (false when they never got there).
  Future<void> logNotifOptInResult(
          {required bool accepted, required bool granted}) =>
      _safeLog('notif_optin_result', {
        'accepted': accepted.toString(),
        'granted': granted.toString(),
      });

  // --- User properties (for cohort slicing) ---

  Future<void> setLanguageProperty(String lang) =>
      _safeSetUserProperty('app_language', lang);

  Future<void> setAgeLevelProperty(int level) =>
      _safeSetUserProperty('age_level', level.toString());

  Future<void> setProProperty(bool isPro) =>
      _safeSetUserProperty('is_pro', isPro.toString());

  /// The paywall A/B bucket as a user property, so every event of that user
  /// — views, checkouts, sales — segments by it without threading the value
  /// through each call.
  Future<void> setPaywallDefaultPlanProperty(String plan) =>
      _safeSetUserProperty('paywall_default_plan', plan);

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
