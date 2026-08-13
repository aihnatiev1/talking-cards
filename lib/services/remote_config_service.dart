import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final instance = RemoteConfigService._();

  static const Map<String, Object> _defaults = {
    'paywall_title': 'Розблокуй всі картки!',
    'paywall_cta': 'Спробувати 3 дні безкоштовно',
    'paywall_show_trial': true,
    'free_preview_count': 5,
    'daily_notification_hour': 10,
    'show_card_of_day': true,
    'onboarding_version': 1,
    // A/B lever: paywall right after onboarding vs first-lock-touch only.
    'show_onboarding_paywall': true,
  };

  FirebaseRemoteConfig? _cached;

  /// Null when Firebase isn't initialized (widget tests, or a failed
  /// Firebase init on a broken first launch) — getters then serve
  /// [_defaults] instead of throwing from inside build().
  FirebaseRemoteConfig? get _config {
    try {
      return _cached ??= FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    final config = _config;
    if (config == null) return;
    await config.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await config.setDefaults(_defaults);

    try {
      await config.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }
  }

  String _getString(String key) {
    try {
      return _config?.getString(key) ?? _defaults[key]! as String;
    } catch (_) {
      return _defaults[key]! as String;
    }
  }

  bool _getBool(String key) {
    try {
      return _config?.getBool(key) ?? _defaults[key]! as bool;
    } catch (_) {
      return _defaults[key]! as bool;
    }
  }

  int _getInt(String key) {
    try {
      return _config?.getInt(key) ?? _defaults[key]! as int;
    } catch (_) {
      return _defaults[key]! as int;
    }
  }

  String get paywallTitle => _getString('paywall_title');
  String get paywallCta => _getString('paywall_cta');
  bool get paywallShowTrial => _getBool('paywall_show_trial');
  int get freePreviewCount => _getInt('free_preview_count');
  int get dailyNotificationHour => _getInt('daily_notification_hour');
  bool get showCardOfDay => _getBool('show_card_of_day');
  int get onboardingVersion => _getInt('onboarding_version');
  bool get showOnboardingPaywall => _getBool('show_onboarding_paywall');
}
