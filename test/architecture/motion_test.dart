import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-owner rule for idle loops (architecture audit 2026-09-13
/// §2 F2; motion audit §2.6, §7).
///
/// `repeat()` is how a widget promises to redraw at 60fps until told
/// otherwise — and 14 of the 16 loops we shipped never asked whether the OS
/// reduce-motion flag was on, never stopped, and hung every `pumpAndSettle`
/// that met them. `AmbientLoop` owns the call so that the policy check, the
/// `TickerMode` gate, the stop condition and the disposal happen in one
/// place. A source test is the honest substitute for a lint this project
/// deliberately does not have.
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// The single owner.
  const owner = 'lib/widgets/ambient_loop.dart';

  /// Loops not yet migrated. Shrink-only: entries may be removed, never
  /// added — a new idle animation goes through AmbientLoop.
  const pending = {
    // Owned by another engineer during Sprint 1 (F2a); mascot bounce and
    // hero breath.
    // `repeat(count: 3)` — finite glow; becomes a TweenSequence in F3.
    'lib/screens/card_reveal_screen.dart',
  };

  bool loops(String source) => source.contains('.repeat(');

  test('only AmbientLoop calls repeat()', () {
    final offenders = [
      for (final f in dart)
        if (f.path != owner &&
            !pending.contains(f.path) &&
            loops(f.readAsStringSync()))
          f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Wrap the loop in AmbientLoop (lib/widgets/ambient_loop.dart) '
          'instead of calling repeat() — it gates on MotionPolicy, honours '
          'TickerMode, can settle after an intro accent and disposes itself.',
    );
  });

  test('the pending list only shrinks', () {
    final stale = [
      for (final path in pending)
        if (!File(path).existsSync() || !loops(File(path).readAsStringSync()))
          path,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'These files no longer loop on their own — remove them from '
          '`pending` so nobody can hide a new repeat() behind the entry.',
    );
  });

  test('AmbientLoop itself calls repeat() exactly once', () {
    final source = File(owner).readAsStringSync();
    expect(
      '.repeat('.allMatches(source).length,
      1,
      reason: 'One controller, one loop — keep the owner boring.',
    );
  });
}
