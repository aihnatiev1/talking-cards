import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';

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
    with
        TickerProviderStateMixin,
        ShakeAnimationMixin,
        ConfettiOverlayMixin,
        GameStateMixin {
  @override
  String get gameId => 'opposite_game';

  bool _answered = false;
  String? _tappedId;

  late _Round _round;

  @override
  void initState() {
    super.initState();
    initShake();
    startGame();
    _buildRound();
  }

  @override
  void dispose() {
    disposeShake();
    disposeConfetti();
    super.dispose();
  }

  void _buildRound() {
    if (!nextRound()) return;

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
      _tappedId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.playWordOnly(question.audioKey, question.sound);
    });
  }

  void _onTap(CardModel card) {
    if (_answered) return;
    final isCorrect = card.id == _round.correct.id;

    setState(() {
      _tappedId = card.id;
      _answered = true;
    });

    if (isCorrect) {
      HapticFeedback.lightImpact();
      scorePoint();
      showConfetti();
      // Play the opposite word so child hears both words of the pair
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) AudioService.instance.playWordOnly(card.audioKey, card.sound);
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _buildRound();
      });
    } else {
      HapticFeedback.mediumImpact();
      shake(id: card.id);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() { _answered = false; _tappedId = null; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    if (finished) return _buildFinishScreen(s);

    final question = _round.question;
    final correct = _round.correct;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FF),
      appBar: AppBar(
        title: Text(
          s('Знайди протилежність', 'Find the opposite'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $score  $roundsPlayed/$maxRounds',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Question card — large, tappable for audio (word only — kids
              // get confused if the full example sentence plays each tap)
              GestureDetector(
                onTap: () => AudioService.instance
                    .playWordOnly(question.audioKey, question.sound),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _QuestionCard(key: ValueKey(question.id), card: question, s: s),
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
                    final isTapped = _tappedId == card.id;

                    final tile = _OptionTile(
                      card: card,
                      showCorrect: _answered && isCorrectCard,
                      showWrong: _answered && isTapped && !isCorrectCard,
                      onTap: () => _onTap(card),
                    );

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: wrapShake(tile, id: card.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishScreen(AppS s) {
    final pct = score / maxRounds;
    final stars = pct >= 0.8 ? 3 : pct >= 0.5 ? 2 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stars == 3
                      ? s('Чудово! 🎉', 'Excellent! 🎉')
                      : stars == 2
                          ? s('Молодець! 👍', 'Well done! 👍')
                          : s('Спробуй ще! 💪', 'Keep trying! 💪'),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Text(
                      i < stars ? '⭐' : '☆',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s('$score з $maxRounds протилежностей',
                      '$score of $maxRounds opposites'),
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      s('Готово', 'Done'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    resetGame();
                    _buildRound();
                  },
                  child: Text(
                    s('Грати ще раз 🔄', 'Play again 🔄'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
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
          if (card.image != null)
            SizedBox(
              height: 110,
              child: Image.asset(
                'assets/images/webp/${card.image}.webp',
                fit: BoxFit.contain,
              ),
            )
          else
            Text(card.emoji, style: const TextStyle(fontSize: 80)),
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
//  Option tile
// ─────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final CardModel card;
  final bool showCorrect;
  final bool showWrong;
  final VoidCallback onTap;

  const _OptionTile({
    required this.card,
    required this.showCorrect,
    required this.showWrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: showCorrect
              ? const Color(0xFFE8F5E9)
              : showWrong
                  ? const Color(0xFFFFEBEE)
                  : card.colorBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showCorrect
                ? const Color(0xFF43A047)
                : showWrong
                    ? const Color(0xFFE53935)
                    : card.colorAccent.withValues(alpha: 0.3),
            width: showCorrect || showWrong ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Vertical layout: image centered on top, word below — matches the
        // question card above so the whole screen reads as a column of
        // big centered illustrations.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (card.image != null)
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/webp/${card.image}.webp',
                    fit: BoxFit.contain,
                  ),
                )
              else
                Text(card.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(width: 14),
              Text(
                card.sound,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: showCorrect
                      ? const Color(0xFF2E7D32)
                      : showWrong
                          ? const Color(0xFFC62828)
                          : card.colorAccent,
                ),
              ),
              const Spacer(),
              if (showCorrect)
                const Text('✅', style: TextStyle(fontSize: 22)),
              if (showWrong)
                const Text('❌', style: TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}
