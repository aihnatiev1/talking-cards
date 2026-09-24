import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-owner rule for design tokens (F1, architecture-gap-audit
/// 2026-09-13 §1.1).
///
/// `DT` in `lib/utils/design_tokens.dart` is the palette, the type scale and
/// the motion scale. A token file only becomes a *contract* when nothing else
/// may mint a raw colour or name the kid font — otherwise every screen grows
/// its own cream, its own indigo, its own `'Nunito'` TextStyle, and the app
/// stops looking like one author. Dart has no way to say "only this file may
/// call `Color(0x…)`", so a source test is the honest substitute, modelled on
/// `asset_access_test.dart`.
///
/// The tree did not start clean. Files that violate today are listed below;
/// the list is **shrink-only**: remove an entry when the file is clean, never
/// add one. A new file that needs a colour reads a token or adds one to `DT`.
void main() {
  const tokens = 'lib/utils/design_tokens.dart';

  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Files that still build raw `Color(0x…)` literals (27 on 2026-09-13,
  /// 21 after F6).
  ///
  /// shrink-only: remove an entry when the file is clean, never add.
  ///
  /// Two kinds live here. Art painters (`bloom_mascot`,
  /// `quest_journey_map` landscape, `bubble_pop`) may keep a handful of
  /// scene colours that are genuinely not UI roles — even those should move
  /// to a `DT` palette (`DT.confetti`, `DT.bloom…`) so the golden tests in
  /// F7 have one source. Everything else is plain migration debt.
  const colorLiteralDebt = {
    'lib/screens/quest_map_screen.dart',
    'lib/services/whatsnew_service.dart',
    'lib/widgets/bubble_pop.dart',
    'lib/widgets/playful_navigation_bar.dart',
    'lib/widgets/quest_journey_map.dart',
  };

  /// Files that still spell the kid font by name instead of `DT.kidFont`
  /// (or, better, one of the `DT.display / h1 / h2 / tileTitle` styles).
  ///
  /// shrink-only: remove an entry when the file is clean, never add.
  const fontLiteralDebt = <String>{};

  List<String> offenders(
    bool Function(String source) hasProblem, {
    required Set<String> debt,
  }) =>
      [
        for (final f in dart)
          if (f.path != tokens &&
              !debt.contains(f.path) &&
              hasProblem(f.readAsStringSync()))
            f.path,
      ];

  /// Entries that no longer violate — the list must shrink to match, so
  /// that a cleaned file cannot quietly regress behind a stale allowance.
  List<String> stale(
    bool Function(String source) hasProblem, {
    required Set<String> debt,
  }) =>
      [
        for (final path in debt)
          if (!File(path).existsSync() ||
              !hasProblem(File(path).readAsStringSync()))
            path,
      ];

  bool rawColor(String s) => s.contains('Color(0x');
  bool rawKidFont(String s) => s.contains("'Nunito'");

  group('Color(0x literals', () {
    test('appear only in design_tokens.dart and the shrink-only debt list',
        () {
      expect(
        offenders(rawColor, debt: colorLiteralDebt),
        isEmpty,
        reason: 'Read a DT token (DT.brand, DT.coral, PackPalette.of(...)) '
            'or add a named one to lib/utils/design_tokens.dart. Do not add '
            'this file to colorLiteralDebt — that list only shrinks.',
      );
    });

    test('the debt list has no stale entries', () {
      expect(
        stale(rawColor, debt: colorLiteralDebt),
        isEmpty,
        reason: 'These files are clean now — remove them from '
            'colorLiteralDebt so they stay clean.',
      );
    });
  });

  group("'Nunito' literal", () {
    test('appears only in design_tokens.dart and the shrink-only debt list',
        () {
      expect(
        offenders(rawKidFont, debt: fontLiteralDebt),
        isEmpty,
        reason: 'Use DT.kidFont, or one of DT.display / h1 / h2 / tileTitle. '
            'Do not add this file to fontLiteralDebt — that list only shrinks.',
      );
    });

    test('the debt list has no stale entries', () {
      expect(
        stale(rawKidFont, debt: fontLiteralDebt),
        isEmpty,
        reason: 'These files are clean now — remove them from '
            'fontLiteralDebt so they stay clean.',
      );
    });
  });

  test('constants.dart is gone and nothing spells its aliases', () {
    // kAccent & co. were legacy aliases of DT tokens (road-to-9 F1: "влити
    // constants.dart у DT"). One name per colour now — a second spelling
    // is where a second value creeps in.
    expect(File('lib/utils/constants.dart').existsSync(), isFalse);
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r'\b(kAccent|kSoundRed|kTeal|kStreakOrange)\b')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'Use DT.brand / DT.soundRed / DT.teal / DT.streakOrange.');
  });

  test('main.dart takes its theme from app_theme.dart', () {
    // The second background colour (#FAF8F5 vs DT.bgWarm) was born from an
    // inline ThemeData in main.dart. One builder, one background.
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('buildAppTheme()'));
    expect(source, isNot(contains('ThemeData(')),
        reason: 'Edit lib/utils/app_theme.dart instead.');
  });
}
