import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/opposite_game_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/services/profile_service.dart';
import 'package:talking_cards/widgets/quiz_option.dart';

import '../helpers/motion.dart';

/// Consecutive pairs, as the opposites pack stores them. The long words
/// are the ones that have to fit a narrow tile.
const words = [
  'ВЕЛИКИЙ',
  'МАЛЕНЬКИЙ',
  'ГАРЯЧИЙ',
  'ХОЛОДНИЙ',
  'ШВИДКИЙ',
  'ПОВІЛЬНИЙ',
];

final pack = PackModel(
  id: 'opposites',
  title: 'Протилежності',
  icon: '',
  color: Colors.pink,
  isLocked: false,
  isFree: false,
  cards: [
    for (final (i, w) in words.indexed)
      CardModel(
        id: 'op$i',
        sound: w,
        text: '',
        emoji: '',
        image: 'op$i',
        audioKey: 'op$i',
        colorBg: Colors.white,
        colorAccent: Colors.pink,
      ),
  ],
);

void main() {
  useTestMotion();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    AudioService.debugWordSink = (_) {};
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    required int level,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) => ProfileNotifier(ref, [
              ProfileModel(
                id: ProfileService.activeId,
                name: 'Соня',
                avatarEmoji: '',
                createdAt: DateTime(2026),
                level: level,
              ),
            ]),
          ),
        ],
        child: MaterialApp(home: OppositeGameScreen(pack: pack)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('two pictures to choose from at 1–3 years', (tester) async {
    await pumpGame(tester, level: 2);
    expect(find.byType(QuizOption), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    testWidgets('three pictures from three years fit $size, words whole', (
      tester,
    ) async {
      await pumpGame(tester, level: 3, size: size);
      expect(tester.takeException(), isNull);
      final tiles = find.byType(QuizOption);
      expect(tiles, findsNWidgets(3));
      for (final tile in tiles.evaluate()) {
        final rect = tester.getRect(find.byWidget(tile.widget));
        expect(rect.width, greaterThanOrEqualTo(72));
        expect(rect.height, greaterThanOrEqualTo(72));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        // The word sits inside its tile on one line — never cut, never «…».
        final word = find.descendant(
          of: find.byWidget(tile.widget),
          matching: find.text((tile.widget as QuizOption).card.sound),
        );
        expect(word, findsOneWidget);
        final text = tester.getRect(word);
        expect(text.left, greaterThanOrEqualTo(rect.left));
        expect(text.right, lessThanOrEqualTo(rect.right));
        expect(tester.widget<Text>(word).maxLines, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
