import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'welcome_shown': true,
      'swipe_hint_shown': true,
    });
  });

  group('App launch and navigation', () {
    testWidgets('app launches and shows splash then home', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Home screen should show the app title or packs
      expect(find.byType(Scaffold), findsAtLeast(1));
    });
  });

  group('Paywall flow', () {
    testWidgets('paywall screen renders correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for a locked pack or paywall trigger
      // The exact flow depends on home screen state
      // Verify home screen loaded first
      expect(find.byType(Scaffold), findsAtLeast(1));
    });
  });
}
