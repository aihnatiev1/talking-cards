import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/board_theme.dart';
import 'bloom/bloom_painter.dart' show BloomSilhouettePainter;

/// The back of a memory card: the reverse of a printed paper card with a
/// stamp on it (docs/design/memory_match_redesign.md §1).
///
/// **Every back is pixel-identical.** No `Random`, no seed from a tile id,
/// no per-tile phase: a three-year-old would learn the cards by a star that
/// sits two points to the left, and the game would stop being a memory
/// game. The only thing that varies is [theme] — one colour for the whole
/// board — which is also the only reason [shouldRepaint] ever says yes.
///
/// The drawing lives in a 100 × 110 design space and is expressed in
/// fractions of the tile, so a 106 dp phone tile and a 300 dp tablet tile
/// carry the same picture. Host it inside a `RepaintBoundary`
/// ([CardBack] does).
class CardBackPainter extends CustomPainter {
  final BoardTheme theme;

  const CardBackPainter(this.theme);

  /// Corner radius of a card of [width] — shared with the front face so a
  /// card keeps its shape while it turns.
  static double radiusOf(double width) => (width * 0.13).clamp(14.0, 22.0);

  // Line work
  static const _outerInset = 0.07;
  static const _innerInset = 0.11;
  static const _outerStroke = 2.2;
  static const _innerStroke = 1.2;
  static const _segments = 12;
  static const _wobble = 0.6;

  // The stamp
  static const _sealDiameter = 0.34;

  /// The seven doodles, in fractions of the tile: x, y, size, kind.
  /// Fixed by hand inside the frame band — never generated.
  static const _doodles = <(double, double, double, _Doodle)>[
    (0.20, 0.18, 0.06, _Doodle.star),
    (0.79, 0.22, 0.03, _Doodle.dot),
    (0.62, 0.14, 0.03, _Doodle.dot),
    (0.24, 0.80, 0.03, _Doodle.dot),
    (0.78, 0.76, 0.05, _Doodle.heart),
    (0.17, 0.52, 0.07, _Doodle.swirl),
    (0.83, 0.50, 0.06, _Doodle.star),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final radius = Radius.circular(radiusOf(w));

    // 1. The field.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = theme.wash,
    );

    // 2. Two pencil frames. The line is not vector-straight: every side is
    // twelve segments whose vertices are nudged by a fixed sine, which is
    // what makes it read as drawn rather than printed.
    _frame(
      canvas,
      size,
      _outerInset,
      _outerStroke,
      theme.ink.withValues(alpha: 0.55),
      0,
    );
    _frame(
      canvas,
      size,
      _innerInset,
      _innerStroke,
      theme.ink.withValues(alpha: 0.30),
      1.9,
    );

    // 3. Doodles — the same motifs that fly around the apple and the
    // skateboard on the card illustrations.
    final doodle = Paint()
      ..color = theme.seal.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    for (final (fx, fy, fs, kind) in _doodles) {
      _drawDoodle(canvas, Offset(fx * w, fy * h), fs * w, kind, doodle);
    }

    // 4. The stamp: Bloom's silhouette on a disc of [seal]. One character,
    // one brand, readable at 60 dp and at 300 dp.
    _seal(canvas, size);
  }

  void _frame(
    Canvas canvas,
    Size size,
    double inset,
    double stroke,
    Color color,
    double phase,
  ) {
    final pad = inset * size.width;
    final rect = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (var side = 0; side < 4; side++) {
      final from = corners[side];
      final to = corners[(side + 1) % 4];
      for (var i = 1; i <= _segments; i++) {
        final t = i / _segments;
        final p = Offset.lerp(from, to, t)!;
        // Deterministic hand wobble: the same sine for every card, so the
        // backs stay indistinguishable.
        final n = _wobble * math.sin(phase + side * 2.3 + i * 1.7);
        final along = (to - from) / (to - from).distance;
        final normal = Offset(-along.dy, along.dx);
        path.lineTo(p.dx + normal.dx * n, p.dy + normal.dy * n);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _seal(Canvas canvas, Size size) {
    final d = _sealDiameter * size.width;
    final r = d / 2;
    final c = Offset(size.width / 2, size.height * 0.5);

    canvas.drawCircle(c, r, Paint()..color = theme.seal);
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..color = theme.paper.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 1)));
    // The mascot's own silhouette, cropped by the disc: head and ears fill
    // the stamp, the body runs off the bottom edge like a real wax seal.
    final box = r * 1.8;
    canvas.translate(c.dx - box / 2, c.dy - box / 2 + r * 0.18);
    BloomSilhouettePainter(color: theme.paper).paint(canvas, Size(box, box));
    canvas.restore();

    // Two happy arcs and a nose, in the stamp's own ink.
    final face = Paint()
      ..color = theme.seal
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, d * 0.06)
      ..strokeCap = StrokeCap.round;
    final eyeY = c.dy + r * 0.20;
    for (final dx in [-r * 0.26, r * 0.26]) {
      final path = Path()
        ..moveTo(c.dx + dx - r * 0.14, eyeY)
        ..quadraticBezierTo(
          c.dx + dx,
          eyeY - r * 0.22,
          c.dx + dx + r * 0.14,
          eyeY,
        );
      canvas.drawPath(path, face);
    }
    final nose = Path()
      ..moveTo(c.dx - r * 0.10, c.dy + r * 0.44)
      ..lineTo(c.dx + r * 0.10, c.dy + r * 0.44)
      ..lineTo(c.dx, c.dy + r * 0.60)
      ..close();
    canvas.drawPath(nose, Paint()..color = theme.seal);
  }

  static void _drawDoodle(
    Canvas canvas,
    Offset at,
    double size,
    _Doodle kind,
    Paint paint,
  ) {
    switch (kind) {
      case _Doodle.dot:
        canvas.drawCircle(at, size / 2, paint);
      case _Doodle.star:
        canvas.drawPath(starPath(at, size / 2), paint);
      case _Doodle.heart:
        canvas.drawPath(_heartPath(at, size), paint);
      case _Doodle.swirl:
        final stroke = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, size * 0.16)
          ..strokeCap = StrokeCap.round;
        final path = Path()..moveTo(at.dx - size / 2, at.dy);
        path.quadraticBezierTo(
          at.dx,
          at.dy - size * 0.7,
          at.dx + size / 2,
          at.dy,
        );
        path.quadraticBezierTo(
          at.dx + size * 0.15,
          at.dy + size * 0.55,
          at.dx - size * 0.1,
          at.dy + size * 0.2,
        );
        canvas.drawPath(path, stroke);
    }
  }

  /// A five-pointed star of [radius] around [at] — the one star shape of
  /// the board: on the back, on a matched card and in the spark burst.
  static Path starPath(Offset at, double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = at + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  static Path _heartPath(Offset at, double size) {
    final s = size / 2;
    return Path()
      ..moveTo(at.dx, at.dy + s * 0.9)
      ..cubicTo(
        at.dx - s * 1.6,
        at.dy - s * 0.2,
        at.dx - s * 0.5,
        at.dy - s * 1.2,
        at.dx,
        at.dy - s * 0.35,
      )
      ..cubicTo(
        at.dx + s * 0.5,
        at.dy - s * 1.2,
        at.dx + s * 1.6,
        at.dy - s * 0.2,
        at.dx,
        at.dy + s * 0.9,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant CardBackPainter old) => old.theme != theme;
}

enum _Doodle { dot, star, heart, swirl }

/// The card back as a widget: the painter, the card's hard-edged sticker
/// shadow, and a `RepaintBoundary` so a board of twelve backs never
/// repaints while one of them turns.
class CardBack extends StatelessWidget {
  final BoardTheme theme;

  const CardBack({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final radius = CardBackPainter.radiusOf(
          box.hasBoundedWidth ? box.maxWidth : 100,
        );
        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: theme.seal.withValues(alpha: 0.28),
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: theme.seal.withValues(alpha: 0.12),
                  offset: const Offset(0, 8),
                  blurRadius: 14,
                ),
              ],
            ),
            child: CustomPaint(
              painter: CardBackPainter(theme),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}
