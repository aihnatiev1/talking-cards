import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/motion.dart';

/// How the pieces travel.
enum ConfettiMode {
  /// Radially out of [ConfettiBurst.origin], with a little gravity.
  burst,

  /// Fall from above the top edge across the whole width.
  rain,
}

/// The one confetti in the app (motion audit 2026-09-13 §2.5: there were
/// three painters with two palettes).
///
/// Pieces are precomputed once, painted with a single reused [Paint] inside
/// a [RepaintBoundary] so the card and buttons above are not redrawn at
/// 60 fps along with them, wrapped in [IgnorePointer], and always one-shot:
/// the controller runs `forward()` once and the widget paints nothing when
/// it is done.
///
/// Two ways to drive it:
///  * standalone — leave [progress] null and the widget owns a controller
///    (used by `ConfettiOverlayMixin` for the in-game micro burst);
///  * choreographed — pass [progress] (0→1) from a parent's master
///    controller, as `Celebration` does, so a scene has one clock.
///
/// Under reduced motion a standalone burst jumps straight to "done"; a
/// choreographed one paints whatever its parent decided (the parent is
/// expected not to build it at all).
class ConfettiBurst extends StatefulWidget {
  /// Centre of a [ConfettiMode.burst]; defaults to the upper third of the
  /// screen. Ignored by [ConfettiMode.rain].
  final Offset? origin;
  final ConfettiMode mode;
  final int count;

  /// External 0→1 drive. When set, no controller is created here.
  final Animation<double>? progress;

  const ConfettiBurst({
    super.key,
    this.origin,
    this.mode = ConfettiMode.burst,
    this.count = 20,
    this.progress,
  });

  /// Piece colours — the celebration slice of the brand accents.
  static const palette = [
    DT.coral,
    DT.sunBurst,
    DT.mint,
    DT.sky,
    DT.violet,
    DT.peach,
    DT.pink,
  ];

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  late final List<_Piece> _pieces;
  bool _started = false;

  Animation<double> get _progress => widget.progress ?? _own!;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _pieces = List.generate(widget.count, (_) => _Piece(rng, widget.mode));
    if (widget.progress == null) {
      _own = AnimationController(
        vsync: this,
        duration: widget.mode == ConfettiMode.burst
            ? DT.motion.confettiBurst
            : DT.motion.confettiRain,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final own = _own;
    if (_started || own == null) return;
    _started = true;
    // Reduced motion: jump straight to "done" (paints nothing). Callers keep
    // their own sounds, so the win is still announced.
    if (MotionPolicy.of(context).reduce) {
      own.value = 1.0;
    } else {
      own.forward();
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            if (t >= 1.0) return const SizedBox.shrink();
            return CustomPaint(
              size: MediaQuery.sizeOf(context),
              painter: _ConfettiPainter(
                pieces: _pieces,
                progress: t,
                mode: widget.mode,
                origin: widget.origin,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One precomputed piece. Fields double up between modes: in a burst
/// `angle`/`speed` are polar velocity; in rain `x` is the start column and
/// `speed` the fall rate.
class _Piece {
  final double angle;
  final double speed;
  final double size;
  final double x;
  final double drift;
  final double spin;
  final Color color;

  _Piece(Random rng, ConfettiMode mode)
      : angle = rng.nextDouble() * 2 * pi,
        speed = mode == ConfettiMode.burst
            ? 100 + rng.nextDouble() * 200
            : 0.5 + rng.nextDouble(),
        size = mode == ConfettiMode.burst
            ? 4 + rng.nextDouble() * 6
            : 4 + rng.nextDouble() * 8,
        x = rng.nextDouble(),
        drift = (rng.nextDouble() - 0.5) * 0.15,
        spin = (rng.nextDouble() - 0.5) * 12,
        color = ConfettiBurst
            .palette[rng.nextInt(ConfettiBurst.palette.length)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double progress;
  final ConfettiMode mode;
  final Offset? origin;

  /// One paint for every piece; only its colour changes.
  final Paint _paint = Paint();

  _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.mode,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final from = origin ?? Offset(size.width / 2, size.height / 3);

    for (final p in pieces) {
      final double x;
      final double y;
      final double rotation;
      switch (mode) {
        case ConfettiMode.burst:
          final dist = p.speed * t;
          x = from.dx + cos(p.angle) * dist;
          y = from.dy + sin(p.angle) * dist + 50 * t * t; // gravity
          rotation = t * p.speed * 0.02;
        case ConfettiMode.rain:
          y = -20 + (size.height + 40) * t * p.speed;
          x = p.x * size.width + p.drift * size.width * t;
          rotation = t * p.spin;
      }

      _paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        _paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
