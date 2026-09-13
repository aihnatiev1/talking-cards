import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../models/semantic_group.dart';
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
  final Random _rng = Random();
  late _Round _round;

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

  /// Builds a question the child can *see*: three cards of one semantic
  /// group and one from another (experience audit п. 22). Only when the
  /// available cards cannot make one — a profile with nothing but sound
  /// packs open — does it fall back to the old "three from one pack, one
  /// from another", which is right by catalogue and not always by picture.
  void _buildRound() {
    final task = SemanticGroups.task(
      widget.packs.expand((p) => p.cards),
      _rng,
    );
    final _Round round = task != null ? _semantic(task) : _byPack();

    setState(() {
      _round = round;
      _answered = false;
      _misses.reset();
      _nudges.clear();
    });
  }

  _Round _semantic(OddOneOutTask task) => _Round(
        slots: [
          ...task.majority.map((c) => _Slot(card: c, isOdd: false)),
          _Slot(card: task.odd, isOdd: true),
        ]..shuffle(_rng),
        key: task.majorityGroup.name,
      );

  _Round _byPack() {
    final pool = [
      for (final p in widget.packs)
        if (p.cards.isNotEmpty) p,
    ]..shuffle(_rng);
    final majority = pool.first;
    final oddPack = pool.length > 1 ? pool[1] : pool.first;

    final majorityCards = List<CardModel>.from(majority.cards)..shuffle(_rng);
    final oddCards = [
      for (final c in oddPack.cards)
        if (!majorityCards.take(3).any((m) => m.id == c.id)) c,
    ]..shuffle(_rng);

    return _Round(
      slots: [
        ...majorityCards.take(3).map((c) => _Slot(card: c, isOdd: false)),
        _Slot(card: oddCards.first, isOdd: true),
      ]..shuffle(_rng),
      key: majority.id,
    );
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
      // The card itself pops, frames in success and bursts (AnswerFrame) —
      // and `_answered` also starts the wordless demonstration: the three
      // that belong together close ranks, the odd one drifts off the board.
      setState(() {
        _answered = true;
        scorePoint();
      });
      if (score >= maxRounds) {
        Future.delayed(DT.motion.sortRoundGap, () {
          if (!mounted) return;
          completeGame();
          _showCelebration();
        });
      } else {
        Future.delayed(DT.motion.sortRoundGap, () {
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
    final motion = MotionPolicy.of(context);

    final majorityCards = _round.majority;
    final hintColor = majorityCards.first.colorAccent;

    // No text title — "Odd one out" is for the parent; the hint row of
    // thumbnails + ❓ below is the child's question.
    return KidScreen.game(
      accent: DT.brand,
      background: DT.violetTint,
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Hint — small thumbnails of the actual majority cards + "?"
              AnimatedSwitcher(
                duration: motion.dur(DT.motion.enter),
                child: Column(
                  key: ValueKey(_round.key),
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
                        color: hintColor,
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
                  crossAxisCount: _columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.88,
                  children: [
                    for (var i = 0; i < _round.slots.length; i++)
                      _buildCard(_round.slots[i], i),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
      ),
    );
  }

  static const _columns = 2;

  Widget _buildCard(_Slot sl, int index) {
    final card = sl.card;
    final mark = !sl.isOdd
        ? AnswerMark.none
        : _answered
            ? AnswerMark.correct
            : _misses.showHint
                ? AnswerMark.hint
                : AnswerMark.none;

    return _SortDemo(
      key: ValueKey(card.id),
      playing: _answered,
      isOdd: sl.isOdd,
      column: index % _columns,
      row: index ~/ _columns,
      child: KidTap(
        onTap: () => _onTap(sl),
        child: AnswerFrame(
          background: card.colorBg,
          accent: card.colorAccent,
          mark: mark,
          nudge: _nudges[card.id] ?? 0,
          radius: 20,
          child: _CardChip(card: card),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Slot {
  final CardModel card;
  final bool isOdd;
  const _Slot({required this.card, required this.isOdd});
}

class _Round {
  final List<_Slot> slots;

  /// What the hint row is keyed on for its cross-fade — the semantic group
  /// name, or the pack id in the fallback.
  final String key;

  const _Round({required this.slots, required this.key});

  List<CardModel> get majority => [
        for (final s in slots)
          if (!s.isOdd) s.card,
      ];
}

// ─────────────────────────────────────────────
//  The answer's short explanation (п. 22)
// ─────────────────────────────────────────────

/// Wordless "why": once the odd card is found, the three that belong
/// together lean in towards each other and the odd one slides off the board
/// and dims. [DT.motion.sortDemo] long, inside the [DT.motion.sortRoundGap]
/// that was already there — the next question does not wait for it.
///
/// Under reduced motion nothing travels; the success frame and sticker on
/// the odd tile still carry the answer.
class _SortDemo extends StatelessWidget {
  final bool playing;
  final bool isOdd;
  final int column;
  final int row;
  final Widget child;

  const _SortDemo({
    super.key,
    required this.playing,
    required this.isOdd,
    required this.column,
    required this.row,
    required this.child,
  });

  /// How far the group closes in, and how far the odd one leaves — both as
  /// a fraction of a tile.
  static const _closeIn = 0.05;
  static const _leaveX = 0.42;
  static const _leaveY = 0.22;

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context);
    final away = column == 0 ? -_leaveX : _leaveX;
    final awayY = row == 0 ? -_leaveY : _leaveY;
    final offset = !playing
        ? Offset.zero
        : isOdd
            ? Offset(away, awayY)
            : Offset(
                column == 0 ? _closeIn : -_closeIn,
                row == 0 ? _closeIn : -_closeIn,
              );

    return AnimatedSlide(
      offset: motion.reduce ? Offset.zero : offset,
      duration: motion.dur(DT.motion.sortDemo),
      curve: DT.motion.standard,
      child: AnimatedOpacity(
        opacity: playing && isOdd && !motion.reduce ? 0.55 : 1,
        duration: motion.dur(DT.motion.sortDemo),
        child: AnimatedScale(
          scale: !playing || motion.reduce
              ? 1
              : isOdd
                  ? 0.86
                  : 1.03,
          duration: motion.dur(DT.motion.sortDemo),
          curve: DT.motion.standard,
          child: child,
        ),
      ),
    );
  }
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
      // 56, not 44: the hint row is the child's second chance at the round
      // and has to read at arm's length (ux-gap G12).
      width: 56,
      height: 56,
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
