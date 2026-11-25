import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
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
  image: meadowVoices.entries.firstWhere((e) => e.key == key).value.$1,
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

void main() {
  useTestMotion();

  final spoken = <String?>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    spoken.clear();
    AudioService.debugSpeakSink = spoken.add;
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugSpeakSink = null;
  });

  group('who lives on the meadow', () {
    test('without Pro: the five free animals', () {
      final animals = meadowAnimals(
        packs: [soundPack(locked: true)],
        rewards: const {},
      );
      expect(animals.map((a) => a.key), ['cat', 'dog', 'cow', 'horse', 'pig']);
    });

    test(
      'a lesson friend joins — first, with a star, even with a paid voice',
      () {
        final animals = meadowAnimals(
          packs: [soundPack(locked: true)],
          rewards: const {'forest_friends', 'pond_friends'},
        );
        expect(animals.take(2).map((a) => a.key).toSet(), {'owl', 'duck'});
        expect(animals.take(2).every((a) => a.earned), isTrue);
        expect(animals, hasLength(7));
      },
    );

    test('with Pro: all twelve', () {
      final animals = meadowAnimals(
        packs: [soundPack(locked: false)],
        rewards: const {},
      );
      expect(animals, hasLength(12));
    });
  });

  Future<void> pumpMeadow(WidgetTester tester, {bool locked = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MeadowWorld(
              isEn: false,
              animals: meadowAnimals(
                packs: [soundPack(locked: locked)],
                rewards: const {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a tap: the animal speaks, its sound in a cloud, then Bloom '
      'invites the child to say it', (tester) async {
    await pumpMeadow(tester);
    expect(find.text('Торкнись друга й послухай'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meadow-cat')));
    await tester.pump();
    expect(spoken, ['snd_cat']);
    expect(find.text('няв-няв'), findsOneWidget);
    // The recording ends (the sink returns at once): the invitation.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('А ти скажи: «няв-няв»!'), findsOneWidget);
    // A while later the meadow is quiet again.
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Торкнись друга й послухай'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the meadow walks sideways to the last friend and the pond', (
    tester,
  ) async {
    await pumpMeadow(tester, locked: false);
    expect(
      find.byKey(const ValueKey('meadow-owl')).hitTestable(),
      findsNothing,
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('meadow-fish')),
      find.byKey(const ValueKey('meadow-scroll')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meadow-owl')), findsOneWidget);
    // No two animals overlap, and none stands in the water.
    final rects = [
      for (final key in meadowVoices.keys)
        tester.getRect(find.byKey(ValueKey('meadow-$key'))),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
    final pond = tester.getRect(find.byKey(const ValueKey('meadow-fish')));
    for (final r in rects) {
      expect(r.overlaps(pond), isFalse);
    }
    await tester.tap(find.byKey(const ValueKey('meadow-fish')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // The fish has no voice.
    expect(spoken, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
