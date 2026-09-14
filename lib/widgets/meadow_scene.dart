import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// The meadow the games are played in: sky, three clouds, two hills, a
/// bush and a handful of flower blots.
///
/// It was drawn for Bubble Pop and lived inside that screen; it is here
/// because the same sky answers the same question everywhere — a game
/// screen with nothing behind it reads as a screen that failed to load,
/// and every empty band on a phone is one a child stares at.
///
/// Static: rasterised once, `shouldRepaint` is always false, and there is
/// nothing here that moves — the game's own objects own the motion.
///
/// Pair it with `background: DT.sceneSkyTop` on the shell so the header
/// band matches the top of the sky.

class MeadowScene extends StatelessWidget {
  const MeadowScene({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: MeadowPainter(),
        isComplex: true,
        willChange: false,
        child: SizedBox.expand(),
      ),
    );
  }
}

class MeadowPainter extends CustomPainter {
  const MeadowPainter();

  /// The meadow band: 23 % of the height, never under 150 dp.
  static double meadowHeight(double h) => max(0.23 * h, 150.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    // L0 — sky. Cool at the top, a paper-warm horizon; the warmth is the
    // only "sun" — a yellow disc would read as one more target.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DT.sceneSkyTop, DT.sceneSkyMid, DT.sceneSkyHorizon],
          stops: [0.0, 0.62, 1.0],
        ).createShader(full),
    );

    // L1 — paper grain: asset-only (see _BubbleScene). Nothing drawn.

    // L2 — three soft clouds in the upper third: white on the sky at low
    // local contrast, no outline, no face. The flight zone stays calm.
    _cloud(canvas, Offset(w * 0.18, h * 0.10), w * 0.11);
    _cloud(canvas, Offset(w * 0.72, h * 0.17), w * 0.13);
    _cloud(canvas, Offset(w * 0.46, h * 0.29), w * 0.08);

    // L3 — meadow: far hill, near hill, a shaded foreground band, a bush
    // and a handful of flower blots. Everything with colour and edge lives
    // in this bottom band; the sky above belongs to the bubbles.
    final mh = meadowHeight(h);
    final top = h - mh;

    final far = Path()
      ..moveTo(0, top + mh * 0.30)
      ..quadraticBezierTo(w * 0.5, top + mh * 0.02, w, top + mh * 0.26)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = DT.sceneGrassFar);

    final near = Path()
      ..moveTo(0, top + mh * 0.58)
      ..quadraticBezierTo(w * 0.32, top + mh * 0.28, w * 0.66, top + mh * 0.50)
      ..quadraticBezierTo(w * 0.86, top + mh * 0.62, w, top + mh * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = DT.sceneGrassNear);

    final shade = Path()
      ..moveTo(0, h - mh * 0.16)
      ..quadraticBezierTo(w * 0.5, h - mh * 0.30, w, h - mh * 0.14)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(shade, Paint()..color = DT.sceneGrassShade);

    // Bush — two tones, left of centre, away from Bloom's corner.
    final bushC = Offset(w * 0.14, top + mh * 0.66);
    final bushR = mh * 0.17;
    canvas.drawCircle(
      bushC + Offset(bushR * 0.55, bushR * 0.18),
      bushR * 0.9,
      Paint()..color = DT.sceneBushDark,
    );
    canvas.drawCircle(bushC, bushR, Paint()..color = DT.sceneBushLight);
    canvas.drawCircle(
      bushC + Offset(-bushR * 0.7, bushR * 0.3),
      bushR * 0.6,
      Paint()..color = DT.sceneBushLight,
    );

    // Flowers — colour blots without outline (spec: coral 55 %, sunBurst
    // 60 %, violet 45 %). Positions are fixed so the meadow is the same
    // meadow every round.
    final k = (mh / 150).clamp(1.0, 1.6);
    for (final f in _flowers) {
      canvas.drawCircle(
        Offset(w * f.$1, top + mh * f.$2),
        f.$4 * k,
        Paint()..color = f.$3,
      );
    }
  }

  static final _coral = DT.coral.withValues(alpha: 0.55);
  static final _sun = DT.sunBurst.withValues(alpha: 0.60);
  static final _violet = DT.violet.withValues(alpha: 0.45);

  /// (x fraction of width, y fraction of the meadow band, colour, radius).
  static final _flowers = <(double, double, Color, double)>[
    (0.06, 0.82, _coral, 6),
    (0.24, 0.90, _sun, 5),
    (0.34, 0.76, _violet, 6),
    (0.47, 0.86, _coral, 5),
    (0.58, 0.74, _sun, 7),
    (0.66, 0.92, _violet, 5),
    (0.30, 0.96, _sun, 4),
    (0.52, 0.96, _coral, 4),
  ];

  void _cloud(Canvas canvas, Offset c, double r) {
    void puff(Offset centre, double radius) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              DT.sceneCloud.withValues(alpha: 0.85),
              DT.sceneCloud.withValues(alpha: 0.0),
            ],
            stops: const [0.45, 1.0],
          ).createShader(rect),
      );
    }

    puff(c, r);
    puff(c + Offset(-r * 0.9, r * 0.25), r * 0.75);
    puff(c + Offset(r * 0.95, r * 0.2), r * 0.8);
  }

  @override
  bool shouldRepaint(covariant MeadowPainter oldDelegate) => false;
}
