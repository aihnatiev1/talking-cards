import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import 'bloom_mascot.dart';
import 'confetti_burst.dart';

/// Shared end-of-game celebration for all mini-games.
///
/// Deliberately contains NO scores, NO stars, NO attempt counters and NO
/// elapsed time — a 2-year-old just finished playing, so every completion is
/// a full win: waving mascot, confetti, recorded praise and one big
/// "play again" button.
///
/// Shows as a dimmed dialog route on top of the (finished) game board.
/// [onAgain] must restart the game via the same reset path the old
/// "play again" button used; [onDone] typically pops the game screen.
Future<void> showGameCelebration(
  BuildContext context, {
  required String lang,
  String childName = '',
  required VoidCallback onAgain,
  required VoidCallback onDone,
  String? subtitle,
}) {
  AudioService.instance.playSfx('tada');
  AudioService.instance.playPraise(lang: lang, always: true);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'celebration',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => _GameCelebrationOverlay(
      lang: lang,
      childName: childName,
      subtitle: subtitle,
      // Pop the dialog itself first, then hand control back to the game.
      onAgain: () {
        Navigator.of(ctx).pop();
        onAgain();
      },
      onDone: () {
        Navigator.of(ctx).pop();
        onDone();
      },
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

class _GameCelebrationOverlay extends StatelessWidget {
  final String lang;
  final String childName;
  final String? subtitle;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  const _GameCelebrationOverlay({
    required this.lang,
    required this.childName,
    required this.subtitle,
    required this.onAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(lang);
    final size = MediaQuery.of(context).size;
    final name = childName.trim();
    final headline = name.isEmpty
        ? s('Молодець!', 'Great job!')
        : s.p('Молодець, {name}!', 'Great job, {name}!', {'name': name});

    return Stack(
      children: [
        // Confetti burst behind the card.
        IgnorePointer(
          child: ConfettiBurst(
            origin: Offset(size.width / 2, size.height / 3),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: DT.shadowLift(kAccent),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BloomMascot(
                      size: 96 * screenScale(context).clamp(1.0, 1.25),
                      emotion: BloomEmotion.waving,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: DT.h1.copyWith(fontSize: 22),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: DT.body.copyWith(fontSize: 16),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // ONE big primary action — min 72dp for toddler fingers.
                    SizedBox(
                      width: double.infinity,
                      height: 72,
                      child: ElevatedButton(
                        onPressed: onAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          textStyle: DT.tileTitle.copyWith(fontSize: 20),
                        ),
                        child: Text(s('Ще раз', 'Play again')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Small secondary exit for the parent.
                    TextButton(
                      onPressed: onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: kAccent.withValues(alpha: 0.8),
                        textStyle: DT.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(s('Готово', 'Done')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
