import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/animal_friend_art.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/cue_pill.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/listen_button.dart';
import '../widgets/quiz_options_board.dart';

/// Which clay friends look alike as a flat shape.
///
/// Checked on a sheet of all the outlines: the five four-legged friends are
/// one round body with different ears, and the two birds are close. A
/// board never shows two shadows from one group — «whose shadow is this»
/// must have one answer a toddler can see, which is the mistake «Знайди
/// зайве» made with its oval among the food.
const shadowGroups = <String, String>{
  'cat': 'four-legged',
  'dog': 'four-legged',
  'cow': 'four-legged',
  'horse': 'four-legged',
  'pig': 'four-legged',
  'chicken': 'bird',
  'duck': 'bird',
  'frog': 'frog',
  'fish': 'fish',
};

/// The free animals packs, by language.
const shadowPackIds = <String>{'animals', 'en_animals'};

/// The cards «Чия тінь?» can play with: one per clay friend with a shape
/// of its own, and a name that is recorded and on the device.
List<CardModel> shadowPool(PackModel pack) => [
  for (final card in pack.cards)
    if (shadowGroups.containsKey(card.image) &&
        AudioService.instance.hasSound(card.audioKey) &&
        AudioService.instance.isWordAvailable(card.audioKey))
      card,
];

/// The shadows on the board for [piece]: its own, and [count] − 1 others
/// from *other* look-alike groups, one per group. Shuffled.
List<CardModel> shadowBoard(
  CardModel piece,
  List<CardModel> pool,
  int count,
  math.Random random,
) {
  final taken = {shadowGroups[piece.image]};
  final others = List<CardModel>.from(pool)..shuffle(random);
  final board = [piece];
  for (final card in others) {
    if (board.length >= count) break;
    if (taken.add(shadowGroups[card.image])) board.add(card);
  }
  return board..shuffle(random);
}

String _lower(String word) => word.toLowerCase();

/// «Це котик!» — the name stays in the nominative, the only recorded form.
String shadowFound(CardModel card, {required bool isEn}) =>
    isEn ? 'It is the ${_lower(card.sound)}!' : 'Це ${_lower(card.sound)}!';

/// «Чия тінь?» — a clay friend, and two or three shadows; one is its own.
///
/// The friend is named, and the child puts it on its shadow: a tap on the
/// shadow sends it there, and so does carrying it. On its own shadow the
/// friend lands and the shadow fills with colour; on another, it comes
/// back and the name is said again. Let go anywhere else and it simply
/// goes home — that is not an answer.
class ShadowMatchScreen extends ConsumerStatefulWidget {
  const ShadowMatchScreen({super.key, required this.cards});

  /// The pool, from [shadowPool]. Friends from at least two groups.
  final List<CardModel> cards;

  /// Friends matched in one game.
  static const rounds = 5;

  @override
  ConsumerState<ShadowMatchScreen> createState() => _ShadowMatchScreenState();
}

class _ShadowMatchScreenState extends ConsumerState<ShadowMatchScreen>
    with SingleTickerProviderStateMixin, GameStateMixin {
  @override
  String get gameId => 'shadow_match';

  @override
  int get maxRounds => ShadowMatchScreen.rounds;

  // No daily-quest task is about shadows.
  @override
  Null get questTask => null;

  final _random = math.Random();
  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  late CardModel _piece;
  CardModel? _lastPiece;
  List<CardModel> _board = const [];

  /// The friend has landed on its shadow; the next one waits.
  bool _matched = false;
  int _misses = 0;
  final Map<String, int> _nudges = {};

  /// Bumped on every turn, so a late timer or clip cannot move a screen
  /// that has moved on.
  int _turn = 0;
  bool _celebrationShown = false;
  Timer? _timer;

  // ── The friend in the hand ──────────────────────────────────────────
  bool _carrying = false;
  Offset _drag = Offset.zero;
  late final AnimationController _move;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  VoidCallback? _afterMove;

  final _pieceKey = GlobalKey();
  final Map<String, GlobalKey> _shadowKeys = {};

  int get _level => ref.read(profileProvider).active?.level ?? 2;

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
    _bloom.sceneEntered(this, BloomScene.game);
    startGame();
    _deal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_board.length < 2) {
        Navigator.of(context).pop();
        return;
      }
      AudioService.instance.playInstruction(
        'shadow_match',
        isEn: ref.read(languageProvider) == 'en',
      );
      _scheduleWord(DT.motion.gameInstructionGap);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turn++;
    _move.dispose();
    _bloom.sceneLeft(this);
    AudioService.instance.stop();
    super.dispose();
  }

  /// The next friend — not the one just matched — and its board.
  void _deal() {
    final pool = List<CardModel>.from(widget.cards)..shuffle(_random);
    _piece = pool.firstWhere(
      (c) => c.id != _lastPiece?.id,
      orElse: () => pool.first,
    );
    _lastPiece = _piece;
    _board = shadowBoard(_piece, pool, _level <= 2 ? 2 : 3, _random);
    _matched = false;
    _misses = 0;
    _nudges.clear();
    _carrying = false;
    _drag = Offset.zero;
  }

  // ── The word ────────────────────────────────────────────────────────

  void _scheduleWord(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (mounted && !_matched) _sayWord();
    });
  }

  void _sayWord() {
    if (_matched) return;
    AudioService.instance.playWordOnly(_piece.audioKey, _piece.sound);
  }

  // ── Carrying ────────────────────────────────────────────────────────

  bool get _busy => _matched || _move.isAnimating;

  Offset get _offset => !_carrying
      ? Offset.zero
      : _move.isAnimating
      ? Offset.lerp(_from, _to, Curves.easeOutCubic.transform(_move.value))!
      : _drag;

  void _animate(Offset from, Offset to, VoidCallback then) {
    _from = from;
    _to = to;
    _afterMove = then;
    _move.forward(from: 0);
  }

  Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The shadow the carried friend is over, if any: the nearest centre
  /// among those it is within reach of. The piece's key sits outside the
  /// transform that carries it, so its rect is always at rest.
  CardModel? _shadowUnder() {
    final home = _rectOf(_pieceKey);
    if (home == null) return null;
    final at = home.center + _drag;
    CardModel? best;
    var bestDistance = double.infinity;
    for (final card in _board) {
      final rect = _rectOf(_shadowKeys[card.id]);
      if (rect == null || !rect.inflate(24).contains(at)) continue;
      final distance = (rect.center - at).distance;
      if (distance < bestDistance) {
        best = card;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _tapShadow(CardModel shadow) {
    if (_busy || _carrying) return;
    final home = _rectOf(_pieceKey);
    final rect = _rectOf(_shadowKeys[shadow.id]);
    if (home == null || rect == null) {
      _put(shadow);
      return;
    }
    setState(() {
      _carrying = true;
      _drag = Offset.zero;
    });
    _animate(Offset.zero, rect.center - home.center, () => _put(shadow));
  }

  void _panStart() {
    if (_busy) return;
    setState(() {
      _carrying = true;
      _drag = Offset.zero;
    });
  }

  void _panUpdate(DragUpdateDetails details) {
    if (_busy || !_carrying) return;
    setState(() => _drag += details.delta);
  }

  void _panEnd() {
    if (_busy || !_carrying) return;
    final shadow = _shadowUnder();
    if (shadow != null) {
      _put(shadow);
    } else {
      // Let go on the grass: not an answer. It goes home.
      _goHome();
    }
  }

  void _goHome() {
    _animate(_drag, Offset.zero, () {
      if (!mounted) return;
      setState(() {
        _carrying = false;
        _drag = Offset.zero;
      });
    });
  }

  // ── Putting it on a shadow ──────────────────────────────────────────

  Future<void> _put(CardModel shadow) async {
    if (!mounted || _matched) return;

    if (shadow.id != _piece.id) {
      FeedbackService.instance.event(FeedbackEvent.wrong);
      setState(() {
        _misses++;
        _nudges[shadow.id] = (_nudges[shadow.id] ?? 0) + 1;
      });
      if (_misses == 2) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
        final at = _board.indexWhere((c) => c.id == _piece.id);
        if (at >= 0) _bloom.nudged(quizOptionDirection(at, _board.length));
      }
      _goHome();
      _scheduleWord(DT.motion.quizRetell);
      return;
    }

    _timer?.cancel();
    final turn = ++_turn;
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    setState(() => _matched = true);
    await Future.wait([
      Future<void>.delayed(DT.motion.pairHold),
      AudioService.instance
          .speakCard(_piece.audioKey, _piece.sound, _piece.text)
          .timeout(_clipCap, onTimeout: () {}),
    ]);
    if (!mounted || turn != _turn) return;
    if (!nextRound() || roundsPlayed >= ShadowMatchScreen.rounds) {
      if (!finished) completeGame();
      _celebrate();
      return;
    }
    setState(_deal);
    _scheduleWord(DT.motion.quizQuestionGap);
  }

  static const _clipCap = Duration(seconds: 6);

  void _celebrate() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    showGameCelebration(
      context,
      isEn: ref.read(languageProvider) == 'en',
      childName: ref.read(profileProvider).active?.name ?? '',
      onAgain: () {
        resetGame();
        setState(() {
          _celebrationShown = false;
          _deal();
        });
        _scheduleWord(DT.motion.gameInstructionGap);
      },
      onDone: () => Navigator.of(context).pop(),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final cue = _matched
        ? shadowFound(_piece, isEn: isEn)
        : _misses >= 2
        ? s('Дивись, я підкажу', 'Look, I’ll show you')
        : _misses > 0
        ? s('Спробуй іншу тінь', 'Try another shadow')
        : s('Чия це тінь?', 'Whose shadow is it?');
    final companion = DT.size.mascotCompanionOf(context);
    final strip =
        math.max(companion, DT.size.tapMin) +
        BloomMascot.hopClearance +
        DT.sp16;
    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      backdrop: 'assets/images/backdrops/guess_sky.webp',
      title: ListenButton(
        key: const ValueKey('shadow-match-word'),
        label: s('Послухати ще раз', 'Listen again'),
        onTap: () {
          _timer?.cancel();
          _sayWord();
        },
      ),
      progress: roundsPlayed / ShadowMatchScreen.rounds,
      mascotCorner: BloomMascot(
        size: companion,
        semanticsLabel: s('Блум', 'Bloom'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, strip),
              child: Column(
                children: [
                  // The shadows: one row of white plates.
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, card) in _board.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _Shadow(
                              key: _shadowKeys.putIfAbsent(
                                card.id,
                                GlobalKey.new,
                              ),
                              card: card,
                              filled: _matched && card.id == _piece.id,
                              hinting:
                                  !_matched &&
                                  _misses >= 2 &&
                                  card.id == _piece.id,
                              nudge: _nudges[card.id] ?? 0,
                              onTap: () => _tapShadow(card),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The friend, sized from the height that is left.
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final side = math.min(box.maxHeight, box.maxWidth * .5);
                        return Center(
                          child: AnimatedBuilder(
                            animation: _move,
                            builder: (context, child) => Transform.translate(
                              key: _pieceKey,
                              offset: _offset,
                              child: child,
                            ),
                            child: RepaintBoundary(
                              child: AnimatedScale(
                                // Landed: it is in the plate now.
                                scale: _matched ? 0 : (_carrying ? .9 : 1),
                                duration: MotionPolicy.of(
                                  context,
                                ).dur(DT.motion.base),
                                curve: Curves.easeIn,
                                child: GestureDetector(
                                  onPanStart: (_) => _panStart(),
                                  onPanUpdate: _panUpdate,
                                  onPanEnd: (_) => _panEnd(),
                                  onPanCancel: _panEnd,
                                  child: KidTap(
                                    key: const ValueKey('shadow-match-piece'),
                                    // The name is the answer to this tap.
                                    sound: null,
                                    onTap: () {
                                      _timer?.cancel();
                                      _sayWord();
                                    },
                                    child: SizedBox.square(
                                      dimension: side,
                                      child: AnimalFriendArt(
                                        animal: _piece.image!,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.caption.copyWith(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: DT.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A white plate with a friend's shadow on it — and the friend itself, in
/// colour, once it has been put there.
class _Shadow extends StatefulWidget {
  const _Shadow({
    super.key,
    required this.card,
    required this.filled,
    required this.hinting,
    required this.nudge,
    required this.onTap,
  });

  final CardModel card;
  final bool filled;
  final bool hinting;
  final int nudge;
  final VoidCallback onTap;

  @override
  State<_Shadow> createState() => _ShadowState();
}

class _ShadowState extends State<_Shadow> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: DT.motion.slow,
  );

  @override
  void didUpdateWidget(_Shadow old) {
    super.didUpdateWidget(old);
    if (widget.nudge > old.nudge && !MotionPolicy.of(context).reduce) {
      _wiggle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    final friend = AnimalFriendArt(animal: widget.card.image!);
    return KidTap(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _wiggle,
        builder: (_, child) => Transform.rotate(
          angle: math.sin(_wiggle.value * math.pi * 4) * .05,
          child: child,
        ),
        child: AmbientLoop(
          period: DT.motion.speakerPulse,
          // After two misses the right plate breathes.
          enabled: widget.hinting,
          builder: (_, t, child) =>
              Transform.scale(scale: 1 + .05 * t, child: child),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DT.surfaceWhite,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.filled
                    ? DT.success
                    : widget.hinting
                    ? DT.hint
                    : DT.outline,
                width: widget.filled || widget.hinting ? 4 : 2,
              ),
              boxShadow: DT.shadowSoft(DT.brand),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: policy.dur(DT.motion.successPop),
                switchInCurve: Curves.easeOutBack,
                child: widget.filled
                    ? KeyedSubtree(
                        key: ValueKey('filled-${widget.card.image}'),
                        child: friend,
                      )
                    : KeyedSubtree(
                        key: ValueKey('shadow-${widget.card.image}'),
                        // The friend as one flat shape.
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            DT.textSecondary.withValues(alpha: .45),
                            BlendMode.srcIn,
                          ),
                          child: friend,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
