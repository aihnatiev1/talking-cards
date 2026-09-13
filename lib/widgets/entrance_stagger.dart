import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utils/design_tokens.dart';
import '../utils/motion.dart';

/// Entrance choreography for a list, a grid or a row of options
/// (ux-gap-audit 2026-09-13 G11, "Entrance-stagger 40 ms/елемент").
///
/// A grid of nine packs that materialises in one frame reads as a page
/// that finished loading. The same grid arriving tile after tile reads as
/// someone laying cards out on a table — which is the only cue a
/// pre-reader gets that these things are *objects*, not a picture of a
/// screen. The beat is [DTMotion.stagger] per item on top of the shared
/// [DTMotion.enter] fade, in the app's one curve (`easeOutCubic`).
///
/// Two rules keep it from becoming a tax:
///
/// * the wave is capped at [DTMotion.staggerCap], so a 21-pack grid still
///   finishes arriving in ~0.6 s rather than 1.1 s;
/// * a [StaggerScope] around the list remembers when the list was built,
///   so a tile that a `GridView.builder` creates *later* — because the
///   child scrolled to it — appears at once instead of replaying a wave
///   that passed seconds ago. Mid-wave items join the animation already in
///   progress rather than restarting it.
///
/// Under reduced motion or [MotionMode.test] the child is returned
/// untouched: no controller, no delay, nothing for `pumpAndSettle` to wait
/// on, and the first frame is already the final frame.
class StaggerScope extends StatefulWidget {
  /// Per-item delay; defaults to [DTMotion.stagger].
  final Duration? step;

  final Widget child;

  const StaggerScope({super.key, this.step, required this.child});

  @override
  State<StaggerScope> createState() => _StaggerScopeState();
}

class _StaggerScopeState extends State<StaggerScope> {
  /// Frame time when the list appeared. Frame timestamps rather than a
  /// `Stopwatch`, so the clock is the same one the animations run on —
  /// including the fake clock a widget test drives.
  late final Duration _bornAt = SchedulerBinding.instance.currentFrameTimeStamp;

  @override
  Widget build(BuildContext context) {
    return _StaggerScopeData(
      step: widget.step ?? DT.motion.stagger,
      bornAt: _bornAt,
      child: widget.child,
    );
  }
}

class _StaggerScopeData extends InheritedWidget {
  final Duration step;
  final Duration bornAt;

  const _StaggerScopeData({
    required this.step,
    required this.bornAt,
    required super.child,
  });

  /// How long ago the list this item belongs to first appeared.
  Duration get elapsed {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final since = now - bornAt;
    return since < Duration.zero ? Duration.zero : since;
  }

  static _StaggerScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StaggerScopeData>();

  // The clock is read once per child, at its first build; a notification
  // would only cause needless rebuilds of an already-scheduled animation.
  @override
  bool updateShouldNotify(_StaggerScopeData oldWidget) => false;
}

/// One item of a staggered list. [index] is its position in the list — the
/// same index the builder already has.
class StaggeredEntrance extends StatefulWidget {
  final int index;

  /// Explicit per-item delay when there is no [StaggerScope] above (a row
  /// of four options built in one go, say). Defaults to [DTMotion.stagger].
  final Duration? step;

  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    this.step,
    required this.child,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  /// Null when this item does not animate: reduced motion, or the wave had
  /// already passed by the time the item was built.
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _scale;
  bool _resolved = false;

  static const double _scaleFrom = 0.94;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MotionPolicy reads MediaQuery, so the decision belongs here rather
    // than in initState — but it is made exactly once per item.
    if (_resolved) return;
    _resolved = true;
    if (MotionPolicy.of(context).reduce) return;

    final scope = _StaggerScopeData.maybeOf(context);
    final step = widget.step ?? scope?.step ?? DT.motion.stagger;
    final cap = DT.motion.staggerCap;
    var delay = step * widget.index;
    if (delay > cap) delay = cap;

    final total = delay + DT.motion.enter;
    final elapsed = scope?.elapsed ?? Duration.zero;
    // Built after this item's own entrance would have finished: it is a
    // scroll-in, not an arrival. Show it.
    if (elapsed >= total) return;

    final controller = AnimationController(vsync: this, duration: total);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: DT.motion.standard,
      ),
    );
    _fade = curve;
    _scale = Tween<double>(begin: _scaleFrom, end: 1).animate(curve);
    _controller = controller;
    // Join the wave where it already is instead of starting it over.
    controller.value = elapsed.inMicroseconds / total.inMicroseconds;
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    final scale = _scale;
    if (fade == null || scale == null) return widget.child;
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}
