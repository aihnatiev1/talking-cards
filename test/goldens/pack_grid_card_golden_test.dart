import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/pack_grid_card.dart';

import '../helpers/motion.dart';

/// One pack tile in each of the states the grid can show: free, locked,
/// seasonal (badge + glow at rest), plus an in-progress bar.
///
/// Fixtures carry `image: null` so `CardImage` draws the pack emoji instead
/// of reaching for a webp — the golden pins the tile, not the artwork. The
/// tester has no emoji font, so the glyph itself renders as the engine's
/// missing-glyph box; that is deterministic and fine. The seasonal tile's
/// `AmbientLoop` shimmer sits at t = 0 under `useTestMotion()`.
void main() {
  useTestMotion();

  setUp(() {
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: true);
  });

  CardModel card(String id) => CardModel(
        id: id,
        sound: id,
        text: id,
        emoji: '🐶',
        colorBg: DT.surfaceWhite,
        colorAccent: DT.textPrimary,
        image: null,
        audioKey: id,
      );

  PackModel pack({required bool locked, String title = 'Тварини'}) =>
      PackModel(
        id: 'animals',
        title: title,
        icon: '🐶',
        color: DT.mint,
        isLocked: locked,
        isFree: !locked,
        cards: [for (var i = 0; i < 8; i++) card('c$i')],
      );

  const size = Size(200, 240);

  Future<void> pumpTile(WidgetTester tester, Widget tile) => pumpGolden(
        tester,
        Center(child: SizedBox(width: 160, height: 190, child: tile)),
        size: size,
        wrap: (host) => ProviderScope(child: host),
      );

  group('PackGridCard', () {
    testWidgets('free', (tester) async {
      await pumpTile(
        tester,
        PackGridCard(pack: pack(locked: false), onTap: () {}),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/pack_grid_card_free.png'),
      );
    });

    testWidgets('locked', (tester) async {
      await pumpTile(
        tester,
        PackGridCard(pack: pack(locked: true), onTap: () {}),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/pack_grid_card_locked.png'),
      );
    });

    testWidgets('seasonal', (tester) async {
      await pumpTile(
        tester,
        PackGridCard(
          pack: pack(locked: false, title: 'Зима'),
          onTap: () {},
          isSeasonal: true,
        ),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/pack_grid_card_seasonal.png'),
      );
    });

    testWidgets('in progress (3 of 8)', (tester) async {
      await pumpTile(
        tester,
        PackGridCard(pack: pack(locked: false), onTap: () {}, progress: 3),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/pack_grid_card_progress.png'),
      );
    });

    testWidgets('completed', (tester) async {
      await pumpTile(
        tester,
        PackGridCard(
          pack: pack(locked: false),
          onTap: () {},
          isCompleted: true,
          progress: 8,
        ),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/pack_grid_card_completed.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
