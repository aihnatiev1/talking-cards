import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/card_model.dart';

class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  static const _appGroupId = 'group.com.talkingcards.shared';
  static const _iOSWidgetName = 'CardOfDayWidget';

  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      if (kDebugMode) debugPrint('WidgetService.init: $e');
    }
  }

  /// Pushes Card-of-Day data to the OS home-screen widget.
  ///
  /// Wrapped in try/catch because Android requires a native AppWidgetProvider
  /// class with the same name that isn't registered in this build — invoking
  /// `HomeWidget.updateWidget` raises a `ClassNotFoundException` we don't care
  /// about (the widget is opt-in for users who add it to their home screen).
  Future<void> updateCardOfDay(CardModel card) async {
    final colorHex =
        '#${card.colorAccent.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    try {
      await Future.wait([
        HomeWidget.saveWidgetData('cotd_emoji', card.emoji),
        HomeWidget.saveWidgetData('cotd_sound', card.sound),
        HomeWidget.saveWidgetData('cotd_text', card.text),
        HomeWidget.saveWidgetData('cotd_color', colorHex),
      ]);

      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: 'CardOfDayWidget',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('WidgetService.updateCardOfDay: $e');
    }
  }
}
