import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/screens/repeat_game_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/kid_screen.dart';

import '../helpers/motion.dart';

/// «Повтори за мною» is an honest game for two (experience audit §21).
///
/// The screen wore a microphone and asked the grown-up for a verdict. A
/// microphone promises that something is listening to the child's
/// pronunciation and judging it — nothing in this app listens. So the
/// header says who is playing, the two pills are supportive rather than
/// right/wrong, and a set is short enough to finish — both the first one
/// and the one after «Ще раз».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestMotion();

  setUp(() {
    debugResetKidOverlayQueue();
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
    FeedbackService.debugMute = true;
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
  });

  CardModel card(String id) => CardModel(
    id: id,
    sound: 'СЛОВО $id',
    text: 'text $id',
    emoji: '🐶',
    colorBg: const Color(0xFFFFFFFF),
    colorAccent: const Color(0xFF000000),
    audioKey: id,
  );

  /// Twelve words available — the set must still be short.
  List<CardModel> deck() => [for (var i = 0; i < 12; i++) card('w$i')];

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: RepeatGameScreen(cards: deck())),
      ),
    );
    // The entry voice line and the gap before the first word.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets every pending gap (voice cue, card exit, praise hold) run out, so
  /// a test never ends on a live timer.
  Future<void> settleGaps(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Taps «Вийшло!» until the celebration shows, counting the words.
  /// Returns how many words the set asked for.
  Future<int> playSet(WidgetTester tester, {int limit = 12}) async {
    var words = 0;
    for (var i = 0; i < limit; i++) {
      // The celebration sits over the game screen, whose pills are still
      // in the tree — the set has ended when it appears.
      if (find.text('Ще раз').evaluate().isNotEmpty) break;
      final gotIt = find.text('Вийшло!');
      if (gotIt.evaluate().isEmpty) break;
      await tester.tap(gotIt);
      words++;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
    }
    return words;
  }

  testWidgets('the header says who is playing, and the pills support', (
    tester,
  ) async {
    await pumpGame(tester);

    expect(find.text('Разом із дорослим'), findsOneWidget);
    expect(find.text('Вийшло!'), findsOneWidget);
    expect(find.text('Спробуємо ще'), findsOneWidget);

    // Not a verdict, not a score, and never the child's failure.
    expect(find.text('Неправильно'), findsNothing);
    expect(find.text('Помилка'), findsNothing);
    await settleGaps(tester);
  });

  testWidgets('nothing on the screen promises that the app is listening', (
    tester,
  ) async {
    await pumpGame(tester);

    for (final icon in [
      Icons.mic,
      Icons.mic_rounded,
      Icons.mic_none,
      Icons.mic_none_rounded,
      Icons.keyboard_voice,
      Icons.record_voice_over,
      Icons.graphic_eq,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon promises a '
          'machine that grades pronunciation; this app cannot hear.');
    }
    await settleGaps(tester);
  });

  testWidgets('a set is short — and so is the one after «Ще раз»', (
    tester,
  ) async {
    await pumpGame(tester);

    final first = await playSet(tester);
    expect(first, RepeatGameScreen.sessionLength);
    expect(RepeatGameScreen.sessionLength, lessThanOrEqualTo(5));

    // The celebration comes to everyone who reaches the end of the set.
    final again = find.text('Ще раз');
    expect(again, findsOneWidget);
    // The pills ignore taps for the first moments of the overlay.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(again);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ще раз'), findsNothing);

    final second = await playSet(tester);
    expect(
      second,
      RepeatGameScreen.sessionLength,
      reason: '«ще раз» deals another short set, not a longer one',
    );
    await settleGaps(tester);
  });

  test('the source keeps no microphone and no verdict wording', () {
    final src = File('lib/screens/repeat_game_screen.dart').readAsStringSync();
    expect(src.contains('Icons.mic'), isFalse);
    expect(src.contains('Icons.keyboard_voice'), isFalse);
    expect(src.contains('Icons.record_voice_over'), isFalse);
    // The practice pass is at most this long, so a hard set cannot double.
    expect(
      RepeatGameScreen.practiceLength,
      lessThanOrEqualTo(RepeatGameScreen.sessionLength),
    );
  });
}
