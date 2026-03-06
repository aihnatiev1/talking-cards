import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight confetti burst overlay (no background dim).
/// Shows 20 particles for 1 second, then auto-removes.
class ConfettiBurst extends StatefulWidget {
  final Offset origin;

  const ConfettiBurst({super.key, required this.origin});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(20, (_) => _Particle(rng));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isCompleted) return const SizedBox.shrink();
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _BurstPainter(
            particles: _particles,
            progress: _controller.value,
            origin: widget.origin,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double angle; // radians
  final double speed; // 100..300
  final double size;
  final Color color;

  static const _colors = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D),
    Color(0xFF6C63FF), Color(0xFFFF85A1), Color(0xFF45B7D1),
    Color(0xFFF0B27A), Color(0xFF58D68D),
  ];

  _Particle(Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        speed = 100 + rng.nextDouble() * 200,
        size = 4 + rng.nextDouble() * 6,
        color = _colors[rng.nextInt(_colors.length)];
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset origin;

  _BurstPainter({
    required this.particles,
    required this.progress,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dist = p.speed * progress;
      final x = origin.dx + cos(p.angle) * dist;
      final y = origin.dy + sin(p.angle) * dist + 50 * progress * progress; // gravity
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.speed * 0.02);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
