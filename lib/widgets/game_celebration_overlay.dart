import 'package:flutter/material.dart';

import 'celebration.dart';

/// Shared end-of-game celebration for all mini-games — a thin wrapper over
/// [celebrate] with [CelebrationTier.round], kept so the games' call sites
/// read as what they are.
///
/// Deliberately carries NO scores, NO stars, NO attempt counters and NO
/// elapsed time — a 2-year-old just finished playing, so every completion is
/// a full win: hopping mascot, one confetti burst, recorded praise and one
/// clear next action. Adventure rounds lead back to the map; replay stays
/// available as a secondary choice.
///
/// [onAgain] must restart the game via the same reset path the old
/// "play again" button used; [onDone] typically pops the game screen. Both
/// run after the overlay has popped itself. System Back also finishes the
/// game so its completed, empty board is never left visible.
Future<void> showGameCelebration(
  BuildContext context, {
  required bool isEn,
  String childName = '',
  required VoidCallback onAgain,
  required VoidCallback onDone,
  String? subtitle,
  bool returnToAdventure = false,
}) async {
  var handled = false;
  await celebrate(
    context,
    tier: CelebrationTier.round,
    isEn: isEn,
    childName: childName,
    subtitle:
        subtitle ??
        (returnToAdventure
            ? (isEn
                  ? 'Game complete. The adventure continues!'
                  : 'Гру завершено. Пригода триває!')
            : null),
    doneLabel: returnToAdventure
        ? (isEn ? 'Back to adventure' : 'До пригоди')
        : null,
    preferDone: returnToAdventure,
    onAgain: () {
      handled = true;
      onAgain();
    },
    onDone: () {
      handled = true;
      onDone();
    },
  );
  // System Back dismisses the overlay without selecting a button. A
  // finished game has no board left, so leave it rather than show a void.
  if (!handled &&
      context.mounted &&
      (ModalRoute.of(context)?.isCurrent ?? true)) {
    onDone();
  }
}
