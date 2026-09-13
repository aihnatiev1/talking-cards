import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/motion.dart';

/// The one owner of `repeat()` in the app (architecture audit §2 F2;
/// `test/architecture/motion_test.dart` keeps it that way).
///
/// Every idle loop — a breathing hero, a bobbing chest, a pulsing speaker —
/// used to own its own `AnimationController`, its own reduce-motion `if`
/// and its own stop condition, and 14 of 16 forgot at least one of them
/// (motion audit §2.6). `AmbientLoop` folds those into one widget:
///
/// * it only ticks when [MotionPolicy.of] says `ambient` **and** [enabled];
///   otherwise it renders `builder(context, 0, child)` once and never
///   schedules a frame, so `pumpAndSettle` terminates and reduced-motion
///   users see the rest pose;
/// * it inherits `TickerMode` through its ticker provider, so a loop on a
///   hidden `IndexedStack` tab costs nothing;
/// * [settleAfter] gives a loop a stop condition — "short intro accent, then
///   calm" — and returns it to t = 0 along its own curve instead of snapping;
/// * one controller per instance, disposed with the widget.
///
/// [builder] receives `t` already mapped through [curve] (0 → rest,
/// 1 → peak), so call sites express only amplitude: `1 + 0.02 * t`.
class AmbientLoop extends StatefulWidget {
  /// Time for one pass from rest to peak (and back again when [reverse]).
  final Duration period;

  /// `true` (default) swings 0 → 1 → 0; `false` runs 0 → 1 and wraps, for
  /// cyclic gestures like a hand sliding across a hint pill.
  final bool reverse;

  /// After this much wall-clock time the loop finishes its current pass
  /// and rests at t = 0. `null` loops until disabled or disposed.
  final Duration? settleAfter;

  /// Toggle for loops that answer to app state (a word is being spoken, a
  /// step is the active one). Turning it off stops the loop at rest;
  /// turning it back on restarts — including a fresh [settleAfter] window.
  final bool enabled;

  final Curve curve;

  final Widget Function(BuildContext context, double t, Widget? child) builder;

  /// Pre-built subtree that does not depend on `t` — passed through to
  /// [builder] unchanged so it is not rebuilt every frame.
  final Widget? child;

  const AmbientLoop({
    super.key,
    required this.period,
    required this.builder,
    this.reverse = true,
    this.settleAfter,
    this.enabled = true,
    this.curve = Curves.easeInOut,
    this.child,
  });

  @override
  State<AmbientLoop> createState() => _AmbientLoopState();
}

class _AmbientLoopState extends State<AmbientLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  Timer? _settleTimer;
  bool _settled = false;
  bool _ambient = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is not available in initState, and the OS flag can flip
    // while we are mounted — so the policy is re-read here.
    _ambient = MotionPolicy.of(context).ambient;
    _sync();
  }

  @override
  void didUpdateWidget(covariant AmbientLoop old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _ctrl.duration = widget.period;
    if (!old.enabled && widget.enabled) _settled = false;
    if (old.enabled != widget.enabled ||
        old.reverse != widget.reverse ||
        old.settleAfter != widget.settleAfter ||
        old.period != widget.period) {
      _sync();
    }
  }

  void _sync() {
    final shouldRun = _ambient && widget.enabled && !_settled;
    if (shouldRun) {
      if (!_ctrl.isAnimating) {
        _ctrl.repeat(reverse: widget.reverse);
        _armSettle();
      }
    } else {
      _rest();
    }
  }

  void _armSettle() {
    _settleTimer?.cancel();
    final after = widget.settleAfter;
    if (after == null) return;
    _settleTimer = Timer(after, _settle);
  }

  /// Finish the current pass gracefully, then stay at rest.
  void _settle() {
    _settled = true;
    if (!_ctrl.isAnimating) return;
    final v = _ctrl.value;
    _ctrl.stop();
    if (widget.reverse) {
      // Same speed as the loop itself, so the last breath out is not a snap.
      _ctrl.animateBack(0, duration: widget.period * v);
    } else {
      // A wrapping loop's rest pose is its start; play the pass out and wrap.
      _ctrl.animateTo(1, duration: widget.period * (1 - v)).then((_) {
        if (mounted) _ctrl.value = 0;
      });
    }
  }

  void _rest() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _ctrl.stop();
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, widget.curve.transform(_ctrl.value), child),
    );
  }
}
