import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;
import 'package:talking_cards/screens/home_screen.dart';
import 'package:talking_cards/screens/cards_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('home opens real packs and returns', (tester) async {
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
    await tester.tap(find.text('Тваринки').first);
    await frames(tester, 20);
    expect(find.byType(CardsScreen), findsOneWidget);
    await binding.takeScreenshot('02-pack');
    Navigator.of(tester.element(find.byType(CardsScreen))).pop();
    await frames(tester, 20);
    expect(find.byType(HomeScreen), findsOneWidget);
    await binding.takeScreenshot('03-home-return');
  });
}
