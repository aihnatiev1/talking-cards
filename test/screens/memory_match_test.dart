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
import 'package:talking_cards/services/memory_comfort_service.dart';
import 'package:talking_cards/utils/memory_tiers.dart';
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

  final nudges = <List<int>>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nudges.clear();
    MemoryMatchScreen.debugNudgeSink = (step, hints) =>
        nudges.add([step, hints]);
    MemoryComfortService.debugValue = null;
    FeedbackService.debugSounds.clear();
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
    FeedbackService.debugSounds.clear();
    MemoryMatchScreen.debugNudgeSink = null;
    MemoryComfortService.debugValue = null;
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

    // Level 2's first round opens with a face-up preview; a tap cuts it
    // short. Let the board actually be face down before playing, or the
    // four preview faces look like a stuck board.
    final faces = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Text),
    );
    for (var i = 0; i < 20 && faces.evaluate().isNotEmpty; i++) {
      await tester.tap(tiles().at(0));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(faces, findsNothing);

    await tester.tap(tiles().at(0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(tiles().at(1));

    // The hold now waits for the word to finish before turning the cards
    // back, so its length is not a fixed number to pump past. Walk the
    // clock until the board settles instead — a fixed 2.5 s was a race.
    var settled = false;
    for (var i = 0; i < 40 && !settled; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      settled = i >= 8 && faces.evaluate().length.isEven;
    }

    expect(tester.takeException(), isNull);
    // Cards only ever rest in pairs: both of a match stay up, a mismatch
    // goes back down together, and a finished round previews the next one
    // face up. An odd count means a card was left hanging mid-flip.
    expect(faces.evaluate().length.isEven, isTrue);
  });

  group('the two-step nudge', () {
    // Nothing has been touched for a while: the board asks once without a
    // sound ("there is something here"), then once with one, pointing at
    // the card that actually is the pair. Only the second step counts as
    // a hint — which is the number the confidence of the round reads, and
    // which was hard-wired to zero until this existed (§6).

    testWidgets('the invitation comes first and says nothing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await open(tester, packOf(2), 2);

      // Level 2 (the default profile): 5 s to the invitation.
      await tester.pump(const Duration(seconds: 5));
      expect(nudges, [
        [1, 0],
      ], reason: 'step 1 is silent and costs no hint');
      expect(FeedbackService.debugSounds, isNot(contains(KidSound.tick)));
    });

    testWidgets('the hint follows, sounds, and counts', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await open(tester, packOf(2), 2);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 4));
      expect(nudges.last, [2, 1], reason: 'step 2 is the hint of §6');
      expect(
        FeedbackService.debugSounds,
        contains(KidSound.tick),
        reason: 'the hint asks out loud — the quietest tick in the palette',
      );
      // And the number the ladder reads is no longer a constant zero.
      expect(
        MemoryTiers.confidenceOf(pairs: 2, misses: 0, hints: 2),
        RoundConfidence.struggle,
      );
    });

    testWidgets('a touch answers the board and restarts the clock', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await open(tester, packOf(2), 2);

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(tiles().at(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(nudges, isEmpty, reason: 'a child who is playing is not nudged');

      await tester.pump(const Duration(seconds: 5));
      expect(nudges.first, [1, 0]);
    });

    testWidgets('after three unanswered hints the board stops asking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await open(tester, packOf(2), 2);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 9));
      }
      final hints = nudges.where((n) => n.first == 2).length;
      expect(hints, 3, reason: 'a mascot that keeps poking is ignored');
    });

    testWidgets('the board settles under test motion', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await open(tester, packOf(2), 2);
      await tester.pump(const Duration(seconds: 9));
      // No nudge ticker is left running: under reduced motion the board
      // asks (the hint is information) but never moves.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a parent may pin the board from the progress strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, packOf(6), null);
    // The default profile is level 2: three pairs.
    expect(find.text('0/3'), findsOneWidget);

    await tester.longPress(find.byKey(MemoryMatchScreen.parentStripKey));
    await tester.pumpAndSettle();
    expect(find.text('Для батьків'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '4'));
    await tester.pumpAndSettle();
    expect(find.text('0/4'), findsOneWidget);
    expect(tiles(), findsNWidgets(8));
  });

  testWidgets('the session opens on the board that was calm last time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    MemoryComfortService.debugValue = 4;
    await open(tester, packOf(6), null);
    // The remembered tier arrives from storage a beat after the first
    // deal; an untouched board takes it.
    await tester.pumpAndSettle();
    expect(find.text('0/4'), findsOneWidget);
  });
}
