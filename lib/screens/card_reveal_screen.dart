import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/card_image.dart';
import '../widgets/kid_tap.dart';

/// Full-screen card reveal with celebration effects.
class CardRevealScreen extends ConsumerStatefulWidget {
  final CardModel card;
  final PackModel pack;
  final int newTotal;

  /// Kept for call-site compatibility; the Share button was removed from
  /// this child-facing screen (no parental gate exists in the app).
  final void Function(BuildContext)? onShare;
  final VoidCallback? onGoToPack;
  final bool skipAnimation;

  const CardRevealScreen({
    super.key,
    required this.card,
    required this.pack,
    required this.newTotal,
    this.onShare,
    this.onGoToPack,
    this.skipAnimation = false,
  });

  @override
  ConsumerState<CardRevealScreen> createState() => _CardRevealScreenState();
}

class _CardRevealScreenState extends ConsumerState<CardRevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _envelopeCtrl;
  late final AnimationController _openCtrl;
  late final AnimationController _settleCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _confettiCtrl;
  late final AnimationController _bgCtrl;

  bool _phase2Started = false;
  bool _phase3Started = false;
  bool _showButtons = false;

  late final List<_Particle> _burstParticles;
  late final List<_ConfettiPiece> _confetti;
  final _rng = Random();

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();

    _burstParticles = List.generate(50, (_) => _Particle.random(_rng));
    // Precomputed once: the old painter re-seeded Random(42) and rebuilt
    // 45 pieces on every frame.
    _confetti = List.generate(40, (_) => _ConfettiPiece.random(_rng));

    _envelopeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.skipAnimation) {
      // Jump straight to final settled state
      _phase2Started = true;
      _phase3Started = true;
      _showButtons = true;
      _envelopeCtrl.value = 1.0;
      _openCtrl.value = 1.0;
      _settleCtrl.value = 1.0;
      _burstCtrl.value = 1.0;
      _bgCtrl.value = 1.0;
      // Reads MediaQuery, so it has to wait until we are in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAmbient();
      });
    } else {
      _envelopeCtrl.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _startPhase2();
        });
      });
    }
  }

  void _startPhase2() {
    setState(() => _phase2Started = true);
    // The open moment: tada + heavy haptic in one event. The three
    // hand-placed haptics of the old phases collapse into this.
    FeedbackService.instance.event(FeedbackEvent.reveal);
    _openCtrl.forward();
    _burstCtrl.forward();
    _bgCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _startPhase3();
    });
  }

  void _startPhase3() {
    setState(() => _phase3Started = true);
    // Voice the revealed word — the reward moment must be heard, not read.
    AudioService.instance.playWordOnly(widget.card.audioKey, widget.card.sound);
    _settleCtrl.forward();
    _startAmbient();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showButtons = true);
    });
  }

  /// Glow pulses three times and rests bright; confetti rains once and
  /// fades. Both used to `repeat()` forever — full-screen repaints at 60 fps
  /// on an old tablet until the parent pressed a button.
  void _startAmbient() {
    if (_reduceMotion) {
      _glowCtrl.value = 1.0;
      return;
    }
    _glowCtrl.repeat(reverse: true, count: 3);
    _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _envelopeCtrl.dispose();
    _openCtrl.dispose();
    _settleCtrl.dispose();
    _burstCtrl.dispose();
    _glowCtrl.dispose();
    _confettiCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // Derive vibrant bg colors from pack color
  Color get _bgDark {
    final hsl = HSLColor.fromColor(widget.pack.color);
    return hsl
        .withLightness((hsl.lightness * 0.15).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
        .toColor();
  }

  Color get _bgMid {
    final hsl = HSLColor.fromColor(widget.pack.color);
    return hsl
        .withLightness((hsl.lightness * 0.3).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final packColor = widget.pack.color;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Animated radial gradient background — pack-colored
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_bgCtrl.value);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.6 + t * 0.6,
                    colors: [
                      _bgMid.withValues(alpha: 0.5 + t * 0.5),
                      _bgDark,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),

          // Subtle radial light rays. Each full-screen painter sits in its
          // own RepaintBoundary so the card and buttons stay off the hot path.
          if (_phase3Started && !_reduceMotion)
            _fullScreenLayer(
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _RaysPainter(
                      progress: _glowCtrl.value,
                      color: packColor,
                    ),
                  );
                },
              ),
            ),

          // Burst particles (one-shot on open)
          if (_phase2Started && !_reduceMotion)
            _fullScreenLayer(
              AnimatedBuilder(
                animation: _burstCtrl,
                builder: (_, __) => CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _BurstPainter(
                    particles: _burstParticles,
                    progress: _burstCtrl.value,
                    color: packColor,
                  ),
                ),
              ),
            ),

          // Confetti rain — one pass, fades out at the end
          if (_phase3Started && !_reduceMotion)
            _fullScreenLayer(
              AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(
                    pieces: _confetti,
                    progress: _confettiCtrl.value,
                    packColor: packColor,
                  ),
                ),
              ),
            ),

          // Glow behind card
          if (_phase3Started)
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) {
                final pulse = 0.4 + _glowCtrl.value * 0.3;
                return Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      // blur 80 / spread 30 was the single most expensive
                      // draw on the screen; 40 / 10 reads the same at arm's
                      // length (perf guardrail, motion audit §7).
                      BoxShadow(
                        color: packColor.withValues(alpha: pulse),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: pulse * 0.2),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                );
              },
            ),

          // The card phases
          if (!_phase2Started)
            _buildEnvelope()
          else if (!_phase3Started)
            _buildCardFlying()
          else
            _buildCardSettled(),

          // Buttons
          if (_showButtons)
            Positioned(
              bottom: 30 + MediaQuery.of(context).padding.bottom,
              left: 28,
              right: 28,
              child: _buildButtons(),
            ),

          // Close button. The drawing stays small and half-transparent on
          // purpose — leaving the reveal is not something to invite — but
          // the hit zone is the full 72 dp, and its centre sits 48 dp in
          // from the right edge so a palm resting on the bezel misses it
          // (ux-gap G12).
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _showButtons
                ? KidTap(
                    onTap: () => Navigator.of(context).pop(),
                    sound: null,
                    child: Semantics(
                      button: true,
                      label: 'Close',
                      child: SizedBox(
                        width: DT.size.tapBack,
                        height: DT.size.tapBack,
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 28,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _fullScreenLayer(Widget child) =>
      IgnorePointer(child: RepaintBoundary(child: child));

  Widget _buildEnvelope() {
    return AnimatedBuilder(
      animation: _envelopeCtrl,
      builder: (_, __) {
        final scale = Curves.elasticOut.transform(_envelopeCtrl.value);
        final shake =
            sin(_envelopeCtrl.value * pi * 6) * 3 * (1 - _envelopeCtrl.value);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 1.2),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.pack.color,
                    widget.pack.color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: widget.pack.color.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.pack.icon, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  const Text('🎁', style: TextStyle(fontSize: 36)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFlying() {
    return AnimatedBuilder(
      animation: _openCtrl,
      builder: (_, __) {
        final t = Curves.easeOutBack.transform(_openCtrl.value);
        final scale = 0.3 + t * 0.7;
        final rotation = (1 - t) * 0.3;
        final yOffset = (1 - t) * 100;
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(angle: rotation, child: _cardWidget()),
          ),
        );
      },
    );
  }

  Widget _buildCardSettled() {
    return AnimatedBuilder(
      animation: _settleCtrl,
      builder: (_, __) {
        final bounce = Curves.elasticOut.transform(
          _settleCtrl.value.clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.95 + bounce * 0.05,
          child: _cardWidget(),
        );
      },
    );
  }

  Widget _cardWidget() {
    final card = widget.card;
    final packColor = widget.pack.color;
    final total = widget.pack.cards.length;
    final progress = widget.newTotal / total;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: card.colorBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: card.colorAccent.withValues(alpha: 0.25),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: packColor.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pack badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: packColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${widget.pack.icon} ${widget.pack.title}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: packColor,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Card image / emoji
          SizedBox(
            height: 120,
            child: CardImage.forCard(card, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 16),

          // Sound
          Text(
            card.sound,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: card.colorAccent,
            ),
          ),
          if (card.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            // Description
            Text(
              card.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Progress bar instead of plain counter
          Row(
            children: [
              Text(
                '${widget.newTotal}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: packColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: packColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(packColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: packColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    final packColor = widget.pack.color;
    final s = AppS(ref.read(languageProvider) == 'en');

    return AnimatedOpacity(
      opacity: _showButtons ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary button — go to pack
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                KidTap.feedback();
                Navigator.of(context).pop();
                widget.onGoToPack?.call();
              },
              icon: Text(
                widget.pack.icon,
                style: const TextStyle(fontSize: 20),
              ),
              label: Text(
                s(
                  'До розділу "${widget.pack.title}"',
                  'To "${widget.pack.title}"',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: packColor,
                foregroundColor: Colors.white,
                // Rule 1: both buttons on this screen are child targets.
                minimumSize: Size.fromHeight(DT.size.tapMin),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
                shadowColor: packColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // No Share button here — this screen is child-facing and the app
          // has no parental gate to protect an outbound share flow.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                KidTap.feedback();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: Text(
                s('На головну', 'Home'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(DT.size.tapMin),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LIGHT RAYS — subtle rotating rays behind the card
// ═══════════════════════════════════════════════════════════════

class _RaysPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RaysPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    const rayCount = 12;
    final baseAngle = progress * pi * 2 / rayCount; // slow rotation

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < rayCount; i++) {
      final angle = baseAngle + (i * 2 * pi / rayCount);
      final alpha = (0.04 + sin(progress * pi) * 0.03);
      paint.color = color.withValues(alpha: alpha);

      final path = Path();
      final tipDist = size.height * 0.6;
      const spread = 0.08;

      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + cos(angle - spread) * tipDist,
        center.dy + sin(angle - spread) * tipDist,
      );
      path.lineTo(
        center.dx + cos(angle + spread) * tipDist,
        center.dy + sin(angle + spread) * tipDist,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════
//  BURST PARTICLES — explode outward on open (one-shot)
// ═══════════════════════════════════════════════════════════════

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double startDelay;
  final Color colorTint;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.startDelay,
    required this.colorTint,
  });

  factory _Particle.random(Random rng) {
    final colors = [
      Colors.amber,
      Colors.pinkAccent,
      Colors.white,
      Colors.yellowAccent,
      Colors.lightBlueAccent,
      Colors.orangeAccent,
      Colors.greenAccent,
    ];
    return _Particle(
      angle: rng.nextDouble() * pi * 2,
      speed: 100 + rng.nextDouble() * 250,
      size: 3 + rng.nextDouble() * 7,
      startDelay: rng.nextDouble() * 0.25,
      colorTint: colors[rng.nextInt(colors.length)],
    );
  }
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _BurstPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    for (final p in particles) {
      final t = ((progress - p.startDelay) / (1 - p.startDelay)).clamp(
        0.0,
        1.0,
      );
      if (t <= 0) continue;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final dist = p.speed * Curves.easeOut.transform(t);
      final pos = center + Offset(cos(p.angle) * dist, sin(p.angle) * dist);
      final paint = Paint()
        ..color = p.colorTint.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════
//  CONFETTI — continuous colorful rain
// ═══════════════════════════════════════════════════════════════

class _ConfettiPiece {
  final double x; // 0..1 of width
  final double speed; // 0.3..1.0
  final double phase; // 0..1
  final int colorIndex; // into base colours; -1 = pack colour
  final double w;
  final double h;
  final bool rect;
  final double spin; // ±1

  const _ConfettiPiece({
    required this.x,
    required this.speed,
    required this.phase,
    required this.colorIndex,
    required this.w,
    required this.h,
    required this.rect,
    required this.spin,
  });

  factory _ConfettiPiece.random(Random rng) {
    final w = 4.0 + rng.nextDouble() * 6;
    return _ConfettiPiece(
      x: rng.nextDouble(),
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble(),
      colorIndex: rng.nextInt(_ConfettiPainter._baseColors.length + 1) - 1,
      w: w,
      h: rng.nextBool() ? (6.0 + rng.nextDouble() * 10) : w,
      rect: rng.nextBool(),
      spin: rng.nextBool() ? 1 : -1,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  final Color packColor;

  _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.packColor,
  });

  static const _baseColors = [
    DT.coral,
    DT.sunBurst,
    DT.mint,
    DT.sky,
    DT.pink,
    DT.peach,
    DT.violet,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    // Rain at full strength for 70 % of the pass, then thin out to nothing.
    final fade = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
    final paint = Paint()..style = PaintingStyle.fill;
    // Slower overall drift than the old 5 s loop so one pass reads as rain.
    final t = progress * 3;

    for (final p in pieces) {
      final color = p.colorIndex < 0 ? packColor : _baseColors[p.colorIndex];
      final yNorm = ((t * p.speed + p.phase) % 1.0);
      final y = yNorm * (size.height + 40) - 20;
      final wobble = sin((t * 5 + p.phase * pi * 2)) * 18;
      final rotation = t * pi * 3 * p.spin + p.phase * pi;

      paint.color = color.withValues(
        alpha: (1.0 - yNorm * 0.4).clamp(0.3, 0.8) * fade,
      );

      canvas.save();
      canvas.translate(p.x * size.width + wobble, y);
      canvas.rotate(rotation);

      final w = p.w;
      final h = p.h;
      if (p.rect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, w / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
