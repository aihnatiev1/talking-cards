import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/app_review_provider.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/board_theme.dart';
import '../utils/design_tokens.dart';
import '../utils/memory_tiers.dart';
import '../utils/motion.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/board_mat_painter.dart';
import '../widgets/card_back_painter.dart';
import '../widgets/card_image.dart';
import '../widgets/celebration.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/sparkle_burst.dart';

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Tile {
  final CardModel card;
  final int pairId; // same for the two tiles that form a pair
  final int tileId; // unique across the board
  bool isFlipped = false;
  bool isMatched = false;

  /// Bumped when this tile is tapped while already face up — it bounces
  /// and repeats its word (rule 2: every touch answers).
  int bounce = 0;

  /// Bumped when the pair was found: the two cards knock towards each
  /// other, a ring opens and the sparks fly.
  int knock = 0;

  /// Unit vector towards the twin, for that knock.
  Offset towardsTwin = Offset.zero;

  _Tile({required this.card, required this.pairId, required this.tileId});
}

/// Board geometry. Extracted verbatim from the `LayoutBuilder` that fixed
/// the clipped-bottom-row bug (`test/screens/memory_board_fit_test.dart`)
/// so the *same* formula can be asked twice: once by the scene, to find out
/// whether there is room for Bloom beside the mat, and once by the board
/// itself. The maths is untouched — only its address changed.
class _BoardMetrics {
  final double tileW;
  final int cols;
  final int rows;
  final double ratio;
  final double width;
  final double height;

  const _BoardMetrics({
    required this.tileW,
    required this.cols,
    required this.rows,
    required this.ratio,
    required this.width,
    required this.height,
  });

  static const gap = 12.0;

  /// 3 pairs → 2×3 grid with big toddler tiles; bigger boards keep the
  /// classic 3-column layout.
  static int colsFor(int pairs) => pairs <= 3 ? 2 : 3;

  static _BoardMetrics of({
    required Size box,
    required int pairs,
    required int tiles,
  }) {
    final cols = colsFor(pairs);
    final rows = (tiles / cols).ceil();
    final ratio = pairs <= 3 ? 0.9 : 0.82;

    final tileW = min(
      (box.width - gap * (cols - 1)) / cols,
      (box.height - gap * (rows - 1)) / rows * ratio,
    );
    return _BoardMetrics(
      tileW: tileW,
      cols: cols,
      rows: rows,
      ratio: ratio,
      width: tileW * cols + gap * (cols - 1),
      height: tileW / ratio * rows + gap * (rows - 1),
    );
  }
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────

/// «Знайди пару» — cards on a mat on a table, Bloom sitting beside it
/// (docs/design/memory_match_redesign.md).
class MemoryMatchScreen extends ConsumerStatefulWidget {
  final PackModel pack;
  final List<CardModel> cards;

  /// Pairs on the board, or `null` — the usual case — for the board to
  /// size itself from the profile's level and how calm the last rounds
  /// were (§6). An explicit value pins the board for the whole session
  /// (tests, a parent's choice) and turns the ladder off.
  final int? pairCount;

  const MemoryMatchScreen({
    super.key,
    required this.pack,
    required this.cards,
    this.pairCount,
  });

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  late final BoardTheme _theme;
  late final int _level;
  late final MemoryDifficulty _difficulty;

  late List<_Tile> _tiles;
  int? _firstIndex; // index of first flipped tile awaiting a pair
  bool _isLocked = false; // true while a mismatch is being shown
  int _matched = 0;

  /// Pairs on the current board — stable for the whole round, and never
  /// more than the pool can fill.
  int _activePairs = 0;

  // Confidence of the round (§6). Hints are always 0 in wave 1 — the
  // two-step nudge arrives with wave 2 — but the counter is the one the
  // rule reads, so it is already here.
  int _misses = 0;
  int _hints = 0;
  int _rounds = 0;

  /// All cards are face up for a moment at the start (§4, level 1 and the
  /// first round of level 2). Any tap ends it.
  bool _previewing = false;

  /// A tap that arrived while the board was busy: exactly one is kept and
  /// applied as soon as the cards have landed (rule 3, forgiving input).
  int? _queuedTap;

  DateTime? _holdStart;
  Timer? _holdTimer;
  Timer? _roundEndTimer;
  final List<Timer> _previewTimers = [];

  /// Every other pending delay (the word cue, the queued tap). Tracked so
  /// `dispose` can cancel them: a timer that outlives the route fires into
  /// a dead screen on device and fails every widget test that touches it.
  final List<Timer> _timers = [];
  int _voiceWaits = 0;

  /// The shared celebration is up: the in-scene Bloom fades so there is
  /// one Bloom on screen.
  bool _celebrating = false;

  final Object _bloomScene = Object();
  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _theme = BoardTheme.of(widget.pack, widget.cards);
    _level = ref.read(profileProvider).active?.level ?? 2;
    _difficulty = MemoryDifficulty(level: _level, fixedPairs: widget.pairCount);
    _tiles = const [];
    AnalyticsService.instance.logGameStart('memory_match');
    _bloom.sceneEntered(_bloomScene, BloomScene.memory);
    _deal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'memory',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  Timer _after(Duration d, VoidCallback fn) {
    late Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      if (mounted) fn();
    });
    _timers.add(t);
    return t;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _roundEndTimer?.cancel();
    for (final t in [..._previewTimers, ..._timers]) {
      t.cancel();
    }
    _bloom.sceneLeft(_bloomScene);
    super.dispose();
  }

  // ── Setup ───────────────────────────────────

  /// Builds a board of [MemoryDifficulty.pairs] pairs — or of as many as
  /// the pool can actually fill. A pack with five recorded cards used to
  /// hand out five tiles while the counter waited for six pairs, and the
  /// round could never be won.
  void _deal() {
    _holdTimer?.cancel();
    _roundEndTimer?.cancel();
    for (final t in _previewTimers) {
      t.cancel();
    }
    _previewTimers.clear();

    final wanted = _difficulty.pairs;
    final playable = widget.cards.where((c) => c.audioKey != null).toList();
    // Prefer cards with audio; fall back to all cards if not enough.
    final pool = playable.length >= wanted ? playable : widget.cards;
    final pairs = min(wanted, pool.length);
    final picks = (List<CardModel>.from(
      pool,
    )..shuffle(Random())).take(pairs).toList();

    final tiles = <_Tile>[];
    for (int i = 0; i < picks.length; i++) {
      tiles.add(_Tile(card: picks[i], pairId: i, tileId: i * 2));
      tiles.add(_Tile(card: picks[i], pairId: i, tileId: i * 2 + 1));
    }
    tiles.shuffle(Random());

    final preview = _previewEnabled && tiles.isNotEmpty;
    if (preview) {
      for (final t in tiles) {
        t.isFlipped = true;
      }
    }

    setState(() {
      _tiles = tiles;
      _activePairs = picks.length;
      _firstIndex = null;
      _isLocked = false;
      _matched = 0;
      _misses = 0;
      _hints = 0;
      _queuedTap = null;
      _celebrating = false;
      _previewing = preview;
    });

    // The one "shuffle" accent of the round; the deal choreography itself
    // is wave 2.
    FeedbackService.instance.play(KidSound.cardLand);

    if (preview) _startPreview();
  }

  /// Meeting the cards first (§4, п. 20): level 1 always, level 2 on the
  /// first round of a session. Never for a pinned board — a test or a
  /// parent asked for exactly this board, not for a lesson.
  bool get _previewEnabled =>
      !_difficulty.isFixed && (_level <= 1 || (_level == 2 && _rounds == 0));

  Duration get _previewHold =>
      _level <= 1 ? DT.motion.memoryPreviewL1 : DT.motion.memoryPreviewL2;

  void _startPreview() {
    _previewTimers.add(
      Timer(_previewHold, () {
        if (!mounted || !_previewing) return;
        // Face down one after another, then the board is live.
        for (var i = 0; i < _tiles.length; i++) {
          _previewTimers.add(
            Timer(DT.motion.memoryPreviewStagger * i, () {
              if (!mounted || !_previewing) return;
              setState(() => _tiles[i].isFlipped = false);
              if (i == _tiles.length - 1) setState(() => _previewing = false);
            }),
          );
        }
      }),
    );
  }

  /// Any tap during the preview puts every card down at once and is then
  /// applied — nobody waits for the show to end (п. 18).
  void _endPreview({int? applyIndex}) {
    for (final t in _previewTimers) {
      t.cancel();
    }
    _previewTimers.clear();
    setState(() {
      for (final t in _tiles) {
        if (!t.isMatched) t.isFlipped = false;
      }
      _previewing = false;
    });
    if (applyIndex != null) _onTap(applyIndex);
  }

  // ── Interaction ─────────────────────────────

  void _onTap(int index) {
    if (index >= _tiles.length) return;
    if (_previewing) {
      _endPreview(applyIndex: index);
      return;
    }
    if (_isLocked) {
      _cutHold(index);
      return;
    }
    final tile = _tiles[index];

    // Rule 2: a tap on a card that is already face up (or already found)
    // is not a silent no-op — it bounces and says its word again. A free
    // repetition is exactly what a talking-cards app is for.
    if (tile.isFlipped || tile.isMatched) {
      setState(() => tile.bounce++);
      _say(tile.card, onlyWhenQuiet: true);
      return;
    }

    _say(tile.card);
    setState(() => tile.isFlipped = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    // Second tile tapped — evaluate the pair.
    final first = _firstIndex!;
    _firstIndex = null;

    if (_tiles[first].pairId == tile.pairId) {
      _onMatch(first, index);
    } else {
      _onMismatch(first, index);
    }
  }

  /// The word. The flip does not wait for it and it does not wait for the
  /// flip: it starts [DTMotion.memoryWordCue] after the touch, while the
  /// card is still turning (п. 11).
  void _say(CardModel card, {bool onlyWhenQuiet = false}) {
    if (onlyWhenQuiet && AudioService.instance.isSpeaking.value) return;
    final delay = _reduce ? Duration.zero : DT.motion.memoryWordCue;
    if (delay == Duration.zero) {
      AudioService.instance.playWordOnly(card.audioKey, card.sound);
      return;
    }
    _after(delay, () {
      AudioService.instance.playWordOnly(card.audioKey, card.sound);
    });
  }

  void _onMatch(int a, int b) {
    FeedbackService.instance.event(FeedbackEvent.correct, step: _matched + 1);
    final dir = _towards(a, b);
    setState(() {
      _tiles[a].isMatched = true;
      _tiles[b].isMatched = true;
      _tiles[a].towardsTwin = dir;
      _tiles[b].towardsTwin = -dir;
      _tiles[a].knock++;
      _tiles[b].knock++;
      _matched++;
    });
    // Matched cards stay on the board face up: a growing gallery of what
    // the child has found is the reward, and a board with holes in it
    // loses a two-year-old.
    if (_matched < _activePairs) return;
    _roundEndTimer?.cancel();
    _roundEndTimer = Timer(DT.motion.memoryRoundEnd, _finishRound);
  }

  /// Unit vector from tile [a] towards tile [b] on the grid — the two
  /// cards move 5 dp along it and back: they *find each other*.
  Offset _towards(int a, int b) {
    final cols = _BoardMetrics.colsFor(_activePairs);
    final from = Offset((a % cols).toDouble(), (a ~/ cols).toDouble());
    final to = Offset((b % cols).toDouble(), (b ~/ cols).toDouble());
    final d = to - from;
    return d.distance == 0 ? Offset.zero : d / d.distance;
  }

  void _onMismatch(int a, int b) {
    _misses++;
    // Not a punishment: one muted note, no buzz, no red. The only
    // consequence is that the cards lie back down.
    FeedbackService.instance.event(FeedbackEvent.wrong);
    _isLocked = true;
    _holdStart = DateTime.now();
    _voiceWaits = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer(
      _reduce ? DT.motion.reducedFade : DT.motion.memoryHold(_level),
      () => _endHold(a, b),
    );
  }

  /// The pair turns back once the hold is over **and** the second word has
  /// finished: a fixed 900 ms used to cut «протилежності» in half.
  void _endHold(int a, int b) {
    if (!mounted) return;
    if (!_reduce &&
        AudioService.instance.isSpeaking.value &&
        _voiceWaits < 10) {
      _voiceWaits++;
      _holdTimer = Timer(DT.motion.memoryVoiceGrace, () => _endHold(a, b));
      return;
    }
    _flipBack(a, b);
  }

  void _flipBack(int a, int b) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdStart = null;
    if (!mounted) return;
    setState(() {
      if (!_tiles[a].isMatched) _tiles[a].isFlipped = false;
      if (!_tiles[b].isMatched) _tiles[b].isFlipped = false;
      _isLocked = false;
    });
    final queued = _queuedTap;
    if (queued == null) return;
    _queuedTap = null;
    // The tap the child made while the cards were still up: honoured once
    // they have landed, so the touch is never simply lost.
    _after(_reduce ? Duration.zero : DT.motion.memoryFlip, () {
      if (_isLocked) return;
      _onTap(queued);
    });
  }

  /// A tap during the mismatch hold. After half a second the child has
  /// seen both cards, so the wait ends immediately and the tap is queued;
  /// before that the tap only sounds (KidTap already answered the finger).
  void _cutHold(int index) {
    final start = _holdStart;
    if (start == null) return;
    if (DateTime.now().difference(start) < DT.motion.memoryHoldCut) return;
    _queuedTap ??= index;
    final a = _tiles.indexWhere((t) => t.isFlipped && !t.isMatched);
    final b = _tiles.lastIndexWhere((t) => t.isFlipped && !t.isMatched);
    if (a < 0 || b < 0) return;
    _flipBack(a, b);
  }

  // ── Round end ────────────────────────────────

  void _finishRound() {
    _roundEndTimer = null;
    if (!mounted) return;
    _rounds++;
    AnalyticsService.instance.logGameComplete('memory_match', _matched);
    // Aggregates only, no identifiers (COPPA): the thresholds of §6 are
    // calibrated from these.
    final confidence = MemoryTiers.confidenceOf(
      pairs: _activePairs,
      misses: _misses,
      hints: _hints,
    );
    AnalyticsService.instance.logEvent(
      'memory_round',
      parameters: {
        'level': _level,
        'pairs': _activePairs,
        'misses': _misses,
        'hints': _hints,
        'calm': confidence == RoundConfidence.calm ? 1 : 0,
      },
    );
    final from = _difficulty.pairs;
    final change = _difficulty.applyRound(misses: _misses, hints: _hints);
    if (change != TierChange.stay) {
      AnalyticsService.instance.logEvent(
        'memory_tier_change',
        parameters: {
          'from': from,
          'to': _difficulty.pairs,
          'reason': change.name,
        },
      );
    }

    ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
    // See GameStateMixin._complete: the first finished game is the one
    // automatic review ask that English-market families actually reach.
    final firstGame = isFirstGame(ref);
    ref.read(gameStatsProvider.notifier).record('memory', _matched);
    if (firstGame) {
      ref.read(appReviewControllerProvider).noteFirstGameFinished();
    }

    setState(() => _celebrating = true);
    // Any completion is a full win — no attempts, no stars, no time.
    celebrate(
      context,
      tier: CelebrationTier.round,
      isEn: ref.read(languageProvider) == 'en',
      childName: ref.read(profileProvider).active?.name ?? '',
      onAgain: _deal,
      onDone: () => Navigator.of(context).pop(),
    );
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    _reduce = policy.reduce;
    final color = widget.pack.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KidScreen.game(
      accent: color,
      // The room, not the objects: a dark tablet at bedtime dims the table
      // the cards lie on, never the cards.
      background: isDark ? DT.bgDark : _theme.bg,
      // No title: cards may come from several packs, so naming one would be
      // wrong, and "Find the pair" is spoken, not read.
      trailing: SizedBox(
        width: 72,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: DT.shadowSoft(color),
            ),
            child: Text(
              '$_matched/$_activePairs',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Pair progress dots ─────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_activePairs, (i) {
                final done = i < _matched;
                return AnimatedContainer(
                  duration: policy.dur(DT.motion.base),
                  curve: DT.motion.emphasized,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: done ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: done ? color : color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
          ),

          // ── The table: mat, cards, Bloom ────
          Expanded(child: _scene(policy)),
        ],
      ),
    );
  }

  /// Where the board goes and where Bloom sits (§2). The board's own
  /// fitting maths is untouched; all that is decided here is which box it
  /// is handed — beside Bloom, or above him.
  Widget _scene(MotionPolicy policy) {
    return LayoutBuilder(
      builder: (context, box) {
        if (_tiles.isEmpty) return const SizedBox.shrink();
        final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
        final full = _BoardMetrics.of(
          box: Size(box.maxWidth - 24, box.maxHeight - 12),
          pairs: _activePairs,
          tiles: _tiles.length,
        );
        final spareW = box.maxWidth - full.width;

        // Bloom always on the left: the hand reaching for the cards is
        // usually the right one, and the counter pill is the diagonal
        // opposite corner.
        if (spareW >= _sideModeSpare) {
          final size = tablet && box.maxWidth < 900 ? 112.0 : 160.0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _bloomZoneWidth,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _bloomZone(policy, size: size),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(child: _board(tablet: tablet)),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: _board(tablet: tablet)),
            SizedBox(
              height: _bloomStrip,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 0, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _bloomZone(policy),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Width of the zone Bloom needs beside the mat, and the height of the
  /// strip he gets under it (8 gap + 88 Bloom + 16 bottom).
  static const _bloomZoneWidth = 200.0;
  static const _bloomStrip = 112.0;
  static const _sideModeSpare = 216.0;

  Widget _bloomZone(MotionPolicy policy, {double size = 88}) {
    return AnimatedOpacity(
      opacity: _celebrating ? 0 : 1,
      duration: policy.dur(DT.motion.bloomFade),
      child: BloomMascot(size: size, semanticsLabel: 'Bloom'),
    );
  }

  Widget _board({required bool tablet}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      // SliverGridDelegateWithFixedCrossAxisCount derives a tile's HEIGHT
      // from its width, so on a wide screen the rows grow past the box —
      // and with NeverScrollableScrollPhysics they are then simply
      // clipped. On an 11" iPad the bottom row was cut in half and its two
      // cards could not be tapped at all.
      //
      // Size the board from the box instead: keep the designed tile
      // proportions, take the largest board that fits both dimensions, and
      // centre it. Correct on a phone, a tablet, and either rotation.
      child: LayoutBuilder(
        builder: (context, box) {
          final m = _BoardMetrics.of(
            box: Size(box.maxWidth, box.maxHeight),
            pairs: _activePairs,
            tiles: _tiles.length,
          );
          if (m.tileW <= 0) return const SizedBox.shrink();

          final bleed = tablet
              ? BoardMatPainter.tabletBleed
              : BoardMatPainter.phoneBleed;

          return Center(
            child: SizedBox(
              width: m.width,
              height: m.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The mat under the cards. It may run off a phone's
                  // edge — the table is bigger than the screen.
                  Positioned(
                    left: -bleed,
                    top: -bleed,
                    right: -bleed,
                    bottom: -bleed,
                    child: RepaintBoundary(
                      child: CustomPaint(painter: BoardMatPainter(_theme)),
                    ),
                  ),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: m.cols,
                      mainAxisSpacing: _BoardMetrics.gap,
                      crossAxisSpacing: _BoardMetrics.gap,
                      childAspectRatio: m.ratio,
                    ),
                    itemCount: _tiles.length,
                    itemBuilder: (context, i) => _TileWidget(
                      key: ValueKey(_tiles[i].tileId),
                      tile: _tiles[i],
                      theme: _theme,
                      onTap: () => _onTap(i),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tile
// ─────────────────────────────────────────────

class _TileWidget extends StatefulWidget {
  final _Tile tile;
  final BoardTheme theme;
  final VoidCallback onTap;

  const _TileWidget({
    super.key,
    required this.tile,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _accent; // knock on a match / tap bounce
  late final AnimationController _sticker;

  // Track last-processed state to avoid mutable-object comparison issue.
  // _Tile is mutated in-place → old.tile == widget.tile (same ref), so
  // comparing old.tile.isFlipped gives the NEW value, not the old one.
  bool _lastFaceUp = false;
  int _lastKnock = 0;
  int _lastBounce = 0;
  bool _knocking = false;

  /// Non-null while a match burst is on screen; the key restarts it.
  int? _burst;

  bool _reduce = false;

  bool get _faceUp => widget.tile.isFlipped || widget.tile.isMatched;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: DT.motion.memoryFlip);
    _accent = AnimationController(vsync: this, duration: DT.motion.memoryKnock);
    _sticker = AnimationController(
      vsync: this,
      duration: DT.motion.memorySticker,
    );
    _lastFaceUp = _faceUp;
    _lastKnock = widget.tile.knock;
    _lastBounce = widget.tile.bounce;
    if (_faceUp) _flip.value = 1.0;
    if (widget.tile.isMatched) _sticker.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = MotionPolicy.of(context);
    _reduce = policy.reduce;
    _flip.duration = policy.dur(DT.motion.memoryFlip);
    _accent.duration = policy.dur(DT.motion.memoryKnock);
    _sticker.duration = policy.dur(DT.motion.memorySticker);
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    final nowFace = _faceUp;
    if (nowFace && !_lastFaceUp) _flip.forward();
    if (!nowFace && _lastFaceUp) _flip.reverse();
    _lastFaceUp = nowFace;

    if (widget.tile.knock != _lastKnock) {
      _lastKnock = widget.tile.knock;
      _knocking = true;
      _accent.duration = _reduce ? Duration.zero : DT.motion.memoryKnock;
      _accent.forward(from: 0);
      _sticker.forward(from: 0);
      // No setState: didUpdateWidget is followed by this element's own
      // build, and the sparks are drawn from the same frame.
      if (!_reduce) _burst = _lastKnock;
    }
    if (widget.tile.bounce != _lastBounce) {
      _lastBounce = widget.tile.bounce;
      if (!_reduce) {
        _knocking = false;
        _accent.duration = DT.motion.memoryBounce;
        _accent.forward(from: 0);
      }
    }
    if (!widget.tile.isMatched && _sticker.value != 0) _sticker.value = 0;
  }

  @override
  void dispose() {
    _flip.dispose();
    _accent.dispose();
    _sticker.dispose();
    super.dispose();
  }

  /// 0 → peak → 0, so a knock and a bounce both end where they started.
  double get _accentPulse => sin(_accent.value * pi);

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: widget.onTap,
      // Paper snap on the way down; the card answers with its word.
      sound: KidSound.flip,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _accent]),
        builder: (_, __) {
          final angle = _reduce ? 0.0 : _flip.value * pi;
          final showFront = _flip.value > 0.5;
          final Widget face = showFront
              ? Transform(
                  transform: Matrix4.identity()..rotateY(_reduce ? 0 : pi),
                  alignment: Alignment.center,
                  child: _FrontFace(
                    tile: widget.tile,
                    theme: widget.theme,
                    sticker: _sticker,
                  ),
                )
              : CardBack(theme: widget.theme);

          // Lift: the card leaves the table while it turns and clicks back
          // down on landing; a knock is 1.06, a bounce 1.04.
          final lift = _reduce ? 0.0 : sin(_flip.value * pi);
          final pulse = _accentPulse;
          final scale = 1 + lift * 0.06 + pulse * (_knocking ? 0.06 : 0.04);
          final shift = _knocking
              ? widget.tile.towardsTwin * 5 * pulse
              : Offset.zero;

          return Transform.translate(
            offset: shift,
            child: Transform.scale(
              scale: scale,
              // The sparks live outside the card's rotation: they belong to
              // the table, not to the turning card.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: face,
                    ),
                  ),
                  if (_burst != null)
                    Positioned.fill(
                      child: SparkleBurst(
                        key: ValueKey('burst_$_burst'),
                        color: widget.theme.seal,
                        onDone: () {
                          if (mounted) setState(() => _burst = null);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The face of a card: the illustration the child is learning, and its
/// word. No green tick, no `#4CAF50` — "found" reads as a frame in the
/// board's own ink plus a star sticker, and the picture stays in full
/// colour: the gallery of what has been found is the reward.
class _FrontFace extends StatelessWidget {
  final _Tile tile;
  final BoardTheme theme;
  final Animation<double> sticker;

  const _FrontFace({
    required this.tile,
    required this.theme,
    required this.sticker,
  });

  @override
  Widget build(BuildContext context) {
    final matched = tile.isMatched;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.hasBoundedWidth ? box.maxWidth : 100.0;
        final radius = CardBackPainter.radiusOf(w);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.paper,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: matched
                        ? theme.seal
                        : tile.card.colorAccent.withValues(alpha: 0.45),
                    width: matched ? 3 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.seal.withValues(
                        alpha: matched ? 0.18 : 0.28,
                      ),
                      offset: Offset(0, matched ? 2 : 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      Expanded(flex: 4, child: _art()),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tile.card.sound,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: DT.kidFont,
                                fontVariations: DT.kidWeight(800),
                                fontSize: 22,
                                color: DT.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (matched)
              Positioned(
                top: -4,
                right: -4,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: sticker,
                    curve: DT.motion.emphasized,
                  ),
                  child: _StarSticker(size: w * 0.18, ink: theme.ink),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _art() {
    final letter = tile.card.letter;
    if (letter != null) {
      // Sound packs: the letter *is* the picture.
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: DT.kidFont,
              fontVariations: DT.kidWeight(900),
              fontSize: 64,
              color: DT.onTint(tile.card.colorAccent),
            ),
          ),
        ),
      );
    }
    // Only ever through CardImage: on Android the paid art arrives in a
    // Play asset pack after install, and CardImage is the one thing that
    // never throws over a file that has not landed yet.
    return CardImage.forCard(
      tile.card,
      fit: BoxFit.contain,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// The one star of the board — the same shape as on the card back and in
/// the spark burst.
class _StarSticker extends StatelessWidget {
  final double size;
  final Color ink;

  const _StarSticker({required this.size, required this.ink});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(ink: ink)),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color ink;

  const _StarPainter({required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final path = CardBackPainter.starPath(
      size.center(Offset.zero),
      size.shortestSide / 2,
    );
    canvas.drawPath(path, Paint()..color = DT.sunBurst);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.ink != ink;
}
