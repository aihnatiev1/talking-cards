import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final instance = RemoteConfigService._();

  final _config = FirebaseRemoteConfig.instance;

  Future<void> init() async {
    await _config.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await _config.setDefaults({
      'paywall_title': 'Розблокуй всі картки!',
      'paywall_cta': 'Спробувати 3 дні безкоштовно',
      'paywall_show_trial': true,
      'free_preview_count': 5,
      'daily_notification_hour': 10,
      'show_card_of_day': true,
      'onboarding_version': 1,
    });

    try {
      await _config.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }
  }

  String get paywallTitle => _config.getString('paywall_title');
  String get paywallCta => _config.getString('paywall_cta');
  bool get paywallShowTrial => _config.getBool('paywall_show_trial');
  int get freePreviewCount => _config.getInt('free_preview_count');
  int get dailyNotificationHour => _config.getInt('daily_notification_hour');
  bool get showCardOfDay => _config.getBool('show_card_of_day');
  int get onboardingVersion => _config.getInt('onboarding_version');
}
