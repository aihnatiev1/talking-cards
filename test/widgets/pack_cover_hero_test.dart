import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/utils/kid_routes.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/card_image.dart';
import 'package:talking_cards/widgets/pack_cover_hero.dart';
import 'package:talking_cards/widgets/pack_grid_card.dart';

/// The shared element of ux-gap-audit G11: the pack's picture flies from
/// its tile on the home grid to the header of `CardsScreen`, and does it
/// exactly once — two live heroes under one tag is a `FlutterError`, and
/// this app would turn that into a fatal report (`main.dart` forwards
/// `FlutterError.onError` to Crashlytics).
void main() {
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

  final pack = PackModel(
    id: 'animals',
    title: 'Тварини',
    icon: '🐶',
    color: DT.mint,
    isLocked: false,
    isFree: true,
    cards: [for (var i = 0; i < 4; i++) card('c$i')],
  );

  /// Home tile → a stand-in for the `CardsScreen` header: the same widget
  /// the screen uses, at the size it uses it.
  Widget app() => ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  height: 190,
                  child: PackGridCard(
                    pack: pack,
                    onTap: () => Navigator.of(context).push(
                      KidRoutes.content(_HeaderScreen(pack: pack)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('one hero takes off from the tile and lands in the header',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.byType(PackCoverHero), findsOneWidget);

    await tester.tap(find.byType(PackGridCard));
    await tester.pump();
    // Mid-flight: one shuttle in the overlay, and neither end is drawing
    // its own picture (both are showing the tinted placeholder).
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(PackCoverHero.shuttleKeyFor(pack.id)), findsOneWidget);
    expect(find.byType(CardImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(PackCoverHero.shuttleKeyFor(pack.id)), findsNothing);
    expect(find.byType(PackCoverHero), findsOneWidget);
  });

  testWidgets('the flight survives art that has not arrived yet',
      (tester) async {
    // `ArtPending` / `ArtMissing` must not throw out of the shuttle: both
    // ends name the same picture, and CardImage answers with the emoji.
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: false);
    await tester.pumpWidget(app());
    await tester.tap(find.byType(PackGridCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('under MotionMode.test', () {
    setUp(() => MotionPolicy.debugOverride = MotionMode.test);
    tearDown(() => MotionPolicy.debugOverride = null);

    testWidgets('the hero is switched off and pumpAndSettle terminates',
        (tester) async {
      await tester.pumpWidget(app());
      final mode = tester.widget<HeroMode>(
        find.descendant(
          of: find.byType(PackCoverHero),
          matching: find.byType(HeroMode),
        ),
      );
      expect(mode.enabled, isFalse);

      await tester.tap(find.byType(PackGridCard));
      await tester.pumpAndSettle();
      expect(find.byKey(PackCoverHero.shuttleKeyFor(pack.id)), findsNothing);
      expect(find.byType(_HeaderScreen), findsOneWidget);
    });
  });
}

/// Stands in for `CardsScreen`'s `_PackCoverBadge` — private there, but the
/// hero end it builds is this exact shape.
class _HeaderScreen extends StatelessWidget {
  final PackModel pack;

  const _HeaderScreen({required this.pack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: PackCoverHero(
          pack: pack,
          borderRadius: BorderRadius.circular(10),
          transitionOnUserGestures: false,
          child: SizedBox(
            width: 40,
            height: 40,
            child: CardImage(
              name: PackCoverHero.coverOf(pack),
              fallbackEmoji: pack.icon,
            ),
          ),
        ),
      ),
    );
  }
}
