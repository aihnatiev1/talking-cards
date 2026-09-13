import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/app_logo_mark.dart';
import 'package:talking_cards/widgets/paywall_hero_art.dart';

import '../helpers/motion.dart';

/// The drawn parent-zone art (ux-gap-audit 2026-09-13 G15).
///
/// The paywall banner, the About mark and the three benefit glyphs on one
/// sheet — the surfaces where the app asks a grown-up for money or trust
/// and therefore must not look like it borrowed its icons from the OS.
/// When the illustrator's `paywall_hero.webp` replaces the composition,
/// this PNG is where the swap is reviewed.
void main() {
  useTestMotion();

  group('parent-zone art', () {
    testWidgets('paywall banner, logo mark and benefit glyphs',
        (tester) async {
      await pumpGolden(
        tester,
        const _ParentArtSheet(),
        size: const Size(390, 420),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/parent_zone_art.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}

class _ParentArtSheet extends StatelessWidget {
  const _ParentArtSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.sp16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DT.sp20,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DT.brand.withValues(alpha: 0.18),
                  DT.sunBurst.withValues(alpha: 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(
                color: DT.brand.withValues(alpha: 0.30),
                width: 1.5,
              ),
            ),
            child: const PaywallHeroArt(semanticsLabel: 'Bloom and the cards'),
          ),
          const SizedBox(height: DT.sp16),
          Row(
            children: [
              const AppLogoMark(semanticsLabel: 'FirstWords Cards'),
              const SizedBox(width: DT.sp16),
              for (final icon in const [
                AppIcon.stepCards,
                AppIcon.sound,
                AppIcon.star,
                AppIcon.calendar,
                AppIcon.gameSort,
                AppIcon.gameSyllables,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: DT.sp8),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DT.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DT.rSm),
                    ),
                    child: AppIconView(icon, key: ValueKey(icon.name), size: 26),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
