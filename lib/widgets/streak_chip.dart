import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';
import 'kid_tap.dart';

/// Bright streak counter visible on home — Duolingo signature pattern adapted
/// for our 1-4 audience: pulsing flame + day count, single-tap to stats.
///
/// Hidden when [streak] is 0 to avoid drawing attention to "nothing yet".
class StreakChip extends StatelessWidget {
  final int streak;
  final VoidCallback onTap;

  const StreakChip({
    super.key,
    required this.streak,
    required this.onTap,
  });

  /// Two full pulses (1400 ms out, 1400 ms back, twice) as an intro accent,
  /// then calm. A permanent loop kept the home tab repainting at 60fps for
  /// the whole session (battery/thermal cost on the old tablets kids get
  /// handed); the 30 s re-burst it was replaced with still made Home the
  /// screen with four idle loops (motion audit §7 — budget is one).
  static const _burst = Duration(milliseconds: 1400 * 2 * 2);

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();

    return KidTap(
      onTap: onTap,
      // Under reduced motion the flame and the day count sit at rest
      // (glow 0.25, scale 1.0) and stay just as legible.
      child: AmbientLoop(
        period: const Duration(milliseconds: 1400),
        settleAfter: _burst,
        builder: (context, t, _) {
          final glow = 0.25 + 0.35 * t;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kStreakOrange.withValues(alpha: 0.95),
                  DT.coral,
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
                  // The flame with eyes (spec §5.1), sticker-edged on the
                  // orange gradient.
                  child: const AppIconView(
                    AppIcon.streakFlame,
                    size: 20,
                    sticker: true,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$streak',
                  style: DT.tileTitle.copyWith(
                    fontSize: responsiveFont(context, 14),
                    fontVariations: DT.kidWeight(900),
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
