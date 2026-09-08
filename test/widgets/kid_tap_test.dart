import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

/// Every child target answers a tap the same way. The haptic and the pop
/// go through platform channels that are inert in tests; what can be pinned
/// is that the press is shown and the tap is delivered — once.
void main() {
  Widget host({VoidCallback? onTap}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: KidTap(
              onTap: onTap,
              child: const SizedBox(
                key: ValueKey('target'),
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
      );

  testWidgets('press scales the child down and release restores it',
      (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('target'))));
    await tester.pump(DT.pressMs);
    final pressed = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(pressed.scale, DT.pressScale);

    await gesture.up();
    await tester.pump(DT.pressMs);
    final released = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(released.scale, 1.0);
  });

  testWidgets('a tap calls back exactly once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.tap(find.byKey(const ValueKey('target')));
    await tester.pump(DT.pressMs);
    expect(taps, 1);
  });

  testWidgets('without a callback it neither scales nor throws',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const ValueKey('target')));
    await tester.pump(DT.pressMs);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);
  });
}
