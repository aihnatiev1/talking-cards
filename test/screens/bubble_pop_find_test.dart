import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/bloom_reactions_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/bubble_pop_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/services/profile_service.dart';
import 'package:talking_cards/widgets/card_image.dart';
import 'package:talking_cards/widgets/kid_screen.dart';

import '../helpers/motion.dart';

/// «Лопай бульбашки», wave 3 (docs/design/bubble_pop_redesign.md §8:
/// 3.1 find mode, 3.2 the noticed run of misses, 3.3 calibration,
/// 3.5 wiping) — and, through 3.1, п. 23 of the experience audit.
///
/// The rules this file exists to hold:
///
///  * exactly one live bubble is ever the thing on Bloom's sign;
///  * popping any other one still pops, still shows its card and takes
///    **nothing** away — there is no punishment anywhere in this game;
///  * the sign turns over once the child has found it;
///  * a one-year-old may wipe instead of tap, and only a one-year-old;
///  * the round reports how many of the taps landed, so the diameters of
///    a level can be checked against the hands that play it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pictures from curated [SemanticGroup]s: find mode draws its targets
  // from them so two targets in a row are two visibly different things.
  const images = <String>[
    'cat', 'dog', 'cow', 'horse', // animals
    'apple', 'banana', 'grapes', 'kavun', // food
    'avtomobil', 'avtobus', 'poizd', 'litak', // transport
  ];

  CardModel card(String image) => CardModel(
        id: image,
        sound: image,
        text: image,
        emoji: '🐱',
        colorBg: const Color(0xFFFFFFFF),
        colorAccent: const Color(0xFF000000),
        image: image,
        audioKey: 'no_such_$image', // unknown key → AudioService stays quiet
      );

  final pack = PackModel(
    id: 'animals',
    title: 'Animals',
    icon: '🐱',
    color: const Color(0xFF6C63FF),
    isLocked: false,
    isFree: true,
    cards: [for (final i in images) card(i)],
  );

  Widget host({int level = 3, BubbleMode mode = BubbleMode.find}) =>
      ProviderScope(
        overrides: [
          packsProvider.overrideWith((ref) => [pack]),
          profileProvider.overrideWith(
            (ref) => ProfileNotifier(ref, [
              ProfileModel(
                id: ProfileService.activeId,
                name: 'Тест',
                avatarEmoji: '👶',
                createdAt: DateTime(2026),
                level: level,
              ),
            ]),
          ),
        ],
        child: MaterialApp(home: BubblePopScreen(mode: mode)),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
    debugResetKidOverlayQueue();
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
    AnalyticsService.debugSink = null;
  });

  Future<void> open(
    WidgetTester tester, {
    int level = 3,
    BubbleMode mode = BubbleMode.find,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(level: level, mode: mode));
    await tester.pump(); // post-frame → _startRound
  }

  /// The picture on Bloom's sign. Read after the turn-over has finished,
  /// so the outgoing card is gone and only one is in the frame.
  String? signImage(WidgetTester tester) {
    final images = tester
        .widgetList<CardImage>(find.descendant(
          of: find.byKey(const ValueKey('find_sign')),
          matching: find.byType(CardImage),
        ))
        .map((w) => w.name)
        .toList();
    return images.isEmpty ? null : images.last;
  }

  /// Live bubbles, by the key the layer gives them → the picture inside.
  Map<String, String?> liveBubbles(WidgetTester tester) {
    final out = <String, String?>{};
    final finder = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('bubble_'),
    );
    for (final element in finder.evaluate()) {
      final key = (element.widget.key! as ValueKey<String>).value;
      final image = tester
          .widgetList<CardImage>(find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(CardImage),
          ))
          .first
          .name;
      out[key] = image;
    }
    return out;
  }

  group('«Знайди бульбашку» — one thing to look for (§5, audit п. 23)', () {
    testWidgets('exactly one live bubble is the one on the sign',
        (tester) async {
      await open(tester);
      // The two pre-seeded bubbles are up before the first tick: the sign
      // must not be a question the sky cannot answer even then.
      expect(signImage(tester), isNotNull);
      expect(
        liveBubbles(tester).values.where((i) => i == signImage(tester)),
        hasLength(1),
        reason: 'the target is in the sky from the first frame',
      );

      // Let the round breathe: bubbles are born, others leave the top
      // (a bubble that escapes costs nothing — it is simply gone, and the
      // target is put back up at the very next spawn).
      var absent = 0;
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 700));
        final target = signImage(tester);
        final up =
            liveBubbles(tester).values.where((image) => image == target);
        expect(up.length, lessThanOrEqualTo(1),
            reason: 'two of the same picture is not a question');
        absent = up.isEmpty ? absent + 1 : 0;
        expect(absent, lessThanOrEqualTo(2),
            reason: '§5: the target is back in the sky at the first spawn '
                'after it left');
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the wrong bubble still pops, still speaks, and costs '
        'nothing', (tester) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 700));

      final target = signImage(tester);
      final other = liveBubbles(tester).entries.firstWhere(
            (e) => e.value != target,
            orElse: () => throw StateError('needed a second picture up'),
          );

      await tester.tap(find.byKey(ValueKey(other.key)));
      await tester.pump();

      // It popped like any other bubble…
      expect(FeedbackService.debugLog, contains(FeedbackEvent.bubblePop));
      // …but it was not the answer, so no "found it" note over the pop.
      expect(FeedbackService.debugLog, isNot(contains(FeedbackEvent.correct)));
      // The card is revealed with its word (the queue itself is covered in
      // bubble_pop_tuning_test): the wrong bubble is still a lesson.
      expect(
        tester.widgetList<CardImage>(find.byType(CardImage)).map((w) => w.name),
        contains(other.value),
      );
      // Nothing is taken away and nothing is scolded — the counter waits.
      expect(find.text('0/6'), findsOneWidget);
      expect(signImage(tester), target, reason: 'the task did not change');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('finding it counts, sounds and turns the sign over',
        (tester) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 700));

      final target = signImage(tester);
      final hit = liveBubbles(tester)
          .entries
          .firstWhere((e) => e.value == target);

      await tester.tap(find.byKey(ValueKey(hit.key)));
      await tester.pump();

      expect(find.text('1/6'), findsOneWidget);
      expect(FeedbackService.debugLog, contains(FeedbackEvent.bubblePop));
      expect(
        FeedbackService.debugLog,
        contains(FeedbackEvent.correct),
        reason: 'the warm note of §4 over the pop',
      );

      // Past the turn-over: a different thing to look for, and still only
      // one of it in the sky.
      await tester.pump(const Duration(milliseconds: 400));
      final next = signImage(tester);
      expect(next, isNotNull);
      expect(next, isNot(target));

      await tester.pump(const Duration(milliseconds: 1600));
      expect(
        liveBubbles(tester).values.where((image) => image == next),
        hasLength(1),
        reason: '§5: the sky always has something to find in it — the '
            'first spawn after the sign turns over carries it',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('free popping is untouched: every bubble counts',
        (tester) async {
      await open(tester, mode: BubbleMode.all);
      expect(find.byKey(const ValueKey('find_sign')), findsNothing);
      expect(find.text('0/20'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bubble_1')));
      await tester.pump();
      expect(find.text('1/20'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    group('under MotionMode.test', () {
      useTestMotion();

      testWidgets('pumpAndSettle terminates on a find round', (tester) async {
        await open(tester, level: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('0/4'), findsOneWidget, reason: 'L2 looks for four');
        expect(find.byKey(const ValueKey('find_sign')), findsOneWidget);
      });
    });
  });

  group('Wiping — a one-year-old sweeps (3.5, rule 3)', () {
    /// Put the finger down on empty sky above the bubbles, then drag it
    /// through the middle of [key].
    Future<void> wipeThrough(WidgetTester tester, String key) async {
      final body = tester.getRect(find.byType(KidScreen));
      final gesture =
          await tester.startGesture(Offset(body.width * 0.5, body.top + 140));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(key))));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    testWidgets('L1: the bubble the finger travels through bursts',
        (tester) async {
      await open(tester, level: 1, mode: BubbleMode.all);
      expect(find.text('0/8'), findsOneWidget);

      await wipeThrough(tester, 'bubble_2');

      expect(find.text('1/8'), findsOneWidget);
      expect(FeedbackService.debugLog, contains(FeedbackEvent.bubblePop));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('L2: a drag is not a pop — two-year-olds aim', (tester) async {
      await open(tester, level: 2, mode: BubbleMode.all);
      expect(find.text('0/12'), findsOneWidget);

      await wipeThrough(tester, 'bubble_2');

      expect(find.text('0/12'), findsOneWidget);
      expect(
        FeedbackService.debugLog,
        isNot(contains(FeedbackEvent.bubblePop)),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('A run of misses (3.2) — help, never judgement', () {
    /// Bloom's pose, read out of the brain the screen is talking to.
    BloomEmotion emotion(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(BubblePopScreen)),
        ).read(bloomReactionsProvider).emotion;

    Future<void> missOnce(WidgetTester tester) async {
      final body = tester.getRect(find.byType(KidScreen));
      await tester.tapAt(Offset(body.width * 0.5, body.top + 140));
      await tester.pump();
    }

    testWidgets('one miss is nothing; three in four seconds is noticed',
        (tester) async {
      await open(tester, level: 2, mode: BubbleMode.all);

      await missOnce(tester);
      expect(emotion(tester), isNot(BloomEmotion.curious),
          reason: 'a single miss earns nothing — fingers land next to '
              'things all day');

      await missOnce(tester);
      await missOnce(tester); // L2: three in a row is a child trying
      expect(emotion(tester), BloomEmotion.curious);

      // And still nothing was taken away.
      expect(find.text('0/12'), findsOneWidget);
      expect(
        FeedbackService.debugLog,
        isNot(contains(FeedbackEvent.wrong)),
        reason: 'a miss is not a wrong answer',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a one-year-old is noticed after two', (tester) async {
      await open(tester, level: 1, mode: BubbleMode.all);
      final body = tester.getRect(find.byType(KidScreen));
      await tester.tapAt(Offset(body.width * 0.5, body.top + 140));
      await tester.pump();
      await tester.tapAt(Offset(body.width * 0.5, body.top + 140));
      await tester.pump();
      expect(emotion(tester), BloomEmotion.curious);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Calibration (3.3) — aggregates, never a child', () {
    testWidgets('hit_rate is pops over taps, with the level and the device',
        (tester) async {
      final events = <(String, Map<String, Object>)>[];
      AnalyticsService.debugSink = (name, params) => events.add((name, params));

      await open(tester, level: 2, mode: BubbleMode.all);
      // Two frames: the first arms the ticker's clock, the second moves
      // the round on and gives `_elapsedMs` something to report.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // One pop…
      await tester.tap(find.byKey(const ValueKey('bubble_1')));
      await tester.pump();
      // …and three taps into empty sky, just under the header.
      final body = tester.getRect(find.byType(KidScreen));
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(Offset(body.width * 0.5, body.top + 140));
        await tester.pump();
      }

      // Past the L2 time limit: a round with at least one pop ends for
      // real (a round with none would quietly start over instead).
      await tester.pump(const Duration(seconds: 51));
      await tester.pump();

      final done = events.lastWhere((e) => e.$1 == 'game_complete');
      expect(done.$2['game_id'], 'bubble_pop_all');
      expect(done.$2['score'], 1);
      expect(done.$2['hit_rate'], 0.25, reason: '1 pop of 4 taps');
      expect(done.$2['level'], 2);
      expect(done.$2['device_class'], 'phone');
      expect(done.$2['time_to_first_pop_ms'], isA<int>());
      // Nothing that could name the child or the card.
      expect(
        done.$2.keys,
        everyElement(isNot(anyOf('card_id', 'profile_id', 'name'))),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });
}
