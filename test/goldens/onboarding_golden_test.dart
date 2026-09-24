import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/onboarding_screen.dart';

import '../helpers/motion.dart';

void main() {
  useTestMotion();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('warm age picker with stable selection', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('uk');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await pumpGolden(tester, const OnboardingScreen(),
        wrap: (host) => ProviderScope(child: host));
    await tester.tap(find.text('Далі →'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(goldenKey),
        matchesGoldenFile('images/onboarding_age_uk.png'));
  });
}
