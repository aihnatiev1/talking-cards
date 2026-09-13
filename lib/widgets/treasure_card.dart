import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';
import 'kid_tap.dart';

/// Compact daily-quest progress tile shown next to [CardOfDayHero].
///
/// Shows a small progress ring around the chest so the child sees how close
/// they are to "opening" today's reward.
class TreasureCard extends StatelessWidget {
  final int done;
  final int total;
  final bool isEn;
  final VoidCallback onTap;

  const TreasureCard({
    super.key,
    required this.done,
    required this.total,
    required this.onTap,
    this.isEn = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = DT.peach;
    final allDone = done >= total;
    final progress =
        total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    return KidTap(
      onTap: onTap,
      child: Container(
        height: 108,
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
            width: 2,
          ),
          boxShadow: DT.shadowSoft(accent),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DT.rLg - 2),
          child: Row(
            children: [
              // Chest pane — progress ring around a bobbing treasure
              SizedBox(
                width: 92,
                child: Container(
                  color: accent.withValues(alpha: 0.12),
                  child: Center(
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              backgroundColor:
                                  accent.withValues(alpha: 0.22),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          // Bob 0 → -3 px over 1400 ms. Under reduced
                          // motion the chest rests at offset 0; the ring
                          // and the "n / total" label carry the state.
                          AmbientLoop(
                            period: const Duration(milliseconds: 1400),
                            builder: (_, t, child) => Transform.translate(
                              offset: Offset(0, -3 * t),
                              child: child,
                            ),
                            // The same chest the quest map ends on, closed
                            // until the last step is done (G13).
                            child: AppIconView(
                              allDone
                                  ? AppIcon.rewardChestOpen
                                  : AppIcon.rewardChestClosed,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIconView(AppIcon.stepQuest, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              isEn ? 'Quest' : 'Скарб',
                              style: DT.caption.copyWith(
                                fontSize: 10,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          allDone
                              ? (isEn ? 'Done! 🎉' : 'Готово!')
                              : '$done / $total',
                          maxLines: 1,
                          style: DT.h1.copyWith(
                            color: accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
