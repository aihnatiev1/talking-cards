import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/hide_seek_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/services/profile_service.dart';
import 'package:talking_cards/widgets/animal_friend_art.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';

import '../helpers/motion.dart';

/// image → (real audio key, word), as in the animals pack.
const animals = {
  'cat': ('kotik', 'КОТИК'),
  'dog': ('sobachka', 'СОБАЧКА'),
  'cow': ('korova', 'КОРОВА'),
  'horse': ('konik', 'КОНИК'),
  'pig': ('svinka', 'СВИНКА'),
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

CardModel other(String image, String key) => CardModel(
  id: image,
  sound: image.toUpperCase(),
  text: '',
  emoji: '',
  image: image,
  audioKey: key,
  colorBg: Colors.white,
  colorAccent: Colors.teal,
);

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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HideSeekScreen(
            cards: [for (final image in animals.keys) animal(image)],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the friend stand, hide, and the question be asked.
  Future<void> untilAsked(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(seconds: 1));
  }

  String imageOf(String? audioKey) =>
      animals.entries.firstWhere((e) => e.value.$1 == audioKey).key;

  Finder places() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('place-'),
  );

  /// The place the friend [image] is behind.
  Finder placeOf(String image) => find.ancestor(
    of: find.byKey(ValueKey('hider-$image')),
    matching: places(),
  );

  /// A place with nobody behind it.
  Finder emptyPlace() => find.byWidget(
    places().evaluate().firstWhere((e) {
      return find
          .descendant(
            of: find.byWidget(e.widget),
            matching: find.byType(AnimalFriendArt),
          )
          .evaluate()
          .isEmpty;
    }).widget,
  );

  group('hideSeekPool', () {
    test('only the clay friends that can hide, with a recorded name', () {
      final pack = PackModel(
        id: 'animals',
        title: 'Тваринки',
        icon: '',
        color: Colors.teal,
        isLocked: false,
        isFree: true,
        cards: [
          animal('cat'),
          animal('cow'),
          other('fish', 'ribka'), // a friend, but it does not hide in a bush
          other('bunny', 'zaichik'), // no clay friend to show
        ],
      );
      expect(hideSeekPool(pack).map((c) => c.id), ['cat', 'cow']);
    });
  });

  group('what Bloom says', () {
    test('keeps the name in the nominative', () {
      final cow = animal('cow');
      expect(hideSeekHiding(cow, isEn: false), 'Корова ховається!');
      expect(hideSeekWhere(cow, isEn: false), 'Де корова?');
      expect(hideSeekHere(cow, isEn: false), 'Ось корова!');
    });
  });

  testWidgets('one friend is named, hides behind one of two places, and is '
      'asked for', (tester) async {
    await pumpGame(tester);
    // Standing up, named.
    expect(words, hasLength(1));
    final image = imageOf(words.single);
    expect(find.text(hideSeekHiding(animal(image), isEn: false)), findsOne);
    expect(places(), findsNWidgets(2));
    expect(find.byType(AnimalFriendArt), findsOneWidget);
    expect(find.byType(BloomMascot), findsOneWidget);

    await untilAsked(tester);
    expect(find.text(hideSeekWhere(animal(image), isEn: false)), findsOne);
    expect(words, [words.first, words.first]);
    expect(spoken, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty place is not a failure: the word again, then a hint', (
    tester,
  ) async {
    await pumpGame(tester);
    await untilAsked(tester);
    final image = imageOf(words.last);
    final asked = words.length;

    await tester.tap(emptyPlace());
    await tester.pump();
    expect(find.text('Послухай ще раз'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(words.length, asked + 1);
    expect(spoken, isEmpty);

    await tester.tap(emptyPlace());
    await tester.pump();
    expect(find.text('Дивись, я підкажу'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(placeOf(image));
    await tester.pump();
    expect(find.text(hideSeekHere(animal(image), isEn: false)), findsOne);
    expect(spoken, [animals[image]!.$1]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('five friends found end the game with the celebration', (
    tester,
  ) async {
    await pumpGame(tester);
    for (var i = 0; i < HideSeekScreen.rounds; i++) {
      await untilAsked(tester);
      await tester.tap(placeOf(imageOf(words.last)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ще раз'), findsOneWidget);
    expect(events.first, 'game_start:hide_seek');
    expect(events, contains('game_complete:hide_seek'));
    // Never the same friend twice in a row.
    for (var i = 1; i < spoken.length; i++) {
      expect(spoken[i], isNot(spoken[i - 1]));
    }
    await tester.tap(find.text('Готово'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('from three years two friends hide behind three places and '
      'only one is asked for', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
                level: 3,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: HideSeekScreen(
            cards: [for (final image in animals.keys) animal(image)],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(places(), findsNWidgets(3));
    expect(find.byType(AnimalFriendArt), findsNWidgets(2));
    // Nobody is named while both are standing: that would be the answer.
    expect(words, isEmpty);
    expect(find.text('Хто ховається?'), findsOneWidget);
    await untilAsked(tester);
    expect(words, hasLength(1));
    final image = imageOf(words.single);

    // The other friend's place: it pops up to say hello, and is a miss.
    final decoy = tester
        .widgetList<AnimalFriendArt>(find.byType(AnimalFriendArt))
        .firstWhere((a) => a.animal != image)
        .animal;
    await tester.tap(placeOf(decoy));
    await tester.pump();
    expect(find.text('Послухай ще раз'), findsOneWidget);
    expect(spoken, isEmpty);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(placeOf(image));
    await tester.pump();
    expect(spoken, [animals[image]!.$1]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    testWidgets('the places fit $size and are big enough to tap', (
      tester,
    ) async {
      await pumpGame(tester, size: size);
      await untilAsked(tester);
      expect(tester.takeException(), isNull);
      for (final place in places().evaluate()) {
        final rect = tester.getRect(find.byWidget(place.widget));
        expect(rect.width, greaterThanOrEqualTo(96));
        expect(rect.height, greaterThanOrEqualTo(96));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
