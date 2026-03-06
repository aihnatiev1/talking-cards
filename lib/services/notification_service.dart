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

  final _cards = [
    ('🐱', 'Кішка каже МЯУ!'),
    ('🐶', 'Собака каже ГАВ!'),
    ('🐮', 'Корова каже МУ-У!'),
    ('🐷', 'Свинка каже ХРЮ!'),
    ('🐸', 'Жабка каже КВА!'),
    ('🦁', 'Лев каже Р-Р-Р!'),
    ('🐔', 'Курочка каже КО-КО!'),
    ('🦆', 'Качка каже КРЯ!'),
    ('🐝', 'Бджілка каже Ж-Ж-Ж!'),
    ('🚗', 'Машина каже БІ-БІ!'),
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

    // Re-schedule if enabled
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledKey) == true) {
      await _scheduleDailyNotification();
    }
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
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
