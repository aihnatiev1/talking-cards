import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/quiz_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/cue_pill.dart';
import '../widgets/entrance_stagger.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/listen_button.dart';
import '../widgets/quiz_option.dart';
import '../widgets/quiz_options_board.dart';

/// The animals a toddler can tell apart by ear.
///
/// Not the whole pack: a bunny, a deer, a dolphin or a crocodile make
/// sounds nobody recognises, a bear and a tiger growl like the lion, and a
/// goat bleats like the sheep. A question with no fair answer is the
/// mistake «Знайди зайве» made; this list keeps one clear voice per animal.
const whoSaidAnimals = <String>{
  'cat',
  'dog',
  'cow',
  'horse',
  'pig',
  'sheep',
  'hen',
  'rooster',
  'duck',
  'frog',
  'bird',
  'crow',
  'owl',
  'wolf',
  'bee',
  'lion',
  'elephant',
  'monkey',
  'donkey',
};

/// The animal-sound packs, by language.
const whoSaidPackIds = <String>{'animal_sounds', 'en_animal_sounds'};

/// The cards «Хто це сказав?» may use from [pack].
///
/// * A locked pack gives only its free preview — the same five animals a
///   family can already open on the Cards tab, never the paid twenty.
/// * Only the animals in [whoSaidAnimals].
/// * Only clips that can be started *after* the narrator's word, and only
///   recordings that are on the device now.
///
/// [contentReady] is whether the paid pictures and sounds have arrived (on
/// Android they come with the Play asset pack after install). Until they
/// have, even a Pro family plays with the preview animals, which ship in
/// the app itself — fewer animals, never a blank tile.
List<CardModel> whoSaidPool(PackModel pack, {required bool contentReady}) {
  final cards = pack.isLocked || !contentReady
      ? pack.cards.take(pack.effectiveFreePreviewCount)
      : pack.cards;
  return [
    for (final card in cards)
      if (_isWhoSaidAnimal(card) &&
          card.image != null &&
          AudioService.instance.hasSoundAfterWord(card.audioKey) &&
          AudioService.instance.isWordAvailable(card.audioKey))
        card,
  ];
}

bool _isWhoSaidAnimal(CardModel card) {
  final key = card.audioKey;
  if (key == null) return false;
  final at = key.indexOf('snd_');
  return at >= 0 && whoSaidAnimals.contains(key.substring(at + 4));
}

/// «Хто це сказав?» — meet four animals, then find each one by its voice.
///
/// Two halves, in the order a speech therapist would play it with real
/// toys: first every animal is touched and heard with its name («котик …
/// няв»), then the voice comes alone and the child points at who it was.
/// Nothing is asked that was not shown a moment earlier.
class WhoSaidScreen extends ConsumerStatefulWidget {
  const WhoSaidScreen({super.key, required this.cards});

  /// The pool, from [whoSaidPool]. At least [setSize] cards.
  final List<CardModel> cards;

  /// Animals in one set — and so questions in one round.
  static const setSize = 4;

  @override
  ConsumerState<WhoSaidScreen> createState() => _WhoSaidScreenState();
}

enum _Phase { meet, ask }

class _WhoSaidScreenState extends ConsumerState<WhoSaidScreen>
    with GameStateMixin {
  @override
  String get gameId => 'who_said';

  @override
  int get maxRounds => WhoSaidScreen.setSize;

  // No daily-quest task is about animal voices.
  @override
  Null get questTask => null;

  final _random = math.Random();

  _Phase _phase = _Phase.meet;
  List<CardModel> _set = const [];

  /// Animals already touched in the meet step.
  final Set<String> _heard = {};

  /// Bumped on every tap and phase change, so a clip that ends late cannot
  /// move a screen that has already moved on.
  int _turn = 0;

  late AutoDisposeStateNotifierProvider<QuizNotifier, QuizState?> _provider;

  bool _showCorrect = false;
  bool _waitingNext = false;
  bool _celebrationShown = false;
  Timer? _soundTimer;
  final _misses = MissTracker();
  final Map<String, int> _nudges = {};

  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _bloom.sceneEntered(this, BloomScene.game);
    _dealSet();
    startGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_set.length < WhoSaidScreen.setSize) {
        Navigator.of(context).pop();
        return;
      }
      AudioService.instance.playInstruction(
        'who_said',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  @override
  void dispose() {
    _soundTimer?.cancel();
    _turn++;
    _bloom.sceneLeft(this);
    AudioService.instance.stop();
    super.dispose();
  }

  /// Four animals for this round — new faces first, so «ще раз» is another
  /// four and not the same four again while the pool has more.
  void _dealSet() {
    final last = {for (final c in _set) c.id};
    final fresh = widget.cards.where((c) => !last.contains(c.id)).toList()
      ..shuffle(_random);
    final seen = widget.cards.where((c) => last.contains(c.id)).toList()
      ..shuffle(_random);
    _set = [...fresh, ...seen].take(WhoSaidScreen.setSize).toList();
    _provider = StateNotifierProvider.autoDispose<QuizNotifier, QuizState?>(
      (ref) => QuizNotifier(
        _set,
        level: ref.read(profileProvider).active?.level ?? 2,
      ),
    );
  }

  // ── Meet ──────────────────────────────────────────────────────────────

  Future<void> _meet(CardModel card) async {
    final turn = ++_turn;
    setState(() => _heard.add(card.id));
    // The whole clip: the name, then the animal's own voice.
    await AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    if (!mounted || turn != _turn || _phase != _Phase.meet) return;
    if (_heard.length >= _set.length) {
      _soundTimer?.cancel();
      _soundTimer = Timer(DT.motion.quizAnswerHold, () {
        if (mounted && turn == _turn) _startAsking();
      });
    }
  }

  void _startAsking() {
    if (_phase == _Phase.ask) return;
    _soundTimer?.cancel();
    _turn++;
    AudioService.instance.stop();
    setState(() {
      _phase = _Phase.ask;
      _showCorrect = false;
      _waitingNext = false;
      _voiceless = false;
      _misses.reset();
      _nudges.clear();
    });
    ref.read(_provider.notifier).start();
    _scheduleSound(DT.motion.gameInstructionGap);
  }

  // ── Ask ───────────────────────────────────────────────────────────────

  void _scheduleSound(Duration delay) {
    _soundTimer?.cancel();
    _soundTimer = Timer(delay, () {
      if (mounted && !_waitingNext) _playVoice();
    });
  }

  /// The animal's voice, without its name.
  ///
  /// If the voice cannot be played — the clip is not on the device, or it
  /// could not be started past the word — the question would be a silent
  /// «хто це сказав?» with no way to answer it. Then the right picture
  /// lights up at once, exactly as it does after two misses: the child
  /// still gets to tap it and hear «котик … няв».
  Future<void> _playVoice() async {
    if (_waitingNext || _phase != _Phase.ask) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;
    final card = state.correctCard;
    final result = await AudioService.instance.playAfterWord(card.audioKey);
    if (result != AfterWord.unavailable || !mounted || _waitingNext) return;
    if (ref.read(_provider)?.correctCard.id != card.id) return;
    if (!_voiceless) setState(() => _voiceless = true);
  }

  /// The current question's voice could not be played — see [_playVoice].
  bool _voiceless = false;

  Future<void> _onAnswer(String cardId) async {
    if (_waitingNext) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;
    ref.read(_provider.notifier).answer(cardId);

    if (cardId != state.correctCard.id) {
      // Gentle redirection, as in every game: one nudge of the tapped
      // tile, then the voice again. No colour, no buzzer.
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _nudges[cardId] = (_nudges[cardId] ?? 0) + 1;
        _misses.miss();
      });
      if (_misses.misses == state.hintAfterMisses) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
        final target = state.options.indexWhere(
          (c) => c.id == state.correctCard.id,
        );
        if (target >= 0) {
          _bloom.nudged(quizOptionDirection(target, state.options.length));
        }
      }
      _scheduleSound(DT.motion.quizRetell);
      return;
    }

    _soundTimer?.cancel();
    final turn = ++_turn;
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    setState(() {
      _showCorrect = true;
      _waitingNext = true;
    });
    // Now the name is the reward: «котик … няв». The next voice waits for
    // this one to finish, not for a fixed beat — a lion roars longer than
    // a duck quacks — but never for more than a few seconds.
    final card = state.correctCard;
    await Future.wait([
      Future<void>.delayed(DT.motion.quizAnswerHold),
      AudioService.instance
          .speakCard(card.audioKey, card.sound, card.text)
          .timeout(_clipCap, onTimeout: () {}),
    ]);
    if (!mounted || turn != _turn) return;
    setState(() {
      _showCorrect = false;
      _waitingNext = false;
      _voiceless = false;
      _misses.reset();
      _nudges.clear();
    });
    ref.read(_provider.notifier).next();
    _scheduleSound(DT.motion.quizQuestionGap);
  }

  static const _clipCap = Duration(seconds: 6);

  void _onFinished() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      completeGame();
      showGameCelebration(
        context,
        isEn: ref.read(languageProvider) == 'en',
        childName: ref.read(profileProvider).active?.name ?? '',
        onAgain: _restart,
        onDone: () => Navigator.of(context).pop(),
      );
    });
  }

  void _restart() {
    _soundTimer?.cancel();
    _turn++;
    resetGame();
    setState(() {
      _dealSet();
      _phase = _Phase.meet;
      _heard.clear();
      _showCorrect = false;
      _waitingNext = false;
      _celebrationShown = false;
      _misses.reset();
      _nudges.clear();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  static const _accent = DT.brand;

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    // Watched in both steps: the provider is auto-disposed, and one that
    // nobody listens to while the animals are being met would be gone —
    // with its first question — by the time the asking starts.
    final quiz = ref.watch(_provider);
    final asking = _phase == _Phase.ask;
    final state = asking ? quiz : null;
    return KidScreen.game(
      accent: _accent,
      meadow: true,
      backdrop: 'assets/images/backdrops/guess_sky.webp',
      // While asking, the round button is the voice again; while meeting,
      // the pictures themselves are the buttons.
      title: asking ? _speaker(s) : null,
      // A way on for the child who has heard enough: the green «play».
      trailing: asking
          ? null
          : KidArtButton(
              key: const ValueKey('who-said-play'),
              art: 'play',
              label: s('Грати', 'Play'),
              onTap: _startAsking,
            ),
      progress: !asking
          ? _heard.length / math.max(1, _set.length)
          : state == null || state.finished
          ? null
          : state.round / state.totalRounds,
      mascotCorner: BloomMascot(
        size: DT.size.mascotCompanionOf(context),
        semanticsLabel: s('Блум', 'Bloom'),
      ),
      body: _body(s, state),
    );
  }

  Widget _body(AppS s, QuizState? state) {
    if (_phase == _Phase.meet) {
      return _board(
        cue: s('Торкнись і послухай', 'Tap and listen'),
        options: _set,
        tile: (index, card) => _MeetTile(
          card: card,
          heard: _heard.contains(card.id),
          onTap: () => _meet(card),
        ),
      );
    }
    if (state == null) return const Center(child: CircularProgressIndicator());
    if (state.finished) {
      _onFinished();
      return const SizedBox.shrink();
    }
    final helping = _voiceless || _misses.misses >= state.hintAfterMisses;
    final cue = _showCorrect
        ? s(
            'Так! Це ${state.correctCard.sound.toLowerCase()}',
            'Yes! ${state.correctCard.sound}',
          )
        : helping
        ? s('Дивись, я підкажу', 'Look, I’ll show you')
        : _misses.misses > 0
        ? s('Послухай ще раз', 'Listen once more')
        : s('Хто це сказав?', 'Who said that?');
    return _board(
      cue: cue,
      options: state.options,
      tile: (index, card) {
        final isTarget = card.id == state.correctCard.id;
        final mark = !isTarget
            ? AnswerMark.none
            : _showCorrect
            ? AnswerMark.correct
            : helping
            ? AnswerMark.hint
            : AnswerMark.none;
        return QuizOption(
          card: card,
          mark: mark,
          nudge: _nudges[card.id] ?? 0,
          onTap: () => _onAnswer(card.id),
        );
      },
    );
  }

  /// The picture board above Bloom's corner, with his line in a bubble at
  /// his side — the same frame «Вгадай звук» uses.
  Widget _board({
    required String cue,
    required List<CardModel> options,
    required Widget Function(int index, CardModel card) tile,
  }) {
    final strip =
        math.max(DT.size.mascotCompanionOf(context), DT.size.tapMin) +
        BloomMascot.hopClearance +
        DT.sp16;
    final style = DT.caption.copyWith(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: DT.textPrimary,
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final companion = DT.size.mascotCompanionOf(context);
        final painter = TextPainter(
          text: TextSpan(text: cue, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1.0, bounds.maxWidth - companion - 56));
        final fits = painter.height + 24 <= strip;
        painter.dispose();
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, strip),
                child: StaggerScope(
                  child: QuizOptionsBoard(
                    options: options,
                    tileBuilder: (index, card) => StaggeredEntrance(
                      key: ValueKey('${_phase.name}-${card.id}'),
                      index: index,
                      child: tile(index, card),
                    ),
                  ),
                ),
              ),
            ),
            if (fits && bounds.maxHeight > 280)
              Positioned(
                left: 24,
                right: companion + 14,
                bottom: 30,
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: MotionPolicy.of(
                        context,
                      ).dur(DT.motion.selectionChange),
                      child: Align(
                        key: ValueKey(cue),
                        alignment: Alignment.centerRight,
                        child: CueBubble(
                          child: Text(
                            cue,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _speaker(AppS s) => ListenButton(
    key: const ValueKey('who-said-voice'),
    label: s('Послухати ще раз', 'Listen again'),
    onTap: () {
      _soundTimer?.cancel();
      _playVoice();
    },
  );
}

/// An animal in the meet step: the same tile as a question, with a painted
/// star once it has been heard — so the child sees which ones are left.
class _MeetTile extends StatelessWidget {
  const _MeetTile({
    required this.card,
    required this.heard,
    required this.onTap,
  });

  final CardModel card;
  final bool heard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: QuizOption(card: card, onTap: onTap),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: IgnorePointer(
          child: AnimatedScale(
            scale: heard ? 1 : 0,
            duration: MotionPolicy.of(context).dur(DT.motion.successPop),
            curve: Curves.easeOutBack,
            child: const AppArt('star', size: 34),
          ),
        ),
      ),
    ],
  );
}
