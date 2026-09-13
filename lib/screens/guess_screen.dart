import 'dart:async';

import 'package:flutter/material.dart';
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
import '../services/feedback_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/quiz_option.dart';

class GuessScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const GuessScreen({super.key, required this.cards});

  @override
  ConsumerState<GuessScreen> createState() => _GuessScreenState();
}

class _GuessScreenState extends ConsumerState<GuessScreen> {
  /// The right tile is framed in success until the next question.
  bool _showCorrect = false;
  bool _waitingNext = false;
  bool _resultsLogged = false;
  bool _celebrationShown = false;

  // A miss is a nudge on the tapped tile, never a colour; after the second
  // miss in one question the right tile starts to glow (G10).
  final _misses = MissTracker();
  final Map<String, int> _nudges = {};

  late final AutoDisposeStateNotifierProvider<QuizNotifier, QuizState?>
  _provider;

  @override
  void initState() {
    super.initState();
    // Playable = real recorded audio only — TTS was removed from the app,
    // so a card without a recording can never be the target of a round.
    final soundCards = widget.cards
        .where((c) => AudioService.instance.hasSound(c.audioKey))
        .toList();
    _provider = StateNotifierProvider.autoDispose<QuizNotifier, QuizState?>((
      ref,
    ) {
      return QuizNotifier(soundCards);
    });

    AnalyticsService.instance.logQuizStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Quiz requires at least 4 image-bearing cards to build its MCQ
      // options. If the caller (e.g. SRS banner with <4 due) didn't pad
      // enough, close the screen instead of hanging on the loader.
      final playable = soundCards.where((c) => c.image != null).length;
      if (playable < 4) {
        final s = AppS(ref.read(languageProvider) == 'en');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s('Ще не достатньо карток для гри', 'Not enough cards to play'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

    ref.read(_provider.notifier).answer(cardId);

    final isCorrect = cardId == state.correctCard.id;

    // Distinguish first-try success from success after help.
    ref
        .read(srsProvider.notifier)
        .recordAnswer(
          state.correctCard.id,
          ref.read(_provider.notifier).lastAnswerQuality,
        );
    if (isCorrect) {
      ref.read(dailyQuestProvider.notifier).recordSrsReview();
    } else {
      ref.read(weakWordsProvider.notifier).recordMistake(state.correctCard.id);
    }

    if (isCorrect) {
      // The tile itself pops, frames in success and bursts (AnswerFrame).
      FeedbackService.instance.event(FeedbackEvent.correct);
      AudioService.instance.playPraise(
        isEn: ref.read(languageProvider) == 'en',
      );
      setState(() => _showCorrect = true);
      _waitingNext = true;
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _showCorrect = false;
          _waitingNext = false;
          _misses.reset();
          _nudges.clear();
        });
        ref.read(_provider.notifier).next();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _playCurrentSound();
        });
      });
    } else {
      // Gentle redirection — a soft low pop (no buzzer, no haptic), one
      // nudge of the tapped tile, then the target word again. The other
      // tiles stay tappable and the progress pill never moves back.
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _nudges[cardId] = (_nudges[cardId] ?? 0) + 1;
        _misses.miss();
      });
      if (_misses.justCrossed) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
      }
      Timer(const Duration(milliseconds: 600), () {
        if (mounted) _playCurrentSound();
      });
    }
  }

  void _restart() {
    ref.read(_provider.notifier).restart();
    setState(() {
      _showCorrect = false;
      _waitingNext = false;
      _resultsLogged = false;
      _celebrationShown = false;
      _misses.reset();
      _nudges.clear();
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
        AnalyticsService.instance.logQuizComplete(
          state.score,
          state.totalRounds,
        );
        ref.read(gameStatsProvider.notifier).record('quiz', state.score);
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
      }
      showGameCelebration(
        context,
        isEn: ref.read(languageProvider) == 'en',
        childName: ref.read(profileProvider).active?.name ?? '',
        onAgain: _restart,
        onDone: () => Navigator.of(context).pop(),
      );
    });
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  static const _accent = kAccent;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);

    // Header: the game's badge, not a sentence — a two-year-old cannot read
    // "Guess the word"; the instruction is spoken (`instr_guess`).
    return KidScreen.game(
      accent: _accent,
      title: const Text('🎧', style: TextStyle(fontSize: 28)),
      progress: state == null || state.finished
          ? null
          : state.round / state.totalRounds,
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
          // Big speaker button — pulses (1.0 → 1.15, 800 ms) while the word
          // plays. Under reduced motion it rests at 1.0; it is already the
          // one big accent-coloured button on the screen.
          KidTap(
            // Replays the target word — no pop under the voice.
            sound: KidSound.none,
            onTap: _playCurrentSound,
            child: ValueListenableBuilder<bool>(
              valueListenable: AudioService.instance.isSpeaking,
              builder: (_, speaking, speaker) => AmbientLoop(
                period: const Duration(milliseconds: 800),
                enabled: speaking,
                builder: (_, t, child) => Transform.scale(
                  scale: 1.0 + 0.15 * t,
                  child: child,
                ),
                child: speaker,
              ),
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
                final isTarget = card.id == state.correctCard.id;
                final mark = !isTarget
                    ? AnswerMark.none
                    : _showCorrect
                        ? AnswerMark.correct
                        : _misses.showHint
                            ? AnswerMark.hint
                            : AnswerMark.none;
                return QuizOption(
                  key: ValueKey(card.id),
                  card: card,
                  mark: mark,
                  nudge: _nudges[card.id] ?? 0,
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
