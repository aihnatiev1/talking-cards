import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'card_back_painter.dart' show CardBackPainter;

/// The local reward of one matched card (memory_match_redesign §4): a ring
/// that opens and closes around the card and six sparks thrown from its
/// centre.
///
/// It replaces the full-screen confetti that used to fire on *every* pair —
/// a whole-screen effect for a micro success leaves nothing for the end of
/// the round, and it covers the board the child is trying to remember.
/// Twelve particles at most, one painter, one controller, and it removes
/// itself through [onDone]. Never built under reduced motion: the match
/// still reads through the seal frame and the star sticker.
class SparkleBurst extends StatefulWidget {
  /// The board's ink — the ring and four of the six sparks.
  final Color color;

  /// Called when the burst has finished so the host can drop the widget.
  final VoidCallback? onDone;

  const SparkleBurst({super.key, required this.color, this.onDone});

  static const particles = 6;

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: DT.motion.memorySparkle)
        ..forward().whenComplete(() {
          if (mounted) widget.onDone?.call();
        });

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklePainter(progress: _ctrl, color: widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _SparklePainter({required this.progress, required this.color})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || size.isEmpty) return;
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * 0.62;

    // The ring: 0 → .7 → 0 just outside the card's own frame.
    final ringT = (t / 0.6).clamp(0.0, 1.0);
    final ringAlpha = (1 - (ringT * 2 - 1).abs()) * 0.7;
    if (ringAlpha > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(-4),
          Radius.circular(CardBackPainter.radiusOf(size.width) + 4),
        ),
        Paint()
          ..color = color.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Six sparks: four stars in the board's ink, two white dots, thrown
    // radially with a little gravity and faded out.
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < SparkleBurst.particles; i++) {
      final a = -math.pi / 2 + i * (2 * math.pi / SparkleBurst.particles);
      final travel = reach * Curves.easeOutCubic.transform(t);
      final at =
          centre +
          Offset(math.cos(a) * travel, math.sin(a) * travel) +
          Offset(0, reach * 0.35 * t * t);
      final isStar = i % 3 != 2;
      final paint = Paint()
        ..color = (isStar ? color : DT.surfaceWhite).withValues(
          alpha: fade * (isStar ? 0.9 : 0.8),
        );
      if (isStar) {
        final r = size.shortestSide * (0.03 + 0.015 * (i % 2));
        canvas.drawPath(CardBackPainter.starPath(at, r), paint);
      } else {
        canvas.drawCircle(at, size.shortestSide * 0.018, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}
