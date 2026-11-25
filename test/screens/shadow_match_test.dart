import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/shadow_match_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/services/profile_service.dart';

import '../helpers/motion.dart';

/// image → (real audio key, word), as in the animals pack.
const animals = {
  'cat': ('kotik', 'КОТИК'),
  'dog': ('sobachka', 'СОБАЧКА'),
  'cow': ('korova', 'КОРОВА'),
  'duck': ('kachechka', 'КАЧЕЧКА'),
  'chicken': ('kurochka', 'КУРОЧКА'),
  'frog': ('jabka', 'ЖАБКА'),
  'fish': ('ribka', 'РИБКА'),
};

CardModel animal(String image) => CardModel(
  id: image,
  sound: animals[image]!.$2,
  text: '',
  emoji: '',
  image: image,
  audioKey: animals[image]!.$1,
  colorBg: Colors.white,
  colorAccent: Colors.teal,
);

final all = [for (final image in animals.keys) animal(image)];

void main() {
  useTestMotion();

  final words = <String?>[];
  final spoken = <String?>[];
  final events = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    words.clear();
    spoken.clear();
    events.clear();
    AudioService.debugWordSink = words.add;
    AudioService.debugSpeakSink = spoken.add;
    AnalyticsService.debugSink = (name, params) {
      if (name.startsWith('game_')) events.add('$name:${params['game_id']}');
    };
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
    AudioService.debugSpeakSink = null;
    AnalyticsService.debugSink = null;
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    int level = 2,
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
        child: MaterialApp(home: ShadowMatchScreen(cards: all)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String imageOf(String? audioKey) =>
      animals.entries.firstWhere((e) => e.value.$1 == audioKey).key;

  Finder plates() =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Shadow');

  /// The plate that shows [image]'s shadow.
  Finder plateOf(String image) => find.ancestor(
    of: find.byKey(ValueKey('shadow-$image')),
    matching: plates(),
  );

  /// The images on the board that are not the friend in hand.
  String wrongOf(WidgetTester tester, String image) {
    for (final other in animals.keys) {
      if (other != image && plateOf(other).evaluate().isNotEmpty) return other;
    }
    throw StateError('no other shadow on the board');
  }

  Finder piece() => find.byKey(const ValueKey('shadow-match-piece'));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(seconds: 1));
  }

  group('shadowPool', () {
    test('only the friends that have a shape of their own', () {
      final pack = PackModel(
        id: 'animals',
        title: 'Тваринки',
        icon: '',
        color: Colors.teal,
        isLocked: false,
        isFree: true,
        cards: [
          animal('cat'),
          animal('fish'),
          CardModel(
            id: 'bunny',
            sound: 'ЗАЙЧИК',
            text: '',
            emoji: '',
            image: 'bunny',
            audioKey: 'zaichik',
            colorBg: Colors.white,
            colorAccent: Colors.teal,
          ),
        ],
      );
      expect(shadowPool(pack).map((c) => c.id), ['cat', 'fish']);
    });
  });

  group('shadowBoard', () {
    test('never two shadows that look alike', () {
      for (var seed = 0; seed < 200; seed++) {
        final random = Random(seed);
        final piece = all[random.nextInt(all.length)];
        final board = shadowBoard(piece, all, 3, random);
        expect(board, contains(piece));
        expect(board, hasLength(3));
        expect(
          {for (final c in board) shadowGroups[c.image]},
          hasLength(3),
          reason: 'seed $seed: ${board.map((c) => c.image)}',
        );
      }
    });

    test('a pool of look-alikes gives a shorter board, not an unfair one', () {
      final quad = [animal('cat'), animal('dog'), animal('cow')];
      expect(shadowBoard(quad.first, quad, 3, Random(1)), [quad.first]);
    });
  });

  testWidgets('the friend is named and two shadows wait', (tester) async {
    await pumpGame(tester);
    expect(words, hasLength(1));
    final image = imageOf(words.single);
    expect(find.text('Чия це тінь?'), findsOneWidget);
    expect(plates(), findsNWidgets(2));
    expect(plateOf(image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tap on its shadow puts the friend there', (tester) async {
    await pumpGame(tester);
    final image = imageOf(words.single);
    await tester.tap(plateOf(image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(ValueKey('filled-$image')), findsOneWidget);
    expect(find.text(shadowFound(animal(image), isEn: false)), findsOneWidget);
    expect(spoken, [animals[image]!.$1]);
    await settle(tester);
    // Another friend now.
    expect(words, hasLength(2));
    expect(words.last, isNot(words.first));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('carrying the friend onto its shadow works too', (tester) async {
    await pumpGame(tester);
    final image = imageOf(words.single);
    final from = tester.getCenter(piece());
    final to = tester.getCenter(plateOf(image));
    await tester.dragFrom(from, to - from);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(ValueKey('filled-$image')), findsOneWidget);
    expect(spoken, [animals[image]!.$1]);
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('let go on the grass: the friend goes home, nothing is counted', (
    tester,
  ) async {
    await pumpGame(tester);
    final home = tester.getCenter(piece());
    await tester.dragFrom(home, const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getCenter(piece()), home);
    expect(find.text('Чия це тінь?'), findsOneWidget);
    expect(words, hasLength(1));
    expect(spoken, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another shadow sends it back with the name again, then a hint', (
    tester,
  ) async {
    await pumpGame(tester);
    final image = imageOf(words.single);
    final wrong = wrongOf(tester, image);
    final home = tester.getCenter(piece());

    await tester.tap(plateOf(wrong));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Спробуй іншу тінь'), findsOneWidget);
    expect(tester.getCenter(piece()), home);
    expect(words, [words.first, words.first]);
    expect(spoken, isEmpty);

    await tester.tap(plateOf(wrong));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Дивись, я підкажу'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('five friends end the game; «Ще раз» starts another', (
    tester,
  ) async {
    await pumpGame(tester);
    for (var i = 0; i < ShadowMatchScreen.rounds; i++) {
      await tester.tap(plateOf(imageOf(words.last)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(events.first, 'game_start:shadow_match');
    expect(events, contains('game_complete:shadow_match'));
    final asked = words.length;
    await tester.tap(find.text('Ще раз'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(plates(), findsNWidgets(2));
    expect(find.text('Чия це тінь?'), findsOneWidget);
    expect(words.length, greaterThan(asked));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    for (final level in const [2, 3]) {
      testWidgets('fits $size at level $level', (tester) async {
        await pumpGame(tester, size: size, level: level);
        expect(tester.takeException(), isNull);
        expect(plates(), findsNWidgets(level <= 2 ? 2 : 3));
        for (final plate in plates().evaluate()) {
          final rect = tester.getRect(find.byWidget(plate.widget));
          expect(rect.width, greaterThanOrEqualTo(72));
          expect(rect.height, greaterThanOrEqualTo(72));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }
        final friend = tester.getRect(piece());
        expect(friend.width, greaterThanOrEqualTo(72));
        expect(friend.height, greaterThanOrEqualTo(72));
        expect(friend.bottom, lessThanOrEqualTo(size.height));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
