import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-owner rule for child feedback (architecture audit
/// 2026-09-13 §1.5–1.6, F3).
///
/// `FeedbackService` in `lib/services/feedback_service.dart` is the table
/// that turns an event (`tap`, `correct`, `wrong`, `roundDone`, …) into a
/// sound, a pitch and a haptic. It only stays a table if nothing else may
/// call `HapticFeedback.*` or `playSfx(` directly — otherwise a correct
/// answer is medium+ding in one game and light+ding in the next, which is
/// exactly how we got 42 hand-placed haptics in 23 files. Dart has no
/// `internal` visibility and the project runs no custom lints, so a source
/// test is the honest substitute (modelled on `asset_access_test.dart`).
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// The single owner of haptics.
  const hapticOwner = 'lib/services/feedback_service.dart';

  /// Files that still call `HapticFeedback.*` themselves. Every remaining
  /// call is either a parent gesture (long-press, gate, settings) or a
  /// screen not yet migrated. **Shrink-only**: remove an entry when the
  /// file is clean, never add one — a new child action names a
  /// `FeedbackEvent` instead.
  const hapticDebt = {
    // Parent-zone long-press on the title (cards_screen._showParentTools).
    'lib/screens/cards_screen.dart',
    // Articulation practice: record/stop accents, not yet mapped.
    'lib/screens/articulation_screen.dart',
    // Word-wall selection click (parent-facing sheet).
    'lib/screens/kid_word_wall_screen.dart',
    // Onboarding selection clicks + finish accent.
    'lib/screens/onboarding_screen.dart',
    // Profile picker selection clicks.
    'lib/screens/profile_selector_screen.dart',
    // Quest map node selection.
    'lib/screens/quest_map_screen.dart',
    // Word-wall chip on the packs tab (opens a parent sheet).
    'lib/tabs/packs_tab.dart',
    // Flip and favourite (long-press) accents on the flash card.
    'lib/widgets/flash_card.dart',
    // Long-press wobble on a pack tile.
    'lib/widgets/pack_grid_card.dart',
    // Keypad press inside the parental gate — a parent's finger.
    'lib/widgets/parental_gate.dart',
  };

  /// Files that may call `playSfx(` / `playSfxVaried(`: the service that
  /// owns the table and the audio layer that defines the methods.
  const sfxOwners = {
    hapticOwner,
    'lib/services/audio_service.dart',
  };

  bool haptics(String s) => s.contains('HapticFeedback.');
  bool sfx(String s) => s.contains('playSfx(') || s.contains('playSfxVaried(');

  List<String> offenders(
    bool Function(String source) hasProblem, {
    required Set<String> allowed,
  }) =>
      [
        for (final f in dart)
          if (!allowed.contains(f.path) && hasProblem(f.readAsStringSync()))
            f.path,
      ];

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

  group('HapticFeedback.', () {
    test('is called only by FeedbackService and the shrink-only debt list',
        () {
      expect(
        offenders(haptics, allowed: {hapticOwner, ...hapticDebt}),
        isEmpty,
        reason: 'Call FeedbackService.instance.event(FeedbackEvent.x) '
            'instead. Do not add this file to hapticDebt — that list only '
            'shrinks.',
      );
    });

    test('the debt list has no stale entries', () {
      expect(
        stale(haptics, debt: hapticDebt),
        isEmpty,
        reason: 'These files no longer call HapticFeedback themselves — '
            'remove them from hapticDebt so they stay clean.',
      );
    });

    test('FeedbackService itself is the one place the platform is asked',
        () {
      final source = File(hapticOwner).readAsStringSync();
      expect(haptics(source), isTrue);
    });
  });

  group('playSfx( / playSfxVaried(', () {
    test('are called only by FeedbackService', () {
      expect(
        offenders(sfx, allowed: sfxOwners),
        isEmpty,
        reason: 'Name the event: FeedbackService.instance.event(...). A new '
            'sound gets a row in the table, not a call site.',
      );
    });
  });

  test('the old celebration surfaces are gone', () {
    // Three overlays with two confetti painters became one Celebration.
    expect(File('lib/widgets/celebration_overlay.dart').existsSync(), isFalse,
        reason: 'Use celebrate(tier: CelebrationTier.pack).');
    expect(
      offenders((s) => s.contains('showGeneralDialog('), allowed: const {}),
      isEmpty,
      reason: 'Celebrations go through KidRoutes.overlay via celebrate().',
    );
  });
}
