import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/bubble_pop_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/services/profile_service.dart';
import 'package:talking_cards/widgets/kid_screen.dart';

import '../helpers/motion.dart';

/// «Лопай бульбашки», wave 1 (docs/design/bubble_pop_redesign.md §5, §8).
///
/// The table of age × device is the contract the round is built from; the
/// two "no punishment" rules (a bubble that escapes, a tap into nothing)
/// are what a toddler feels; the spawn zone keeping clear of Bloom is what
/// stops a bubble from sliding out from under his ears.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BubbleTuning.forLevel — the table of §5', () {
    const cases = <(int, BubbleDeviceClass, int, int, double)>[
      // level, device, target pops, alive, hit slop
      (1, BubbleDeviceClass.phone, 8, 2, 28),
      (1, BubbleDeviceClass.tabletL, 8, 4, 28),
      (2, BubbleDeviceClass.phone, 12, 3, 20),
      (2, BubbleDeviceClass.tabletL, 12, 5, 20),
      (3, BubbleDeviceClass.phone, 20, 3, 12),
      (3, BubbleDeviceClass.tabletL, 20, 6, 12),
    ];
    for (final (level, device, target, alive, slop) in cases) {
      test('L$level on ${device.name}: $target pops, $alive alive, +$slop dp',
          () {
        final t = BubbleTuning.forLevel(level, device);
        expect(t.targetPops, target);
        expect(t.maxAlive, alive);
        expect(t.hitSlop, slop);
      });
    }

    test('L4 shares the L3 preset', () {
      final l3 = BubbleTuning.forLevel(3, BubbleDeviceClass.phone);
      final l4 = BubbleTuning.forLevel(4, BubbleDeviceClass.phone);
      expect(l4.targetPops, l3.targetPops);
      expect(l4.minDiameter, l3.minDiameter);
      expect(l4.popDuration, l3.popDuration);
    });

    test('the smallest bubble anywhere is still a 72 dp target', () {
      for (final level in [1, 2, 3]) {
        for (final device in BubbleDeviceClass.values) {
          final t = BubbleTuning.forLevel(level, device);
          expect(t.minDiameter, greaterThanOrEqualTo(88),
              reason: 'L$level ${device.name}');
          expect(t.minDiameter + 2 * t.hitSlop, greaterThanOrEqualTo(72));
        }
      }
    });

    test('tablets scale the diameter, not the count of taps', () {
      final phone = BubbleTuning.forLevel(2, BubbleDeviceClass.phone);
      final tablet = BubbleTuning.forLevel(2, BubbleDeviceClass.tabletL);
      expect(tablet.minDiameter, closeTo(phone.minDiameter * 1.35, 0.001));
      expect(tablet.targetPops, phone.targetPops);
    });

    test('device class by the shortest side', () {
      expect(BubbleDeviceClass.of(390), BubbleDeviceClass.phone);
      expect(BubbleDeviceClass.of(599), BubbleDeviceClass.phone);
      expect(BubbleDeviceClass.of(600), BubbleDeviceClass.tabletS);
      expect(BubbleDeviceClass.of(834), BubbleDeviceClass.tabletL);
    });
  });

  group('BubbleStage — spawn zone keeps clear of Bloom', () {
    for (final (name, body, device) in const [
      ('phone', Size(390, 700), BubbleDeviceClass.phone),
      ('iPad landscape', Size(1194, 690), BubbleDeviceClass.tabletL),
    ]) {
      test('100 spawns on $name never overlap his box (+24 dp)', () {
        final rng = Random(7);
        final bloom = BubbleStage.bloomRect(body, device);
        final keepOut = bloom.inflate(BubbleStage.bloomMargin);
        final t = BubbleTuning.forLevel(1, device); // the biggest bubbles
        for (var i = 0; i < 100; i++) {
          final size =
              t.minDiameter + rng.nextDouble() * (t.maxDiameter - t.minDiameter);
          final amp = t.swayMin + rng.nextDouble() * (t.swayMax - t.swayMin);
          final x = BubbleStage.spawnAnchorX(
            rng: rng,
            width: body.width,
            size: size,
            amplitude: amp,
            bloom: bloom,
          );
          // The whole swing, as a horizontal span at any height.
          final left = x - size / 2 - amp;
          final right = x + size / 2 + amp;
          expect(right, lessThanOrEqualTo(keepOut.left),
              reason: 'spawn $i: [$left, $right] vs Bloom $keepOut');
          expect(left, greaterThanOrEqualTo(0));
        }
      });
    }

    test('Bloom sits 16 dp from the right and 24 dp from the bottom', () {
      final r = BubbleStage.bloomRect(const Size(390, 700), BubbleDeviceClass.phone);
      expect(r.width, 112);
      expect(r.right, 390 - 16);
      expect(r.bottom, 700 - 24);
    });
  });

  group('BubblePopScreen', () {
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
    });

    CardModel card(String id) => CardModel(
          id: id,
          sound: id,
          text: id,
          emoji: '🐱',
          colorBg: const Color(0xFFFFFFFF),
          colorAccent: const Color(0xFF000000),
          image: 'missing_$id', // resolves to a picture that fails → emoji
          audioKey: 'no_such_$id', // unknown key → AudioService stays quiet
        );

    final pack = PackModel(
      id: 'animals',
      title: 'Animals',
      icon: '🐱',
      color: const Color(0xFF6C63FF),
      isLocked: false,
      isFree: true,
      cards: [for (var i = 0; i < 12; i++) card('c$i')],
    );

    Widget host({int level = 2}) => ProviderScope(
          overrides: [
            // Synchronous: the round starts post-first-frame and reads the
            // catalogue then — in the app it has been loaded for ages.
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
          child: const MaterialApp(home: BubblePopScreen()),
        );

    /// Pump the screen and let `packsProvider` resolve and the round start.
    Future<void> open(WidgetTester tester, {int level = 2}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(level: level));
      await tester.pump(); // post-frame → _startRound
    }

    group('under MotionMode.test', () {
      useTestMotion();

      testWidgets('pumpAndSettle terminates and the round is on the pill',
          (tester) async {
        await open(tester, level: 1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('0/8'), findsOneWidget);
        expect(find.byType(KidScreen), findsOneWidget);
        // Two pre-seeded bubbles, so the sky is not empty on frame one.
        expect(find.byKey(const ValueKey('bubble_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('bubble_2')), findsOneWidget);
      });

      testWidgets('a miss does not move the counter, but is answered',
          (tester) async {
        await open(tester, level: 1);
        await tester.pumpAndSettle();

        // Just under the header, far from the two pre-seeded bubbles at
        // 55 % and 80 % of the play area — empty sky.
        final body = tester.getRect(find.byType(KidScreen));
        await tester.tapAt(Offset(body.width * 0.5, body.top + 140));
        await tester.pumpAndSettle();

        expect(find.text('0/8'), findsOneWidget);
        expect(FeedbackService.debugLog, contains(FeedbackEvent.emptyTap));
        expect(FeedbackService.debugLog, isNot(contains(FeedbackEvent.bubblePop)));
      });

      testWidgets('a pop on pointer-down counts once', (tester) async {
        await open(tester, level: 1);
        await tester.pumpAndSettle();

        final bubble = find.byKey(const ValueKey('bubble_1'));
        final gesture = await tester.startGesture(tester.getCenter(bubble));
        await tester.pump();
        // Counted before the finger lifts.
        expect(find.text('1/8'), findsOneWidget);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('1/8'), findsOneWidget);
        expect(
          FeedbackService.debugLog.where((e) => e == FeedbackEvent.bubblePop),
          hasLength(1),
        );
      });
    });

    testWidgets('a bubble past the top edge changes nothing', (tester) async {
      await open(tester, level: 2);
      expect(find.text('0/12'), findsOneWidget);
      expect(find.byKey(const ValueKey('bubble_1')), findsOneWidget);

      // First tick only arms the clock; the second moves the world by
      // 20 s — longer than any L2 crossing (≤ 15 s), shorter than the
      // 50 s round.
      await tester.pump(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));

      expect(find.byKey(const ValueKey('bubble_1')), findsNothing);
      expect(find.byKey(const ValueKey('bubble_2')), findsNothing);
      expect(find.text('0/12'), findsOneWidget);
      expect(FeedbackService.debugLog, isEmpty, reason: 'no sound for an escape');
      expect(tester.takeException(), isNull);

      // Leave the screen so its ticker and Bloom's blink stop.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
