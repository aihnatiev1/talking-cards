import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/game_state_mixin.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// Game: show one card, pick its opposite from 3 options.
///
/// Convention: cards in the opposites pack come in consecutive pairs.
/// cards[0] ↔ cards[1], cards[2] ↔ cards[3], etc.
class OppositeGameScreen extends ConsumerStatefulWidget {
  final PackModel pack;

  const OppositeGameScreen({super.key, required this.pack});

  @override
  ConsumerState<OppositeGameScreen> createState() => _OppositeGameScreenState();
}

class _OppositeGameScreenState extends ConsumerState<OppositeGameScreen>
    with GameStateMixin {
  @override
  String get gameId => 'opposite_game';

  // 5 rounds ≈ 30-60s — a 2-year-old's full attention span.
  @override
  int get maxRounds => 5;

  bool _answered = false;
  // A miss nudges the tapped tile (no colour, no cross); after the second
  // miss in a round the right tile starts to glow (G10).
  final _misses = MissTracker();
  final Map<String, int> _nudges = {};

  late _Round _round;

  @override
  void initState() {
    super.initState();
    startGame();
    _buildRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'opposites',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  void _buildRound() {
    if (!nextRound()) {
      _showCelebration();
      return;
    }

    final cards = widget.pack.cards;
    // Pairs: index 0↔1, 2↔3 … pick a random pair
    final pairCount = cards.length ~/ 2;
    final pairIndex = Random().nextInt(pairCount);
    final cardA = cards[pairIndex * 2];
    final cardB = cards[pairIndex * 2 + 1];

    // Question is randomly one of the two; answer is the other
    final questionIsA = Random().nextBool();
    final question = questionIsA ? cardA : cardB;
    final correct = questionIsA ? cardB : cardA;

    // Pick 2 distractors from other pairs
    final otherCards = <CardModel>[];
    for (int i = 0; i < pairCount; i++) {
      if (i == pairIndex) continue;
      otherCards.add(cards[i * 2]);
      otherCards.add(cards[i * 2 + 1]);
    }
    otherCards.shuffle(Random());
    final distractors = otherCards.take(2).toList();

    final options = [correct, ...distractors]..shuffle(Random());

    setState(() {
      _round = _Round(question: question, correct: correct, options: options);
      _answered = false;
      _misses.reset();
      _nudges.clear();
    });

    // Small gap so the entry instruction (first round) or the previous
    // round's feedback can finish before the new question word plays.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(DT.motion.questionCue, () {
        if (!mounted) return;
        AudioService.instance.playWordOnly(question.audioKey, question.sound);
      });
    });
  }

  void _showCelebration() {
    showGameCelebration(
      context,
      isEn: ref.read(languageProvider) == 'en',
      childName: ref.read(profileProvider).active?.name ?? '',
      onAgain: () {
        resetGame();
        _buildRound();
      },
      onDone: () => Navigator.of(context).pop(),
    );
  }

  void _onTap(CardModel card) {
    if (_answered) return;
    final isCorrect = card.id == _round.correct.id;

    if (isCorrect) {
      // The tile itself pops, frames in success and bursts (AnswerFrame).
      setState(() => _answered = true);
      FeedbackService.instance.event(FeedbackEvent.correct);
      AudioService.instance
          .playPraise(isEn: ref.read(languageProvider) == 'en');
      scorePoint();
      // Play the opposite word so child hears both words of the pair
      Future.delayed(DT.motion.pairEcho, () {
        if (mounted) AudioService.instance.playWordOnly(card.audioKey, card.sound);
      });
      // The pair now stands side by side under the question (п. 22); the
      // next question waits for that to be seen, not just heard.
      Future.delayed(DT.motion.pairHold, () {
        if (mounted) _buildRound();
      });
    } else {
      // Gentle redirection — a low pop and one nudge; nothing locks, the
      // right tile stays there to be found.
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _nudges[card.id] = (_nudges[card.id] ?? 0) + 1;
        _misses.miss();
      });
      if (_misses.justCrossed) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');
    final motion = MotionPolicy.of(context);

    final question = _round.question;
    final correct = _round.correct;

    // No text title — the ↔️ row under the question card is the prompt.
    return KidScreen.game(
      accent: DT.brand,
      background: DT.violetTint,
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Question card — large, tappable for audio (word only — kids
              // get confused if the full example sentence plays each tap).
              // Once answered it makes room for the pair: the two opposites
              // stand next to each other, which is the thing to understand
              // (experience audit п. 22) — the tap was only the way there.
              KidTap(
                onTap: () => AudioService.instance
                    .playWordOnly(question.audioKey, question.sound),
                // The word itself is the answer to this tap.
                sound: null,
                child: AnimatedSwitcher(
                  duration: motion.dur(DT.motion.pairReveal),
                  child: _answered
                      ? _PairReveal(
                          key: ValueKey('pair-${question.id}'),
                          question: question,
                          answer: correct,
                        )
                      : _QuestionCard(
                          key: ValueKey(question.id),
                          card: question,
                          s: s,
                        ),
                ),
              ),

              const SizedBox(height: 8),

              // Arrow + label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('↔️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    s('Що протилежне?', 'What is the opposite?'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Answer options — vertical stack for big tap targets
              Expanded(
                child: Column(
                  children: _round.options.map((card) {
                    final isCorrectCard = card.id == correct.id;
                    final mark = !isCorrectCard
                        ? AnswerMark.none
                        : _answered
                            ? AnswerMark.correct
                            : _misses.showHint
                                ? AnswerMark.hint
                                : AnswerMark.none;

                    return Expanded(
                      key: ValueKey(card.id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OptionTile(
                          card: card,
                          mark: mark,
                          nudge: _nudges[card.id] ?? 0,
                          onTap: () => _onTap(card),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
//  Round data
// ─────────────────────────────────────────────

class _Round {
  final CardModel question;
  final CardModel correct;
  final List<CardModel> options; // shuffled, includes correct

  _Round({
    required this.question,
    required this.correct,
    required this.options,
  });
}

// ─────────────────────────────────────────────
//  Question card (large)
// ─────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final CardModel card;
  final AppS s;

  const _QuestionCard({super.key, required this.card, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: card.colorBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: card.colorAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Real webp only — plain placeholder if an unsanitized card ever
          // slips through (never emoji in gameplay).
          if (card.image != null)
            SizedBox(
              height: 110,
              child: CardImage.forCard(card, padding: EdgeInsets.zero),
            )
          else
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: card.colorAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            card.sound,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: card.colorAccent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up_rounded,
                  color: Colors.grey[400], size: 14),
              const SizedBox(width: 4),
              Text(
                s('торкнись', 'tap to hear'),
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Pair reveal — the answer explained, without a word of text
// ─────────────────────────────────────────────

/// After a right answer the question card becomes the pair: «великий» and
/// «маленький» next to each other, with the ↔ between them (experience
/// audit 2026-09-13, п. 22). The point of the game is the relation, and a
/// relation cannot be shown by one card at a time.
///
/// It occupies the question card's slot, so nothing moves on the screen
/// except the cross-fade [AnimatedSwitcher] already runs.
class _PairReveal extends StatelessWidget {
  final CardModel question;
  final CardModel answer;

  const _PairReveal({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: DT.success.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: DT.shadowSoft(DT.success),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _PairHalf(card: question)),
          const Text('↔️', style: TextStyle(fontSize: 26)),
          Expanded(child: _PairHalf(card: answer)),
        ],
      ),
    );
  }
}

class _PairHalf extends StatelessWidget {
  final CardModel card;

  const _PairHalf({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card.image != null)
          SizedBox(
            height: 92,
            child: CardImage.forCard(card, padding: EdgeInsets.zero),
          )
        else
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: card.colorAccent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          card.sound,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: card.colorAccent,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Option tile — picture + word inside the shared AnswerFrame
// ─────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final CardModel card;
  final AnswerMark mark;
  final int nudge;
  final VoidCallback onTap;

  const _OptionTile({
    required this.card,
    required this.mark,
    required this.nudge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: onTap,
      child: AnswerFrame(
        background: card.colorBg,
        accent: card.colorAccent,
        mark: mark,
        nudge: nudge,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Image on the left, word beside it — matches the question card
        // above so the whole screen reads as a column of big pictures.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (card.image != null)
              SizedBox(
                width: 80,
                height: 80,
                child: CardImage.forCard(card, padding: EdgeInsets.zero),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: card.colorAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                card.sound,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: card.colorAccent,
                ),
              ),
            ),
            // Room for the corner sticker so it never covers the word.
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}
