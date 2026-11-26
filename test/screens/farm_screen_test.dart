import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/farm_layout_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/streak_provider.dart';
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
  title: 'Тварини і звуки',
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
      id: 'a20',
      sound: 'ЇЖАЧОК',
      text: '',
      emoji: '',
      image: 'hedgehog',
      audioKey: 'ijachok',
      colorBg: Colors.white,
      colorAccent: Colors.teal,
    ),
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
    // One word: never broken at its hyphen.
    expect(find.text('А ти скажи: «няв-\u2060няв»!'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('farm-frog')));
    await tester.pumpAndSettle();
    expect(spoken, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('wake-yes')), findsOneWidget);
    // «No»: just the farm again.
    await tester.tap(find.byKey(const ValueKey('wake-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wake-yes')), findsNothing);
    // «Yes»: the frog's lesson.
    await tester.tap(find.byKey(const ValueKey('farm-frog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wake-yes')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(PlayLessonScreen), findsOneWidget);
    expect(
      find.byType(PlayLessonScreen).evaluate().single.widget,
      isA<PlayLessonScreen>().having((w) => w.topic.id, 'topic', 'sound_pond'),
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
      // Shown, gently: Bloom says who it was; then it says so itself.
      expect(find.text('Ні, це $wrong!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('two misses and the answer beckons — it breathes big and glows', (
    tester,
  ) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-riddle')));
    await tester.pump();
    final asked = riddles.last!.substring(4);
    final wrong = meadowFree.where((k) => k != asked).take(2).toList();
    bool beckons() =>
        tester.widget<MeadowFriend>(find.byKey(ValueKey('farm-$asked'))).beckon;
    for (final (i, key) in wrong.indexed) {
      expect(beckons(), isFalse, reason: 'after $i misses');
      await tester.tap(find.byKey(ValueKey('farm-$key')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(beckons(), isTrue);
    // Found: the next riddle starts with no hint.
    await tester.tap(find.byKey(ValueKey('farm-$asked')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1100));
    final next = riddles.last!.substring(4);
    expect(
      tester.widget<MeadowFriend>(find.byKey(ValueKey('farm-$next'))).beckon,
      isFalse,
    );
    await leave(tester);
  });

  testWidgets('a sleeping animal sleeps: «z z Z» over it', (tester) async {
    await pumpFarm(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('farm-frog')),
        matching: find.text('z z Z'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('farm-cat')),
        matching: find.text('z z Z'),
      ),
      findsNothing,
    );
    await leave(tester);
  });

  testWidgets('the fish jumps and says its name', (tester) async {
    await pumpFarm(tester);
    await tester.tap(find.byKey(const ValueKey('farm-fish')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(words, ['ribka']);
    // Its name in a cloud over it, like every animal's sound.
    final cloud = tester.widget<AnimatedScale>(
      find
          .ancestor(
            of: find.text('рибка'),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(cloud.scale, 1);
    expect(find.text('А ти скажи: «рибка»!'), findsOneWidget);
    await leave(tester);
  });

  group('the barn: the child arranges the farm', () {
    String today() {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}';
    }

    /// Three days in a row: the hedgehog has come.
    void withHedgehog() => SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'streak_last_date': today(),
      'streak_rewards': const ['🦄'],
    });

    FarmLayout layoutOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(FarmScreen)),
    ).read(farmLayoutProvider);

    testWidgets('a guest the streak brought waits in the barn, and the '
        'barn door says so', (tester) async {
      withHedgehog();
      await pumpFarm(tester, locked: false);
      await tester.pump();
      expect(find.byKey(const ValueKey('farm-hedgehog')), findsNothing);
      expect(find.byKey(const ValueKey('farm-barn-new')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('farm-barn')));
      await tester.pump();
      expect(find.byKey(const ValueKey('barn-hedgehog')), findsOneWidget);
      expect(find.byKey(const ValueKey('farm-barn-new')), findsNothing);
      // The open shelf hides nobody — the frog and the duck included.
      final shelf = tester.getRect(
        find.ancestor(
          of: find.byKey(const ValueKey('barn-hedgehog')),
          matching: find.byType(ListView),
        ),
      );
      for (final key in meadowVoices.keys) {
        final animal = find.byKey(ValueKey('farm-$key'));
        if (animal.evaluate().isEmpty) continue;
        expect(
          shelf.overlaps(tester.getRect(animal).deflate(8)),
          isFalse,
          reason: '$key is under the shelf',
        );
      }
      // A tap on the shelf says its name.
      await tester.tap(find.byKey(const ValueKey('barn-hedgehog')));
      await tester.pump();
      expect(words, contains('ijachok'));
      await leave(tester);
    });

    testWidgets('dragged up from the shelf, the guest stands on the farm, '
        'says its name and stays there', (tester) async {
      withHedgehog();
      await pumpFarm(tester, locked: false);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('farm-barn')));
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('barn-hedgehog')),
        const Offset(0, 160),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('farm-hedgehog')), findsOneWidget);
      expect(spoken, contains('ijachok'));
      expect(layoutOf(tester).spotOf('hedgehog'), isNotNull);
      await leave(tester);
    });

    testWidgets('an animal carried across the farm stays where it was put', (
      tester,
    ) async {
      await pumpFarm(tester, locked: false);
      final before = tester.getCenter(find.byKey(const ValueKey('farm-cat')));
      await tester.drag(
        find.byKey(const ValueKey('farm-cat')),
        const Offset(-120, -20),
      );
      await tester.pump();
      final after = tester.getCenter(find.byKey(const ValueKey('farm-cat')));
      expect(after.dx, lessThan(before.dx - 80));
      final spot = layoutOf(tester).spotOf('cat')!;
      expect(spot.x, lessThan(farmSpots['cat']!.$1));
      // A drag is not a tap: the cat did not speak.
      expect(spoken, isEmpty);
      await leave(tester);
    });

    testWidgets('an animal dragged onto the open shelf rests in the barn, '
        'and a riddle never asks for it', (tester) async {
      await pumpFarm(tester, locked: false);
      await tester.tap(find.byKey(const ValueKey('farm-barn')));
      await tester.pump();
      // Everyone is on the farm: the shelf is empty and says what it is.
      final shelf = tester.getCenter(find.textContaining('Тут відпочивають'));
      final cow = tester.getCenter(find.byKey(const ValueKey('farm-cow')));
      await tester.dragFrom(cow, shelf - cow);
      await tester.pump();
      expect(find.byKey(const ValueKey('farm-cow')), findsNothing);
      expect(find.byKey(const ValueKey('barn-cow')), findsOneWidget);
      expect(layoutOf(tester).has('cow'), isTrue);
      expect(layoutOf(tester).spotOf('cow'), isNull);

      await tester.tap(find.byKey(const ValueKey('farm-barn')));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const ValueKey('farm-listen')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('farm-riddle')));
        await tester.pump();
      }
      expect(riddles, isNot(contains('snd_cow')));
      await leave(tester);
    });
  });

  group('carrying, as a toddler carries', () {
    testWidgets('a smeared tap is still a tap: it speaks and stays put', (
      tester,
    ) async {
      await pumpFarm(tester, locked: false);
      final before = tester.getCenter(find.byKey(const ValueKey('farm-cat')));
      await tester.drag(
        find.byKey(const ValueKey('farm-cat')),
        const Offset(26, 6),
      );
      await tester.pump();
      expect(spoken, contains('snd_cat'));
      expect(tester.getCenter(find.byKey(const ValueKey('farm-cat'))), before);
      await leave(tester);
    });

    testWidgets('dropped on the barn door, an animal rests — shelf shut', (
      tester,
    ) async {
      await pumpFarm(tester, locked: false);
      final dog = tester.getCenter(find.byKey(const ValueKey('farm-dog')));
      final door = tester.getCenter(find.byKey(const ValueKey('farm-barn')));
      await tester.dragFrom(dog, door - dog);
      await tester.pump();
      expect(find.byKey(const ValueKey('farm-dog')), findsNothing);
      await leave(tester);
    });

    testWidgets('a carry in the middle of a riddle asks the riddle again', (
      tester,
    ) async {
      await pumpFarm(tester, locked: false);
      await tester.tap(find.byKey(const ValueKey('farm-riddle')));
      await tester.pump();
      expect(riddles, hasLength(1));
      await tester.drag(
        find.byKey(const ValueKey('farm-horse')),
        const Offset(0, 120),
      );
      await tester.pump();
      expect(riddles, hasLength(2));
      expect(riddles.last, riddles.first);
      await leave(tester);
    });

    testWidgets('a second finger does not steal the animal being carried', (
      tester,
    ) async {
      await pumpFarm(tester, locked: false);
      final cat = tester.getCenter(find.byKey(const ValueKey('farm-cat')));
      final pig = tester.getCenter(find.byKey(const ValueKey('farm-pig')));
      final one = await tester.startGesture(cat);
      await one.moveBy(const Offset(-30, 0));
      await one.moveBy(const Offset(-60, 0));
      final two = await tester.startGesture(pig, pointer: 2);
      await two.moveBy(const Offset(-30, -10));
      await two.moveBy(const Offset(-60, -10));
      await one.up();
      await two.up();
      await tester.pump();
      final layout = ProviderScope.containerOf(
        tester.element(find.byType(FarmScreen)),
      ).read(farmLayoutProvider);
      // The cat went where the first finger took it, not to the pig's path.
      final catSpot = layout.spotOf('cat')!;
      expect(catSpot.y, closeTo(farmSpots['cat']!.$2, .02));
      await leave(tester);
    });
  });

  test('the farm layout survives the app closing', () async {
    SharedPreferences.setMockInitialValues({});
    final first = FarmLayoutNotifier();
    await first.place('cat', (x: .3, y: .7));
    await first.rest('cow');
    final again = FarmLayoutNotifier();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(again.state.spotOf('cat'), (x: .3, y: .7));
    expect(again.state.has('cow'), isTrue);
    expect(again.state.spotOf('cow'), isNull);
  });

  test('every streak guest comes with its card in both catalogues', () {
    for (final file in [
      'assets/data/uk_cards.json',
      'assets/data/en_cards.json',
    ]) {
      final packs = (json.decode(File(file).readAsStringSync()) as List)
          .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final guests = meadowAnimals(
        packs: packs,
        rewards: const {},
        withLocked: true,
        guests: {for (final m in milestones) m.guest},
      ).map((a) => a.key).toSet();
      for (final m in milestones) {
        expect(guests, contains(m.guest), reason: '$file: ${m.guest}');
        expect(
          File('assets/images/friends/${m.guest}.webp').existsSync() &&
              File('assets/images/friends/talk/${m.guest}.webp').existsSync(),
          isTrue,
          reason: m.guest,
        );
      }
    }
  });
}
