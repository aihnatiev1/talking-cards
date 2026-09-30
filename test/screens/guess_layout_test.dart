import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/screens/guess_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/quiz_option.dart';
import 'package:talking_cards/widgets/quiz_options_board.dart';
import '../helpers/motion.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';

const salt = CardModel(
  id: 'sc07',
  sound: 'СІЛЬ',
  text: '',
  emoji: '',
  image: 'en_salt',
  audioKey: 'sc07',
  colorBg: Color(0xFFE3F2FD),
  colorAccent: Color(0xFF1565C0),
);
const acorn = CardModel(
  id: 'szh05',
  sound: 'ЖОЛУДЬ',
  text: '',
  emoji: '',
  image: 'zholud',
  audioKey: 'szh05',
  colorBg: Color(0xFFFFF8E1),
  colorAccent: Color(0xFFF57F17),
);

const third = CardModel(
  id: 'third',
  sound: 'ЖОЛУДЬ',
  text: '',
  emoji: '',
  image: 'kotik',
  audioKey: 'szh05',
  colorBg: Color(0xFFFFF8E1),
  colorAccent: Color(0xFFF57F17),
);

const fourth = CardModel(
  id: 'fourth',
  sound: 'СІЛЬ',
  text: '',
  emoji: '',
  image: 'en_salt',
  audioKey: 'sc07',
  colorBg: Color(0xFFE3F2FD),
  colorAccent: Color(0xFF1565C0),
);

void main() {
  useTestMotion();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {'assets/pad_content/images/webp/en_salt.webp'},
      bundled: true,
    );
    FeedbackService.debugMute = true;
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
  });
  for (final size in [
    const Size(280, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    for (final count in [2, 3, 4]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$count choices fill $size at scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var taps = 0;
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 114, 18, 20),
                      child: QuizOptionsBoard(
                        options: [
                          for (var i = 0; i < count; i++)
                            i.isEven ? salt : acorn,
                        ],
                        tileBuilder: (i, c) => QuizOption(
                          key: ValueKey(i),
                          card: c,
                          onTap: () => taps++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final first = tester.getRect(find.byKey(const ValueKey(0)));
          expect(first.top, closeTo(114, 1));
          for (var i = 0; i < count; i++) {
            final tile = find.byKey(ValueKey(i));
            await tester.ensureVisible(tile);
            final rect = tester.getRect(tile);
            expect(rect.width, greaterThanOrEqualTo(72));
            expect(rect.height, greaterThanOrEqualTo(72));
            expect(rect.left, greaterThanOrEqualTo(18));
            expect(rect.right, lessThanOrEqualTo(size.width - 18));
            await tester.tap(tile);
            await tester.pumpAndSettle();
          }
          expect(taps, count);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'real screen keeps replay beside close and board directly below',
    (tester) async {
      const size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var replays = 0;
      AudioService.debugWordSink = (_) => replays++;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(
              key: ValueKey('preview'),
              child: GuessScreen(
                cards: [
                  salt,
                  acorn,
                  CardModel(
                    id: 'other1',
                    sound: 'СІЛЬ',
                    text: '',
                    emoji: '',
                    image: 'en_salt',
                    audioKey: 'sc07',
                    colorBg: Color(0xFFE3F2FD),
                    colorAccent: Color(0xFF1565C0),
                  ),
                  CardModel(
                    id: 'other2',
                    sound: 'ЖОЛУДЬ',
                    text: '',
                    emoji: '',
                    image: 'zholud',
                    audioKey: 'szh05',
                    colorBg: Color(0xFFFFF8E1),
                    colorAccent: Color(0xFFF57F17),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      for (final element in find.byType(Image).evaluate()) {
        await tester.runAsync(
          () => precacheImage((element.widget as Image).image, element),
        );
      }
      await tester.pumpAndSettle();
      final speaker = find.byIcon(Icons.volume_up_rounded);
      expect(tester.getRect(speaker).bottom, lessThan(100));
      final before = replays;
      await tester.tap(speaker);
      await tester.pump();
      expect(replays, before + 1);
      final tiles = find.byType(QuizOption);
      expect(tiles, findsNWidgets(2));
      expect(tester.getRect(tiles.first).top, lessThan(130));
      // Bloom's corner reserves the bottom strip (bloom_character §4.2):
      // the board still reaches most of the way down, just not under him.
      expect(tester.getRect(tiles.last).bottom, greaterThan(700));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('GUESS_PREVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/guess-redesign.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('Bloom sits in the corner and never on the board', (
    tester,
  ) async {
    // bloom_character §4.2: always under the learning object, never over
    // it — including the hop, which the mascot reserves clearance for.
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AudioService.debugWordSink = (_) {};
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GuessScreen(cards: [salt, acorn, third, fourth]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BloomMascot), findsOneWidget);
    final bloom = tester.getRect(find.byType(BloomMascot));
    final board = tester.getRect(find.byType(QuizOptionsBoard));
    expect(
      bloom.overlaps(board),
      isFalse,
      reason: 'Bloom $bloom overlaps the options board $board',
    );
    expect(bloom.bottom, lessThanOrEqualTo(size.height));
    await tester.pumpWidget(const SizedBox());
  });
}
