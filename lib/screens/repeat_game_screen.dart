import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/app_icons.dart';
import '../utils/l10n.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

class RepeatGameScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const RepeatGameScreen({super.key, required this.cards});

  @override
  ConsumerState<RepeatGameScreen> createState() => _RepeatGameScreenState();
}

class _RepeatGameScreenState extends ConsumerState<RepeatGameScreen>
    with
        SingleTickerProviderStateMixin,
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
  // Cards the child pressed "not quite" on — replayed once as an automatic
  // practice round before the celebration.
  final List<CardModel> _missed = [];
  bool _practiceRound = false;

  // Card slide-out when advancing to next
  late AnimationController _exitCtrl;
  late Animation<double> _exitSlide;
  late Animation<double> _exitFade;

  static const _sessionLength = 10;

  @override
  void initState() {
    super.initState();
    // Cap the session so a pack of 200+ cards doesn't become an endless loop.
    // 10 is the sweet spot for toddler attention span (30-60s each).
    final shuffled = List<CardModel>.from(widget.cards)..shuffle(Random());
    _deck = shuffled.take(_sessionLength).toList();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _exitSlide = Tween<double>(
      begin: 0,
      end: -40,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _exitFade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    startGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Entry voice line first, then a short gap before the first word.
      AudioService.instance.playInstruction(
        'repeat',
        isEn: ref.read(languageProvider) == 'en',
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _speakCurrent();
      });
    });
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
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

    // Used to be a silent haptic; a right answer now dings like every
    // other game.
    FeedbackService.instance.event(FeedbackEvent.correct);
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

    FeedbackService.instance.event(FeedbackEvent.wrong);
    // Remember the tricky word — after the main deck we run one gentle
    // practice pass with just these before celebrating. No punishment UI:
    // the card does not shake or change colour, it simply moves on.
    _missed.add(_current);

    await _advance();
  }

  void _restart() {
    resetGame();
    setState(() {
      final shuffled = List<CardModel>.from(widget.cards)..shuffle(Random());
      _deck = shuffled.take(_sessionLength).toList();
      _index = 0;
      _answered = false;
      _practiceRound = false;
      _missed.clear();
    });
    _speakCurrent();
  }

  /// One automatic re-run of only the words the child struggled with —
  /// the speech-therapy core of this game.
  void _startMissedRound() {
    final missed = List<CardModel>.from(_missed)..shuffle(Random());
    setState(() {
      _deck = missed;
      _index = 0;
      _answered = false;
      _practiceRound = true;
      _missed.clear();
    });
    _speakCurrent();
  }

  Future<void> _advance() async {
    await _exitCtrl.forward();
    _exitCtrl.reset();
    if (!mounted) return;

    final isLast = _index >= _deck.length - 1;

    if (isLast) {
      if (_missed.isNotEmpty && !_practiceRound) {
        _startMissedRound();
        return;
      }
      completeGame();
      setState(() {
        _answered = false;
      });
      showGameCelebration(
        context,
        isEn: ref.read(languageProvider) == 'en',
        childName: ref.read(profileProvider).active?.name ?? '',
        onAgain: _restart,
        onDone: () => Navigator.of(context).pop(),
      );
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

    final card = _current;

    // No text title — "Repeat after me" is the parent's cue, and it is
    // already on the card ("Say: …"). Progress is the shell's pill.
    return KidScreen.game(
      accent: DT.brand,
      background: DT.mintTint,
      progress: _deck.isEmpty ? null : _index / _deck.length,
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Card
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _exitCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _exitSlide.value),
                    child: Opacity(opacity: _exitFade.value, child: child),
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
                          // Real webp only — plain placeholder if an
                          // unsanitized card ever slips through (never emoji).
                          if (card.image != null)
                            Expanded(
                              child: CardImage.forCard(
                                card,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: card.colorAccent.withValues(
                                    alpha: 0.25,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),

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
                              Icon(
                                Icons.volume_up_rounded,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s('Натисни, щоб послухати', 'Tap to listen'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Two neutral pills for the parent: "again" and "got it".
              // Neither is a verdict — no red, no cross (G10).
              Row(
                children: [
                  Expanded(
                    child: _ParentPill(
                      label: s('Ще раз', 'Again'),
                      icon: AppIcon.replay,
                      background: DT.surfaceWhite,
                      foreground: DT.brand,
                      border: DT.brand.withValues(alpha: 0.35),
                      enabled: !_answered,
                      onTap: _onWrong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ParentPill(
                      label: s('Вийшло!', 'Got it!'),
                      icon: AppIcon.check,
                      background: DT.success,
                      foreground: Colors.white,
                      enabled: !_answered,
                      onTap: _onCorrect,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Parent pill — 72 dp, icon + word, never a verdict colour
// ─────────────────────────────────────────────

class _ParentPill extends StatelessWidget {
  final String label;
  final AppIcon icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool enabled;
  final VoidCallback onTap;

  const _ParentPill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.enabled,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = border;
    return KidTap(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: DT.motion.quick,
        child: Container(
          height: DT.size.tapMin,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor, width: 2),
            boxShadow: DT.shadowSoft(background),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconView(icon, size: DT.size.iconMd, color: foreground),
              const SizedBox(width: DT.sp8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.tileTitle.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
