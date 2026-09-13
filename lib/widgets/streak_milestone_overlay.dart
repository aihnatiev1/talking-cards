import 'package:flutter/material.dart';

import '../providers/streak_provider.dart';
import '../utils/design_tokens.dart';
import 'celebration.dart';

/// Celebration shown the first time a user crosses a streak milestone
/// (3 / 7 / 14 / 30 days). Parent-first reading, kid-first visual: a warm
/// flame, the reward emoji, Bloom — and no confetti, because this is a
/// parent's note, not the child's prize (motion audit 2026-09-13 §4 T3).
///
/// Thin wrapper over [celebrate] with [CelebrationTier.milestone].
/// [onCelebrated] runs once the overlay has closed, whether by the pill or
/// by the system back.
Future<void> showStreakMilestone(
  BuildContext context, {
  required Milestone milestone,
  required String childName,
  required bool isEn,
  required VoidCallback onCelebrated,
}) async {
  final m = milestone;
  final daysLabel =
      isEn ? (m.days == 1 ? 'day' : 'days') : _ukDaysWord(m.days);
  final title = isEn ? '${m.days}-day streak!' : 'Серія ${m.days} $daysLabel!';
  final subtitle = childName.isNotEmpty
      ? (isEn ? 'Awesome job, $childName!' : 'Молодець, $childName!')
      : (isEn ? 'Awesome job!' : 'Молодець!');

  await celebrate(
    context,
    tier: CelebrationTier.milestone,
    isEn: isEn,
    title: title,
    subtitle: subtitle,
    badge: m.bonusEmoji,
    accent: DT.streakOrange,
  );
  onCelebrated();
}

String _ukDaysWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
    return 'дні';
  }
  return 'днів';
}
