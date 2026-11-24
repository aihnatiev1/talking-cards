import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;
import 'package:talking_cards/screens/home_screen.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/widgets/play_components.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapAction(WidgetTester tester, String title) async {
    final action = find.widgetWithText(PlayAction, title).first;
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await frames(tester);
  }

  testWidgets('real home and complete free animal lesson', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'welcome_shown': true,
      'whats_new_seen_v2_0': true,
      'notifications_permission_asked': true,
    });
    app.keepTestErrorHandlers = true;
    app.main();
    for (
      var i = 0;
      i < 150 && find.byType(HomeScreen).evaluate().isEmpty;
      i++
    ) {
      await frames(tester, 2);
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    await frames(tester, 20);
    await binding.takeScreenshot('01-home');
    await tapAction(tester, 'Грати');
    await binding.takeScreenshot('02-listen');
    for (final word in ['КОРОВА', 'КОТИК', 'СОБАЧКА']) {
      await tester.tap(find.text(word));
      await frames(tester, 35);
      expect(
        AudioService.instance.hasSound(
          {'КОРОВА': 'korova', 'КОТИК': 'kotik', 'СОБАЧКА': 'sobachka'}[word],
        ),
        isTrue,
      );
      await tapAction(tester, 'Далі');
    }
    await frames(tester, 20);
    await binding.takeScreenshot('03-find');
    for (final id in ['a03', 'a01', 'a02']) {
      final option = find.byKey(ValueKey('lesson-option-$id'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await frames(tester, 35);
      await tapAction(tester, 'Далі');
    }
    await tapAction(tester, 'Завершити');
    await binding.takeScreenshot('04-complete');
    await tapAction(tester, 'До мого світу');
    await frames(tester);
    await binding.takeScreenshot('05-world');
    expect(find.text('Торкнись друга й послухай'), findsOneWidget);
  });
}
