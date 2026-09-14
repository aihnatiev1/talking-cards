import 'dart:async';
import 'dart:math' as math;

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
import '../providers/word_evidence_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/entrance_stagger.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/meadow_scene.dart';
import '../widgets/quiz_option.dart';

class GuessScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  /// Card id → the set it belongs to (its pack). The distractors of a
  /// three- or four-picture question are drawn from the answer's own set,
  /// so the child is choosing between animals and not between an animal
  /// and a bus (experience audit §19). Empty is legal — the question then
  /// falls back to the whole pool.
  final Map<String, String> cardGroups;

  const GuessScreen({
    super.key,
    required this.cards,
    this.cardGroups = const {},
  });

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
      // Age only says where the board of pictures starts; how many
      // pictures the next question shows is decided by how this one went.
      return QuizNotifier(
        soundCards,
        level: ref.read(profileProvider).active?.level ?? 2,
        groups: widget.cardGroups,
      );
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
      Future.delayed(DT.motion.gameInstructionGap, () {
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
      // A correct pick is "recognized in a game" — a different, stronger
      // signal than having seen the card, and it is counted separately.
      ref
          .read(wordEvidenceProvider.notifier)
          .recordRecognized(state.correctCard.id);
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
      Timer(DT.motion.quizAnswerHold, () {
        if (!mounted) return;
        setState(() {
          _showCorrect = false;
          _waitingNext = false;
          _misses.reset();
          _nudges.clear();
        });
        ref.read(_provider.notifier).next();
        Future.delayed(DT.motion.quizQuestionGap, () {
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
      if (_misses.misses == state.hintAfterMisses) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
      }
      Timer(DT.motion.quizRetell, () {
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
    Future.delayed(DT.motion.quizQuestionGap, () {
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

  static const _accent = DT.brand;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);

    // Header: the game's badge, not a sentence — a two-year-old cannot read
    // "Guess the word"; the instruction is spoken (`instr_guess`).
    return KidScreen.game(
      accent: _accent,
      // The same meadow Bubble Pop is played in. The board only ever
      // fills part of the screen — two pictures fill less than four — and
      // the rest was cream nothing, which reads as a screen that failed
      // to load. Now it is sky, and the pictures stand on the grass.
      background: DT.sceneSkyTop,
      title: const Text('🎧', style: TextStyle(fontSize: 28)),
      progress: state == null || state.finished
          ? null
          : state.round / state.totalRounds,
      body: Stack(
        children: [
          const Positioned.fill(child: MeadowScene()),
          Positioned.fill(child: _buildBody(state)),
        ],
      ),
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
            sound: null,
            onTap: _playCurrentSound,
            child: ValueListenableBuilder<bool>(
              valueListenable: AudioService.instance.isSpeaking,
              builder: (_, speaking, speaker) => AmbientLoop(
                period: DT.motion.speakerPulse,
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
          // Two, three or four pictures — the board is sized by how the
          // last questions actually went, never by the round number
          // (experience audit §19). The tiles keep their shape at every
          // size, so a two-picture question is two *big* pictures and not
          // two stretched ones.
          Expanded(
            child: StaggerScope(
              child: _OptionsBoard(
                options: state.options,
                tileBuilder: (index, card) {
                  final isTarget = card.id == state.correctCard.id;
                  final mark = !isTarget
                      ? AnswerMark.none
                      : _showCorrect
                          ? AnswerMark.correct
                          : _misses.misses >= state.hintAfterMisses
                              ? AnswerMark.hint
                              : AnswerMark.none;
                  // The options land one after another (G11) so the
                  // child's eye is walked across them instead of being
                  // met by a full board.
                  return StaggeredEntrance(
                    key: ValueKey(card.id),
                    index: index,
                    child: QuizOption(
                      card: card,
                      mark: mark,
                      nudge: _nudges[card.id] ?? 0,
                      onTap: () => _onAnswer(card.id),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  The board of pictures: 2 in a row, 3 as 2 + 1, 4 as 2 × 2
// ─────────────────────────────────────────────

/// Lays out the question's options at a constant tile shape.
///
/// A `GridView` stretched two tiles across the whole remaining height the
/// moment the board dropped from four pictures to two; here the tile keeps
/// its 0.85 ratio and the board is centred in whatever space is left, so
/// the youngest child — the one who gets two options — gets the biggest
/// pictures in the app.
class _OptionsBoard extends StatelessWidget {
  const _OptionsBoard({required this.options, required this.tileBuilder});

  final List<CardModel> options;
  final Widget Function(int index, CardModel card) tileBuilder;

  static const double _gap = 12;
  static const double _aspect = 0.85; // width / height

  /// The tallest a single-row tile may stretch to (width / height).
  static const double _tallAspect = 0.62;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CardModel>>[
      options.take(2).toList(),
      if (options.length > 2) options.sublist(2),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        var tileW = (box.maxWidth - _gap) / 2;
        var tileH = tileW / _aspect;
        if (rows.length == 1) {
          // Two options never fill a phone: the tile can only be half the
          // width, so at 0.85 the board floated in the middle of a screen
          // of nothing. A single row grows downwards into the space it
          // has instead — up to [_tallAspect], past which a picture is a
          // stripe. This is the youngest child's board; it should be the
          // biggest one in the app, and now it is.
          tileH = math.max(tileH, math.min(box.maxHeight, tileW / _tallAspect));
        }
        final stack = tileH * rows.length + _gap * (rows.length - 1);
        if (stack > box.maxHeight && stack > 0) {
          final k = (box.maxHeight - _gap * (rows.length - 1)) /
              (tileH * rows.length);
          tileW *= k;
          tileH *= k;
        }

        var index = 0;
        final children = <Widget>[];
        for (final row in rows) {
          if (children.isNotEmpty) children.add(const SizedBox(height: _gap));
          final tiles = <Widget>[];
          for (final card in row) {
            if (tiles.isNotEmpty) tiles.add(const SizedBox(width: _gap));
            tiles.add(
              SizedBox(
                width: tileW,
                height: tileH,
                child: tileBuilder(index++, card),
              ),
            );
          }
          children.add(
            Row(mainAxisAlignment: MainAxisAlignment.center, children: tiles),
          );
        }

        // Low, not centred: a two-picture board that floats in the middle
        // leaves its dead space under the tiles, which is exactly the part
        // of a phone a small hand can reach. A four-picture board fills
        // the space anyway, so this only moves the small boards down.
        return Align(
          alignment: const Alignment(0, 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        );
      },
    );
  }
}
