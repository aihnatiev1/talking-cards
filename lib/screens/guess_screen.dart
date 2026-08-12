import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/weak_words_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/game_celebration_overlay.dart';
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
  bool _resultsLogged = false;
  bool _celebrationShown = false;
  OverlayEntry? _confettiEntry;

  late final AutoDisposeStateNotifierProvider<QuizNotifier, QuizState?> _provider;

  // Pulsing speaker animation
  late final AnimationController _speakerPulse;
  late final Animation<double> _speakerScale;

  @override
  void initState() {
    super.initState();
    // Playable = real recorded audio only — TTS was removed from the app,
    // so a card without a recording can never be the target of a round.
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

    AnalyticsService.instance.logQuizStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Quiz requires at least 4 image-bearing cards to build its MCQ
      // options. If the caller (e.g. SRS banner with <4 due) didn't pad
      // enough, close the screen instead of hanging on the loader.
      final playable = soundCards.where((c) => c.image != null).length;
      if (playable < 4) {
        final s = AppS(ref.read(languageProvider));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s('Ще не достатньо карток для гри',
              'Not enough cards to play')),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
        return;
      }
      ref.read(_provider.notifier).start();
      // Entry voice line first, then a short gap before the first word.
      AudioService.instance.playInstruction(
        'guess',
        isEn: ref.read(languageProvider) == 'en',
      );
      Future.delayed(const Duration(milliseconds: 400), () {
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
    // Only recorded audio — no TTS fallback (see pubspec: flutter_tts removed).
    if (AudioService.instance.hasSound(card.audioKey)) {
      AudioService.instance.playWordOnly(card.audioKey, card.sound);
    }
  }

  void _onAnswer(String cardId) {
    if (_waitingNext) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;

    setState(() => _answeredCardId = cardId);
    ref.read(_provider.notifier).answer(cardId);

    final isCorrect = cardId == state.correctCard.id;

    // Update SRS state: quality 5 = correct first try, 2 = wrong
    ref
        .read(srsProvider.notifier)
        .recordAnswer(state.correctCard.id, isCorrect ? 5 : 2);
    if (isCorrect) {
      ref.read(dailyQuestProvider.notifier).recordSrsReview();
    } else {
      ref.read(weakWordsProvider.notifier).recordMistake(state.correctCard.id);
    }

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      AudioService.instance.playSfx('ding');
      AudioService.instance
          .playPraise(isEn: ref.read(languageProvider) == 'en');
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
      // Gentle redirection — soft haptic, then replay the target word so the
      // child hears what to look for again instead of silence.
      HapticFeedback.lightImpact();
      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _answeredCardId = null);
        _playCurrentSound();
      });
    }
  }

  void _restart() {
    ref.read(_provider.notifier).restart();
    setState(() {
      _answeredCardId = null;
      _waitingNext = false;
      _resultsLogged = false;
      _celebrationShown = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _playCurrentSound();
    });
  }

  /// Fires completion side effects once and shows the shared celebration
  /// overlay (no scores / stars — every finished session is a full win).
  void _onFinished(QuizState state) {
    if (_celebrationShown) return;
    _celebrationShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_resultsLogged) {
        _resultsLogged = true;
        AnalyticsService.instance.logQuizComplete(state.score, state.totalRounds);
        ref.read(gameStatsProvider.notifier).record('quiz', state.score);
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
      }
      showGameCelebration(
        context,
        lang: ref.read(languageProvider),
        childName: ref.read(profileProvider).active?.name ?? '',
        onAgain: _restart,
        onDone: () => Navigator.of(context).pop(),
      );
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
            const Text('🎧', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ref.read(languageProvider) == 'en'
                    ? 'Guess the word'
                    : 'Вгадай звук',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(QuizState? state) {
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.finished) {
      // Celebration overlay is a dialog route — keep the body empty under it.
      _onFinished(state);
      return const SizedBox.shrink();
    }
    return _buildQuiz(state);
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
