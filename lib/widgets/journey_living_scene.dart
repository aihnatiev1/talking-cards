import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/motion.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';

/// Decorative layers share the book's normalized coordinates. They never
/// intercept a stop or introduce another accessibility target.
class JourneyLivingScene extends StatelessWidget {
  const JourneyLivingScene({
    super.key,
    required this.completed,
    this.celebrateIndex = -1,
  });

  final List<bool> completed;
  final int celebrateIndex;

  static const gardens = [
    Offset(.14, .38),
    Offset(.83, .46),
    Offset(.12, .63),
    Offset(.89, .68),
    Offset(.48, .82),
  ];

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final unit = (bounds.maxWidth / 390).clamp(.75, 1.6);
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AmbientLoop(
                    period: DT.motion.sceneLoop,
                    reverse: false,
                    curve: Curves.linear,
                    builder: (_, phase, __) =>
                        CustomPaint(painter: _AtmospherePainter(phase, unit)),
                  ),
                ),
              ),
              for (var i = 0; i < gardens.length; i++)
                Positioned(
                  left: bounds.maxWidth * gardens[i].dx - 22 * unit,
                  top: bounds.maxHeight * gardens[i].dy - 30 * unit,
                  width: 44 * unit,
                  height: 60 * unit,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('journey-garden-$i'),
                    tween: Tween(
                      begin: completed[i] && celebrateIndex != i ? 1 : 0,
                      end: completed[i] ? 1 : 0,
                    ),
                    duration: MotionPolicy.of(
                      context,
                    ).dur(DT.motion.gardenGrow),
                    curve: Curves.easeOutCubic,
                    builder: (_, growth, __) =>
                        CustomPaint(painter: _GardenPainter(growth, i)),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter(this.phase, this.unit);
  final double phase, unit;

  @override
  void paint(Canvas canvas, Size size) {
    // Highlights move across the pond, never across the exercise plates.
    final water = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final t = (phase + i / 7) % 1;
      final opacity = math.sin(t * math.pi) * .48;
      final x = size.width * (.66 + (i % 3) * .075);
      final y = size.height * (.275 + (i ~/ 3) * .028);
      water
        ..color = DT.journeyWaterLight.withValues(alpha: opacity)
        ..strokeWidth = 1.5 * unit;
      canvas.drawLine(
        Offset(x - 4 * unit, y),
        Offset(x + (4 + 9 * t) * unit, y),
        water,
      );
    }
    // Two small paper butterflies travel closed paths. The loop joins at
    // the same position and wing pose, without a jump at the seam.
    for (var i = 0; i < 2; i++) {
      final a = 2 * math.pi * phase + i * math.pi;
      final centre = Offset(
        size.width * (i == 0 ? .43 : .86) + math.sin(a) * 13 * unit,
        size.height * (i == 0 ? .18 : .52) + math.sin(a * 2) * 6 * unit,
      );
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(math.sin(a) * .22);
      final flap = .38 + .62 * (math.cos(a * 10) + 1) / 2;
      final wing = Paint()
        ..color = i == 0 ? DT.journeyButterflyGold : DT.journeyButterflyLilac;
      for (final side in [-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(side * 3.5 * unit * flap, -2 * unit),
            width: 7 * unit * flap,
            height: 9 * unit,
          ),
          wing,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(side * 2.7 * unit * flap, 3 * unit),
            width: 5 * unit * flap,
            height: 5 * unit,
          ),
          wing,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 1.7 * unit,
            height: 9 * unit,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = DT.journeyButterflyInk,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.phase != phase || old.unit != unit;
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter(this.growth, this.index);
  final double growth;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    if (growth <= 0) return;
    canvas.save();
    canvas.scale(size.width / 44, size.height / 60);
    const colors = DT.journeyFlowers;
    for (var i = 0; i < 3; i++) {
      final t = ((growth - i * .12) / (1 - i * .12)).clamp(0.0, 1.0);
      final x = 10.0 + i * 12;
      final y = 55 - (i == 1 ? 36 : 25) * t;
      final stem = Paint()
        ..color = DT.journeyStem
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, 55), Offset(x, y), stem);
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(t);
      final shadow = Paint()
        ..color = DT.journeyFlowerShadow.withValues(alpha: .18);
      canvas.drawCircle(const Offset(0, 2), 8, shadow);
      for (var petal = 0; petal < 5; petal++) {
        final angle = petal * math.pi * 2 / 5;
        canvas.drawCircle(
          Offset(math.cos(angle) * 4.5, math.sin(angle) * 4.5),
          4,
          Paint()..color = colors[index],
        );
      }
      canvas.drawCircle(
        Offset.zero,
        3,
        Paint()..color = DT.journeyFlowerCentre,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenPainter old) =>
      old.growth != growth || old.index != index;
}
