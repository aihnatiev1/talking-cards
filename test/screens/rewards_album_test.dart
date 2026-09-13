import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/kid_word_wall_screen.dart';
import 'package:talking_cards/screens/rewards_screen.dart';
import 'package:talking_cards/screens/stats_screen.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/app_icons.dart';

import '../helpers/motion.dart';

/// The sticker album's two answers to a finger, and the one door that must
/// stay shut (ux-gap-audit G14).
///
/// An earned sticker is the only thing on the screen that reacts: it hops
/// and plays the success row. A silhouette is *not* a locked tile — tapping
/// it must be harmless and must never sound like a win. And `StatsScreen`,
/// now a parent-only report, may only be reached through the gate.
void main() {
  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  setUp(() {
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
    SharedPreferences.setMockInitialValues({
      'streak_current': 7,
      'streak_last_date': today(),
      // The unicorn (3 days) and the dragon (7 days) are in the album;
      // the rainbow (14) and the butterfly (30) are still silhouettes.
      'streak_rewards': const ['🦄', '🐉'],
    });
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
  });

  /// The album without its header: no Bloom, so nothing breathes and the
  /// test can pump exact frames of the bounce.
  Future<void> pumpAlbum(WidgetTester tester) async {
    setGoldenSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: RewardsAlbum(showHeader: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder stickerArt(int days) => find.descendant(
        of: find.byKey(ValueKey('sticker_$days')),
        matching: find.byType(AppIconView),
      );

  group('RewardsAlbum', () {
    testWidgets('an earned sticker hops and plays the success row',
        (tester) async {
      await pumpAlbum(tester);

      final before = tester.getSize(stickerArt(3));
      await tester.tap(stickerArt(3));
      // Mid-bounce: the art is painted larger than its layout box.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rect = tester.getRect(stickerArt(3));
      expect(
        rect.width,
        greaterThan(before.width),
        reason: 'the sticker should be scaled up mid-bounce',
      );
      expect(FeedbackService.debugLog, contains(FeedbackEvent.correct));

      await tester.pumpAndSettle();
      expect(tester.getRect(stickerArt(3)).width, closeTo(before.width, 0.5));
    });

    testWidgets('a silhouette is harmless: no bounce, no success',
        (tester) async {
      await pumpAlbum(tester);

      final before = tester.getRect(stickerArt(30));
      await tester.tap(stickerArt(30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The press squeeze of `KidTap` may still be springing back, so the
      // assertion is "never grew", not "identical".
      expect(
        tester.getRect(stickerArt(30)).width,
        lessThanOrEqualTo(before.width + 0.5),
        reason: 'a silhouette does not hop',
      );
      expect(
        FeedbackService.debugLog,
        isNot(contains(FeedbackEvent.correct)),
        reason: 'nothing was won — a silhouette must not cheer',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('earned and unearned stickers are both on the sheet',
        (tester) async {
      await pumpAlbum(tester);
      for (final days in [3, 7, 14, 30]) {
        expect(find.byKey(ValueKey('sticker_$days')), findsOneWidget);
      }
      // No padlock, no question mark anywhere on the page.
      expect(find.text('🔒'), findsNothing);
      expect(find.text('❓'), findsNothing);
    });
  });

  group('treasure box', () {
    testWidgets('opens on the stickers tab when asked', (tester) async {
      setGoldenSurface(tester, const Size(390, 844));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: KidWordWallScreen(initialTab: TreasureTab.stickers),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RewardsAlbum), findsOneWidget);
      expect(find.byKey(const ValueKey('treasure_tab_words')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('treasure_tab_stickers')),
        findsOneWidget,
      );

      // Both tabs are child-sized targets (CLAUDE.md rule 1).
      for (final key in const [
        ValueKey('treasure_tab_words'),
        ValueKey('treasure_tab_stickers'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(72));
        expect(size.width, greaterThanOrEqualTo(72));
      }
    });

    testWidgets('the words tab is one tap away from the stickers',
        (tester) async {
      setGoldenSurface(tester, const Size(390, 844));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: KidWordWallScreen(initialTab: TreasureTab.stickers),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('treasure_tab_words')));
      // No pumpAndSettle: the words tab shows a spinner while
      // `packsProvider` loads its JSON, which never settles under test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RewardsAlbum), findsNothing);
    });
  });

  group('StatsScreen', () {
    testWidgets('is unreachable until the gate is passed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => StatsScreen.open(context, isEn: false),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The gate, not the report.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Для батьків'), findsOneWidget);
      expect(find.byType(StatsScreen), findsNothing);

      // Dismissing the gate leaves the child where they were.
      Navigator.of(tester.element(find.byType(Dialog))).pop(false);
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsNothing);
    });

    test('nothing in the kid zone builds the route by hand', () {
      // `StatsScreen.open` is the gate; a second `const StatsScreen()`
      // somewhere else would quietly re-open the ungated door.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('stats_screen.dart')) continue;
        if (entity.readAsStringSync().contains('StatsScreen()')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Call StatsScreen.open(context, isEn: …) — it asks the '
            'parental gate first (CLAUDE.md rule 7).',
      );
    });
  });
}
