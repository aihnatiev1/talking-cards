import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'analytics_service.dart';
import 'locale_registry.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'notifications_enabled';
  static const _paywallReminderId = 999;
  static const _paywallScheduledKey = 'paywall_reminder_scheduled';
  static const _winBackId = 100;
  static const _streakSaveId = 101;
  static const paywallNotificationPayload = 'open_paywall';
  // Payload tags consumed by analytics on notification tap.
  static const _payloadDaily = 'daily';
  static const _payloadSeasonal = 'seasonal';
  static const _payloadWinBack = 'win_back';
  static const _payloadStreakSave = 'streak_save';

  /// Set true on cold start when the OS launched the app via the paywall
  /// reminder notification. Splash reads this and routes through paywall.
  bool launchedFromPaywallReminder = false;

  // ── Copy decks ──────────────────────────────────────────────────────────
  // All notification copy lives in assets/l10n/notifications_<lang>.json
  // (daily / winBack / streakSave / paywallReminder decks + title templates,
  // {streak} placeholder in streakSave). Content-equality with the legacy
  // hardcoded arrays is pinned in test/services/notification_decks_test.dart.

  Map<String, dynamic>? _decks;
  String? _decksLang;

  /// Loads (and caches) the deck manifest for [lang], falling back to the
  /// English file for locales without one, and to null when no asset is
  /// available at all (schedulers then skip silently).
  Future<Map<String, dynamic>?> _loadDecks(String lang) async {
    if (_decksLang == lang && _decks != null) return _decks;
    for (final candidate in [lang, 'en']) {
      try {
        final raw = await rootBundle
            .loadString('assets/l10n/notifications_$candidate.json');
        _decks = json.decode(raw) as Map<String, dynamic>;
        _decksLang = lang;
        return _decks;
      } catch (_) {
        // Try the next candidate.
      }
    }
    return null;
  }

  List<({String emoji, String body})> _deck(
      Map<String, dynamic> decks, String key) {
    return [
      for (final e in decks[key] as List<dynamic>? ?? const [])
        (
          emoji: (e as Map<String, dynamic>)['emoji'] as String? ?? '',
          body: e['body'] as String? ?? '',
        ),
    ];
  }

  Future<void> init({String lang = 'uk'}) async {
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload == paywallNotificationPayload) {
          launchedFromPaywallReminder = true;
        }
        if (resp.payload != null) {
          AnalyticsService.instance.logNotificationOpened(resp.payload!);
        }
      },
    );

    // Detect cold start via the paywall reminder so splash can route through
    // PaywallScreen on the way to home.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final coldPayload = launchDetails?.notificationResponse?.payload;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        coldPayload == paywallNotificationPayload) {
      launchedFromPaywallReminder = true;
    }
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        coldPayload != null) {
      AnalyticsService.instance.logNotificationOpened(coldPayload);
    }

    // Enable by default on first launch, then re-schedule if enabled
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey);
    if (enabled == null) {
      // First launch — enable and request permission
      await prefs.setBool(_enabledKey, true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _scheduleDailyNotification(lang: lang);
      await _scheduleSeasonalNotifications(lang: lang);
    } else if (enabled) {
      await _scheduleDailyNotification(lang: lang);
      await _scheduleSeasonalNotifications(lang: lang);
    }
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled, {String lang = 'uk'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      // Request permission on iOS
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _scheduleDailyNotification(lang: lang);
    } else {
      await _plugin.cancelAll();
    }
  }

  Future<void> _scheduleSeasonalNotifications({required String lang}) async {
    // Seasonal packs are UA-only content; the registry capability skips
    // every other locale (identical to the old `lang == 'en'` early return).
    if (!LocaleRegistry.instance.capabilities(lang).seasonalPacks) return;
    const seasons = [
      (id: 10, month: 12, day: 1,
       title: '🎄 Новорічний пак відкрився!',
       body: 'Вивчай зимові слова з Дідом Морозом 🎅'),
      (id: 11, month: 4, day: 1,
       title: '🐣 Великодній пак відкрився!',
       body: 'Весняні слова для найменших 🌸'),
      (id: 12, month: 6, day: 15,
       title: '☀️ Літній пак відкрився!',
       body: 'Час для літніх пригод! 🌊'),
      (id: 13, month: 10, day: 1,
       title: '🍂 Осінній пак відкрився!',
       body: 'Пізнавай осінь з новими картками 🎃'),
    ];

    final now = tz.TZDateTime.now(tz.local);
    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'seasonal_pack',
        'Сезонні паки',
        channelDescription: 'Сповіщення про нові сезонні паки',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (final season in seasons) {
      var scheduled =
          tz.TZDateTime(tz.local, now.year, season.month, season.day, 9, 0);
      if (scheduled.isBefore(now)) {
        scheduled = tz.TZDateTime(
            tz.local, now.year + 1, season.month, season.day, 9, 0);
      }
      await _plugin.zonedSchedule(
        season.id,
        season.title,
        season.body,
        scheduled,
        notifDetails,
        payload: _payloadSeasonal,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Schedules a one-time soft-paywall reminder 3 days after first launch.
  /// No-op if already scheduled (tracked via SharedPreferences) or if
  /// notifications are disabled. Cancelled when user becomes pro.
  ///
  /// Copy comes from the locale deck file — this fixes the old bug where
  /// the reminder was hardcoded in Ukrainian for every locale.
  Future<void> schedulePaywallReminderIfNeeded({String lang = 'uk'}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_paywallScheduledKey) ?? false) return;
    if (!(prefs.getBool(_enabledKey) ?? true)) return;

    final decks = await _loadDecks(lang);
    final reminders = decks?['paywallReminder'] as List<dynamic>? ?? const [];
    if (reminders.isEmpty) return;
    final reminder = reminders.first as Map<String, dynamic>;

    final scheduled =
        tz.TZDateTime.now(tz.local).add(const Duration(days: 3));
    // Aim for a parent-friendly hour (11:00) on day 3 instead of midnight.
    final atElevenAM = tz.TZDateTime(
      tz.local,
      scheduled.year,
      scheduled.month,
      scheduled.day,
      11,
    );

    await _plugin.zonedSchedule(
      _paywallReminderId,
      reminder['title'] as String? ?? '',
      reminder['body'] as String? ?? '',
      atElevenAM,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'paywall_reminder',
          'Пропозиції підписки',
          channelDescription: 'Періодичні пропозиції безкоштовного періоду',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: paywallNotificationPayload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    await prefs.setBool(_paywallScheduledKey, true);
  }

  /// Called when the user upgrades to pro — also locks future re-scheduling.
  Future<void> cancelPaywallReminder() async {
    await _plugin.cancel(_paywallReminderId);
    final prefs = await SharedPreferences.getInstance();
    // Keep the flag = true so we never reschedule for an existing paying user.
    await prefs.setBool(_paywallScheduledKey, true);
  }

  Future<void> _scheduleDailyNotification({required String lang}) async {
    // Preserve the paywall reminder when re-scheduling daily/seasonal notifs.
    await _plugin.cancel(0);
    final decks = await _loadDecks(lang);
    if (decks == null) return;
    final deck = _deck(decks, 'daily');
    if (deck.isEmpty) return;
    final card = deck[Random().nextInt(deck.length)];
    final title = '${card.emoji} ${decks['dailyTitle'] as String? ?? ''}';

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0,
      title,
      card.body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_card',
          'Щоденна картка',
          channelDescription: 'Нагадування про нові картки',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadDaily,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Win-back reminder fired 48h after the most recent app resume. Rescheduled
  /// on every resume, so an active user never sees it.
  Future<void> scheduleWinBack({required String lang}) async {
    await _plugin.cancel(_winBackId);
    if (!(await isEnabled)) return;

    final decks = await _loadDecks(lang);
    if (decks == null) return;
    final deck = _deck(decks, 'winBack');
    if (deck.isEmpty) return;
    final card = deck[Random().nextInt(deck.length)];
    final title = '${card.emoji} ${decks['dailyTitle'] as String? ?? ''}';

    final when = tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));

    await _plugin.zonedSchedule(
      _winBackId,
      title,
      card.body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'win_back',
          'We miss you',
          channelDescription: 'Reminder after 2 days of inactivity',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadWinBack,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Streak-save reminder at 20:00 tomorrow. Cancelled and rescheduled on
  /// every resume so it always reflects the latest streak value.
  Future<void> scheduleStreakSave({
    required int currentStreak,
    required String lang,
  }) async {
    await _plugin.cancel(_streakSaveId);
    if (!(await isEnabled)) return;
    if (currentStreak < 3) return;

    final now = tz.TZDateTime.now(tz.local);
    final when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 20);

    final decks = await _loadDecks(lang);
    if (decks == null) return;
    final deck = _deck(decks, 'streakSave');
    if (deck.isEmpty) return;
    final card = deck[Random().nextInt(deck.length)];
    final streakText = '$currentStreak';
    final titleTemplate = decks['streakSaveTitle'] as String? ?? '';
    final title =
        '${card.emoji} ${titleTemplate.replaceAll('{streak}', streakText)}';

    await _plugin.zonedSchedule(
      _streakSaveId,
      title,
      card.body.replaceAll('{streak}', streakText),
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_save',
          'Streak reminder',
          channelDescription: 'Reminder to keep the daily streak alive',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadStreakSave,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Called on every app resume to refresh engagement reminders.
  Future<void> refreshEngagement({
    required String lang,
    required int currentStreak,
  }) async {
    await scheduleWinBack(lang: lang);
    await scheduleStreakSave(currentStreak: currentStreak, lang: lang);
  }
}
