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
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

class OddOneOutScreen extends ConsumerStatefulWidget {
  final List<PackModel> packs;

  const OddOneOutScreen({super.key, required this.packs});

  @override
  ConsumerState<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends ConsumerState<OddOneOutScreen>
    with GameStateMixin {
  @override
  String get gameId => 'odd_one_out';

  // 5 rounds ≈ 30-60s — a 2-year-old's full attention span.
  @override
  int get maxRounds => 5;

  bool _answered = false;
  // A miss nudges the tapped card (no colour, no cross); after the second
  // miss in a round the odd card starts to glow (G10).
  final _misses = MissTracker();
  final Map<String, int> _nudges = {};
  late List<_Slot> _slots;

  @override
  void initState() {
    super.initState();
    startGame();
    _buildRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'odd_one_out',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  void _buildRound() {
    final rng = Random();
    final pool = List<PackModel>.from(widget.packs)..shuffle(rng);
    final majority = pool[0];
    final oddPack = pool[1];

    final majorityCards = List<CardModel>.from(majority.cards)..shuffle(rng);
    final oddCards = List<CardModel>.from(oddPack.cards)..shuffle(rng);

    final three = majorityCards.take(3).toList();
    final one = oddCards.first;

    final slots = [
      ...three.map((c) => _Slot(card: c, pack: majority, isOdd: false)),
      _Slot(card: one, pack: oddPack, isOdd: true),
    ]..shuffle(rng);

    setState(() {
      _slots = slots;
      _answered = false;
      _misses.reset();
      _nudges.clear();
    });
  }

  void _onTap(_Slot slot) {
    if (_answered) return;

    // Play the tapped card's word — child hears the item they're evaluating,
    // which anchors the sort-by-category reasoning in speech, not silence.
    AudioService.instance.playWordOnly(slot.card.audioKey, slot.card.sound);

    if (slot.isOdd) {
      FeedbackService.instance.event(FeedbackEvent.correct);
      AudioService.instance
          .playPraise(isEn: ref.read(languageProvider) == 'en');
      // The card itself pops, frames in success and bursts (AnswerFrame).
      setState(() {
        _answered = true;
        scorePoint();
      });
      if (score >= maxRounds) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          completeGame();
          _showCelebration();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _buildRound();
        });
      }
    } else {
      // Gentle redirection — a low pop and one nudge, no harsh feedback;
      // the other cards stay tappable.
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _nudges[slot.card.id] = (_nudges[slot.card.id] ?? 0) + 1;
        _misses.miss();
      });
      if (_misses.justCrossed) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    // Determine majority pack for the hint header
    final majorityPack = _slots.firstWhere((sl) => !sl.isOdd).pack;
    final majorityCards =
        _slots.where((sl) => !sl.isOdd).map((sl) => sl.card).toList();

    // No text title — "Odd one out" is for the parent; the hint row of
    // thumbnails + ❓ below is the child's question.
    return KidScreen.game(
      accent: kAccent,
      background: DT.violetTint,
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Hint — small thumbnails of the actual majority cards + "?"
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(majorityPack.id),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c in majorityCards) ...[
                          _HintThumb(card: c),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 6),
                        const Text('❓',
                            style: TextStyle(fontSize: 36)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s('Яка картка зайва?', 'Which is odd?'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: majorityPack.color,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 2×2 card grid
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.88,
                  children: _slots
                      .map((sl) => _buildCard(sl, s))
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
      ),
    );
  }

  Widget _buildCard(_Slot sl, AppS s) {
    final card = sl.card;
    final mark = !sl.isOdd
        ? AnswerMark.none
        : _answered
            ? AnswerMark.correct
            : _misses.showHint
                ? AnswerMark.hint
                : AnswerMark.none;

    return KidTap(
      key: ValueKey(card.id),
      onTap: () => _onTap(sl),
      child: AnswerFrame(
        background: card.colorBg,
        accent: card.colorAccent,
        mark: mark,
        nudge: _nudges[card.id] ?? 0,
        radius: 20,
        child: _CardChip(card: card),
      ),
    );
  }

}

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Slot {
  final CardModel card;
  final PackModel pack;
  final bool isOdd;
  _Slot({required this.card, required this.pack, required this.isOdd});
}

// ─────────────────────────────────────────────
//  Hint thumbnail — small webp of a majority card
// ─────────────────────────────────────────────

class _HintThumb extends StatelessWidget {
  final CardModel card;
  const _HintThumb({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.colorAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: card.image != null
          ? CardImage.forCard(card, padding: EdgeInsets.zero)
          : DecoratedBox(
              decoration: BoxDecoration(
                color: card.colorBg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  Card chip — picture + word; the frame around it is AnswerFrame's
// ─────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final CardModel card;

  const _CardChip({required this.card});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Real webp only — plain placeholder if an unsanitized card
          // ever slips through (never emoji in gameplay).
          if (card.image != null)
            SizedBox(
              height: 70,
              child: CardImage.forCard(card, padding: EdgeInsets.zero),
            )
          else
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: card.colorAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              card.sound,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: card.colorAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
