import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'app_card_shell.dart';

/// Compact daily-quest progress tile shown next to [CardOfDayHero].
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
    const color = kStreakOrange;
    final allDone = done >= total;
    return AppCardShell(
      color: color,
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: 90),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEn ? '🗺️ Quest' : '🗺️ Скарб',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    allDone
                        ? (isEn ? 'Done! 🎉' : 'Готово!')
                        : '$done / $total',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            allDone ? '🏆' : '🎁',
            style: const TextStyle(fontSize: 36),
          ),
        ],
      ),
    );
  }
}
