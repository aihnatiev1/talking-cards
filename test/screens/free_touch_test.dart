import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/screens/free_touch_screen.dart';
import 'package:talking_cards/services/analytics_service.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';

import '../helpers/motion.dart';

const names = {
  'kotik': 'КОТИК',
  'sobachka': 'СОБАЧКА',
  'korova': 'КОРОВА',
  'konik': 'КОНИК',
  'svinka': 'СВИНКА',
  'kachechka': 'КАЧЕЧКА',
};

final cards = [
  for (final e in names.entries)
    CardModel(
      id: e.key,
      sound: e.value,
      text: '',
      emoji: '',
      image: e.key,
      audioKey: e.key,
      colorBg: Colors.white,
      colorAccent: Colors.teal,
    ),
];

void main() {
  useTestMotion();

  final words = <String?>[];
  final events = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    words.clear();
    events.clear();
    AudioService.debugWordSink = words.add;
    AnalyticsService.debugSink = (name, params) {
      if (name.startsWith('game_')) events.add('$name:${params['game_id']}');
    };
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    AudioService.debugWordSink = null;
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
        child: MaterialApp(home: FreeTouchScreen(cards: cards)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder board() => find.byKey(const ValueKey('free-touch-board'));

  Finder pictures() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('picture-'),
  );

  /// A finger down and up at [at], in the board's own coordinates.
  Future<void> touch(WidgetTester tester, Offset at) async {
    final origin = tester.getTopLeft(board());
    final gesture = await tester.startGesture(origin + at);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a touch anywhere makes a picture there and says its word', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(find.text('Торкнись будь-де'), findsOneWidget);
    expect(pictures(), findsNothing);

    await touch(tester, const Offset(180, 300));
    expect(pictures(), findsOneWidget);
    expect(words, hasLength(1));
    final origin = tester.getTopLeft(board());
    expect(tester.getCenter(pictures()), origin + const Offset(180, 300));
    // Bloom says the word too.
    expect(
      find.text(
        '${names[words.single]![0]}'
        '${names[words.single]!.substring(1).toLowerCase()}!',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('touching a picture says the same word again, no new picture', (
    tester,
  ) async {
    await pumpGame(tester);
    await touch(tester, const Offset(180, 300));
    await touch(tester, const Offset(190, 310));
    expect(pictures(), findsOneWidget);
    expect(words, [words.first, words.first]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every word comes once before any comes twice', (tester) async {
    await pumpGame(tester);
    final spots = [
      for (var i = 0; i < cards.length; i++)
        Offset(70 + 250.0 * (i % 2), 80 + 190.0 * (i ~/ 2)),
    ];
    for (final spot in spots) {
      await touch(tester, spot);
      // Let it leave, so the next touch is never on a standing picture.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(words.toSet(), names.keys.toSet());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no more than five pictures stand at once', (tester) async {
    await pumpGame(tester);
    final spots = [
      for (var i = 0; i < 7; i++)
        Offset(70 + 250.0 * (i % 2), 70 + 150.0 * (i ~/ 2)),
    ];
    for (final spot in spots) {
      await touch(tester, spot);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(
      pictures().evaluate().length,
      lessThanOrEqualTo(FreeTouchScreen.maxPictures),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a touch at the very edge keeps the picture on the board', (
    tester,
  ) async {
    await pumpGame(tester);
    await touch(tester, const Offset(2, 2));
    final rect = tester.getRect(pictures());
    final area = tester.getRect(board());
    expect(rect.left, greaterThanOrEqualTo(area.left));
    expect(rect.top, greaterThanOrEqualTo(area.top));
    await touch(tester, Offset(area.width - 2, area.height - 2));
    for (final picture in pictures().evaluate()) {
      final r = tester.getRect(find.byWidget(picture.widget));
      expect(r.right, lessThanOrEqualTo(area.right));
      expect(r.bottom, lessThanOrEqualTo(area.bottom));
    }
    // Never on Bloom.
    final bloom = tester.getRect(find.byType(BloomMascot));
    for (final picture in pictures().evaluate()) {
      expect(
        tester.getRect(find.byWidget(picture.widget)).overlaps(bloom),
        isFalse,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ten touches count as a played game, and the play goes on', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(events, ['game_start:free_touch']);
    for (var i = 0; i < FreeTouchScreen.touchesToCount; i++) {
      await touch(tester, const Offset(180, 300));
    }
    expect(events, contains('game_complete:free_touch'));
    expect(events.where((e) => e.startsWith('game_complete')), hasLength(1));
    // No celebration over the board; another touch still works.
    expect(find.text('Ще раз'), findsNothing);
    final said = words.length;
    await touch(tester, const Offset(180, 300));
    expect(words.length, said + 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(390, 844), Size(280, 568)]) {
    testWidgets('fits $size', (tester) async {
      await pumpGame(tester, size: size);
      await touch(tester, const Offset(100, 100));
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(pictures());
      expect(rect.width, greaterThanOrEqualTo(96));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
