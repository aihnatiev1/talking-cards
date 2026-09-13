import 'package:flutter/material.dart';

import '../utils/board_theme.dart';
import 'card_back_painter.dart' show CardBackPainter;

/// The mat the cards lie on (docs/design/memory_match_redesign.md §2).
///
/// Three layers of depth make the board feel like a table rather than a
/// Material demo: room ([BoardTheme.bg]) < mat < card. The mat is 14 % of
/// the theme against the back's 20 %, so it never competes with a card; it
/// is completely static, which is why it can live under a `RepaintBoundary`
/// with `shouldRepaint` false.
class BoardMatPainter extends CustomPainter {
  final BoardTheme theme;

  const BoardMatPainter(this.theme);

  /// How far the mat sticks out past the board on a phone / a tablet. On a
  /// phone it may run off the screen edge — the table is bigger than the
  /// screen, and clamping it would look like a torn placemat.
  static const phoneBleed = 16.0;
  static const tabletBleed = 24.0;

  static const _radius = 32.0;
  static const _dash = 8.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    canvas.drawRRect(rrect, Paint()..color = theme.mat);

    // Stitches around the edge: a dashed line, extracted from the rounded
    // rectangle's own metric so the corners stay even.
    final stitch = Paint()
      ..color = theme.ink.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()..addRRect(rrect.deflate(6));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + _dash).clamp(0.0, metric.length)),
          stitch,
        );
        d += _dash + _gap;
      }
    }

    // Four corner doodles, the same star as on the card back.
    final doodle = Paint()..color = theme.seal.withValues(alpha: 0.18);
    const inset = 20.0;
    for (final at in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawPath(CardBackPainter.starPath(at, 5), doodle);
    }
  }

  @override
  bool shouldRepaint(covariant BoardMatPainter old) => old.theme != theme;
}
