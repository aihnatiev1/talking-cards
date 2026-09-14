import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/language_ladder.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/curriculum_progress_provider.dart';
import '../providers/listen_enabled_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/word_evidence_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../services/listen_service.dart';
import '../services/voice_gate.dart';
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

  /// A set is five words, not ten (experience audit §21). Ten words of
  /// "say it after me" is a lesson; five is something a parent and a
  /// two-year-old finish together, and finishing is the point — the
  /// celebration comes to everyone who reaches the end of the set.
  static const sessionLength = 5;

  /// The gentle second pass over the words the grown-up tapped
  /// «Спробуємо ще» on. Capped so the set cannot double in length.
  static const practiceLength = 3;

  /// Draw the set from the Core 60 teaching plan instead of the library.
  ///
  /// The library is 471 cards and a random five of them is a quiz, not a
  /// lesson: the same handful arrive by chance and nothing is ever
  /// finished. With the plan on, the sixty words that a child of 1–3
  /// actually uses come round in order, least-practised first. Off where
  /// there is no plan for the language — then [cards] is the deck.
  final bool useCurriculum;

  const RepeatGameScreen({
    super.key,
    required this.cards,
    this.useCurriculum = false,
  });

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

  /// A listening turn is open for the current card. The grown-up's two
  /// pills stay live throughout: the microphone is help, never a gate.
  bool _listening = false;

  /// The card a listening turn belongs to, so an outcome that arrives
  /// after the deck moved on is dropped instead of scoring the next word.
  String? _listeningFor;

  /// Listening turns already spent on the current card. Two, and then the
  /// screen goes quiet and waits: a word repeated at a child who is not
  /// answering stops being an invitation somewhere around the third time.
  /// A deliberate tap on the card starts the count over.
  int _listenTurns = 0;
  static const _maxListenTurns = 2;

  // Card slide-out when advancing to next
  late AnimationController _exitCtrl;
  late Animation<double> _exitSlide;
  late Animation<double> _exitFade;


  @override
  void initState() {
    super.initState();
    _deck = _dealDeck();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: DT.motion.repeatCardExit,
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
      Future.delayed(DT.motion.gameInstructionGap, () {
        if (mounted) _speakCurrent();
      });
    });
  }

  /// The grown-up decided, or the screen is closing: the window closes
  /// with it. [_listeningFor] is cleared so a late outcome is dropped.
  void _stopListening() {
    _listeningFor = null;
    if (_listening) ListenService.instance.cancel();
  }

  @override
  void dispose() {
    _stopListening();
    _exitCtrl.dispose();
    disposeConfetti();
    super.dispose();
  }

  /// Five words for one set.
  ///
  /// From the plan when there is one — in plan order, so a set is a step
  /// through the sixty rather than a shuffle — and from the library
  /// otherwise, shuffled as it always was. Each word is counted as offered
  /// the moment the set is dealt: what matters is that the plan moves on,
  /// and it must move on for a child who closed the screen halfway too.
  List<CardModel> _dealDeck() {
    if (widget.useCurriculum) {
      final planned = ref
          .read(speakSetProvider)
          .take(RepeatGameScreen.sessionLength)
          .toList();
      if (planned.length >= RepeatGameScreen.sessionLength) {
        final progress = ref.read(curriculumProgressProvider.notifier);
        for (final card in planned) {
          progress.record(card.id);
        }
        return planned;
      }
    }
    final shuffled = List<CardModel>.from(widget.cards)..shuffle(Random());
    return shuffled.take(RepeatGameScreen.sessionLength).toList();
  }

  CardModel get _current => _deck[_index];

  /// Where this card sits on the ladder for this child. Read fresh each
  /// time: a «Вийшло!» during the set can be the third mark.
  LadderStep get _step => ladderStepFor(
    _current,
    ref.read(wordEvidenceProvider)[_current.id]?.parentMarked ?? 0,
  );

  Future<void> _speakCurrent() async {
    final step = _step;
    if (step.playsSentence) {
      // The whole recording: the word, then the phrase it lives in. The
      // child has said this word to a grown-up three times — the next
      // thing to ask for is the phrase, and the take already has it.
      await AudioService.instance.speakCard(
        _current.audioKey,
        _current.sound,
        _current.text,
      );
    } else {
      await AudioService.instance.playWordOnly(
        _current.audioKey,
        _current.sound,
      );
    }
    await _maybeListen();
  }

  /// Opens the microphone for one turn, after the word has finished — the
  /// app must never hear itself. Off by default; a family that has not
  /// turned it on plays exactly the game they played before.
  Future<void> _maybeListen() async {
    if (!mounted || _answered || _listening) return;
    if (!ref.read(listenEnabledProvider)) return;
    if (_listenTurns >= _maxListenTurns) return;
    _listenTurns++;
    final card = _current;
    setState(() {
      _listening = true;
      _listeningFor = card.id;
    });
    final outcome = await ListenService.instance.listenOnce();
    if (!mounted) return;
    setState(() => _listening = false);
    // The deck moved on while the window was open (the grown-up tapped):
    // this outcome belongs to a card that is no longer on screen.
    if (_listeningFor != card.id || _answered) return;
    AnalyticsService.instance.logSpeechTurn(
      via: 'mic',
      outcome: outcome == VoiceOutcome.spoke ? 'spoke' : 'quiet',
      micEnabled: true,
    );
    if (outcome == VoiceOutcome.spoke) {
      await _onHeard();
    } else {
      // Quiet is not a failure and is never said to be one: Bloom simply
      // says the word again, and the turn stays open for as long as the
      // grown-up leaves the screen there.
      await _speakCurrent();
    }
  }

  /// The microphone noticed a voice.
  ///
  /// Everything [_onCorrect] does except the one thing it must not: no
  /// `recordParentMark`. That mark means a person heard the word, and a
  /// gate that only knows "a voice happened" cannot make it. The pill is
  /// still there for the grown-up who did hear it.
  Future<void> _onHeard() async {
    if (_answered) return;
    setState(() => _answered = true);
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    showConfetti();
    ref.read(dailyQuestProvider.notifier).recordSpeechCorrect();
    await Future.delayed(DT.motion.repeatPraiseHold);
    if (!mounted) return;
    await _advance();
  }

  Future<void> _onCorrect() async {
    if (_answered) return;
    setState(() => _answered = true);
    _stopListening();
    AnalyticsService.instance.logSpeechTurn(
      via: 'parent',
      outcome: 'nice',
      micEnabled: ref.read(listenEnabledProvider),
    );

    // Used to be a silent haptic; a right answer now dings like every
    // other game.
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    showConfetti();
    // The grown-up's own judgement — the only signal in the app that comes
    // from a human ear. Stored apart from views and game answers so the
    // dashboard can show it as exactly that.
    ref.read(wordEvidenceProvider.notifier).recordParentMark(_current.id);
    ref.read(dailyQuestProvider.notifier).recordSpeechCorrect();

    await Future.delayed(DT.motion.repeatPraiseHold);
    if (!mounted) return;
    await _advance();
  }

  Future<void> _onWrong() async {
    if (_answered) return;
    setState(() => _answered = true);
    _stopListening();
    AnalyticsService.instance.logSpeechTurn(
      via: 'parent',
      outcome: 'again',
      micEnabled: ref.read(listenEnabledProvider),
    );

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
      _deck = _dealDeck();
      _index = 0;
      _answered = false;
      _practiceRound = false;
      _listenTurns = 0;
      _missed.clear();
    });
    _speakCurrent();
  }

  /// One short, automatic second go at the words the grown-up tapped
  /// «Спробуємо ще» on — the speech-therapy core of this game. It is never
  /// announced as a retry and it never grows: at most [practiceLength]
  /// words, then the celebration, whichever way they went.
  void _startMissedRound() {
    final missed = List<CardModel>.from(_missed)..shuffle(Random());
    setState(() {
      _deck = missed.take(RepeatGameScreen.practiceLength).toList();
      _index = 0;
      _answered = false;
      _practiceRound = true;
      _listenTurns = 0;
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
        _listenTurns = 0;
      });
      _speakCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    final card = _current;
    // The ladder decides what is being asked for — the word, or the phrase
    // it lives in once a grown-up has marked it three times.
    final prompt = _step.prompt;

    // The one sentence on this screen is for the grown-up, and it says
    // what the game actually is: the two of you play it, the phone only
    // says the word (§21). It lives small in the header, out of the
    // child's field of play (CLAUDE.md rule 4).
    return KidScreen.game(
      accent: DT.brand,
      // Played in the games' meadow, like every other game.
      meadow: true,
      title: _TogetherChip(label: s('Разом із дорослим', 'With a grown-up')),
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
                  // The card is a static picture for the whole exit: the
                  // boundary inside the `Opacity` turns a full-card
                  // `saveLayer` per frame into one retained layer the
                  // compositor slides and fades (motion_language.md §7.1).
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _exitSlide.value),
                    child: Opacity(
                      opacity: _exitFade.value,
                      child: RepaintBoundary(child: child),
                    ),
                  ),
                  child: KidTap(
                    // A deliberate tap is a fresh invitation: the word is
                    // said again and the microphone gets its turns back.
                    onTap: () {
                      _listenTurns = 0;
                      _speakCurrent();
                    },
                    // The card speaks the word — a tock on top of the voice
                    // is one sound too many (G12).
                    sound: null,
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
              // The instruction the grown-up reads out loud — the point of
              // the screen, not a footnote. It was 16 sp of the system face
              // in the default grey and disappeared under the picture.
              Text(
                s('Скажи: «$prompt»', 'Say: «$prompt»'),
                textAlign: TextAlign.center,
                style: DT.h2.copyWith(color: DT.textPrimary),
              ),
              // Why the ask grew. Without this line a parent whose child
              // has been saying «мама» for a week meets a whole phrase and
              // reads it as the app losing the plot.
              if (_step.playsSentence) ...[
                const SizedBox(height: 4),
                Text(
                  s(
                    'Це слово вже виходить — пробуємо фразою',
                    'This word is coming along — try the phrase',
                  ),
                  textAlign: TextAlign.center,
                  style: DT.caption.copyWith(
                    fontSize: 12,
                    color: DT.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // The only thing on screen that says the microphone is open,
              // and it says it to the child, not the parent: a row of dots
              // that grows with her own voice. No countdown, no score, and
              // nothing that could be read as a verdict — when the window
              // closes quietly the row simply disappears.
              SizedBox(
                height: 26,
                child: _listening
                    ? _ListeningDots(level: ListenService.instance.level)
                    : null,
              ),
              const SizedBox(height: 12),

              // Two supportive pills for the grown-up. Neither is a
              // verdict and neither claims to have *heard* anything: the
              // app cannot listen, so it never pretends to (§21). One says
              // "that came out", the other "let's try that one again".
              Row(
                children: [
                  Expanded(
                    child: _ParentPill(
                      label: s('Спробуємо ще', 'Try again'),
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
                      label: s('Вийшло!', 'Nice!'),
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
//  «Разом із дорослим» — the header note, for the grown-up
// ─────────────────────────────────────────────

/// A small two-together badge and one quiet line.
///
/// The game once wore a microphone icon, which promises a machine judging
/// a child's pronunciation — and a parent who believed that would read
/// every «Вийшло!» as a verdict about their child's speech (§21). The app
/// can now open the microphone, but what it does with it is smaller than
/// the icon claimed: it notices that a voice happened, and never how the
/// word was said. The grown-up is still the one who hears. Two figures
/// side by side stays the honest picture.
class _TogetherChip extends StatelessWidget {
  const _TogetherChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DT.sp12,
        vertical: DT.sp4 + 2,
      ),
      decoration: BoxDecoration(
        color: DT.surfaceWhite.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(DT.rMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconView(
            AppIcon.gameRepeat,
            size: DT.size.iconSm,
            semanticLabel: label,
          ),
          const SizedBox(width: DT.sp4 + 2),
          Text(label, style: DT.caption),
        ],
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

/// Five dots that light up with the live microphone level.
///
/// Deliberately not a waveform or a number: a two-year-old cannot read
/// either, and both invite the reading "the app is scoring me". Dots that
/// answer a voice say the one true thing — someone is listening.
class _ListeningDots extends StatelessWidget {
  const _ListeningDots({required this.level});

  final ValueListenable<double> level;

  static const _count = 5;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: level,
      builder: (context, value, __) {
        final lit = (value * _count).ceil().clamp(0, _count);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _count; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              AnimatedContainer(
                duration: DT.pressMs,
                width: i < lit ? 18 : 12,
                height: i < lit ? 18 : 12,
                decoration: BoxDecoration(
                  color: i < lit
                      ? DT.brand
                      : DT.brand.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
