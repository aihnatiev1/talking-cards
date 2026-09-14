import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

import '../helpers/motion.dart';

/// The one press language for the kid zone, as pixels: a 120×120 tile at
/// rest and at the bottom of the squeeze (`DT.pressScale`, reached
/// `DT.pressDownMs` after the finger lands).
///
/// `KidTap` reads the OS reduce-motion flag directly rather than
/// `MotionPolicy`, so `useTestMotion()` freezes everything *around* the
/// tile while the press itself still animates — which is what lets the
/// mid-press frame be captured at a known scale.
void main() {
  useTestMotion();

  const tile = ValueKey('tile');

  Widget subject({VoidCallback? onTap}) => Center(
        child: KidTap(
          onTap: onTap,
          child: Container(
            key: tile,
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: DT.skyTint,
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(color: DT.sky.withValues(alpha: 0.35), width: 2),
              boxShadow: DT.shadowSoft(DT.sky),
            ),
            alignment: Alignment.center,
            child: Text(
              'Тап',
              style: DT.h1.copyWith(color: DT.onTint(DT.sky)),
            ),
          ),
        ),
      );

  group('KidTap', () {
    testWidgets('at rest', (tester) async {
      await pumpGolden(tester, subject(onTap: () {}),
          size: const Size(200, 200));
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/kid_tap_rest.png'),
      );
    });

    testWidgets('mid-press, 90 ms after the finger lands', (tester) async {
      await pumpGolden(tester, subject(onTap: () {}),
          size: const Size(200, 200));

      // onTap only — with no long-press recogniser in the arena the tap
      // wins on pointer-down and the squeeze starts on the same frame.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byKey(tile)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final scale = tester
          .widget<ScaleTransition>(find.descendant(
            of: find.byType(KidTap),
            matching: find.byType(ScaleTransition),
          ))
          .scale
          .value;
      expect(scale, closeTo(DT.pressScale, 0.001),
          reason: 'the golden must capture the bottom of the squeeze, '
              'not a frame on the way there');

      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/kid_tap_pressed.png'),
      );

      // Let the spring finish so no ticker outlives the test.
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('disabled (no onTap) renders identically to rest',
        (tester) async {
      await pumpGolden(tester, subject(), size: const Size(200, 200));
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/kid_tap_rest.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
