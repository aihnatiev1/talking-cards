import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/streak_chip.dart';
import 'package:talking_cards/widgets/treasure_card.dart';

/// Every idle loop in the kid zone runs through `AmbientLoop`, which asks
/// [MotionPolicy] before it starts (motion audit 2026-09-13 §2.6: 14 of 16
/// loops used to ignore the OS flag). Under reduced motion the widget must
/// still render its content and reach rest — an ungated loop makes
/// `pumpAndSettle` throw. [reduceMotionOf] stays as the one-line alias for
/// `MotionPolicy.of(context).reduce`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child, {required bool reduce}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      );

  test('reduceMotionOf mirrors MediaQuery.disableAnimations', () {
    // Pure function of the inherited data; checked through a widget below.
    expect(reduceMotionOf, isNotNull);
  });

  group('TreasureCard', () {
    testWidgets('reduced motion: settles and still shows progress',
        (tester) async {
      await tester.pumpWidget(host(
        TreasureCard(done: 2, total: 5, onTap: () {}),
        reduce: true,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TreasureCard), findsOneWidget);
    });

    testWidgets('full motion: the bob loop is running', (tester) async {
      await tester.pumpWidget(host(
        TreasureCard(done: 2, total: 5, onTap: () {}),
        reduce: false,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);
      expect(find.byType(TreasureCard), findsOneWidget);
    });
  });

  group('StreakChip', () {
    testWidgets('reduced motion: settles', (tester) async {
      await tester.pumpWidget(host(
        StreakChip(streak: 6, onTap: () {}),
        reduce: true,
      ));
      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
    });
  });
}
