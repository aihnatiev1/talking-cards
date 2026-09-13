import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/card_reveal_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';

/// The daily-quest reveal used to run two `repeat()` controllers forever
/// (glow + confetti): three full-screen painters redrawing at 60 fps until
/// the parent pressed a button (motion audit 2026-09-13, P0). Now the glow
/// pulses three times and the confetti rains once, so the screen reaches
/// rest — which is exactly what `pumpAndSettle` asserts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: true);
  });

  const card = CardModel(
    id: 'cat',
    sound: 'КОТИК',
    text: 'Котик муркоче',
    emoji: '🐱',
    colorBg: Color(0xFFFFF4E0),
    colorAccent: Color(0xFFB07A3C),
  );
  final pack = PackModel(
    id: 'animals',
    title: 'Тваринки',
    icon: '🐾',
    color: const Color(0xFF4ECDC4),
    isLocked: false,
    isFree: true,
    cards: const [card],
  );

  Widget app({bool reduceMotion = false}) => ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child ?? const SizedBox(),
          ),
          home: CardRevealScreen(
            card: card,
            pack: pack,
            newTotal: 12,
            skipAnimation: true,
          ),
        ),
      );

  testWidgets('settled reveal comes to rest within a few seconds',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    // Glow: 3 × 1.6 s; confetti: one 5 s pass. Generous ceiling.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 12),
    );
    expect(find.text('КОТИК'), findsOneWidget);
  });

  testWidgets('reduced motion: no ambient animation at all', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pump();
    // Settles immediately: nothing is ticking.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );
    expect(find.text('КОТИК'), findsOneWidget);
  });
}
