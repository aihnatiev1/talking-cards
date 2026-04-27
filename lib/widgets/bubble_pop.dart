import 'dart:math';

import 'package:flutter/material.dart';

/// Sago Mini-style ambient delight: a tinted bubble springs from the tap point
/// and floats all the way up to the top of the screen, popping at the edge.
///
/// Spawn one via [showBubblePop] — the bubble inserts itself into the nearest
/// [Overlay], auto-removes when its animation completes, and is fully
/// pointer-transparent so it never blocks the underlying UI.
void showBubblePop(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _BubbleStage(
          startGlobal: globalPosition,
          onDone: () => entry.remove(),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

/// Wraps the actual bubble in a full-screen [Stack] so [Positioned] is always
/// a direct Stack child — avoids any parent-data ambiguity inside Overlay.
class _BubbleStage extends StatefulWidget {
  final Offset startGlobal;
  final VoidCallback onDone;

  const _BubbleStage({required this.startGlobal, required this.onDone});

  @override
  State<_BubbleStage> createState() => _BubbleStageState();
}

class _BubbleStageState extends State<_BubbleStage>
    with SingleTickerProviderStateMixin {
  // Cycle bubble tints so consecutive taps look varied.
  static const _palette = <Color>[
    Color(0xFFFFB7C5), // pink
    Color(0xFFB7E0FF), // sky
    Color(0xFFC9F2C7), // mint
    Color(0xFFFFE4A8), // butter
    Color(0xFFD4C5F9), // lavender
  ];
  static int _paletteCursor = 0;

  late final AnimationController _ctrl;
  late final Color _tint;
  late final double _size;
  late final double _driftAmplitude;
  late final double _driftPhase;
  late final Duration _duration;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _tint = _palette[_paletteCursor++ % _palette.length];
    _size = 36 + rand.nextDouble() * 22; // 36–58
    _driftAmplitude = 14 + rand.nextDouble() * 22; // 14–36 px sideways
    _driftPhase = rand.nextDouble() * 2 * pi;
    // Float duration scales with how far the bubble has to travel; tuned to
    // give Sago Mini-style relaxed drift (≈140 px/sec) so it reads as ambient
    // delight, not "shooting up".
    final travel = (widget.startGlobal.dy + _size).clamp(150.0, 1200.0);
    _duration = Duration(milliseconds: 1200 + (travel * 4.5).round());
    _ctrl = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            // Float from tap.dy all the way past the top edge of the screen.
            final startY = widget.startGlobal.dy;
            final endY = -_size; // off-screen top
            final eased = Curves.easeOutCubic.transform(t);
            final currentY = startY + (endY - startY) * eased - _size / 2;
            final drift =
                sin(t * 2 * pi + _driftPhase) * _driftAmplitude;
            // Pop: scale snaps in last 18%, opacity fades.
            final scale = t < 0.82
                ? 1.0 + 0.08 * sin(t * pi)
                : 1.5 * (1 - (t - 0.82) / 0.18);
            final opacity =
                t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);

            return Positioned(
              left: widget.startGlobal.dx - _size / 2 + drift,
              top: currentY,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale.clamp(0.0, 2.0),
                  child: _BubbleVisual(size: _size, tint: _tint),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BubbleVisual extends StatelessWidget {
  final double size;
  final Color tint;

  const _BubbleVisual({required this.size, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            tint.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 1.0],
          center: const Alignment(-0.3, -0.3),
        ),
        border: Border.all(
          color: tint.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      // Tiny highlight dot for the toy-like look.
      child: const Align(
        alignment: Alignment(-0.4, -0.4),
        child: FractionallySizedBox(
          widthFactor: 0.28,
          heightFactor: 0.28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
