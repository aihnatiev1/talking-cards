import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/onboarding_screen.dart';

/// Onboarding branches on the system locale: EN opens straight into the
/// magic moment (English installs churned on the keyboard page before ever
/// hearing a card), UA keeps name → age → magic.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOnboarding(WidgetTester tester, Locale locale) async {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: OnboardingScreen()),
    ));
    // The magic moment reads its starter cards from the asset bundle — real
    // I/O, so it needs runAsync. pumpAndSettle is out (mascot + spinner
    // animate forever), hence the hand-stepped frames.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 100)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('EN starts on the magic moment, without the name page',
      (tester) async {
    await pumpOnboarding(tester, const Locale('en'));

    expect(find.text('Tap the card to hear the word!'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Two steps only: magic moment + age.
    expect(find.text("Child's name (optional)"), findsNothing);
  });

  testWidgets('UA starts on the name page', (tester) async {
    await pumpOnboarding(tester, const Locale('uk'));

    expect(find.text('Знайомство'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Далі →'), findsOneWidget);
  });
}
