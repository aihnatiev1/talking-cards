import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../utils/design_tokens.dart';
import 'answer_feedback.dart';
import 'card_image.dart';
import 'kid_tap.dart';

/// One of the four picture choices in the guess game.
///
/// All answer feedback — the miss nudge, the success frame, pop, check and
/// burst, the hint glow — is [AnswerFrame]'s; this widget only lays out the
/// picture and the word. There is no "wrong" look by design (G10).
class QuizOption extends StatelessWidget {
  final CardModel card;
  final AnswerMark mark;

  /// Miss counter for this tile; every increment nudges it once.
  final int nudge;
  final VoidCallback onTap;

  const QuizOption({
    super.key,
    required this.card,
    required this.onTap,
    this.mark = AnswerMark.none,
    this.nudge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = card.colorBg;
    return KidTap(
      onTap: onTap,
      child: AnswerFrame(
        background: Colors.white,
        accent: card.colorAccent,
        mark: mark,
        nudge: nudge,
        radius: 28,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              // Pools are sanitized upstream (image required), so the
              // null branch is a defensive placeholder — never emoji.
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.lerp(cardColor, Colors.white, .45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: card.image != null
                    ? CardImage.forCard(
                        card,
                        size: CardArtSize.tile,
                        padding: const EdgeInsets.all(4),
                      )
                    : Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              card.sound,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DT.tileTitle.copyWith(color: DT.textPrimary, fontSize: 19),
            ),
          ],
        ),
      ),
    );
  }
}
