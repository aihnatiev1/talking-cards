import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/streak_provider.dart';
import 'package:talking_cards/screens/rewards_screen.dart';
import 'package:talking_cards/services/feedback_service.dart';

import '../helpers/motion.dart';

/// «Що вже твоє і що відкриється за наступне коротке заняття»
/// (experience audit 2026-09-13, п. 26).
///
/// The album showed what the child *has*; the empty pages said "someday".
/// One goal — the next sticker, on the streak the album already runs on —
/// now sits above the sheet. It must disappear the moment the album is
/// full: a finished collection ends on the stickers, not on a bar that can
/// never fill.
void main() {
  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  setUp(() {
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
  });

  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
  });

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

  testWidgets('an unfinished album shows the next goal', (tester) async {
    await pumpAlbum(tester, streak: 7, rewards: const ['🦄', '🐉']);

    expect(find.byKey(const ValueKey('next-goal')), findsOneWidget);

    // It is the *next* sticker (the rainbow at 14 days), not some new
    // currency: the track is filled by the streak the album already runs on.
    final track = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('next-goal-track')),
    );
    expect(track.value, closeTo(7 / 14, 0.001));

    // A child-sized target that explains itself to an adult without
    // printing a paragraph on a toddler's page (rule 4).
    expect(tester.getSize(find.byKey(const ValueKey('next-goal'))).height,
        greaterThanOrEqualTo(72));
    await tester.tap(find.byKey(const ValueKey('next-goal')));
    await tester.pumpAndSettle();
    expect(find.text('Ще 7 днів гри — і Веселка чекає'), findsOneWidget);
  });

  testWidgets('a brand-new album points at the first sticker', (tester) async {
    await pumpAlbum(tester, streak: 0, rewards: const []);
    expect(find.byKey(const ValueKey('next-goal')), findsOneWidget);
    final track = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('next-goal-track')),
    );
    // Never empty: the road has a beginning even on day zero.
    expect(track.value, greaterThan(0));
    expect(track.value, lessThan(1));
  });

  testWidgets('a full album shows no next goal', (tester) async {
    await pumpAlbum(
      tester,
      streak: 40,
      rewards: [for (final m in milestones) m.id],
    );
    expect(find.byKey(const ValueKey('next-goal')), findsNothing);
    // The stickers themselves are still all there.
    for (final m in milestones) {
      expect(find.byKey(ValueKey('sticker_${m.days}')), findsOneWidget);
    }
  });
}
