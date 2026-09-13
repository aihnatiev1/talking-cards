import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/rewards_screen.dart';

import '../helpers/motion.dart';

/// The sticker album in its three moments (ux-gap-audit G14): nothing
/// earned, half the sheet, and full.
///
/// The empty state is the one that matters most — it must read as "there
/// is something here to get", four paper silhouettes on the page, and
/// never as a row of padlocks. A drift in the silhouette alpha, a stroke
/// that thickens, an accent that leaks into the unearned state all show up
/// here as one PNG diff.
///
/// State comes from `SharedPreferences` (the provider's own source) with
/// `streak_last_date` set to today, so `recordActivity()` returns early and
/// the count on the header does not depend on when the test runs.
void main() {
  useTestMotion();

  const size = Size(390, 844);

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpAlbum(
    WidgetTester tester, {
    required int streak,
    required List<String> rewards,
  }) async {
    SharedPreferences.setMockInitialValues({
      'streak_current': streak,
      'streak_last_date': today(),
      'streak_rewards': rewards,
    });
    await pumpGolden(
      tester,
      const RewardsAlbum(),
      size: size,
      wrap: (host) => ProviderScope(child: host),
    );
    await tester.pumpAndSettle();
  }

  group('RewardsAlbum', () {
    testWidgets('empty sheet — four silhouettes', (tester) async {
      await pumpAlbum(tester, streak: 1, rewards: const []);
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/rewards_album_empty.png'),
      );
    });

    testWidgets('two stickers earned', (tester) async {
      await pumpAlbum(tester, streak: 7, rewards: const ['🦄', '🐉']);
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/rewards_album_partial.png'),
      );
    });

    testWidgets('full album', (tester) async {
      await pumpAlbum(
        tester,
        streak: 30,
        rewards: const ['🦄', '🐉', '🌈', '🦋'],
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/rewards_album_full.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
