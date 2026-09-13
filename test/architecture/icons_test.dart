import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-icon-language rule for the kid zone (architecture audit
/// 2026-09-13 §1.4 / F5; ux-gap-audit §4 G1, §5.1).
///
/// `AppIcon` + `AppIconView` (`lib/utils/app_icons.dart`, art in
/// `lib/widgets/app_icon_painters.dart`) is the only glyph set a child sees.
/// Three languages side by side — emoji, Material, hand-drawn — were the
/// structural reason the home screen never read as one author. Dart cannot
/// forbid `Icons.` in a directory, so this source test is the honest
/// substitute (same shape as `design_tokens_test.dart`).
///
/// Scope is `lib/widgets` and `lib/tabs`. `lib/screens` is being
/// restructured by another track (Sprint 2 F6) and joins when that lands;
/// the parent zone keeps Material by design.
void main() {
  const uiDirs = ['lib/widgets', 'lib/tabs'];

  final dart = [
    for (final dir in uiDirs)
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  /// Kid-zone files migrated to `AppIconView`. `Icons.` may never return
  /// here — this list only grows as files are migrated.
  const migrated = {
    'lib/utils/app_icons.dart',
    'lib/widgets/app_icon_painters.dart',
    'lib/widgets/speaker_button.dart',
    'lib/widgets/quest_journey_map.dart',
    'lib/widgets/pack_grid_card.dart',
    'lib/widgets/daily_hero_card.dart',
    'lib/widgets/treasure_card.dart',
    'lib/widgets/streak_chip.dart',
    'lib/widgets/playful_navigation_bar.dart',
    'lib/tabs/games_tab.dart',
  };

  /// Files in the guarded directories that still use `Icons.` — parent
  /// sheets, dialogs and rows a child does not tap, plus widgets not yet
  /// migrated (8 on 2026-09-13).
  ///
  /// shrink-only: remove an entry when the file is clean, never add. A new
  /// kid-facing widget reaches for `AppIconView`; a new parent-zone widget
  /// that genuinely needs Material belongs in `lib/screens` or gets a
  /// reason here — and even then the list may not grow.
  const materialDebt = {
    // Parent settings sheet (SettingsActionRow takes IconData), favourites
    // and About; the child-facing icons on this tab are AppIconView.
    'lib/tabs/packs_tab.dart',
    ..._widgetDebt,
  };

  bool material(String s) => s.contains('Icons.');

  test('migrated kid-zone files never use Material Icons', () {
    final offenders = [
      for (final path in migrated)
        if (File(path).existsSync() && material(File(path).readAsStringSync()))
          path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Use AppIconView(AppIcon.x). A glyph that does not exist yet '
          'gets a routine in app_icon_painters.dart, not a Material fallback.',
    );
  });

  test('every migrated file exists (the list is not decorative)', () {
    expect(
      migrated.where((p) => !File(p).existsSync()),
      isEmpty,
    );
  });

  test('Icons. appears only in the shrink-only debt list', () {
    final offenders = [
      for (final f in dart)
        if (!materialDebt.contains(f.path) &&
            !migrated.contains(f.path) &&
            material(f.readAsStringSync()))
          f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Kid-facing: use AppIconView. Do not add this file to '
          'materialDebt — that list only shrinks.',
    );
  });

  test('the debt list has no stale entries', () {
    final stale = [
      for (final path in materialDebt)
        if (!File(path).existsSync() ||
            !material(File(path).readAsStringSync()))
          path,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'These files are clean now — remove them from materialDebt '
          'so they stay clean (and add them to `migrated` if kid-facing).',
    );
  });

  test('no file is both migrated and in debt', () {
    expect(migrated.intersection(materialDebt), isEmpty);
  });

  group('emoji as icon', () {
    /// The old `_categoryIcons` map (label → 💬/🔤/🌍) and the game-tile
    /// `badge: '🎧'` strings were the two places emoji stood in for a
    /// design-system glyph on the home tabs. Their replacements are
    /// `AppIcon` values; the emoji must not come back as a lookup table.
    const categoryEmoji = ['💬', '🔤', '🌍'];
    const gameEmoji = ['🎧', '🧠', '🫧', '🎤', '🔍', '↔️', '👅'];
    const stepEmoji = ['🔊', '🃏', '🗺️'];

    test('packs_tab has no category-emoji map', () {
      final s = File('lib/tabs/packs_tab.dart').readAsStringSync();
      expect(s, isNot(contains('_categoryIcons')));
      for (final e in categoryEmoji) {
        expect(s, isNot(contains("'$e'")),
            reason: 'Category chips render AppIcon.catSpeech/catSounds/'
                'catWorld, not $e.');
      }
      for (final e in stepEmoji) {
        expect(s, isNot(contains("emoji: '$e'")),
            reason: 'DailyTask takes an AppIcon, not $e.');
      }
    });

    test('games_tab has no game-badge emoji', () {
      final s = File('lib/tabs/games_tab.dart').readAsStringSync();
      for (final e in gameEmoji) {
        expect(s, isNot(contains("badge: '$e'")),
            reason: 'Game badges are AppIcon.game*, not $e.');
      }
    });

    test('DailyTask carries an AppIcon, not an emoji string', () {
      final s = File('lib/widgets/daily_hero_card.dart').readAsStringSync();
      expect(s, contains('final AppIcon icon;'));
      expect(s, isNot(contains('final String emoji;')));
    });
  });
}

/// Widgets in `lib/widgets` that still use `Icons.` on 2026-09-13.
/// Part of [materialDebt]; kept separate only so the reasoned entries
/// above stay readable. shrink-only.
const _widgetDebt = {
  'lib/widgets/flash_card.dart',
  'lib/widgets/notification_toggle_tile.dart',
  'lib/widgets/profile_avatar_chip.dart',
  'lib/widgets/settings_action_row.dart',
  'lib/widgets/srs_review_banner.dart',
  'lib/widgets/swipe_hint.dart',
};
