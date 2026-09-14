import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../utils/design_tokens.dart';
import 'bloom_pose.dart';

/// Anything that can draw a [BloomPose] into a canvas (architecture audit
/// F4). [PaintedBloom] is the procedural renderer and the permanent
/// fallback; a `RiveBloom` (wave 3) would implement the same interface so
/// `BloomMascot` never learns how it is drawn.
abstract interface class MascotRenderer {
  /// Draws [pose] scaled into [size]. [look] is the pupil offset in
  /// `-1..1` per axis (screen-aligned), [eyeOpen] the blink phase (1 = open).
  void paint(
    Canvas canvas,
    Size size,
    BloomPose pose, {
    required Offset look,
    required double eyeOpen,
  });
}

/// Bloom in ink and cream — a `CustomPainter` body in a fixed 120×120
/// design space (docs/design/bloom_character.md §2.1, anatomy v2).
///
/// Nothing here animates. The widget hands it a pose per frame (only while
/// a transition runs) and the painter draws it; at rest the boundary is
/// never invalidated.
final class PaintedBloom implements MascotRenderer {
  const PaintedBloom();

  /// Design-space size every coordinate below is written against.
  static const double designSize = 120;

  /// Pupil travel in design units at `look = ±1`.
  static const double _pupilTravel = 1.6;

  @override
  void paint(
    Canvas canvas,
    Size size,
    BloomPose pose, {
    required Offset look,
    required double eyeOpen,
  }) {
    final scale = size.shortestSide / designSize;
    canvas.save();
    canvas.translate(
      (size.width - designSize * scale) / 2,
      (size.height - designSize * scale) / 2,
    );
    canvas.scale(scale, scale);

    // The outline may not drop under 1.5 dp on screen at any size, so the
    // design-space stroke grows as the drawing shrinks (§2.1).
    final stroke = math.max(2.0, 1.5 / scale);
    final ink = Paint()
      ..color = DT.bloomInk.withValues(alpha: DT.bloomInkAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()..color = DT.bloomBody;

    _shadow(canvas);

    // Body squash is anchored at the base line so the feet stay planted.
    canvas.save();
    canvas.translate(60, 118);
    canvas.scale(1, pose.bodySquash);
    canvas.translate(-60, -118);

    // Head + ears + face tilt together around the neck.
    canvas.save();
    canvas.translate(60, 86);
    canvas.rotate(pose.headTilt);
    canvas.translate(-60, -86);
    _ear(canvas, pose, isLeft: true, body: body, ink: ink);
    _ear(canvas, pose, isLeft: false, body: body, ink: ink);
    canvas.restore();

    _body(canvas, body, ink);

    canvas.save();
    canvas.translate(60, 86);
    canvas.rotate(pose.headTilt);
    canvas.translate(-60, -86);
    _head(canvas, body, ink);
    _cheeks(canvas, pose, body, ink);
    _eyes(canvas, pose, look, eyeOpen);
    _nose(canvas);
    _mouth(canvas, pose);
    if (pose.zzz) _zzz(canvas);
    canvas.restore();

    _paw(canvas, pose.pawLeft, pose.pawLeftAngle, body, ink);
    _paw(canvas, pose.pawRight, pose.pawRightAngle, body, ink);
    if (pose.prop == BloomProp.wand) _wand(canvas, pose);

    canvas.restore(); // squash
    canvas.restore(); // fit
  }

  void _shadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 116), width: 60, height: 8),
      Paint()..color = DT.bloomShadow,
    );
  }

  /// One ear: a 20×50 rounded slab whose upper third bends by
  /// [BloomPose.earBend] on the right side — the silhouette's signature.
  void _ear(
    Canvas canvas,
    BloomPose pose, {
    required bool isLeft,
    required Paint body,
    required Paint ink,
  }) {
    canvas.save();
    canvas.translate(isLeft ? 44 : 76, 26 + pose.earShift);
    canvas.rotate(isLeft ? pose.earLeft : pose.earRight);
    final bend = isLeft ? 0.0 : pose.earBend;

    final outer = _earPath(width: 20, height: 50, bend: bend);
    final inner = _earPath(width: 10, height: 30, bend: bend, inset: 4);
    canvas.drawPath(outer, body);
    canvas.drawPath(inner, Paint()..color = DT.bloomEarInside);
    canvas.drawPath(outer, ink);
    canvas.restore();
  }

  /// Ear geometry centred on the origin: a lower slab plus an upper cap
  /// rotated by [bend] about the join, united into one path so the outline
  /// has no seam.
  Path _earPath({
    required double width,
    required double height,
    required double bend,
    double inset = 0,
  }) {
    final top = -height / 2 + inset;
    final bottom = height / 2 + inset;
    final joinY = top + height / 3;
    final radius = Radius.circular(width / 2);
    final lower = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(-width / 2, joinY - width / 2, width / 2, bottom),
        radius,
      ));
    if (bend == 0) {
      final whole = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(-width / 2, top, width / 2, bottom),
          radius,
        ));
      return whole;
    }
    final upper = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(-width / 2, top, width / 2, joinY + width / 2),
        radius,
      ));
    final m = Matrix4.identity()
      ..translateByDouble(0, joinY, 0, 1)
      ..rotateZ(bend)
      ..translateByDouble(0, -joinY, 0, 1);
    return Path.combine(
      PathOperation.union,
      lower,
      upper.transform(m.storage),
    );
  }

  void _body(Canvas canvas, Paint body, Paint ink) {
    final rect = Rect.fromCenter(
      center: const Offset(60, 95),
      width: 60,
      height: 47,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(23));
    canvas.drawRRect(rrect, body);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 102), width: 34, height: 20),
      Paint()..color = DT.bloomHighlight,
    );
    canvas.drawRRect(rrect, ink);
  }

  void _head(Canvas canvas, Paint body, Paint ink) {
    final head = Rect.fromCenter(
      center: const Offset(60, 60),
      width: 66,
      height: 60,
    );
    canvas.drawOval(head, body);
    canvas.drawOval(head, ink);
  }

  void _cheeks(Canvas canvas, BloomPose pose, Paint body, Paint ink) {
    if (pose.puffCheeks) {
      for (final c in const [Offset(36, 64), Offset(84, 64)]) {
        final r = Rect.fromCenter(center: c, width: 18, height: 12);
        canvas.drawOval(r, body);
        canvas.drawOval(r, ink);
      }
      return;
    }
    final paint = Paint()..color = DT.bloomCheek;
    final w = 14 * pose.cheekScale;
    final h = 8 * pose.cheekScale;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(36, 64), width: w, height: h),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(84, 64), width: w, height: h),
      paint,
    );
  }

  void _eyes(Canvas canvas, BloomPose pose, Offset look, double eyeOpen) {
    switch (pose.eyes) {
      case BloomEyes.open:
        _openEyes(canvas, look, eyeOpen);
      case BloomEyes.happyClosed:
        _arcEyes(canvas, up: true, squeeze: pose.eyeSqueeze);
      case BloomEyes.sleepClosed:
        _arcEyes(canvas, up: false, squeeze: 0);
    }
  }

  void _openEyes(Canvas canvas, Offset look, double eyeOpen) {
    final ink = Paint()..color = DT.bloomInk;
    final shine = Paint()..color = DT.bloomEyeShine;
    final shift = Offset(
      look.dx.clamp(-1.0, 1.0) * _pupilTravel,
      look.dy.clamp(-1.0, 1.0) * _pupilTravel,
    );
    final open = eyeOpen.clamp(0.0, 1.0);
    for (final c in const [Offset(46, 55), Offset(74, 55)]) {
      if (open < 0.15) {
        // Mid-blink: a short line where the eye was.
        canvas.drawLine(
          c + const Offset(-3.2, 0),
          c + const Offset(3.2, 0),
          Paint()
            ..color = DT.bloomInk
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final centre = c + shift;
      canvas.drawOval(
        Rect.fromCenter(center: centre, width: 6.8, height: 6.8 * open),
        ink,
      );
      if (open > 0.6) {
        canvas.drawCircle(centre + const Offset(-1.2, -1.2), 1.1, shine);
      }
    }
  }

  /// `^^` (up) or `˘˘` (down). [squeeze] 0 → the everyday happy arc,
  /// 1 → the cheer squint (wider, higher).
  void _arcEyes(Canvas canvas, {required bool up, required double squeeze}) {
    final paint = Paint()
      ..color = DT.bloomInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final halfW = up ? 6 + 2 * squeeze : 6.0;
    final rise = up ? 7 + 2 * squeeze : -4.0;
    final baseY = up ? 56.0 : 55.0;
    for (final cx in const [46.0, 74.0]) {
      final path = Path()
        ..moveTo(cx - halfW, baseY)
        ..quadraticBezierTo(cx, baseY - rise, cx + halfW, baseY);
      canvas.drawPath(path, paint);
    }
  }

  void _nose(Canvas canvas) {
    final path = Path()
      ..moveTo(56, 66)
      ..lineTo(64, 66)
      ..quadraticBezierTo(60, 71, 56, 66)
      ..close();
    canvas.drawPath(path, Paint()..color = DT.bloomNose);
  }

  void _mouth(Canvas canvas, BloomPose pose) {
    final stroke = Paint()
      ..color = DT.bloomInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(60, 74);
    canvas.scale(pose.mouthScale, pose.mouthScale);
    canvas.translate(-60, -74);
    switch (pose.mouth) {
      case BloomMouth.smile:
        final path = Path()
          ..moveTo(54, 72)
          ..quadraticBezierTo(60, 78, 66, 72);
        canvas.drawPath(path, stroke);
      case BloomMouth.o:
        canvas.drawCircle(
          const Offset(60, 74),
          3,
          stroke..strokeWidth = 2.0,
        );
      case BloomMouth.cheerD:
        final d = Path()
          ..moveTo(52, 71)
          ..lineTo(68, 71)
          ..quadraticBezierTo(60, 81, 52, 71)
          ..close();
        canvas.drawPath(d, Paint()..color = DT.bloomInk);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(60, 77), width: 6, height: 4),
          Paint()..color = DT.bloomCheek,
        );
      case BloomMouth.line:
        canvas.drawLine(
          const Offset(57, 74),
          const Offset(63, 74),
          stroke..strokeWidth = 2.0,
        );
    }
    canvas.restore();
  }

  /// A small "z" doodle above the right ear — part of the sleep pose, not
  /// an animation.
  void _zzz(Canvas canvas) {
    final paint = Paint()
      ..color = DT.bloomInk.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final z = Path()
      ..moveTo(96, 14)
      ..lineTo(104, 14)
      ..lineTo(96, 22)
      ..lineTo(104, 22);
    canvas.drawPath(z, paint);
  }

  void _paw(Canvas canvas, Offset centre, double angle, Paint body, Paint ink) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: 20, height: 14);
    canvas.drawOval(rect, body);
    canvas.drawOval(rect, ink);
    canvas.restore();
  }

  /// Bubble wand in the right paw: a stick to the ring at (106, 26).
  void _wand(Canvas canvas, BloomPose pose) {
    final paint = Paint()
      ..color = DT.sky
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const ring = Offset(106, 26);
    canvas.drawLine(pose.pawRight, ring + const Offset(-2, 5), paint);
    canvas.drawCircle(ring, 5, paint);
  }
}

/// `CustomPaint` delegate around a [MascotRenderer]. Repaints only when the
/// pose, the pupil offset or the blink phase changes — never on a timer.
class BloomPainter extends CustomPainter {
  final BloomPose pose;
  final Offset look;
  final double eyeOpen;
  final MascotRenderer renderer;

  const BloomPainter({
    required this.pose,
    this.look = Offset.zero,
    this.eyeOpen = 1,
    this.renderer = const PaintedBloom(),
  });

  @override
  void paint(Canvas canvas, Size size) =>
      renderer.paint(canvas, size, pose, look: look, eyeOpen: eyeOpen);

  @override
  bool shouldRepaint(covariant BloomPainter old) =>
      old.pose != pose ||
      old.look != look ||
      old.eyeOpen != eyeOpen ||
      old.renderer != renderer;
}

/// Bloom's outline as one flat shape — ears, head and body — for the card
/// back in Memory and any badge that wants the mascot at 16–40 dp without
/// a face (docs/design/bloom_character.md §5.5). Same geometry as
/// [PaintedBloom], so the silhouette can never drift from the character.
class BloomSilhouettePainter extends CustomPainter {
  final Color color;

  const BloomSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / PaintedBloom.designSize;
    canvas.save();
    canvas.translate(
      (size.width - PaintedBloom.designSize * scale) / 2,
      (size.height - PaintedBloom.designSize * scale) / 2,
    );
    canvas.scale(scale, scale);
    const pose = BloomPose.idle;
    final paint = Paint()..color = color;

    for (final isLeft in const [true, false]) {
      canvas.save();
      canvas.translate(isLeft ? 44 : 76, 26);
      canvas.rotate(isLeft ? pose.earLeft : pose.earRight);
      final ear = const PaintedBloom()._earPath(
        width: 20,
        height: 50,
        bend: isLeft ? 0 : pose.earBend,
      );
      canvas.drawPath(ear, paint);
      canvas.restore();
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(60, 95), width: 60, height: 47),
        const Radius.circular(23),
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 60), width: 66, height: 60),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BloomSilhouettePainter old) =>
      old.color != color;
}
