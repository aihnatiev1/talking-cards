import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/farm_screen.dart';
import 'package:talking_cards/screens/play_lesson_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/meadow_world.dart';

import '../helpers/motion.dart';

CardModel sound(String key) => CardModel(
  id: 'as_$key',
  sound: key.toUpperCase(),
  text: '',
  emoji: '',
  image: meadowVoices[key]!.$1,
  audioKey: 'snd_$key',
  colorBg: Colors.white,
  colorAccent: Colors.teal,
);

PackModel soundPack({required bool locked}) => PackModel(
  id: 'animal_sounds',
  title: 'Звуки тварин',
  icon: '',
  color: Colors.teal,
  isLocked: locked,
  isFree: false,
  cards: [for (final key in meadowVoices.keys) sound(key)],
);

const animalsPack = PackModel(
  id: 'animals',
  title: 'Тварини',
  icon: '',
  color: Colors.teal,
  isLocked: false,
  isFree: true,
  cards: [
    CardModel(
      id: 'a10',
      sound: 'РИБКА',
      text: '',
      emoji: '',
      image: 'fish',
      audioKey: 'ribka',
      colorBg: Colors.white,
      colorAccent: Colors.teal,
    ),
  ],
);

void main() {
  useTestMotion();

  final words = <String?>[];

  final spoken = <String?>[];
  final riddles = <String?>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    spoken.clear();
    riddles.clear();
    words.clear();
    AudioService.debugWordSink = words.add;
    AudioService.debugSpeakSink = spoken.add;
    AudioService.debugAfterWordSink = riddles.add;
    AudioService.debugAfterWordResult = (_) => AfterWord.played;
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugSpeakSink = null;
    AudioService.debugWordSink = null;
    AudioService.debugAfterWordSink = null;
    AudioService.debugAfterWordResult = null;
  });

  group('who lives on the farm', () {
    test('without Pro: the five free animals', () {
      final animals = meadowAnimals(
        packs: [soundPack(locked: true)],
        rewards: const {},
      );
      expect(animals.map((a) => a.key), ['cat', 'dog', 'cow', 'horse', 'pig']);
    });

    test('the farm keeps the others, asleep', () {
      final animals = meadowAnimals(
        packs: [soundPack(locked: true)],
        rewards: const {},
        withLocked: true,
      );
      expect(animals, hasLength(12));
      expect(animals.where((a) => a.locked), hasLength(7));
    });

    test(
      'a lesson friend joins — first, with a star, even with a paid voice',
      () {
        final animals = meadowAnimals(
          packs: [soundPack(locked: true)],
          rewards: const {'forest_friends', 'pond_friends'},
        );
        expect(animals.take(2).map((a) => a.key).toSet(), {'owl', 'duck'});
        expect(animals.take(2).every((a) => a.earned && !a.locked), isTrue);
        expect(animals, hasLength(7));
      },
    );

    test('with Pro: all twelve awake', () {
      final animals = meadowAnimals(
        packs: [soundPack(locked: false)],
        rewards: const {},
        withLocked: true,
      );
      expect(animals.where((a) => !a.locked), hasLength(12));
    });

    test('the real catalogues: all twelve on the Ukrainian farm; the '
        'English one without the owl, whose English recording is pulled '
        '(hidden_cards_test) — no farm animal speaks with a pulled voice', () {
      Set<String> farm(String file) {
        final packs = (json.decode(File(file).readAsStringSync()) as List)
            .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return meadowAnimals(
          packs: packs,
          rewards: const {},
          withLocked: true,
        ).map((a) => a.key).toSet();
      }

      expect(farm('assets/data/uk_cards.json'), meadowVoices.keys.toSet());
      expect(
        farm('assets/data/en_cards.json'),
        meadowVoices.keys.toSet().difference({'owl'}),
      );
    });

    test('every animal has its spot', () {
      expect(farmSpots.keys.toSet(), meadowVoices.keys.toSet());
    });
  });

  Future<void> pumpFarm(WidgetTester tester, {bool locked = true}) async {
    // A phone on its side.
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    // The notch and the home bar of a phone on its side.
    tester.view.padding = const FakeViewPadding(
      left: 47,
      right: 47,
      bottom: 21,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packsProvider.overrideWith(
            (ref) async => [soundPack(locked: locked), animalsPack],
          ),
        ],
        child: const MaterialApp(home: FarmScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('the whole farm at once: every animal on the board, none '
      'overlapping, none in the water', (tester) async {
    await pumpFarm(tester, locked: false);
    final screen = Offset.zero & const Size(844, 390);
    final rects = [
      for (final key in meadowVoices.keys)
        tester.getRect(find.byKey(ValueKey('farm-$key'))),
    ];
    for (final r in rects) {
      expect(screen.contains(r.center), isTrue);
      // A toddler's finger: 72 dp at least.
      expect(r.shortestSide, greaterThanOrEqualTo(72));
    }
    // The buttons stand in the sky: at most an ear tip under them.
    for (final button in ['farm-listen', 'farm-riddle']) {
      final b = tester.getRect(find.byKey(ValueKey(button)));
      for (final (i, r) in rects.indexed) {
        final o = b.intersect(r);
        expect(
          o.width > 0 && o.height > 12,
          isFalse,
          reason: '$button on ${meadowVoices.keys.elementAt(i)}',
        );
      }
    }
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].intersect(rects[j]).width > 4 &&
              rects[i].intersect(rects[j]).height > 4,
          isFalse,
          reason:
              '${meadowVoices.keys.elementAt(i)} on '
              '${meadowVoices.keys.elementAt(j)}',
        );
      }
    }
    await leave(tester);
  });

  testWidgets('listen: a tap — the animal speaks, its sound in a cloud, then '
      'Bloom invites the child to say it', (tester) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-cat')));
    await tester.pump();
    expect(spoken, ['snd_cat']);
    expect(find.text('няв-няв'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('А ти скажи: «няв-няв»!'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a tap moves only that animal — its neighbours keep still', (
    tester,
  ) async {
    await pumpFarm(tester);
    final dog = tester.element(find.byKey(const ValueKey('farm-dog')));
    final cat = tester.element(find.byKey(const ValueKey('farm-cat')));
    await tester.tap(find.byKey(const ValueKey('farm-pig')));
    await tester.pump();
    // The same elements: not rebuilt from scratch, so no second hop.
    expect(tester.element(find.byKey(const ValueKey('farm-dog'))), same(dog));
    expect(tester.element(find.byKey(const ValueKey('farm-cat'))), same(cat));
    await leave(tester);
  });

  testWidgets('a sleeping animal says nothing and offers to play the '
      'lesson that wakes it — no grown-up screen', (tester) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-sheep')));
    await tester.pumpAndSettle();
    expect(spoken, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('wake-yes')), findsOneWidget);
    // «No»: just the farm again.
    await tester.tap(find.byKey(const ValueKey('wake-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wake-yes')), findsNothing);
    // «Yes»: the sheep's lesson.
    await tester.tap(find.byKey(const ValueKey('farm-sheep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wake-yes')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(PlayLessonScreen), findsOneWidget);
    expect(
      find.byType(PlayLessonScreen).evaluate().single.widget,
      isA<PlayLessonScreen>().having(
        (w) => w.topic.id,
        'topic',
        'sheep_voices',
      ),
    );
    await leave(tester);
  });

  testWidgets('riddle: the voice without the name, a wrong animal just says '
      'its own, four found and the farm listens again', (tester) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-riddle')));
    await tester.pump();
    expect(riddles, hasLength(1));
    expect(find.text('Хто так каже?'), findsOneWidget);
    for (var found = 0; found < FarmScreen.riddlesPerRound; found++) {
      final asked = riddles.last!.substring(4);
      // Never one that is asleep.
      expect(meadowFree, contains(asked));
      final wrong = meadowFree.firstWhere((k) => k != asked);
      spoken.clear();
      await tester.tap(find.byKey(ValueKey('farm-$wrong')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(spoken, ['snd_$wrong']);
      // A breath, then the riddle again — with no cloud left on anyone.
      await tester.pump(const Duration(milliseconds: 1100));
      final cloud = tester.widget<AnimatedScale>(
        find
            .ancestor(
              of: find.text(meadowVoices[wrong]!.$2),
              matching: find.byType(AnimatedScale),
            )
            .first,
      );
      expect(cloud.scale, 0);
      // The same voice comes again.
      expect(riddles.last, 'snd_$asked');
      await tester.tap(find.byKey(ValueKey('farm-$asked')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(spoken.last, 'snd_$asked');
      await tester.pump(const Duration(milliseconds: 1100));
    }
    expect(find.text('Молодець!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Торкнись тваринку й послухай'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the fish jumps and says its name', (tester) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-fish')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(words, ['ribka']);
    expect(find.text('А ти скажи: «рибка»!'), findsOneWidget);
    await leave(tester);
  });
}
