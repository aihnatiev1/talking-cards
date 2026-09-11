import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/memory_match_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';

/// The board must fit the screen it is given.
///
/// SliverGridDelegateWithFixedCrossAxisCount derives tile height from tile
/// width, so on a wide screen the rows grew past the box — and with
/// NeverScrollableScrollPhysics they were clipped, not scrolled. On an 11"
/// iPad the bottom row was cut in half and those two cards could not be
/// tapped at all, which in a matching game means the round cannot be won.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: true);
  });

  CardModel card(String id) => CardModel(
        id: id,
        sound: id,
        text: id,
        emoji: '🐶',
        colorBg: const Color(0xFFFFFFFF),
        colorAccent: const Color(0xFF000000),
        image: null,
        audioKey: id,
      );

  final pack = PackModel(
    id: 'animals',
    title: 'Animals',
    icon: '🐶',
    color: const Color(0xFF6C63FF),
    isLocked: false,
    isFree: true,
    cards: [for (var i = 0; i < 8; i++) card('c$i')],
  );

  /// Every screen the app can be handed: phone portrait, phone landscape,
  /// 11" iPad both ways.
  const surfaces = {
    'phone portrait': Size(390, 844),
    'phone landscape': Size(844, 390),
    'iPad portrait': Size(834, 1194),
    'iPad landscape': Size(1194, 834),
  };

  for (final pairs in [3, 4]) {
    for (final entry in surfaces.entries) {
      testWidgets('$pairs pairs fit on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MemoryMatchScreen(
                pack: pack,
                cards: pack.cards,
                pairCount: pairs,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Every tile has to be reachable: a card clipped off the bottom
        // cannot be turned, and an unturnable card makes the game
        // unwinnable rather than merely ugly.
        final tiles = find.byType(GestureDetector);
        expect(tiles, findsWidgets);
        final screen = Rect.fromLTWH(0, 0, entry.value.width,
            entry.value.height);
        for (final element in tiles.evaluate()) {
          final box = element.renderObject as RenderBox?;
          if (box == null || !box.hasSize || box.size.isEmpty) continue;
          final topLeft = box.localToGlobal(Offset.zero);
          final rect = topLeft & box.size;
          expect(screen.contains(rect.center), isTrue,
              reason: 'a tappable tile centred outside the screen on '
                  '${entry.key}: $rect');
        }
      });
    }
  }
}
