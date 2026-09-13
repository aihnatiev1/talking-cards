import 'package:flutter/widgets.dart';

/// How much the UI is allowed to move right now.
///
/// * [full] — the default on a device: every loop and transition plays.
/// * [reduced] — the OS reduce-motion flag (`MediaQuery.disableAnimations`)
///   is on: one-shot transitions collapse to zero duration and idle loops
///   never start; information must still read through colour / icon / text.
/// * [test] — set by widget tests via [MotionPolicy.debugOverride] so that
///   `pumpAndSettle` terminates without every test having to know which
///   widget owns a loop.
enum MotionMode { full, reduced, test }

/// One answer to "should this screen move?" (motion audit 2026-09-13 §7,
/// architecture audit §2 F2).
///
/// Ask it instead of `MediaQuery.disableAnimationsOf` directly: the policy
/// also folds in the test override, so a loop gated here is automatically
/// static under `MotionMode.test` — which is what makes `pumpAndSettle`
/// safe on screens that idle-animate.
final class MotionPolicy {
  const MotionPolicy(this.mode);

  /// Tests set `MotionMode.test` (and reset to null in tearDown) to freeze
  /// every [AmbientLoop] and every `dur()`-gated transition at once.
  /// Ignored outside tests only by convention — never set it in app code.
  static MotionMode? debugOverride;

  /// Resolves the current mode: the override wins, then the OS flag.
  static MotionPolicy of(BuildContext context) {
    final override = debugOverride;
    if (override != null) return MotionPolicy(override);
    return MotionPolicy(
      MediaQuery.disableAnimationsOf(context)
          ? MotionMode.reduced
          : MotionMode.full,
    );
  }

  final MotionMode mode;

  /// One-shot transitions should sit at their end state instead of playing.
  bool get reduce => mode != MotionMode.full;

  /// Collapses [d] to zero when motion is reduced — for `AnimatedContainer`,
  /// `AnimatedSwitcher`, route transitions and the like.
  Duration dur(Duration d) => reduce ? Duration.zero : d;

  /// Whether idle loops (breathing, bobbing, shimmer) may run at all.
  /// Only [AmbientLoop] should need this; everyone else asks [reduce].
  bool get ambient => mode == MotionMode.full;
}

/// Shorthand kept for existing call sites: `MotionPolicy.of(context).reduce`.
bool reduceMotionOf(BuildContext context) => MotionPolicy.of(context).reduce;
