import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/memory_match_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

import '../helpers/motion.dart';

/// Two rules of the redesign that used to be bugs
/// (docs/design/memory_match_redesign.md §4, §6):
///
///  * the board never asks for more pairs than the pool can fill — a pack
///    with three recorded cards used to deal three tiles while the counter
///    waited for six pairs, so the round could not be won;
///  * a tap on a card that is already face up (or already found) is never a
///    silent `return` — it repeats the word, which is the whole point of a
///    talking-cards app (CLAUDE.md rule 2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestMotion();

  final words = <String?>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    words.clear();
    AudioService.debugWordSink = words.add;
  });

  tearDown(() {
    AudioService.debugWordSink = null;
    FeedbackService.debugMute = false;
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

  PackModel packOf(int cards) => PackModel(
    id: 'animals',
    title: 'Animals',
    icon: '🐶',
    color: const Color(0xFF6C63FF),
    isLocked: false,
    isFree: true,
    cards: [for (var i = 0; i < cards; i++) card('c$i')],
  );

  Future<void> open(WidgetTester tester, PackModel pack, int? pairs) async {
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
  }

  Finder tiles() =>
      find.descendant(of: find.byType(GridView), matching: find.byType(KidTap));

  testWidgets('a small pack is dealt as many pairs as it can fill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Asked for six pairs, only three cards exist.
    await open(tester, packOf(3), 6);

    expect(tiles(), findsNWidgets(6));
    // The counter waits for three pairs, not six — the round is winnable.
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('a tap on a matched card says its word again', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, packOf(1), 1);
    expect(tiles(), findsNWidgets(2));

    await tester.tap(tiles().at(0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(tiles().at(1));
    await tester.pump(const Duration(milliseconds: 400));

    // Both halves of the only pair are found and stay on the board.
    expect(find.text('c0'), findsNWidgets(2));

    words.clear();
    await tester.tap(tiles().at(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      words,
      contains('c0'),
      reason: 'a matched card must answer a touch with its word',
    );
  });

  testWidgets('a mismatch lies back down by itself, and the board stays sane', (
    tester,
  ) async {
    // Full motion on purpose: the hold, the turn back and the word cue all
    // run at their real length here, and nothing may be left pending.
    MotionPolicy.debugOverride = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, packOf(2), 2);
    expect(tiles(), findsNWidgets(4));

    await tester.tap(tiles().at(0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(tiles().at(1));
    // Long enough for the hold (1200 ms at level 2) and the turn back.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    // Either the two were a pair and both stay up, or they were not and
    // the board is face down again — never one card left hanging.
    final faces = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Text),
    );
    expect(faces.evaluate().length, anyOf(0, 2));
  });
}
