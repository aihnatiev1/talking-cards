import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

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
    with SingleTickerProviderStateMixin {
  int _score = 0;
  bool _answered = false;
  String? _tappedId;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  late _Round _round;

  // Shake for wrong answers
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingId;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _shakeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _shakeCtrl.reset();
        setState(() => _shakingId = null);
      }
    });
    AnalyticsService.instance.logGameStart('opposite_game');
    _buildRound();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _confettiEntry?.remove();
    super.dispose();
  }

  void _buildRound() {
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
      _shakingId = null;
    });

    // Speak question after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speakCard(
        question.audioKey,
        question.sound,
        question.text,
      );
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
      _score++;
      _showConfetti();
      Future.delayed(const Duration(milliseconds: 300), () {
        final isEn = ref.read(languageProvider) == 'en';
        TtsService.instance.speak(
          isEn ? 'Great!' : 'Молодець!',
          locale: isEn ? 'en-US' : 'uk-UA',
        );
      });
      if (!_questDone && _score >= 3) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
        AnalyticsService.instance.logGameComplete('opposite_game', _score);
        ref.read(gameStatsProvider.notifier).record('opposite_game', _score);
      }
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _buildRound();
      });
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _shakingId = card.id);
      _shakeCtrl.forward();
    }
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    _confettiEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(origin: Offset(size.width / 2, size.height / 3)),
      ),
    );
    Overlay.of(context).insert(_confettiEntry!);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _confettiEntry?.remove();
      _confettiEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');
    final question = _round.question;
    final correct = _round.correct;

    return Scaffold(
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
                '⭐ $_score',
                style: const TextStyle(
                  fontSize: 16,
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

              // Question card — large, tappable for audio
              GestureDetector(
                onTap: () => AudioService.instance.speakCard(
                  question.audioKey,
                  question.sound,
                  question.text,
                ),
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
                  Text('↔️', style: const TextStyle(fontSize: 22)),
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
                    final isShaking = _shakingId == card.id;

                    Widget tile = _OptionTile(
                      card: card,
                      showCorrect: _answered && isCorrectCard,
                      showWrong: _answered && isTapped && !isCorrectCard,
                      onTap: () => _onTap(card),
                    );

                    if (isShaking) {
                      tile = AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) {
                          final offset = 8 *
                              (0.5 - (_shakeAnim.value % 0.25) / 0.25).abs() *
                              2 -
                              4;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: tile,
                      );
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: tile,
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
      height: 180,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (card.image != null)
            SizedBox(
              height: 100,
              child: Image.asset(
                'assets/images/webp/${card.image}.webp',
                fit: BoxFit.contain,
              ),
            )
          else
            Text(card.emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.sound,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: card.colorAccent,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.volume_up_rounded,
                      color: Colors.grey[400], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    s('торкнись', 'tap to hear'),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
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
        // Horizontal layout: image/emoji on left, word on right
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (card.image != null)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset(
                    'assets/images/webp/${card.image}.webp',
                    fit: BoxFit.contain,
                  ),
                )
              else
                Text(card.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
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
