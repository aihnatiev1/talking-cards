import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/quiz_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/cue_pill.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/listen_button.dart';
import '../widgets/quiz_option.dart';

/// The food packs, by language. One pack per language on purpose: «яблуко»,
/// «каша» and «водичка» also live in the home pack, and mixing the two
/// could put two plates with the same word on the table.
const feedBloomPackIds = <String>{'food', 'en_food'};

/// The foods «Нагодуй Блума» may put on the table from [pack].
///
/// The same access rule as «Хто це сказав?»: a locked pack — or one whose
/// paid pictures and sounds have not arrived yet — gives only its free
/// preview, which ships inside the app; and only recordings that are on the
/// device now.
List<CardModel> feedBloomPool(PackModel pack, {required bool contentReady}) {
  final cards = pack.isLocked || !contentReady
      ? pack.cards.take(pack.effectiveFreePreviewCount)
      : pack.cards;
  return [
    for (final card in cards)
      if (card.image != null &&
          AudioService.instance.hasSound(card.audioKey) &&
          AudioService.instance.isWordAvailable(card.audioKey))
        card,
  ];
}

/// What Bloom says when he asks for [card].
///
/// Verb-free on purpose. Only the nominative word is recorded and written
/// on the card, so «хочу полуницю» or «дай кашу» cannot be built from it —
/// and «Полуниця, будь ласка!» needs no declension, suits a drink as well
/// as a fruit, and is how we would like the child to ask.
String feedBloomAsk(CardModel card, {required bool isEn}) => isEn
    ? '${_sentenceCase(card.sound)}, please!'
    : '${_sentenceCase(card.sound)}, будь ласка!';

/// What he says with his mouth full.
String feedBloomYum(CardModel card, {required bool isEn}) => isEn
    ? 'Yum! ${_sentenceCase(card.sound)}'
    : 'Ням-ням! ${_sentenceCase(card.sound)}';

String _sentenceCase(String word) => word.isEmpty
    ? word
    : word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();

/// «Нагодуй Блума» — he asks for a food by name, the child gives it to him.
///
/// A word-understanding game dressed as play with a toy: Bloom is hungry,
/// says «яблуко», and two or three plates are on the table. A tap sends
/// the food to him and so does a drag — a one-year-old pokes, a
/// three-year-old carries. A food dropped anywhere else simply goes back to
/// its plate; only a wrong food *given to him* is a miss, and a miss is
/// only the word again.
///
/// Bloom here is the one being played with, not the companion in the
/// corner, so the screen passes no `mascotCorner`: one Bloom per screen.
class FeedBloomScreen extends ConsumerStatefulWidget {
  const FeedBloomScreen({super.key, required this.cards});

  /// The pool, from [feedBloomPool]. At least [setSize] cards.
  final List<CardModel> cards;

  /// Foods in one round.
  static const setSize = 5;

  @override
  ConsumerState<FeedBloomScreen> createState() => _FeedBloomScreenState();
}

class _FeedBloomScreenState extends ConsumerState<FeedBloomScreen>
    with SingleTickerProviderStateMixin, GameStateMixin {
  @override
  String get gameId => 'feed_bloom';

  @override
  int get maxRounds => FeedBloomScreen.setSize;

  // No daily-quest task is about feeding Bloom.
  @override
  Null get questTask => null;

  final _random = math.Random();
  List<CardModel> _set = const [];
  late AutoDisposeStateNotifierProvider<QuizNotifier, QuizState?> _provider;

  /// Bumped whenever the question moves on, so a clip that ends late
  /// cannot move a screen that has already moved.
  int _turn = 0;

  // ── The food in the hand ────────────────────────────────────────────
  /// The plate being dragged or flying to Bloom.
  String? _activeId;

  /// Where the dragged food is, relative to its plate.
  Offset _drag = Offset.zero;

  /// Carries a food to Bloom on a tap, and back to its plate on a miss or
  /// a drop elsewhere.
  late final AnimationController _move;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  VoidCallback? _afterMove;

  /// The right food has reached him: he chews, the plate is empty, and the
  /// next question waits.
  bool _eating = false;

  bool _celebrationShown = false;
  Timer? _wordTimer;
  final _misses = MissTracker();
  final Map<String, int> _nudges = {};

  final _bloomKey = GlobalKey();
  final Map<String, GlobalKey> _plateKeys = {};

  @override
  void initState() {
    super.initState();
    _move = AnimationController(vsync: this, duration: DT.motion.base)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _drag = _to;
        final then = _afterMove;
        _afterMove = null;
        then?.call();
      });
    _dealSet();
    startGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_set.length < 4) {
        Navigator.of(context).pop();
        return;
      }
      ref.read(_provider.notifier).start();
      AudioService.instance.playInstruction(
        'feed_bloom',
        isEn: ref.read(languageProvider) == 'en',
      );
      _scheduleWord(DT.motion.gameInstructionGap);
    });
  }

  @override
  void dispose() {
    _wordTimer?.cancel();
    _turn++;
    _move.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  /// Five foods for this round — new ones first, so «ще раз» is another
  /// meal and not the same one while the pool has more.
  void _dealSet() {
    final last = {for (final c in _set) c.id};
    final fresh = widget.cards.where((c) => !last.contains(c.id)).toList()
      ..shuffle(_random);
    final seen = widget.cards.where((c) => last.contains(c.id)).toList()
      ..shuffle(_random);
    _set = [...fresh, ...seen].take(FeedBloomScreen.setSize).toList();
    final level = ref.read(profileProvider).active?.level ?? 2;
    _provider = StateNotifierProvider.autoDispose<QuizNotifier, QuizState?>(
      // Two plates for the youngest, three after that — a table, not a
      // board: the count does not climb with every right answer.
      (ref) =>
          QuizNotifier(_set, level: level, fixedOptions: level <= 2 ? 2 : 3),
    );
  }

  // ── The word ────────────────────────────────────────────────────────

  void _scheduleWord(Duration delay) {
    _wordTimer?.cancel();
    _wordTimer = Timer(delay, () {
      if (mounted && !_eating) _sayWord();
    });
  }

  void _sayWord() {
    if (_eating) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;
    final card = state.correctCard;
    AudioService.instance.playWordOnly(card.audioKey, card.sound);
  }

  // ── Carrying ────────────────────────────────────────────────────────

  bool get _busy => _eating || _move.isAnimating;

  Offset _offsetOf(String id) {
    if (id != _activeId) return Offset.zero;
    if (!_move.isAnimating) return _drag;
    return Offset.lerp(_from, _to, Curves.easeOutCubic.transform(_move.value))!;
  }

  void _animate(Offset from, Offset to, VoidCallback then) {
    _from = from;
    _to = to;
    _afterMove = then;
    _move.forward(from: 0);
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// From a plate at rest to Bloom's mouth. The plate keys sit outside the
  /// transform that carries the food, so their rects are always at rest.
  Offset? _toMouth(String id) {
    final plate = _rectOf(_plateKeys[id]!);
    final bloom = _rectOf(_bloomKey);
    if (plate == null || bloom == null) return null;
    final mouth = Offset(bloom.center.dx, bloom.top + bloom.height * .45);
    return mouth - plate.center;
  }

  bool _overBloom(String id) {
    final plate = _rectOf(_plateKeys[id]!);
    final bloom = _rectOf(_bloomKey);
    if (plate == null || bloom == null) return false;
    // Where the food is now: its plate plus how far it has been carried.
    // Not read back from the screen — a quick flick ends before the last
    // move has been painted. Generous, too: near him is on him.
    return bloom.inflate(32).contains(plate.center + _drag);
  }

  void _tapFeed(CardModel card) {
    if (_busy || _activeId != null) return;
    final delta = _toMouth(card.id);
    if (delta == null) {
      _give(card);
      return;
    }
    setState(() {
      _activeId = card.id;
      _drag = Offset.zero;
    });
    _animate(Offset.zero, delta, () => _give(card));
  }

  void _panStart(CardModel card) {
    if (_busy) return;
    setState(() {
      _activeId = card.id;
      _drag = Offset.zero;
    });
  }

  void _panUpdate(CardModel card, DragUpdateDetails details) {
    if (_busy || _activeId != card.id) return;
    setState(() => _drag += details.delta);
  }

  void _panEnd(CardModel card) {
    if (_busy || _activeId != card.id) return;
    if (_overBloom(card.id)) {
      _give(card);
    } else {
      // Let go on the grass: not an answer at all. It goes home.
      _goHome();
    }
  }

  void _goHome() {
    _animate(_drag, Offset.zero, () {
      if (!mounted) return;
      setState(() {
        _activeId = null;
        _drag = Offset.zero;
      });
    });
  }

  // ── Giving ──────────────────────────────────────────────────────────

  Future<void> _give(CardModel card) async {
    if (!mounted || _eating) return;
    final state = ref.read(_provider);
    if (state == null || state.finished) return;
    ref.read(_provider.notifier).answer(card.id);

    if (card.id != state.correctCard.id) {
      // Not what he asked for: the food goes back and he says the word
      // again. No colour, no buzzer, no «ні».
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _nudges[card.id] = (_nudges[card.id] ?? 0) + 1;
        _misses.miss();
      });
      if (_misses.misses == state.hintAfterMisses) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
      }
      _goHome();
      _scheduleWord(DT.motion.quizRetell);
      return;
    }

    _wordTimer?.cancel();
    final turn = ++_turn;
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    setState(() => _eating = true);
    // The whole clip now — the word and the phrase it lives in — while he
    // chews. The next food waits for it to finish, within reason.
    await Future.wait([
      Future<void>.delayed(DT.motion.quizAnswerHold),
      AudioService.instance
          .speakCard(card.audioKey, card.sound, card.text)
          .timeout(_clipCap, onTimeout: () {}),
    ]);
    if (!mounted || turn != _turn) return;
    setState(() {
      _eating = false;
      _activeId = null;
      _drag = Offset.zero;
      _misses.reset();
      _nudges.clear();
    });
    ref.read(_provider.notifier).next();
    _scheduleWord(DT.motion.quizQuestionGap);
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
    _wordTimer?.cancel();
    _turn++;
    resetGame();
    setState(() {
      _dealSet();
      _eating = false;
      _activeId = null;
      _drag = Offset.zero;
      _celebrationShown = false;
      _misses.reset();
      _nudges.clear();
    });
    ref.read(_provider.notifier).start();
    _scheduleWord(DT.motion.gameInstructionGap);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final state = ref.watch(_provider);
    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      backdrop: 'assets/images/backdrops/guess_sky.webp',
      title: ListenButton(
        key: const ValueKey('feed-bloom-word'),
        label: s('Послухати ще раз', 'Listen again'),
        onTap: () {
          _wordTimer?.cancel();
          _sayWord();
        },
      ),
      progress: state == null || state.finished
          ? null
          : (state.round - (_eating ? 0 : 1)) / state.totalRounds,
      body: _body(s, isEn, state),
    );
  }

  Widget _body(AppS s, bool isEn, QuizState? state) {
    if (state == null) return const Center(child: CircularProgressIndicator());
    if (state.finished) {
      _onFinished();
      return const SizedBox.shrink();
    }
    final target = state.correctCard;
    final helping = _misses.misses >= state.hintAfterMisses;
    final cue = _eating
        ? feedBloomYum(target, isEn: isEn)
        : helping
        ? s('Дивись, я підкажу', 'Look, I’ll show you')
        : _misses.misses > 0
        ? s('Послухай ще раз', 'Listen once more')
        : feedBloomAsk(target, isEn: isEn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Column(
        children: [
          Expanded(flex: 6, child: _bloomAndBubble(cue)),
          const SizedBox(height: 10),
          Expanded(flex: 5, child: _table(state, helping)),
        ],
      ),
    );
  }

  Widget _bloomAndBubble(String cue) => LayoutBuilder(
    builder: (context, box) {
      // He stands in the middle, on the grass, as big as the space allows;
      // his words hang above him, where a whole «…, будь ласка!» fits. A
      // bubble at his side had room for half a word.
      final side = math.max(
        96.0,
        math.min(box.maxHeight - 92, box.maxWidth * .64),
      );
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: MotionPolicy.of(
                  context,
                ).dur(DT.motion.selectionChange),
                child: CueBubble.above(
                  key: ValueKey(cue),
                  child: Text(
                    cue,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.caption.copyWith(
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: DT.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            key: _bloomKey,
            width: side,
            height: side,
            child: _HungryBloom(chewing: _eating, size: side),
          ),
        ],
      );
    },
  );

  Widget _table(QuizState state, bool helping) => LayoutBuilder(
    builder: (context, box) {
      final height = math.min(box.maxHeight, 240.0);
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _move,
            builder: (context, _) => Row(
              children: [
                for (final (i, card) in state.options.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _plate(card, state, helping)),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _plate(CardModel card, QuizState state, bool helping) {
    final isTarget = card.id == state.correctCard.id;
    final eaten = _eating && isTarget;
    final carried = card.id == _activeId;
    final key = _plateKeys.putIfAbsent(card.id, GlobalKey.new);
    return Transform.translate(
      key: key,
      offset: _offsetOf(card.id),
      child: RepaintBoundary(
        child: AnimatedScale(
          // Into his mouth: the food shrinks to nothing where he is.
          scale: eaten ? 0 : (carried ? .9 : 1),
          duration: MotionPolicy.of(context).dur(DT.motion.base),
          curve: Curves.easeIn,
          child: GestureDetector(
            onPanStart: (_) => _panStart(card),
            onPanUpdate: (d) => _panUpdate(card, d),
            onPanEnd: (_) => _panEnd(card),
            onPanCancel: () => _panEnd(card),
            child: QuizOption(
              card: card,
              mark: isTarget && helping && !_eating
                  ? AnswerMark.hint
                  : AnswerMark.none,
              nudge: _nudges[card.id] ?? 0,
              onTap: () => _tapFeed(card),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloom at the table: mouth open while he asks, cheeks full while he
/// chews. Two painted poses on the same canvas as his others, so he does
/// not jump when one replaces the other.
class _HungryBloom extends StatelessWidget {
  const _HungryBloom({required this.chewing, required this.size});

  final bool chewing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    return AmbientLoop(
      period: DT.motion.speakerPulse,
      // He leans in, asking, until he is fed.
      enabled: !chewing,
      builder: (_, t, child) => Transform.scale(
        scale: 1 + .025 * t,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: AnimatedScale(
        scale: chewing ? 1.06 : 1,
        alignment: Alignment.bottomCenter,
        duration: policy.dur(DT.motion.successPop),
        curve: Curves.easeOutBack,
        child: AnimatedSwitcher(
          duration: policy.dur(DT.motion.quick),
          child: Image.asset(
            'assets/images/bloom/${chewing ? 'chew' : 'hungry'}.webp',
            key: ValueKey(chewing),
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
          ),
        ),
      ),
    );
  }
}
