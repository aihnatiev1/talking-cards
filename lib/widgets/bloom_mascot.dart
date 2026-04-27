import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Bloom" — Skillar's procedural mascot, a cream-cheeked bunny with closed
/// happy eyes. Drawn via [CustomPainter] in a fixed 120×120 design space and
/// scaled to whatever [size] the parent gives. Zero asset weight, perfectly
/// crisp at any scale, easily swappable for a professionally-illustrated
/// version later.
///
/// By default [interactive] is true — tap on Bloom triggers a happy bounce
/// (scale-pulse + wobble + haptic). Set false for purely decorative usage
/// where you want zero hit-testing (e.g. inside larger composite widgets).
///
/// Emotions: [BloomEmotion.happy] (default), [BloomEmotion.waving] (right paw
/// raised). Add more by branching on [emotion] inside [_BloomPainter].
enum BloomEmotion { happy, waving }

class BloomMascot extends StatefulWidget {
  final double size;
  final BloomEmotion emotion;
  final bool interactive;

  const BloomMascot({
    super.key,
    this.size = 120,
    this.emotion = BloomEmotion.happy,
    this.interactive = true,
  });

  @override
  State<BloomMascot> createState() => _BloomMascotState();
}

class _BloomMascotState extends State<BloomMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _react;

  @override
  void initState() {
    super.initState();
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _react.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _react
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final mascot = AnimatedBuilder(
      animation: _react,
      builder: (_, child) {
        if (_react.isDismissed) return child!;
        // Bounce: 0..0.5 grow to 1.15 (elastic-out), 0.5..1 settle back.
        final t = _react.value;
        final scale = t < 0.5
            ? 1.0 + Curves.elasticOut.transform(t * 2) * 0.15
            : 1.0 + 0.15 * (1 - (t - 0.5) * 2);
        // Subtle wobble on the way back to neutral.
        final rotation =
            t < 0.5 ? 0.0 : 0.06 * (1 - (t - 0.5) * 2) * (t.isNaN ? 0 : 1);
        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _BloomPainter(emotion: widget.emotion),
        ),
      ),
    );

    if (!widget.interactive) return mascot;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: mascot,
    );
  }
}

class _BloomPainter extends CustomPainter {
  final BloomEmotion emotion;

  _BloomPainter({required this.emotion});

  // Brand palette — kept warm and pastel to match Skillar tone.
  static const _bodyCream = Color(0xFFFFF1E0);
  static const _bodyShade = Color(0xFFF5E2C7);
  static const _earInside = Color(0xFFFFB7C5);
  static const _cheek = Color(0xFFFFC4D0);
  static const _nose = Color(0xFFE38DA8);
  static const _ink = Color(0xFF3A2E2A);
  static const _shadow = Color(0x14000000);

  @override
  void paint(Canvas canvas, Size size) {
    // All coordinates designed against a 120×120 reference; final scale comes
    // from whatever [size] the parent allots.
    final scale = size.width / 120.0;
    canvas.scale(scale, scale);

    _paintShadow(canvas);
    _paintEar(canvas, isLeft: true);
    _paintEar(canvas, isLeft: false);
    _paintBody(canvas);
    _paintHead(canvas);
    _paintCheeks(canvas);
    _paintEyes(canvas);
    _paintNose(canvas);
    _paintMouth(canvas);
    _paintPaws(canvas);
  }

  void _paintShadow(Canvas canvas) {
    final paint = Paint()..color = _shadow;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 116), width: 60, height: 8),
      paint,
    );
  }

  void _paintEar(Canvas canvas, {required bool isLeft}) {
    final body = Paint()..color = _bodyCream;
    final inside = Paint()..color = _earInside;
    final outline = Paint()
      ..color = _ink.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.save();
    // Ears centered at y=24 with shorter height keeps the rotated bbox top
    // above y=0 so parent containers with clipping don't crop the tips.
    canvas.translate(isLeft ? 42 : 78, 24);
    canvas.rotate(isLeft ? -0.22 : 0.22);

    final earRect = Rect.fromCenter(
      center: Offset.zero,
      width: 20,
      height: 42,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(earRect, const Radius.circular(10)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(earRect, const Radius.circular(10)),
      outline,
    );

    final innerRect = Rect.fromCenter(
      center: const Offset(0, 4),
      width: 10,
      height: 28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(5)),
      inside,
    );

    canvas.restore();
  }

  void _paintBody(Canvas canvas) {
    final body = Paint()..color = _bodyCream;
    final outline = Paint()
      ..color = _ink.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final shade = Paint()..color = _bodyShade;

    final rect = Rect.fromCenter(
      center: const Offset(60, 92),
      width: 64,
      height: 50,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(25));

    canvas.drawRRect(rrect, body);

    // Soft belly highlight: inset oval slightly lighter for depth.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 100), width: 36, height: 22),
      shade..color = const Color(0x22FFFFFF),
    );

    canvas.drawRRect(rrect, outline);
  }

  void _paintHead(Canvas canvas) {
    final body = Paint()..color = _bodyCream;
    final outline = Paint()
      ..color = _ink.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final head = Rect.fromCenter(
      center: const Offset(60, 56),
      width: 70,
      height: 64,
    );
    canvas.drawOval(head, body);
    canvas.drawOval(head, outline);
  }

  void _paintCheeks(Canvas canvas) {
    final cheek = Paint()..color = _cheek;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(36, 62), width: 14, height: 8),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(84, 62), width: 14, height: 8),
      cheek,
    );
  }

  void _paintEyes(Canvas canvas) {
    final eye = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Closed-arc happy eyes ^_^ — work for every emotion currently in use.
    final left = Path()
      ..moveTo(40, 56)
      ..quadraticBezierTo(46, 49, 52, 56);
    final right = Path()
      ..moveTo(68, 56)
      ..quadraticBezierTo(74, 49, 80, 56);
    canvas.drawPath(left, eye);
    canvas.drawPath(right, eye);
  }

  void _paintNose(Canvas canvas) {
    final paint = Paint()..color = _nose;
    final path = Path()
      ..moveTo(56, 65)
      ..lineTo(64, 65)
      ..quadraticBezierTo(60, 70, 56, 65)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintMouth(Canvas canvas) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(54, 72)
      ..quadraticBezierTo(60, 78, 66, 72);
    canvas.drawPath(path, paint);
  }

  void _paintPaws(Canvas canvas) {
    final body = Paint()..color = _bodyCream;
    final outline = Paint()
      ..color = _ink.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Left paw — always low.
    final left = Rect.fromCenter(
      center: const Offset(40, 110),
      width: 20,
      height: 14,
    );
    canvas.drawOval(left, body);
    canvas.drawOval(left, outline);

    // Right paw — raised in waving emotion, otherwise low.
    if (emotion == BloomEmotion.waving) {
      canvas.save();
      canvas.translate(86, 60);
      canvas.rotate(0.4);
      final raisedRect = Rect.fromCenter(
        center: Offset.zero,
        width: 20,
        height: 14,
      );
      canvas.drawOval(raisedRect, body);
      canvas.drawOval(raisedRect, outline);
      canvas.restore();
    } else {
      final right = Rect.fromCenter(
        center: const Offset(80, 110),
        width: 20,
        height: 14,
      );
      canvas.drawOval(right, body);
      canvas.drawOval(right, outline);
    }
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) =>
      oldDelegate.emotion != emotion;
}
