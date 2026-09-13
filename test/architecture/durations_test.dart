import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-owner rule for motion durations (architecture audit
/// 2026-09-13 §1.2 / F1, motion audit §7).
///
/// `DT.motion` (`lib/utils/design_tokens.dart`) is the duration scale —
/// `instant / quick / base / enter / slow / celebrate` plus the route,
/// sheet and overlay pairs. A scale only becomes a *contract* when a widget
/// cannot quietly pick 180 ms because 220 felt slow that afternoon; the
/// audit counted 40-odd hand-written millisecond values across the UI,
/// which is why no two tiles pressed alike. Dart has no way to forbid a
/// `Duration(milliseconds: …)` literal outside one file, so a source test
/// is the honest substitute — same shape as `design_tokens_test.dart`.
///
/// The tree did not start clean. Files that still write a literal are
/// listed below; the list is **shrink-only**: remove an entry when the file
/// is clean, never add one. A new widget or screen reads `DT.motion.quick`
/// (or `DT.pressDownMs` / `pressUpMs` for a press) or adds a named step to
/// `DTMotion`.
void main() {
  /// Only the kid-facing UI layers are held to the scale. `lib/services`
  /// (audio fades, purchase backstops, notification schedules) and
  /// `lib/providers` are timing, not motion.
  const uiDirs = ['lib/widgets', 'lib/screens', 'lib/tabs'];

  final dart = [
    for (final dir in uiDirs)
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  /// Files that still build `Duration(milliseconds: …)` literals
  /// (35 on 2026-09-13).
  ///
  /// shrink-only: remove an entry when the file is clean, never add.
  ///
  /// Three kinds live here. Painters and reward moments (`bubble_pop`,
  /// `card_reveal_screen`) may keep a stagger or two that is genuinely
  /// choreography, but the base beats should still come from `DT.motion`
  /// (the celebration beats already do — see `Celebration`). Idle loops
  /// (`daily_hero_card`, `streak_chip`, `pack_grid_card` shimmer) hand a
  /// `period` to `AmbientLoop` — a `DTMotion.ambient*` step is the way out.
  /// Everything else is plain migration debt.
  const durationLiteralDebt = {
    'lib/screens/articulation_screen.dart',
    'lib/screens/bubble_pop_screen.dart',
    'lib/screens/card_reveal_screen.dart',
    'lib/screens/cards_screen.dart',
    'lib/screens/coloring_screen.dart',
    'lib/screens/guess_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/kid_word_wall_screen.dart',
    'lib/screens/memory_match_screen.dart',
    'lib/screens/odd_one_out_screen.dart',
    'lib/screens/onboarding_screen.dart',
    'lib/screens/opposite_game_screen.dart',
    'lib/screens/paywall_screen.dart',
    'lib/screens/quest_map_screen.dart',
    'lib/screens/repeat_game_screen.dart',
    'lib/screens/splash_screen.dart',
    'lib/tabs/games_tab.dart',
    'lib/tabs/packs_tab.dart',
    'lib/widgets/activity_chart.dart',
    'lib/widgets/bubble_pop.dart',
    'lib/widgets/daily_hero_card.dart',
    'lib/widgets/flash_card.dart',
    'lib/widgets/pack_grid_card.dart',
    'lib/widgets/playful_navigation_bar.dart',
    'lib/widgets/quest_journey_map.dart',
    'lib/widgets/speaker_button.dart',
    'lib/widgets/streak_chip.dart',
    'lib/widgets/swipe_hint.dart',
    'lib/widgets/treasure_card.dart',
  };

  /// Matches the literal however the formatter wrapped it — including
  /// `Duration(\n  milliseconds: 220,\n)` — so a line break cannot hide one.
  final literal = RegExp(r'Duration\(\s*milliseconds:');
  bool rawDuration(String s) => literal.hasMatch(s);

  List<String> offenders() => [
        for (final f in dart)
          if (!durationLiteralDebt.contains(f.path) &&
              rawDuration(f.readAsStringSync()))
            f.path,
      ];

  /// Entries that no longer violate — the list must shrink to match, so
  /// that a cleaned file cannot quietly regress behind a stale allowance.
  List<String> stale() => [
        for (final path in durationLiteralDebt)
          if (!File(path).existsSync() ||
              !rawDuration(File(path).readAsStringSync()))
            path,
      ];

  group('Duration(milliseconds: literals in the UI layers', () {
    test('appear only in the shrink-only debt list', () {
      expect(
        offenders(),
        isEmpty,
        reason: 'Read a step from DT.motion (quick / base / enter / slow / '
            'celebrate, or the route/sheet/overlay pairs), or DT.pressDownMs '
            '/ DT.pressUpMs for a press. Do not add this file to '
            'durationLiteralDebt — that list only shrinks.',
      );
    });

    test('the debt list has no stale entries', () {
      expect(
        stale(),
        isEmpty,
        reason: 'These files are clean now — remove them from '
            'durationLiteralDebt so they stay clean.',
      );
    });

    test('every debt entry lives in a guarded directory', () {
      // A typo'd path would be caught as stale, but a path outside
      // lib/widgets|screens|tabs would silently allow nothing at all.
      expect(
        durationLiteralDebt.where(
          (p) => !uiDirs.any((d) => p.startsWith('$d/')),
        ),
        isEmpty,
      );
    });
  });

  test('the motion scale lives in design_tokens.dart, and KidTap reads it',
      () {
    // The two foundations F7 leans on must themselves be on the scale:
    // DTMotion is the owner, and the press widget — the most-instantiated
    // animation in the app — takes its beats from DT.
    final tokens = File('lib/utils/design_tokens.dart').readAsStringSync();
    expect(tokens, contains('class DTMotion'));
    final kidTap = File('lib/widgets/kid_tap.dart').readAsStringSync();
    expect(kidTap, isNot(matches(literal)),
        reason: 'KidTap sets the press language for every tile; its '
            'durations come from DT.pressDownMs / DT.pressUpMs.');
    expect(kidTap, contains('DT.pressDownMs'));
  });
}
