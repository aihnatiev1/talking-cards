import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/widgets/card_image.dart';
import 'package:talking_cards/widgets/reward_pack_picker.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  const first = CardModel(
    id: 'cat',
    sound: 'Кіт',
    text: '',
    emoji: '',
    image: 'cat',
    colorBg: Colors.white,
    colorAccent: Colors.orange,
  );
  const next = CardModel(
    id: 'dog',
    sound: 'Песик',
    text: '',
    emoji: '',
    image: 'dog',
    colorBg: Colors.white,
    colorAccent: Colors.teal,
  );
  const pack = PackModel(
    id: 'animals',
    title: 'Тварини та їхні маленькі дитинчата',
    icon: '',
    color: Colors.teal,
    isLocked: true,
    isFree: false,
    freePreviewCountOverride: 1,
    cards: [first, next],
  );
  const other = PackModel(
    id: 'friends',
    title: 'Наші друзі',
    icon: '',
    color: Colors.deepPurple,
    isLocked: true,
    isFree: false,
    freePreviewCountOverride: 0,
    cards: [first],
  );

  setUp(
    () => AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    ),
  );

  for (final width in [280.0, 390.0, 834.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('reward choices fit $width with text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var picks = 0;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: RewardPackPicker(
                      packs: const [pack, other],
                      bonusCards: const {},
                      isEn: false,
                      onPick: (_) => picks++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widgetList<CardImage>(find.byType(CardImage)).first.name,
          'dog',
        );
        final a = tester.getRect(
          find.byKey(const ValueKey('reward-option-animals')),
        );
        final b = tester.getRect(
          find.byKey(const ValueKey('reward-option-friends')),
        );
        expect(a.overlaps(b), isFalse);
        expect(a.left, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(width));
        await tester.ensureVisible(find.text(pack.title));
        await tester.tap(find.text(pack.title));
        await tester.tap(find.text(pack.title));
        await tester.pumpAndSettle();
        expect(picks, 1);
      });
    }
  }

  testWidgets('reward choice preview', (tester) async {
    await pumpGolden(
      tester,
      SingleChildScrollView(
        child: RewardPackPicker(
          packs: const [pack, other],
          bonusCards: const {},
          isEn: false,
          onPick: (_) {},
        ),
      ),
      wrap: (host) => ProviderScope(child: host),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('../goldens/images/reward_pack_picker.png'),
    );
  }, skip: !Platform.isMacOS);
}
