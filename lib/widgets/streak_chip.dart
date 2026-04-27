import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/design_tokens.dart';

/// Bright streak counter visible on home — Duolingo signature pattern adapted
/// for our 1-4 audience: pulsing flame + day count, single-tap to stats.
///
/// Hidden when [streak] is 0 to avoid drawing attention to "nothing yet".
class StreakChip extends StatefulWidget {
  final int streak;
  final VoidCallback onTap;

  const StreakChip({
    super.key,
    required this.streak,
    required this.onTap,
  });

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_pulse.value);
          final glow = 0.25 + 0.35 * t;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kStreakOrange.withValues(alpha: 0.95),
                  const Color(0xFFFF6F4D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kStreakOrange.withValues(alpha: glow),
                  blurRadius: 10 + 4 * t,
                  spreadRadius: 1 + 0.5 * t,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + 0.08 * t,
                  child: const Text('🔥', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 5),
                Text(
                  '${widget.streak}',
                  style: TextStyle(
                    fontSize: responsiveFont(context, 14),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
