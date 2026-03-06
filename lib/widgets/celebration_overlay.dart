import 'dart:math';
import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Full-screen celebration overlay with falling stars and confetti.
class CelebrationOverlay extends StatefulWidget {
  final String packTitle;
  final String packIcon;
  final Color color;
  final VoidCallback onDone;
  final VoidCallback? onReplay;
  final VoidCallback? onShare;

  const CelebrationOverlay({
    super.key,
    required this.packTitle,
    required this.packIcon,
    required this.color,
    required this.onDone,
    this.onReplay,
    this.onShare,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _particles = List.generate(40, (_) => _Particle(_rng));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: Material(
        color: Colors.black54,
        child: Stack(
          children: [
            // Confetti particles
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),
            // Center message
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.packIcon, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      const Text('⭐', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Молодець!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.packTitle} пройдено!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.onReplay != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onReplay,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text(
                              'Грати знову',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (widget.onShare != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onShare,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text(
                              'Поділитись 🎉',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onDone,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.color,
                            side: BorderSide(color: widget.color),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'На головну',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double speed; // 0.5..1.5
  final double size;
  final Color color;
  final double drift; // horizontal drift

  static const _colors = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D),
    Color(0xFF6C63FF), Color(0xFFFF85A1), Color(0xFF45B7D1),
    Color(0xFFF0B27A), Color(0xFF58D68D),
  ];

  _Particle(Random rng)
      : x = rng.nextDouble(),
        speed = 0.5 + rng.nextDouble(),
        size = 4 + rng.nextDouble() * 8,
        color = _colors[rng.nextInt(_colors.length)],
        drift = (rng.nextDouble() - 0.5) * 0.15;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x = p.x * size.width + p.drift * size.width * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      // Rotating rectangles for confetti effect
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.speed * 6);
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
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
