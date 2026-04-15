import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'notifications_enabled';

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

  Future<void> init() async {
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
    await _plugin.initialize(settings);

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
      await _scheduleDailyNotification();
      await _scheduleSeasonalNotifications();
    } else if (enabled) {
      await _scheduleDailyNotification();
      await _scheduleSeasonalNotifications();
    }
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      // Request permission on iOS
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _scheduleDailyNotification();
    } else {
      await _plugin.cancelAll();
    }
  }

  Future<void> _scheduleSeasonalNotifications() async {
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _scheduleDailyNotification() async {
    await _plugin.cancelAll();
    final random = Random();
    final card = _cards[random.nextInt(_cards.length)];

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0,
      '${card.$1} Час для карток!',
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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
