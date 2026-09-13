import 'package:flutter/material.dart';

import 'celebration.dart';

/// Shared end-of-game celebration for all mini-games — a thin wrapper over
/// [celebrate] with [CelebrationTier.round], kept so the games' call sites
/// read as what they are.
///
/// Deliberately carries NO scores, NO stars, NO attempt counters and NO
/// elapsed time — a 2-year-old just finished playing, so every completion is
/// a full win: hopping mascot, one confetti burst, recorded praise and one
/// big "play again" pill.
///
/// [onAgain] must restart the game via the same reset path the old
/// "play again" button used; [onDone] typically pops the game screen. Both
/// run after the overlay has popped itself.
Future<void> showGameCelebration(
  BuildContext context, {
  required bool isEn,
  String childName = '',
  required VoidCallback onAgain,
  required VoidCallback onDone,
  String? subtitle,
}) =>
    celebrate(
      context,
      tier: CelebrationTier.round,
      isEn: isEn,
      childName: childName,
      subtitle: subtitle,
      onAgain: onAgain,
      onDone: onDone,
    );
