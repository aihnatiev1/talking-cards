import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

class RepeatGameScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const RepeatGameScreen({super.key, required this.cards});

  @override
  ConsumerState<RepeatGameScreen> createState() => _RepeatGameScreenState();
}

class _RepeatGameScreenState extends ConsumerState<RepeatGameScreen>
    with TickerProviderStateMixin {
  late List<CardModel> _deck;
  int _index = 0;
  int _score = 0;
  int _attempts = 0;
  bool _listening = false;
  bool _answered = false;
  bool _correct = false;
  String? _heard;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  // Mic pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Card flip animation
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  Timer? _listenTimeout;
  static const _maxAttempts = 2;

  @override
  void initState() {
    super.initState();
    _deck = List<CardModel>.from(widget.cards)..shuffle(Random());

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    AnalyticsService.instance.logGameStart('repeat_game');
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _listenTimeout?.cancel();
    _pulseCtrl.dispose();
    _flipCtrl.dispose();
    _confettiEntry?.remove();
    SpeechService.instance.cancelListening();
    super.dispose();
  }

  CardModel get _current => _deck[_index];

  Future<void> _speakCurrent() async {
    await AudioService.instance.playWordOnly(_current.audioKey, _current.sound);
  }

  Future<void> _startListening() async {
    if (_listening || _answered) return;
    final speech = SpeechService.instance;

    if (!speech.isAvailable) {
      // No mic support — show manual confirm UI
      setState(() => _listening = true);
      return;
    }

    setState(() {
      _listening = true;
      _heard = null;
    });
    _pulseCtrl.repeat(reverse: true);

    // Auto-stop after 6s if speech recognition produces no result
    _listenTimeout?.cancel();
    _listenTimeout = Timer(const Duration(seconds: 6), () {
      if (mounted && _listening) _stopListening();
    });

    await speech.startListening(
      pauseFor: const Duration(seconds: 3),
      onResult: (text) {
        _listenTimeout?.cancel();
        _pulseCtrl.stop();
        _pulseCtrl.reset();
        _evaluateResult(text);
      },
    );
  }

  void _stopListening() {
    _listenTimeout?.cancel();
    SpeechService.instance.stopListening();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() => _listening = false);
  }

  void _evaluateResult(String recognized) {
    final isMatch = SpeechService.matches(recognized, _current.sound);
    setState(() {
      _listening = false;
      _answered = true;
      _correct = isMatch;
      _heard = recognized;
      _attempts++;
    });

    if (isMatch) {
      HapticFeedback.lightImpact();
      _score++;
      _showConfetti();
      if (!_questDone) {
        ref.read(dailyQuestProvider.notifier).recordSpeechCorrect();
        if (_score >= 3) {
          _questDone = true;
          AnalyticsService.instance.logGameComplete('repeat_game', _score);
          ref.read(gameStatsProvider.notifier).record('repeat_game', _score);
        }
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  // Manual confirm (when no mic) — user says they got it right
  void _manualCorrect() {
    _evaluateResult(_current.sound);
  }

  void _manualWrong() {
    _evaluateResult('');
  }

  void _nextCard() {
    _flipCtrl.forward().then((_) {
      _flipCtrl.reset();
      setState(() {
        _index = (_index + 1) % _deck.length;
        _answered = false;
        _correct = false;
        _heard = null;
        _attempts = 0;
        _listening = false;
      });
      _speakCurrent();
    });
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
    final card = _current;
    final hasMic = SpeechService.instance.isAvailable;

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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  min(_deck.length, 8),
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index % 8
                          ? kAccent
                          : i < _index % 8
                              ? kAccent.withValues(alpha: 0.3)
                              : Colors.grey[300],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Card
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _flipAnim,
                  builder: (_, child) => Transform.scale(
                    scale: 1.0 - (_flipAnim.value * 0.08),
                    child: Opacity(
                      opacity: 1.0 - (_flipAnim.value * 0.5),
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
                          color: _answered
                              ? (_correct
                                  ? const Color(0xFF43A047)
                                  : const Color(0xFFE53935))
                              : card.colorAccent.withValues(alpha: 0.25),
                          width: _answered ? 3 : 1.5,
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
                          // Image or emoji
                          if (card.image != null)
                            SizedBox(
                              height: 140,
                              child: Image.asset(
                                'assets/images/webp/${card.image}.webp',
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Text(card.emoji,
                                style: const TextStyle(fontSize: 100)),

                          const SizedBox(height: 16),

                          // Word
                          Text(
                            card.sound,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: card.colorAccent,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Speaker hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: Colors.grey[400], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                s('Натисни на картку, щоб послухати',
                                    'Tap card to listen'),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Result feedback
                          if (_answered)
                            AnimatedOpacity(
                              opacity: 1,
                              duration: const Duration(milliseconds: 300),
                              child: Column(
                                children: [
                                  Text(
                                    _correct
                                        ? s('Чудово! ✅', 'Great! ✅')
                                        : (_heard != null && _heard!.isNotEmpty
                                            ? s('Почули: «$_heard» — спробуй ще!',
                                                'Heard: «$_heard» — try again!')
                                            : s('Спробуй ще раз!',
                                                'Try again!')),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _correct
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Controls
              if (!_answered) ...[
                if (hasMic) ...[
                  // Mic button
                  GestureDetector(
                    onTap: _listening ? _stopListening : _startListening,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _listening ? _pulseAnim.value : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _listening ? const Color(0xFFE53935) : kAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (_listening
                                      ? const Color(0xFFE53935)
                                      : kAccent)
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _listening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _listening
                        ? s('Слухаю... говори!', 'Listening...')
                        : s('Натисни і скажи слово', 'Tap and say the word'),
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ] else ...[
                  // No mic — manual mode
                  Text(
                    s('Скажи: «${card.sound}»', 'Say: «${card.sound}»'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _manualWrong,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(s('Не вийшло ❌', 'Not quite ❌')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _manualCorrect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(s('Сказав! ✅', 'Said it! ✅')),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                // Next card button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _nextCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _correct ? kAccent : Colors.grey[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      s('Далі ▶', 'Next ▶'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!_correct && _attempts < _maxAttempts) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _answered = false;
                        _heard = null;
                      });
                      _speakCurrent();
                    },
                    child: Text(
                      s('Спробувати ще раз 🔄', 'Try again 🔄'),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
