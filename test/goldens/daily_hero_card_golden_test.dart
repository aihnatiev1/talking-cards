import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';
import 'package:talking_cards/widgets/daily_hero_card.dart';

import '../helpers/motion.dart';

/// The home hero (ux-gap G5) in the three states a day passes through:
/// nothing done yet (hero breathes, first stone active), the hero's own
/// step done (check on the disc, one green stone), and everything done
/// (the "all done" row replaces the stones).
///
/// `image: null` so `CardImage` draws the emoji — the golden pins the card,
/// not the artwork; the tester has no emoji font, so the glyph is the
/// engine's missing-glyph box, which is deterministic. Bloom is a still
/// `idle` looking right at the play disc; `useTestMotion()` parks the
/// invite breath and the stone pulse at rest.
void main() {
  useTestMotion();

  setUp(() {
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
  });

  Widget mascot() => BloomMascot(
    size: DT.size.mascotCompanion,
    state: const BloomState.still(
      BloomEmotion.idle,
      lookAt: Alignment(1, -0.2),
    ),
  );

  DailyTask task(
    AppIcon icon,
    String label, {
    required bool done,
    bool active = false,
  }) => DailyTask(
    icon: icon,
    label: label,
    isDone: done,
    isActive: active,
    onTap: () {},
  );

  const size = Size(390, 420);

  Future<void> pumpHero(WidgetTester tester, Widget hero) => pumpGolden(
    tester,
    Padding(
      padding: const EdgeInsets.all(DT.sp16),
      child: Align(alignment: Alignment.topCenter, child: hero),
    ),
    size: size,
    wrap: (host) => ProviderScope(child: host),
  );

  testWidgets('tablet invitation with artwork', (tester) async {
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: DailyHeroCard(
            title: 'Протилежності',
            accent: Colors.purple,
            image: 'big',
            progress: .18,
            onHeroTap: () {},
            mascot: mascot(),
            tasks: [
              task(AppIcon.stepListen, 'Картка дня', done: true),
              task(AppIcon.stepQuest, 'Пригода дня', done: false),
            ],
            isEn: false,
          ),
        ),
      ),
      size: const Size(700, 400),
      wrap: (host) => ProviderScope(child: host),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('images/daily_hero_card_tablet.png'),
    );
  });

  group('DailyHeroCard', () {
    testWidgets('nothing done', (tester) async {
      await pumpHero(
        tester,
        DailyHeroCard(
          title: 'Кіт',
          accent: DT.coral,
          fallbackEmoji: '🐱',
          onHeroTap: () {},
          mascot: mascot(),
          tasks: [
            task(AppIcon.stepCards, 'Пак дня', done: false, active: true),
            task(AppIcon.stepQuest, 'Пригода дня', done: false),
          ],
          isEn: false,
        ),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/daily_hero_card_fresh.png'),
      );
    });

    testWidgets('one of three done (hero listened)', (tester) async {
      await pumpHero(
        tester,
        DailyHeroCard(
          title: 'Кіт',
          accent: DT.coral,
          fallbackEmoji: '🐱',
          heroDone: true,
          onHeroTap: () {},
          mascot: mascot(),
          tasks: [
            task(AppIcon.stepCards, 'Пак дня', done: true),
            task(AppIcon.stepQuest, 'Пригода дня', done: false, active: true),
          ],
          isEn: false,
        ),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/daily_hero_card_one_done.png'),
      );
    });

    testWidgets('all done', (tester) async {
      await pumpHero(
        tester,
        DailyHeroCard(
          title: 'Тварини',
          accent: DT.mint,
          fallbackEmoji: '🐶',
          progress: 5 / 8,
          heroDone: true,
          onHeroTap: () {},
          mascot: mascot(),
          tasks: [
            task(AppIcon.stepListen, 'Картка дня', done: true),
            task(AppIcon.stepQuest, 'Пригода дня', done: true),
          ],
          allDone: true,
          onAllDoneTap: () {},
          isEn: false,
        ),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/daily_hero_card_all_done.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
