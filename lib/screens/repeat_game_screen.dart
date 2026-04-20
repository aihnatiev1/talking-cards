import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';

class RepeatGameScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const RepeatGameScreen({super.key, required this.cards});

  @override
  ConsumerState<RepeatGameScreen> createState() => _RepeatGameScreenState();
}

class _RepeatGameScreenState extends ConsumerState<RepeatGameScreen>
    with
        TickerProviderStateMixin,
        ShakeAnimationMixin,
        ConfettiOverlayMixin,
        GameStateMixin {
  @override
  String get gameId => 'repeat_game';

  @override
  int get maxRounds => _deck.length;

  // Speech games don't complete playQuiz — completion is via recordSpeechCorrect.
  @override
  QuestTask? get questTask => null;

  late List<CardModel> _deck;
  int _index = 0;
  bool _answered = false; // buttons locked during transition

  // Card slide-out when advancing to next
  late AnimationController _exitCtrl;
  late Animation<double> _exitSlide;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    _deck = List<CardModel>.from(widget.cards)..shuffle(Random());

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _exitSlide = Tween<double>(begin: 0, end: -40).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    initShake();

    startGame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
    disposeShake();
    disposeConfetti();
    super.dispose();
  }

  CardModel get _current => _deck[_index];

  Future<void> _speakCurrent() async {
    await AudioService.instance.playWordOnly(_current.audioKey, _current.sound);
  }

  Future<void> _onCorrect() async {
    if (_answered) return;
    setState(() => _answered = true);

    HapticFeedback.lightImpact();
    scorePoint();
    showConfetti();
    ref.read(dailyQuestProvider.notifier).recordSpeechCorrect();

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _advance();
  }

  Future<void> _onWrong() async {
    if (_answered) return;
    setState(() => _answered = true);

    HapticFeedback.mediumImpact();

    // Shake the card
    await shakeController.forward();
    shakeController.reset();
    if (!mounted) return;

    // Replay audio after brief pause
    await Future.delayed(const Duration(milliseconds: 200));
    await _speakCurrent();
    if (!mounted) return;

    // Unlock buttons — let them try again
    setState(() => _answered = false);
  }

  Future<void> _advance() async {
    await _exitCtrl.forward();
    _exitCtrl.reset();
    if (!mounted) return;

    final isLast = _index >= _deck.length - 1;

    if (isLast) {
      completeGame();
      setState(() {
        _answered = false;
      });
    } else {
      setState(() {
        _index++;
        _answered = false;
      });
      _speakCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    if (finished) return _buildFinishScreen(s);

    final card = _current;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFFF5),
      appBar: AppBar(
        title: Text(
          s('Повтори за мною', 'Repeat after me'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $score',
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Progress dots
              _buildProgressDots(),

              const SizedBox(height: 24),

              // Card
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_exitCtrl, shakeController]),
                  builder: (_, child) => Transform.translate(
                    offset: Offset(shakeOffset.value, _exitSlide.value),
                    child: Opacity(
                      opacity: _exitFade.value,
                      child: child,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: _speakCurrent,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: card.colorBg,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: card.colorAccent.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (card.image != null)
                            SizedBox(
                              height: 160,
                              child: Image.asset(
                                'assets/images/webp/${card.image}.webp',
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Text(card.emoji,
                                style: const TextStyle(fontSize: 100)),

                          const SizedBox(height: 16),

                          Text(
                            card.sound,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: card.colorAccent,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: Colors.grey[400], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                s('Натисни, щоб послухати', 'Tap to listen'),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Parent controls
              Text(
                s('Скажи: «${card.sound}»', 'Say: «${card.sound}»'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _answered ? null : _onWrong,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        s('Не вийшло ❌', 'Not quite ❌'),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _answered ? null : _onCorrect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        s('Сказав! ✅', 'Said it! ✅'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    final count = min(_deck.length, 10);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final done = i < _index;
        final active = i == _index;
        return Container(
          width: active ? 10 : 8,
          height: active ? 10 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? kAccent.withValues(alpha: 0.35)
                : active
                    ? kAccent
                    : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildFinishScreen(AppS s) {
    final total = _deck.length;
    final pct = total > 0 ? score / total : 0.0;
    final stars = pct >= 0.8 ? 3 : pct >= 0.5 ? 2 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFFF5),
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
                  s('$score з $total слів', '$score of $total words'),
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
                    setState(() {
                      _deck.shuffle(Random());
                      _index = 0;
                      _answered = false;
                    });
                    _speakCurrent();
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
