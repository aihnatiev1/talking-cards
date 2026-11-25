import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_icons.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../providers/bloom_reactions_provider.dart';
import '../widgets/bloom_mascot.dart';
import '../utils/game_state_mixin.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/cue_pill.dart';
import '../widgets/kid_screen.dart';
import '../widgets/quiz_option.dart';
import '../widgets/quiz_options_board.dart';
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

  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _bloom.sceneEntered(this, BloomScene.game);
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

    // One wrong picture for the youngest, two after that: a child of two
    // is choosing between two things, not scanning a list.
    final level = ref.read(profileProvider).active?.level ?? 2;
    final wrongCount = level <= 2 ? 1 : 2;

    // Distractors come from other pairs
    final otherCards = <CardModel>[];
    for (int i = 0; i < pairCount; i++) {
      if (i == pairIndex) continue;
      otherCards.add(cards[i * 2]);
      otherCards.add(cards[i * 2 + 1]);
    }
    otherCards.shuffle(Random());
    final distractors = otherCards.take(wrongCount).toList();

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
      AudioService.instance.playPraise(
        isEn: ref.read(languageProvider) == 'en',
      );
      scorePoint();
      // Play the opposite word so child hears both words of the pair
      Future.delayed(DT.motion.pairEcho, () {
        if (mounted)
          AudioService.instance.playWordOnly(card.audioKey, card.sound);
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
        final target = _round.options.indexOf(_round.correct);
        if (target >= 0) {
          _bloom.nudged(quizOptionDirection(target, _round.options.length));
        }
      }
    }
  }

  @override
  void dispose() {
    _bloom.sceneLeft(this);
    super.dispose();
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
      // Played in the games' meadow, like every other game.
      meadow: true,
      backdrop: 'assets/images/backdrops/opposites_sky.webp',
      mascotCorner: BloomMascot(
        size: DT.size.mascotCompanionOf(context),
        semanticsLabel: s('Блум', 'Bloom'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          max(DT.size.mascotCompanionOf(context), DT.size.tapMin) +
              BloomMascot.hopClearance +
              DT.sp16,
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Question card — large, tappable for audio (word only — kids
            // get confused if the full example sentence plays each tap).
            // Once answered it makes room for the pair: the two opposites
            // stand next to each other, which is the thing to understand
            // (experience audit п. 22) — the tap was only the way there.
            KidTap(
              onTap: () => AudioService.instance.playWordOnly(
                question.audioKey,
                question.sound,
              ),
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
                        // A short phone gives the picture less, so the
                        // answers below keep a height a finger can hit.
                        artHeight: (MediaQuery.sizeOf(context).height * .19)
                            .clamp(72.0, 150.0),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Arrow + label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SwapBadge(size: 40),
                const SizedBox(width: 10),
                // Shrinks on a narrow phone instead of running off the edge.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CuePill(
                      child: Text(
                        s('Що протилежне?', 'What is the opposite?'),
                        style: DT.h2.copyWith(
                          fontSize: 20,
                          color: DT.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Answer options — big pictures side by side. They were three
            // rows of a thumbnail and a word, which a child who cannot
            // read had to tell apart by a 60 pt picture.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, card) in _round.options.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      key: ValueKey(card.id),
                      child: QuizOption(
                        card: card,
                        mark: card.id != correct.id
                            ? AnswerMark.none
                            : _answered
                            ? AnswerMark.correct
                            : _misses.showHint
                            ? AnswerMark.hint
                            : AnswerMark.none,
                        nudge: _nudges[card.id] ?? 0,
                        onTap: () => _onTap(card),
                      ),
                    ),
                  ],
                ],
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
  final double artHeight;

  const _QuestionCard({
    super.key,
    required this.card,
    required this.s,
    this.artHeight = 150,
  });

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
              height: artHeight,
              child: CardImage.forCard(card, padding: EdgeInsets.zero),
            )
          else
            Container(
              width: 110,
              height: artHeight,
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
          // A picture of an ear says "tap to hear" to a child who cannot read.
          AppArt(
            'listen',
            size: 32,
            semanticLabel: s('торкнись', 'tap to hear'),
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

  const _PairReveal({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DT.success.withValues(alpha: 0.35), width: 2),
        boxShadow: DT.shadowSoft(DT.success),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _PairHalf(card: question)),
          const _SwapBadge(size: 36),
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

/// The two-way arrow between a word and its opposite, drawn instead of the
/// ↔️ emoji.
class _SwapBadge extends StatelessWidget {
  const _SwapBadge({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: DT.brand, width: 2.5),
    ),
    child: Icon(Icons.swap_horiz_rounded, size: size * .62, color: DT.brand),
  );
}
