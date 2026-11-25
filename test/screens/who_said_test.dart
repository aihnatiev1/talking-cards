import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/who_said_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/answer_feedback.dart';
import 'package:talking_cards/widgets/quiz_option.dart';

import '../helpers/motion.dart';

CardModel animal(String name, {String prefix = ''}) => CardModel(
  id: '$prefix$name',
  sound: name.toUpperCase(),
  text: '',
  emoji: '',
  image: 'ph_$name',
  audioKey: '${prefix}snd_$name',
  colorBg: Colors.white,
  colorAccent: Colors.teal,
);

PackModel pack(List<String> names, {required bool locked}) => PackModel(
  id: 'animal_sounds',
  title: 'Звуки тварин',
  icon: '',
  color: Colors.teal,
  isLocked: locked,
  isFree: false,
  cards: [for (final n in names) animal(n)],
);

const four = ['cat', 'dog', 'cow', 'horse'];

void main() {
  useTestMotion();

  final spoken = <String?>[]; // whole clip: the name, then the voice
  final voices = <String?>[]; // the voice alone
  final words = <String?>[]; // the name alone
  final events = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    spoken.clear();
    voices.clear();
    words.clear();
    events.clear();
    AudioService.debugSpeakSink = spoken.add;
    AudioService.debugAfterWordSink = voices.add;
    AudioService.debugWordSink = words.add;
    AudioService.debugAfterWordResult = (_) => AfterWord.played;
    AnalyticsService.debugSink = (name, params) {
      if (name.startsWith('game_')) events.add('$name:${params['game_id']}');
    };
    AudioService.instance.debugSetWordEnds({
      for (final n in [...four, 'pig', 'sheep', 'hen', 'duck', 'bunny', 'deer'])
        'snd_$n': 800,
    });
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugSpeakSink = null;
    AudioService.debugAfterWordSink = null;
    AudioService.debugWordSink = null;
    AudioService.debugAfterWordResult = null;
    AnalyticsService.debugSink = null;
    AudioService.instance.debugSetWordEnds(const {});
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<String> names = four,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WhoSaidScreen(cards: [for (final n in names) animal(n)]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder tileOf(String audioKey) => find.byWidgetPredicate(
    (w) => w is QuizOption && w.card.audioKey == audioKey,
  );

  Future<void> tapTile(WidgetTester tester, String audioKey) async {
    await tester.ensureVisible(tileOf(audioKey));
    await tester.tap(tileOf(audioKey));
    await tester.pump();
  }

  /// Hears all four animals, then waits for the first question's voice.
  Future<void> meetAll(WidgetTester tester) async {
    for (final n in four) {
      await tapTile(tester, 'snd_$n');
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  group('whoSaidPool', () {
    test('a locked pack gives only its free preview', () {
      final pool = whoSaidPool(
        pack([...four, 'pig', 'sheep', 'hen'], locked: true),
        contentReady: true,
      );
      expect(pool.map((c) => c.id), [...four, 'pig']);
    });

    test('an open pack whose content has not arrived stays on the preview', () {
      final pool = whoSaidPool(
        pack([...four, 'pig', 'sheep', 'hen'], locked: false),
        contentReady: false,
      );
      expect(pool.map((c) => c.id), [...four, 'pig']);
    });

    test('an open pack gives every animal a toddler can tell by ear', () {
      final pool = whoSaidPool(
        pack([...four, 'pig', 'sheep', 'hen', 'bunny', 'deer'], locked: false),
        contentReady: true,
      );
      expect(pool.map((c) => c.id), [...four, 'pig', 'sheep', 'hen']);
    });

    test('a clip whose word end is unknown is never a question', () {
      AudioService.instance.debugSetWordEnds({
        for (final n in ['cat', 'dog', 'cow']) 'snd_$n': 800,
      });
      final pool = whoSaidPool(pack(four, locked: false), contentReady: true);
      expect(pool.map((c) => c.id), ['cat', 'dog', 'cow']);
    });
  });

  testWidgets('meeting an animal says its name and voice, nothing is asked', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(find.text('Торкнись і послухай'), findsOneWidget);
    expect(find.byType(QuizOption), findsNWidgets(4));

    await tapTile(tester, 'snd_cat');
    expect(spoken, ['snd_cat']);
    expect(voices, isEmpty);
    // One animal heard is not the end of the introductions.
    await tester.pump(const Duration(seconds: 2));
    expect(voices, isEmpty);
    expect(find.text('Торкнись і послухай'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the question is the voice alone — the name comes only after '
      'the right tap', (tester) async {
    await pumpGame(tester);
    await meetAll(tester);

    expect(find.text('Хто це сказав?'), findsOneWidget);
    expect(voices, hasLength(1));
    final target = voices.single!;
    // Up to here the only names spoken were the four introductions.
    expect(spoken, hasLength(4));
    expect(words, isEmpty);

    final wrong = tester
        .widgetList<QuizOption>(find.byType(QuizOption))
        .firstWhere((o) => o.card.audioKey != target)
        .card
        .audioKey!;
    await tapTile(tester, wrong);
    expect(find.text('Послухай ще раз'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    // A miss replays the voice, still without the name.
    expect(voices, [target, target]);
    expect(spoken, hasLength(4));
    expect(words, isEmpty);

    await tapTile(tester, target);
    expect(tester.widget<QuizOption>(tileOf(target)).mark, AnswerMark.correct);
    expect(spoken.last, target);
    expect(spoken, hasLength(5));
    expect(find.textContaining('Так! Це'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a voice that cannot be played lights the answer instead of '
      'asking in silence', (tester) async {
    AudioService.debugAfterWordResult = (_) => AfterWord.unavailable;
    await pumpGame(tester);
    await meetAll(tester);
    final target = voices.last!;
    expect(find.text('Дивись, я підкажу'), findsOneWidget);
    expect(tester.widget<QuizOption>(tileOf(target)).mark, AnswerMark.hint);
    // The child can still finish the question and hear the name.
    await tapTile(tester, target);
    expect(spoken.last, target);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a voice overtaken by a newer one is not treated as a failure', (
    tester,
  ) async {
    AudioService.debugAfterWordResult = (_) => AfterWord.overtaken;
    await pumpGame(tester);
    await meetAll(tester);
    expect(find.text('Хто це сказав?'), findsOneWidget);
    expect(
      tester.widget<QuizOption>(tileOf(voices.last!)).mark,
      AnswerMark.none,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('«Ще раз» meets new animals first', (tester) async {
    await pumpGame(tester, names: [...four, 'pig', 'sheep', 'hen', 'duck']);
    final first = {
      for (final o in tester.widgetList<QuizOption>(find.byType(QuizOption)))
        o.card.audioKey!,
    };
    for (final key in first) {
      await tapTile(tester, key);
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < WhoSaidScreen.setSize; i++) {
      await tapTile(tester, voices.last!);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ще раз'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Торкнись і послухай'), findsOneWidget);
    final second = {
      for (final o in tester.widgetList<QuizOption>(find.byType(QuizOption)))
        o.card.audioKey!,
    };
    expect(second, hasLength(4));
    expect(second.intersection(first), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the green play button skips the introductions', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byKey(const ValueKey('who-said-play')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Хто це сказав?'), findsOneWidget);
    expect(voices, hasLength(1));
    expect(spoken, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('four answers end the round with the celebration', (
    tester,
  ) async {
    await pumpGame(tester);
    await meetAll(tester);
    for (var i = 0; i < WhoSaidScreen.setSize; i++) {
      await tapTile(tester, voices.last!);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ще раз'), findsOneWidget);
    expect(events.first, 'game_start:who_said');
    expect(events, contains('game_complete:who_said'));
    // Every question was one of the four that had been introduced.
    expect(voices.toSet(), {for (final n in four) 'snd_$n'});
    // Close the celebration properly: overlays queue app-wide, and one left
    // open would keep the next test's celebration waiting behind it.
    await tester.tap(find.text('Готово'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    testWidgets('both steps fit $size with 72 dp tiles', (tester) async {
      await pumpGame(tester, size: size);
      expect(tester.takeException(), isNull);
      for (final tile in tester.widgetList<QuizOption>(
        find.byType(QuizOption),
      )) {
        final rect = tester.getRect(find.byWidget(tile));
        expect(rect.width, greaterThanOrEqualTo(72));
        expect(rect.height, greaterThanOrEqualTo(72));
      }
      await meetAll(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('who-said-voice')), findsOneWidget);
      for (final tile in tester.widgetList<QuizOption>(
        find.byType(QuizOption),
      )) {
        final rect = tester.getRect(find.byWidget(tile));
        expect(rect.width, greaterThanOrEqualTo(72));
        expect(rect.height, greaterThanOrEqualTo(72));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
