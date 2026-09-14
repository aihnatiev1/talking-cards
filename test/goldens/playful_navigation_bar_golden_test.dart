import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/playful_navigation_bar.dart';

import '../helpers/motion.dart';

/// The toy shelf at 390 wide, one golden per selected tab. The selected
/// button's tint, lift and label ink are the whole design; a regression in
/// any of the three is a different PNG.
///
/// The bar's `AnimatedContainer`/`AnimatedSlide` read `reduceMotionOf`,
/// which folds in `MotionPolicy.debugOverride`, so under `useTestMotion()`
/// the selected state is drawn at its end pose on the first frame.
void main() {
  useTestMotion();

  const size = Size(390, 120);

  group('PlayfulNavigationBar', () {
    for (var i = 0; i < 3; i++) {
      testWidgets('tab $i selected (uk)', (tester) async {
        await pumpGolden(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: PlayfulNavigationBar(
              selectedIndex: i,
              onSelected: (_) {},
              isEn: false,
            ),
          ),
          size: size,
        );
        await expectLater(
          find.byKey(goldenKey),
          matchesGoldenFile('images/playful_navigation_bar_tab_$i.png'),
        );
      });
    }

    testWidgets('English labels, tab 0 selected', (tester) async {
      await pumpGolden(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: PlayfulNavigationBar(
            selectedIndex: 0,
            onSelected: (_) {},
            isEn: true,
          ),
        ),
        size: size,
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/playful_navigation_bar_en.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
