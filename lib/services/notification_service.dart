import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'analytics_service.dart';

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

  // (title_emoji, body)
  final _cards = [
    // Тваринки — звуки
    ('🐱', 'Кішка каже МЯУ! Повтори разом із малюком!'),
    ('🐶', 'Собака каже ГАВ-ГАВ! Час для карток!'),
    ('🐮', 'Корова каже МУ-У! Що ще живе на фермі?'),
    ('🐷', 'Свинка каже ХРЮ! Пограйте у картки разом!'),
    ('🐸', 'Жабка каже КВА! Вивчаємо нові слова?'),
    ('🦁', 'Лев каже Р-Р-Р! Тренуємо звук Р сьогодні?'),
    ('🐔', 'Курочка каже КО-КО! Нові картки чекають!'),
    ('🦆', 'Качка каже КРЯ! 5 хвилин — і малюк вивчить нове слово!'),
    ('🐝', 'Бджілка каже Ж-Ж-Ж! Час гратись з картками!'),
    ('🚗', 'Машина каже БІ-БІ! Вивчаємо транспорт?'),
    // Ігри
    ('🔍', 'Знайди зайве! Чи впорається малюк сьогодні?'),
    ('🥁', 'КО-РО-ВА — три склади! Пограйте в «Рахуй склади»!'),
    ('↔️', 'Що протилежне до «ВЕЛИКИЙ»? Пограйте разом!'),
    ('🎤', 'Повтори за мною: РИБА, РАКЕТА, РУКА! Тренуємо вимову!'),
    ('🗂️', 'Розклади картки по купках! Нова гра чекає!'),
    ('🧠', 'Знайди пару! Тренуємо пам\'ять разом із малюком!'),
    ('🎧', 'Вгадай слово на слух! Вікторина вже відкрита!'),
    // Логопедичні — звуки
    ('🦁', 'Звук Р: РАК, РИБА, РАКЕТА! Тренуємо разом!'),
    ('🦋', 'Звук Л: ЛЕВ, ЛИМОН, ЛІТАК! Грайте зі звуком Л!'),
    ('🐍', 'Ш-Ш-Ш! Звук Ш: ШАПКА, МИШКА, МАШИНА!'),
    ('⭐', 'Звук С: СЛОН, СОНЦЕ, СОБАКА! Логопедичний пак відкрито!'),
    // Дії
    ('🏃', 'Бігти, стрибати, їсти — вивчаємо дії разом!'),
    ('💃', 'ТАНЦЮВАТИ, СПІВАТИ, МАЛЮВАТИ — нові слова-дії!'),
    ('🤗', 'Обіймати, цілувати, допомагати — вчимо добрі дії!'),
    // Протилежності
    ('↔️', 'ВЕЛИКИЙ і МАЛЕНЬКИЙ, ДЕНЬ і НІЧ — вчимо протилежності!'),
    ('🔥', 'ГАРЯЧИЙ чи ХОЛОДНИЙ? Відгадай протилежність!'),
    // Мотиваційні
    ('🔥', 'Продовжуйте серію! Малюк вже так добре знає слова!'),
    ('🌟', 'Щоденні 5 хвилин — і мовлення розвивається!'),
    ('⭐', 'Маленькі кроки щодня — великий результат!'),
    ('🏆', 'Ви вже так далеко! Продовжуйте займатись щодня!'),
    ('💪', 'Сьогодні — нове слово, завтра — впевнена мова!'),
  ];

  // EN mirror of _cards — same thematic proportions: 10 animal sounds,
  // 7 game invites, 4 speech sounds, 3 actions, 2 opposites, 5 motivational.
  final _cardsEn = [
    // Animal sounds
    ('🐱', 'Cats say MEOW! Say it together with your little one.'),
    ('🐶', 'Dogs say WOOF-WOOF! Card time with your little one.'),
    ('🐮', 'Cows say MOO! Who else lives on the farm?'),
    ('🐷', 'Pigs say OINK! Play a round of cards together.'),
    ('🐸', 'Frogs say RIBBIT! Ready for new words?'),
    ('🦁', 'Lions ROAR! A perfect day to learn the R sound.'),
    ('🐔', 'Hens say CLUCK! New cards are waiting.'),
    ('🦆', 'Ducks say QUACK! 5 minutes — one new word.'),
    ('🐝', 'Bees say BUZZ-Z-Z! Time to play with cards.'),
    ('🚗', 'Cars say BEEP-BEEP! Let\'s learn about transport.'),
    // Games
    ('🔍', 'Spot the odd one out! Can your little one do it today?'),
    ('🥁', 'BA-NA-NA — three syllables! Try the "Count Syllables" game.'),
    ('↔️', 'What\'s the opposite of BIG? Play together!'),
    ('🎤', 'Repeat after me: FISH, ROCKET, HAND. Practice speaking!'),
    ('🗂️', 'Sort the cards into piles! A new game is waiting.'),
    ('🧠', 'Find the pair! Train memory with your little one.'),
    ('🎧', 'Guess the word by sound! The quiz is open.'),
    // Speech sounds
    ('🦁', 'R sound: RABBIT, ROCKET, RING! Practice together.'),
    ('🦋', 'L sound: LION, LEMON, LEAF! Play with the L sound.'),
    ('🐍', 'SH-SH-SH! Sound SH: SHIP, FISH, SHOES!'),
    ('⭐', 'S sound: SUN, STAR, SNAKE! Speech pack is ready.'),
    // Actions
    ('🏃', 'Run, jump, eat — let\'s learn action words together.'),
    ('💃', 'DANCE, SING, DRAW — fresh action words to try.'),
    ('🤗', 'Hug, kiss, help — learn kind actions together.'),
    // Opposites
    ('↔️', 'BIG and SMALL, DAY and NIGHT — learning opposites.'),
    ('🔥', 'HOT or COLD? Guess the opposite!'),
    // Motivational
    ('🔥', 'Keep the streak going! Your little one knows so many words already.'),
    ('🌟', 'Daily 5 minutes — and speech keeps growing.'),
    ('⭐', 'Small steps every day — big results.'),
    ('🏆', 'You\'ve come so far! Keep practicing every day.'),
    ('💪', 'A new word today — confident speech tomorrow.'),
  ];

  // Win-back copy (T+48h inactivity).
  final _winBackUk = [
    ('👋', 'Скучили за картками! 3 хвилини — і нове слово вивчено.'),
    ('🎈', 'Час для карток! Повертайся до малюка сьогодні.'),
    ('📚', 'Нові картки чекають на малюка. Загляньте на 5 хвилин!'),
    ('🌈', 'Пам\'ятаєш своїх друзів-тваринок? Вони скучили!'),
    ('✨', 'Маленький перерив — і знову до нових слів!'),
    ('🧸', 'Картки сумують без малюка. Пограємо сьогодні?'),
    ('💬', 'Одне нове слово щодня — велика різниця за місяць.'),
  ];

  final _winBackEn = [
    ('👋', 'We miss you! 3 minutes of cards — one new word learned.'),
    ('🎈', 'Shall we learn a word with your little one today?'),
    ('📚', 'Your cards are waiting. 5 minutes makes a difference.'),
    ('🌈', 'Remember your animal friends? They miss you!'),
    ('✨', 'A small break — and back to new words together!'),
    ('🧸', 'The cards miss your little one. Shall we play today?'),
    ('💬', 'One new word a day — a big difference in a month.'),
  ];

  // Streak-save copy (day X+1 at 20:00). Must interpolate currentStreak.
  List<(String, String)> _streakSaveUk(int currentStreak) => [
        ('🔥', 'Серія $currentStreak днів — не втрачай! 5 хвилин на картки сьогодні?'),
        ('⭐', '$currentStreak днів поспіль — чудово! Одна картка — і серія жива.'),
        ('🎯', 'Малюк на серії $currentStreak днів. Трохи карток перед сном?'),
        ('🏅', 'Не розривай серію $currentStreak днів — одна картка рятує день.'),
      ];

  List<(String, String)> _streakSaveEn(int currentStreak) => [
        ('🔥', 'Keep the $currentStreak-day streak alive! Just 5 minutes of cards.'),
        ('⭐', '$currentStreak days in a row! One card keeps the streak going.'),
        ('🎯', 'Your little one is on a $currentStreak-day roll. A quick card before bed?'),
        ('🏅', 'Don\'t break your $currentStreak-day streak — one card saves the day.'),
      ];

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
    if (lang == 'en') {
      // Seasonal packs are UA-only content; skip EN users entirely.
      return;
    }
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
  Future<void> schedulePaywallReminderIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_paywallScheduledKey) ?? false) return;
    if (!(prefs.getBool(_enabledKey) ?? true)) return;

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
      '🎁 Подарунок для нової родини',
      '3 дні безкоштовно — відкрий 234 картки для розвитку мовлення',
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
    final random = Random();
    final deck = lang == 'en' ? _cardsEn : _cards;
    final card = deck[random.nextInt(deck.length)];
    final title = lang == 'en'
        ? '${card.$1} Card time!'
        : '${card.$1} Час для карток!';

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0,
      title,
      card.$2,
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

    final deck = lang == 'en' ? _winBackEn : _winBackUk;
    final card = deck[Random().nextInt(deck.length)];
    final title = lang == 'en'
        ? '${card.$1} Card time!'
        : '${card.$1} Час для карток!';

    final when = tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));

    await _plugin.zonedSchedule(
      _winBackId,
      title,
      card.$2,
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

    final deck = lang == 'en'
        ? _streakSaveEn(currentStreak)
        : _streakSaveUk(currentStreak);
    final card = deck[Random().nextInt(deck.length)];
    final title = lang == 'en'
        ? '${card.$1} Streak day $currentStreak'
        : '${card.$1} Серія $currentStreak днів';

    await _plugin.zonedSchedule(
      _streakSaveId,
      title,
      card.$2,
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
