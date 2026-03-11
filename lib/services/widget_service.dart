import 'package:home_widget/home_widget.dart';

import '../models/card_model.dart';

class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  static const _appGroupId = 'group.com.talkingcards.shared';
  static const _iOSWidgetName = 'CardOfDayWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<void> updateCardOfDay(CardModel card) async {
    final colorHex =
        '#${card.colorAccent.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

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
  }
}
