import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/quiz_provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/quiz_option.dart';

class GuessScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const GuessScreen({super.key, required this.cards});

  @override
  ConsumerState<GuessScreen> createState() => _GuessScreenState();
}

class _GuessScreenState extends ConsumerState<GuessScreen>
    with SingleTickerProviderStateMixin {
  String? _answeredCardId;
  bool _waitingNext = false;
  OverlayEntry? _confettiEntry;

  late final AutoDisposeStateNotifierProvider<QuizNotifier, QuizState?> _provider;

  // Pulsing speaker animation
  late final AnimationController _speakerPulse;
  late final Animation<double> _speakerScale;

  @override
  void initState() {
    super.initState();
    final soundCards = widget.cards
        .where((c) => AudioService.instance.hasSound(c.audioKey))
        .toList();
    _provider = StateNotifierProvider.autoDispose<QuizNotifier, QuizState?>((ref) {
      return QuizNotifier(soundCards);
    });

    _speakerPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _speakerScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _speakerPulse, curve: Curves.easeInOut),
    );

    AudioService.instance.isSpeaking.addListener(_onSpeakingChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_provider.notifier).start();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _playCurrentSound();
      });
    });
  }

  void _onSpeakingChanged() {
    if (!mounted) return;
    if (AudioService.instance.isSpeaking.value) {
      _speakerPulse.repeat(reverse: true);
    } else {
      _speakerPulse.stop();
      _speakerPulse.value = 0.0;
    }
  }

  void _playCurrentSound() {
    final state = ref.read(_provider);
    if (state == null || state.finished) return;
    final card = state.correctCard;
    AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
  }

  void _onAnswer(String cardId) {
    if (_waitingNext) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;

    setState(() => _answeredCardId = cardId);
    ref.read(_provider.notifier).answer(cardId);

    final isCorrect = cardId == state.correctCard.id;
    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _showConfetti();
      _waitingNext = true;
      Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _answeredCardId = null;
          _waitingNext = false;
        });
        ref.read(_provider.notifier).next();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _playCurrentSound();
        });
      });
    } else {
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _answeredCardId = null);
      });
    }
  }

  void _restart() {
    ref.read(_provider.notifier).restart();
    setState(() {
      _answeredCardId = null;
      _waitingNext = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _playCurrentSound();
    });
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    final origin = Offset(size.width / 2, size.height / 2);
    _confettiEntry = OverlayEntry(
      builder: (_) => ConfettiBurst(origin: origin),
    );
    Overlay.of(context).insert(_confettiEntry!);
    Future.delayed(const Duration(milliseconds: 1100), () {
      _confettiEntry?.remove();
      _confettiEntry = null;
    });
  }

  @override
  void dispose() {
    _confettiEntry?.remove();
    AudioService.instance.isSpeaking.removeListener(_onSpeakingChanged);
    _speakerPulse.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  static const _accent = kAccent;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Hero(
              tag: 'pack_icon_quiz',
              child: Material(
                color: Colors.transparent,
                child: Text('🎧', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              state != null && !state.finished
                  ? 'Вгадай звук ${state.round}/${state.totalRounds}'
                  : 'Вгадай звук',
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (state != null && !state.finished)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '⭐ ${state.score}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kStreakOrange,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : state.finished
              ? _buildResults(state)
              : _buildQuiz(state),
    );
  }

  Widget _buildResults(QuizState state) {
    final score = state.score;
    final total = state.totalRounds;
    final ratio = total > 0 ? score / total : 0.0;

    String emoji;
    String message;
    if (ratio >= 0.9) {
      emoji = '🏆';
      message = 'Чудово!';
    } else if (ratio >= 0.7) {
      emoji = '🌟';
      message = 'Молодець!';
    } else if (ratio >= 0.5) {
      emoji = '👍';
      message = 'Непогано!';
    } else {
      emoji = '💪';
      message = 'Спробуй ще!';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            // Score as stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    i < score ? '⭐' : '☆',
                    style: TextStyle(
                      fontSize: total > 7 ? 22 : 28,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text(
              '$score/$total',
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _restart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🔄', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Text(
                      'Грати ще раз',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  '🏠 На головну',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz(QuizState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Progress dots
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.round / state.totalRounds,
                minHeight: 6,
                backgroundColor: _accent.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Big pulsing speaker button
          GestureDetector(
            onTap: _playCurrentSound,
            child: ScaleTransition(
              scale: _speakerScale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent,
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 4 options in 2x2 grid — takes remaining space
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              physics: const NeverScrollableScrollPhysics(),
              children: state.options.map((card) {
                bool? isCorrectAnswer;
                if (_answeredCardId == card.id) {
                  isCorrectAnswer = card.id == state.correctCard.id;
                }
                return QuizOption(
                  card: card,
                  isCorrectAnswer: isCorrectAnswer,
                  onTap: () => _onAnswer(card.id),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
