import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/feed_bloom_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/answer_feedback.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';
import 'package:talking_cards/widgets/quiz_option.dart';

import '../helpers/motion.dart';

/// Real keys from the food pack, so `hasSound` is true without an engine.
const foods = {
  'yabluko': 'ЯБЛУКО',
  'banan': 'БАНАН',
  'vinograd': 'ВИНОГРАД',
  'apelsin': 'АПЕЛЬСИН',
  'polunicia': 'ПОЛУНИЦЯ',
  'kavun': 'КАВУН',
  'grusha': 'ГРУША',
};

CardModel food(String key) => CardModel(
  id: key,
  sound: foods[key]!,
  text: '',
  emoji: '',
  image: key,
  audioKey: key,
  colorBg: Colors.white,
  colorAccent: Colors.teal,
);

PackModel pack({required bool locked}) => PackModel(
  id: 'food',
  title: 'Їжа та фрукти',
  icon: '',
  color: Colors.teal,
  isLocked: locked,
  isFree: false,
  cards: [for (final k in foods.keys) food(k)],
);

void main() {
  useTestMotion();

  final words = <String?>[]; // the word alone: his request
  final spoken = <String?>[]; // the whole clip: the reward
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
    int count = 5,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: FeedBloomScreen(
            cards: [for (final k in foods.keys.take(count)) food(k)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder plateOf(String key) =>
      find.byWidgetPredicate((w) => w is QuizOption && w.card.audioKey == key);

  String wrongOf(WidgetTester tester, String target) => tester
      .widgetList<QuizOption>(find.byType(QuizOption))
      .firstWhere((o) => o.card.audioKey != target)
      .card
      .audioKey!;

  Finder bloom() => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName.contains('images/bloom/'),
  );

  String bloomPose(WidgetTester tester) =>
      ((tester.widget<Image>(bloom().last).image) as AssetImage).assetName;

  /// Lets him finish chewing and the next request be spoken.
  Future<void> settleMeal(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  group('feedBloomPool', () {
    test('a locked pack gives only its free preview', () {
      final pool = feedBloomPool(pack(locked: true), contentReady: true);
      expect(pool.map((c) => c.id), foods.keys.take(5));
    });

    test('an open pack whose content has not arrived stays on the preview', () {
      final pool = feedBloomPool(pack(locked: false), contentReady: false);
      expect(pool.map((c) => c.id), foods.keys.take(5));
    });

    test('an open pack gives the whole table', () {
      final pool = feedBloomPool(pack(locked: false), contentReady: true);
      expect(pool.map((c) => c.id), foods.keys);
    });
  });

  group('what Bloom says', () {
    test('needs no declension — a feminine food reads right', () {
      // «Хочу полуниця» would be wrong and «полуницю» is not recorded.
      expect(
        feedBloomAsk(food('polunicia'), isEn: false),
        'Полуниця, будь ласка!',
      );
      expect(feedBloomYum(food('grusha'), isEn: false), 'Ням-ням! Груша');
      expect(feedBloomAsk(food('vinograd'), isEn: true), 'Виноград, please!');
    });
  });

  testWidgets('there is one Bloom, and he asks by name', (tester) async {
    await pumpGame(tester);
    expect(bloom(), findsOneWidget);
    expect(find.byType(BloomMascot), findsNothing);
    expect(bloomPose(tester), contains('hungry'));
    expect(words, hasLength(1));
    final target = words.single!;
    expect(find.text(feedBloomAsk(food(target), isEn: false)), findsOneWidget);
    // Two plates for a profile of 2–3 years.
    expect(find.byType(QuizOption), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tap feeds him: he chews and the whole clip plays', (
    tester,
  ) async {
    await pumpGame(tester);
    final target = words.single!;
    await tester.tap(plateOf(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(bloomPose(tester), contains('chew'));
    expect(spoken, [target]);
    expect(find.text(feedBloomYum(food(target), isEn: false)), findsOneWidget);
    await settleMeal(tester);
    // The next request is another food.
    expect(words, hasLength(2));
    expect(words.last, isNot(target));
    expect(bloomPose(tester), contains('hungry'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a drag onto Bloom feeds him too', (tester) async {
    await pumpGame(tester);
    final target = words.single!;
    final from = tester.getCenter(plateOf(target));
    final to = tester.getCenter(bloom());
    await tester.dragFrom(from, to - from);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(bloomPose(tester), contains('chew'));
    expect(spoken, [target]);
    await settleMeal(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a food dropped on the grass goes home and is not a miss', (
    tester,
  ) async {
    await pumpGame(tester);
    final target = words.single!;
    final wrong = wrongOf(tester, target);
    final home = tester.getCenter(plateOf(wrong));
    // Carried a little way up and let go, nowhere near him.
    await tester.dragFrom(home, const Offset(0, -60));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getCenter(plateOf(wrong)), home);
    expect(tester.widget<QuizOption>(plateOf(wrong)).nudge, 0);
    expect(find.text(feedBloomAsk(food(target), isEn: false)), findsOneWidget);
    expect(find.text('Послухай ще раз'), findsNothing);
    expect(words, hasLength(1));
    expect(spoken, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a wrong food given to him comes back and he asks again', (
    tester,
  ) async {
    await pumpGame(tester);
    final target = words.single!;
    final wrong = wrongOf(tester, target);
    final home = tester.getCenter(plateOf(wrong));
    await tester.tap(plateOf(wrong));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(bloomPose(tester), contains('hungry'));
    expect(tester.widget<QuizOption>(plateOf(wrong)).nudge, 1);
    expect(tester.getCenter(plateOf(wrong)), home);
    expect(find.text('Послухай ще раз'), findsOneWidget);
    // The word again — never the reward clip.
    expect(words, [target, target]);
    expect(spoken, isEmpty);

    // A second wrong food: the right plate starts to glow.
    await tester.tap(plateOf(wrong));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<QuizOption>(plateOf(target)).mark, AnswerMark.hint);
    expect(find.text('Дивись, я підкажу'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('five foods end the meal with the celebration', (tester) async {
    await pumpGame(tester);
    for (var i = 0; i < FeedBloomScreen.setSize; i++) {
      await tester.tap(plateOf(words.last!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleMeal(tester);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ще раз'), findsOneWidget);
    expect(events.first, 'game_start:feed_bloom');
    expect(events, contains('game_complete:feed_bloom'));
    expect(spoken.toSet(), hasLength(FeedBloomScreen.setSize));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    testWidgets('the table fits $size with 72 dp plates', (tester) async {
      await pumpGame(tester, size: size);
      expect(tester.takeException(), isNull);
      for (final plate in tester.widgetList<QuizOption>(
        find.byType(QuizOption),
      )) {
        final rect = tester.getRect(find.byWidget(plate));
        expect(rect.width, greaterThanOrEqualTo(72));
        expect(rect.height, greaterThanOrEqualTo(72));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      final him = tester.getRect(bloom());
      expect(him.top, greaterThanOrEqualTo(0));
      expect(him.width, greaterThanOrEqualTo(96));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
