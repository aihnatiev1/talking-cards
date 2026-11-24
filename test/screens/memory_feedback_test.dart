import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/memory_match_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/kid_tap.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  const cat = CardModel(
    id: 'cat',
    sound: 'КОТИК',
    text: '',
    emoji: '',
    image: 'cat',
    audioKey: 'sc07',
    colorBg: Colors.white,
    colorAccent: Colors.teal,
  );
  const pack = PackModel(
    id: 'animals',
    title: 'Тварини',
    icon: '',
    color: Colors.teal,
    isLocked: false,
    isFree: true,
    cards: [cat],
  );
  final words = <String?>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    words.clear();
    AudioService.debugWordSink = words.add;
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
  });
  Finder tiles() =>
      find.descendant(of: find.byType(GridView), matching: find.byType(KidTap));

  testWidgets('the cue follows the first card and the completed pair', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MemoryMatchScreen(pack: pack, cards: [cat], pairCount: 1),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Відкрий дві картки'), findsOneWidget);
    await tester.tap(tiles().first);
    await tester.pump();
    expect(find.text('Де така сама?'), findsOneWidget);
    await tester.tap(tiles().last);
    await tester.pump();
    expect(find.text('Усі пари знайдено!'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quick taps schedule only the latest word cue', (tester) async {
    MotionPolicy.debugOverride = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MemoryMatchScreen(pack: pack, cards: [cat], pairCount: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    words.clear();
    await tester.tap(tiles().first);
    await tester.tap(tiles().last);
    await tester.pump(const Duration(milliseconds: 130));
    expect(words, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(words, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('found pair visual preview', (tester) async {
    await pumpGolden(
      tester,
      const MemoryMatchScreen(pack: pack, cards: [cat], pairCount: 1),
      wrap: (host) => ProviderScope(child: host),
    );
    await tester.tap(tiles().first);
    await tester.pump();
    await tester.tap(tiles().last);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('../goldens/images/memory_found_pair.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: !Platform.isMacOS);
}
