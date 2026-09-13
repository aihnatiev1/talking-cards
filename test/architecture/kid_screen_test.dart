import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-shell rule for the kid zone (architecture-gap-audit
/// 2026-09-13 §1.7 / F6; ux-gap-audit G6).
///
/// `KidScreen` (`lib/widgets/kid_screen.dart`) owns the header of every
/// child-facing screen: a 72 dp back / close in a fixed place, an optional
/// progress pill, a safe area, `DT.bgWarm`. A Material `AppBar` is a 48 dp
/// arrow, a text title a toddler cannot read and a toolbar height that
/// differs per platform — so it is forbidden in the screens below. The
/// parent zone (dashboard, stats, paywall, onboarding) keeps `AppBar`; a
/// parent reads. Source test, same shape as `asset_access_test.dart`.
void main() {
  /// The kid-zone screens migrated in F6. Grow this list when a new child
  /// screen lands; never remove an entry to get a test green.
  const kidZone = [
    'lib/screens/guess_screen.dart',
    'lib/screens/memory_match_screen.dart',
    'lib/screens/odd_one_out_screen.dart',
    'lib/screens/opposite_game_screen.dart',
    'lib/screens/repeat_game_screen.dart',
    'lib/screens/bubble_pop_screen.dart',
    'lib/screens/articulation_screen.dart',
    'lib/screens/coloring_screen.dart',
    'lib/screens/cards_screen.dart',
    'lib/screens/quest_map_screen.dart',
    'lib/screens/kid_word_wall_screen.dart',
    'lib/screens/rewards_screen.dart',
  ];

  String read(String path) => File(path).readAsStringSync();

  test('every kid-zone screen exists', () {
    for (final path in kidZone) {
      expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    }
  });

  test('no AppBar( in the kid zone', () {
    final offenders = [
      for (final path in kidZone)
        if (read(path).contains('AppBar(')) path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Build the screen with KidScreen / KidScreen.game '
          '(lib/widgets/kid_screen.dart). The header — back/close, title '
          'slot, progress pill — is the shell\'s job.',
    );
  });

  test('every kid-zone screen is built on KidScreen', () {
    final missing = [
      for (final path in kidZone)
        if (!read(path).contains('KidScreen')) path,
    ];
    expect(missing, isEmpty,
        reason: 'These screens do not use the shell at all.');
  });

  test('the shell itself has no AppBar and keeps one Scaffold underneath',
      () {
    final shell = read('lib/widgets/kid_screen.dart');
    expect(shell, isNot(contains('AppBar(')));
    // ScaffoldMessenger / Overlay / resizeToAvoidBottomInset still need it.
    expect(shell, contains('Scaffold('));
  });

  test('back / close glyphs live behind the one _ctrlIcon helper', () {
    // The icon system (ux-gap-audit G1) will swap Material glyphs for
    // KidIcon in a single edit — only if nobody else names them.
    final shell = read('lib/widgets/kid_screen.dart');
    expect(shell, contains('_ctrlIcon('));
    final offenders = [
      for (final path in kidZone)
        if (read(path).contains('Icons.arrow_back') ||
            read(path).contains('Icons.close'))
          path,
    ];
    expect(offenders, isEmpty,
        reason: 'Use KidBackButton / KidCloseButton, not a raw glyph.');
  });

  test('the parent zone may keep AppBar', () {
    // Sanity check on the boundary: the rule is about the kid zone, not
    // about the widget. If this ever flips, revisit the list above rather
    // than the rule.
    final parent = read('lib/screens/parent_dashboard_screen.dart');
    expect(parent.contains('AppBar(') || parent.contains('Scaffold('), isTrue);
  });
}
