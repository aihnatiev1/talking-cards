import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

/// Every child target answers a tap the same way. The haptic and the pop
/// go through platform channels that are inert in tests; what can be pinned
/// is that the squeeze starts on pointer-down, springs back on release,
/// and the tap is delivered — once.
void main() {
  const target = ValueKey('target');

  Widget host({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool reduceMotion = false,
  }) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: KidTap(
                onTap: onTap,
                onLongPress: onLongPress,
                child: const SizedBox(key: target, width: 80, height: 80),
              ),
            ),
          ),
        ),
      );

  double scaleOf(WidgetTester tester) => tester
      .widget<ScaleTransition>(find.descendant(
        of: find.byType(KidTap),
        matching: find.byType(ScaleTransition),
      ))
      .scale
      .value;

  testWidgets('the squeeze starts on tapDown, before the tap is delivered',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(target)));
    // The ticker's first frame stamps its start; the squeeze shows from the
    // next one — already moving, nothing delivered yet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(scaleOf(tester), lessThan(1.0));
    expect(taps, 0);

    await tester.pump(DT.pressDownMs);
    expect(scaleOf(tester), closeTo(DT.pressScale, 0.001));

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('release springs back past 1.0 and settles at exactly 1.0',
      (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(target)));
    await tester.pump();
    await tester.pump(DT.pressDownMs);
    await gesture.up();

    // Sample the spring: it must overshoot (the "bounce"), but only a hair.
    var peak = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      peak = peak < scaleOf(tester) ? scaleOf(tester) : peak;
    }
    expect(peak, greaterThan(1.0));
    expect(peak, lessThan(1.02));

    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1.0);
  });

  testWidgets('a tap calls back exactly once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.tap(find.byKey(target), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a cancelled press springs back without tapping',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(target)));
    await tester.pump();
    await tester.pump(DT.pressDownMs);
    expect(scaleOf(tester), closeTo(DT.pressScale, 0.001));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1.0);
    expect(taps, 0);
  });

  testWidgets('long-press is forwarded and the scale is released first',
      (tester) async {
    var longPresses = 0;
    var taps = 0;
    await tester.pumpWidget(
      host(onTap: () => taps++, onLongPress: () => longPresses++),
    );
    await tester.longPress(find.byKey(target), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(taps, 0);
    expect(scaleOf(tester), 1.0);
  });

  testWidgets('reduced motion: no scale, but the tap still lands',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++, reduceMotion: true));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(target)));
    await tester.pump();
    await tester.pump(DT.pressDownMs);
    expect(scaleOf(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1.0);
    expect(taps, 1);
  });

  testWidgets('without a callback it neither scales nor throws',
      (tester) async {
    await tester.pumpWidget(host());
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(target)));
    await tester.pump();
    await tester.pump(DT.pressDownMs);
    expect(scaleOf(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1.0);
    expect(tester.takeException(), isNull);
  });
}
