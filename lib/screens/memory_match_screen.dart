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
import '../providers/word_evidence_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../services/memory_comfort_service.dart';
import '../utils/board_theme.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
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

  /// Bumped when the board nudges this card: nothing has been touched for
  /// a while, so one card stirs to say there is something to do here
  /// (§6). The kind says how loudly.
  int nudge = 0;
  _NudgeKind nudgeKind = _NudgeKind.invite;

  _Tile({required this.card, required this.pairId, required this.tileId});
}

/// How a nudged card stirs (§6). The invitation is silent and says only
/// "the board is awake"; the other two are the hint proper and point at
/// the card that actually is the pair.
enum _NudgeKind {
  /// Step 1: 1.03 and a degree and a half of tilt. Any card, no sound.
  invite,

  /// Step 2 from three years up: the twin shakes ±3°.
  shake,

  /// Step 2 for the littlest (level 1): the twin turns up to ~110° — its
  /// face is visible at an angle — and lies back down. The card is never
  /// left open and the word is never spoken: the word is the child's to
  /// win with their own tap.
  peek,
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

  /// A card never grows past this, however much room there is
  /// (memory_match_redesign §8, 3.2). On an 11" iPad three pairs used to
  /// blow up into tiles half a screen tall: impressive for a second, then
  /// a neck-turning scan between two objects far apart. Capped, the board
  /// stays an object on the table and simply sits centred in the space.
  static const maxTileW = 220.0;

  /// 3 pairs → 2×3 grid with big toddler tiles; 8 pairs → 4 columns
  /// (16 cards in 4×4 — three columns would make five rows no screen can
  /// hold); everything between keeps the classic 3-column layout.
  static int colsFor(int pairs) => switch (pairs) {
    <= 3 => 2,
    >= 8 => 4,
    _ => 3,
  };

  static _BoardMetrics of({
    required Size box,
    required int pairs,
    required int tiles,
  }) {
    final cols = colsFor(pairs);
    final rows = (tiles / cols).ceil();
    final ratio = pairs <= 3 ? 0.9 : 0.82;

    final tileW = min(
      maxTileW,
      min(
        (box.width - gap * (cols - 1)) / cols,
        (box.height - gap * (rows - 1)) / rows * ratio,
      ),
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

  /// Test seam for the two-step nudge (§6): `(step, hints)` — step 1 is
  /// the silent invitation, step 2 the hint that counts. Nothing in the
  /// app sets it; the movement itself is what the child sees.
  @visibleForTesting
  static void Function(int step, int hints)? debugNudgeSink;

  /// The parent's door: the progress strip, long-pressed (§6).
  @visibleForTesting
  static const parentStripKey = ValueKey('memory_parent_strip');

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  late BoardTheme _theme;
  late final int _level;
  late MemoryDifficulty _difficulty;

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

  /// The parent's choice of board and of the face-up preview (§6). Set
  /// from the sheet behind a long press; it lasts the session and turns
  /// the automatic ladder off.
  bool? _parentPreview;

  /// The nudge clock (§6). One card stirs after [DTMotion.memoryNudgeInvite]
  /// of stillness and the actual twin after [DTMotion.memoryNudgeHint];
  /// three unanswered hints and the board stops asking.
  Timer? _nudgeTimer;
  int _nudgesGiven = 0;

  /// Bumped by every deal so a tile that is being reused (same key, new
  /// card) flies in again instead of appearing.
  int _dealSerial = 0;

  /// Whether this round has been played at all — a board still untouched
  /// may be quietly re-dealt when the remembered comfort tier arrives.
  bool _touched = false;

  /// After three hints nobody answered, the board stops asking: a mascot
  /// that keeps poking is a mascot the child learns to ignore.
  static const _maxNudges = 3;

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
    _level = ref.read(profileProvider).active?.level ?? 2;
    _difficulty = MemoryDifficulty(level: _level, fixedPairs: widget.pairCount);
    _tiles = const [];
    AnalyticsService.instance.logGameStart('memory_match');
    _bloom.sceneEntered(_bloomScene, BloomScene.memory);
    _deal();
    _restoreComfort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'memory',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The room darkens, the objects do not (§2): a dark tablet at bedtime
    // dims the table the cards lie on, never the cards themselves.
    _theme = BoardTheme.of(
      widget.pack,
      widget.cards,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// The board this child last played calmly (§6, wave 2.6). It arrives a
  /// frame or two late — `SharedPreferences` is a channel — so it is only
  /// honoured while the round is still untouched; from the first tap on,
  /// the board a child is playing never changes underneath them.
  void _restoreComfort() {
    if (widget.pairCount != null) return;
    MemoryComfortService.instance.read().then((comfort) {
      if (!mounted || comfort == null || _touched || _rounds > 0) return;
      if (_difficulty.isFixed || comfort <= _difficulty.pairs) return;
      _difficulty = MemoryDifficulty(level: _level, comfort: comfort);
      _deal();
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
    _nudgeTimer?.cancel();
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
    _nudgeTimer?.cancel();
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
      _dealSerial++;
      _activePairs = picks.length;
      _firstIndex = null;
      _isLocked = false;
      _matched = 0;
      _misses = 0;
      _hints = 0;
      _queuedTap = null;
      _celebrating = false;
      _previewing = preview;
      _touched = false;
      _nudgesGiven = 0;
    });

    // The one "shuffle" accent of the round; the deal choreography itself
    // is wave 2.
    FeedbackService.instance.play(KidSound.cardLand);

    if (preview) {
      _startPreview();
    } else {
      _armNudge();
    }
  }

  /// Meeting the cards first (§4, п. 20): level 1 always, level 2 on the
  /// first round of a session. Never for a pinned board — a test or a
  /// parent asked for exactly this board, not for a lesson.
  bool get _previewEnabled {
    // A parent who asked for (or switched off) the first look owns the
    // answer for the rest of the session.
    final choice = _parentPreview;
    if (choice != null) return choice;
    return !_difficulty.isFixed &&
        (_level <= 1 || (_level == 2 && _rounds == 0));
  }

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
              if (i == _tiles.length - 1) {
                setState(() => _previewing = false);
                _armNudge();
              }
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
    if (applyIndex != null) {
      _onTap(applyIndex);
    } else {
      _armNudge();
    }
  }

  // ── Interaction ─────────────────────────────

  void _onTap(int index) {
    if (index >= _tiles.length) return;
    _touched = true;
    // Any touch answers the board's question, so the nudge clock starts
    // over and the "three unanswered hints" counter is forgiven.
    _nudgesGiven = 0;
    _armNudge();
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

  // ── The nudge (§6) ──────────────────────────
  //
  // The board is still while the child plays (п. 12: movement appears
  // where an action is needed, never as decoration). When nothing has
  // been touched for a while, it asks twice and then stops:
  //
  //   step 1, silent — one closed card stirs: "there is something here";
  //   step 2, with a sound — the card that *is* the pair stirs, and for
  //           the littlest it turns far enough to show its face.
  //
  // Step 2 is the `hints` of the round's confidence (§6), which is why
  // the ladder could not read anything before this existed.

  void _armNudge() {
    _nudgeTimer?.cancel();
    if (!mounted || _tiles.isEmpty) return;
    if (_previewing || _celebrating || _matched >= _activePairs) return;
    if (_nudgesGiven >= _maxNudges) return;
    // From four years up, a still board is a thinking child: the nudge
    // only turns up once the round has actually gone wrong twice.
    if (_level >= 4 && _misses < 2) return;
    _nudgeTimer = Timer(DT.motion.memoryNudgeInvite(_level), _invite);
  }

  /// Step 1 — an invitation, never an answer: any closed card, silent.
  void _invite() {
    _nudgeTimer = null;
    if (!mounted || _previewing || _celebrating) return;
    if (!_isLocked) {
      final index = _closedIndex();
      if (index != null) _stir(index, _NudgeKind.invite);
      MemoryMatchScreen.debugNudgeSink?.call(1, _hints);
    }
    _nudgeTimer = Timer(
      DT.motion.memoryNudgeHint(_level) - DT.motion.memoryNudgeInvite(_level),
      _hint,
    );
  }

  /// Step 2 — the hint proper, and the only step the confidence of the
  /// round counts.
  void _hint() {
    _nudgeTimer = null;
    if (!mounted || _previewing || _celebrating) return;
    if (_isLocked) {
      // The cards are still lying back down; ask again in a moment
      // without spending a hint.
      _nudgeTimer = Timer(DT.motion.memoryNudgeInvite(_level), _hint);
      return;
    }
    final twin = _twinIndex();
    final index = twin ?? _closedIndex();
    if (index == null) return;
    final kind = twin == null
        ? _NudgeKind.invite
        : (_level <= 1 ? _NudgeKind.peek : _NudgeKind.shake);
    _stir(index, kind);
    // Bloom looks where the board is asking (§2: he reacts, he never
    // runs the round). Only step 2 — the invitation of step 1 is silent
    // on purpose, and a mascot pointing at a card is not silent.
    _bloom.nudged(_towardsTile(index));
    _hints++;
    _nudgesGiven++;
    // A pencil tick, the quietest thing in the palette: the hint asks, it
    // does not insist, and every repeat asks a little lower.
    FeedbackService.instance.play(
      KidSound.tick,
      pitch: _nudgesGiven <= 1 ? 1.0 : 0.94,
    );
    MemoryMatchScreen.debugNudgeSink?.call(2, _hints);
    _armNudge();
  }

  /// The direction from Bloom to tile [index], in his own `-1..1` space.
  /// He sits at the bottom-left corner of the table in both layouts
  /// (beside the mat, or in the strip under it), so every card is up and
  /// to the right of him; the grid's own columns and rows say how far.
  Alignment _towardsTile(int index) {
    final cols = _BoardMetrics.colsFor(_activePairs);
    final rows = (_tiles.length / cols).ceil();
    final colT = cols <= 1 ? 0.5 : (index % cols) / (cols - 1);
    final rowT = rows <= 1 ? 0.5 : (index ~/ cols) / (rows - 1);
    return Alignment(0.3 + 0.7 * colT, -0.9 + 0.7 * rowT);
  }

  void _stir(int index, _NudgeKind kind) {
    if (_reduce) return;
    setState(() {
      _tiles[index].nudgeKind = kind;
      _tiles[index].nudge++;
    });
  }

  /// The twin of the one card that is open — the card the child is
  /// looking for right now. `null` when no card is open.
  int? _twinIndex() {
    final first = _firstIndex;
    if (first == null) return null;
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (i != first &&
          !t.isMatched &&
          !t.isFlipped &&
          t.pairId == _tiles[first].pairId) {
        return i;
      }
    }
    return null;
  }

  /// Any card still face down — the invitation does not care which one,
  /// and deliberately never picks the one that would give the pair away.
  int? _closedIndex() {
    final closed = <int>[];
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (!t.isMatched && !t.isFlipped) closed.add(i);
    }
    if (closed.isEmpty) return null;
    return closed[Random().nextInt(closed.length)];
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
    // Finding the twin is a recognition of that word, same signal the quiz
    // records — never confused with a plain card view.
    ref.read(wordEvidenceProvider.notifier).recordRecognized(_tiles[a].card.id);
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
    if (_matched < _activePairs) {
      _armNudge();
      return;
    }
    _nudgeTimer?.cancel();
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
    if (queued == null) {
      _armNudge();
      return;
    }
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
    if (confidence == RoundConfidence.calm) {
      // The board that went well is remembered per profile, so tomorrow
      // opens where today left off instead of at two pairs again (§6).
      MemoryComfortService.instance.remember(_activePairs);
    }
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

  // ── The parent's sheet (§6) ──────────────────

  /// Board size and the first look, behind a long press on the progress
  /// strip. No parental gate: this is not a setting, not a purchase and
  /// not an outside link — it is the same class of action as
  /// «Автогортання» in `CardsScreen`, reached by the same parent gesture.
  /// Choosing a size pins the board for the session and turns the
  /// automatic ladder off; the sheet itself is plain 16 sp parent text.
  void _showParentTools() {
    FeedbackService.instance.event(FeedbackEvent.select);
    final s = AppS(ref.read(languageProvider) == 'en');
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  s('Для батьків', 'For parents'),
                  style: DT.h2.copyWith(color: DT.textSecondary),
                ),
              ),
              ListTile(
                leading: Icon(Icons.grid_view_rounded, color: _theme.seal),
                title: Text(s('Скільки пар', 'How many pairs')),
                subtitle: Text(
                  s(
                    'Поле лишиться таким до кінця гри',
                    'The board stays this size for the session',
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final pairs in MemoryTiers.steps.take(4))
                    ChoiceChip(
                      label: Text('$pairs'),
                      selected:
                          _difficulty.isFixed && _difficulty.pairs == pairs,
                      onSelected: (_) {
                        Navigator.of(ctx).pop();
                        _setBoard(pairs);
                      },
                    ),
                ],
              ),
              SwitchListTile(
                value: _previewEnabled,
                secondary: Icon(Icons.visibility_outlined, color: _theme.seal),
                title: Text(
                  s('Показати картки спочатку', 'Show the cards first'),
                ),
                subtitle: Text(
                  s(
                    'Усі картки лежать лицем догори кілька секунд',
                    'Every card lies face up for a few seconds',
                  ),
                ),
                onChanged: (value) {
                  Navigator.of(ctx).pop();
                  setState(() => _parentPreview = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setBoard(int pairs) {
    final from = _difficulty.pairs;
    _difficulty = MemoryDifficulty(level: _level, fixedPairs: pairs);
    AnalyticsService.instance.logEvent(
      'memory_tier_change',
      parameters: {'from': from, 'to': pairs, 'reason': 'parent'},
    );
    _deal();
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
      trailing: KidCountPill(label: '$_matched/$_activePairs'),
      body: Column(
        children: [
          // ── Pair progress: stars, not dots ──
          //
          // The same star that lands on a found card and flies in its
          // spark burst — one language on the whole board instead of a
          // Material dot the child has never seen anywhere else.
          //
          // The strip is also the parent's door (§6): a long press — the
          // same gesture as on a pack cover, and the same class of action
          // as «Автогортання» — opens the board-size sheet. A child's tap
          // does nothing here.
          GestureDetector(
            key: MemoryMatchScreen.parentStripKey,
            behavior: HitTestBehavior.translucent,
            onLongPress: _showParentTools,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _ProgressStars(
                pairs: _activePairs,
                matched: _matched,
                theme: _theme,
                policy: policy,
              ),
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
          // The board only ever grows to what its own height allows, so
          // handing it the whole remaining width pushed it against the
          // right edge and left Bloom marooned in empty space. Measure the
          // board for the narrowed box and give the pair exactly the room
          // they use, centred together.
          final side = _BoardMetrics.of(
            box: Size(box.maxWidth - size - 40, box.maxHeight - 12),
            pairs: _activePairs,
            tiles: _tiles.length,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _bloomZone(policy, size: size),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: side.width + 24,
                child: _board(tablet: tablet, beside: true),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: _board(tablet: tablet, beside: false)),
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

  /// Height of the strip Bloom gets under the mat (8 gap + 88 Bloom + 16
  /// bottom); beside the mat he takes only his own width.
  static const _bloomStrip = 112.0;
  static const _sideModeSpare = 216.0;

  Widget _bloomZone(MotionPolicy policy, {double size = 88}) {
    return AnimatedOpacity(
      opacity: _celebrating ? 0 : 1,
      duration: policy.dur(DT.motion.bloomFade),
      child: BloomMascot(size: size, semanticsLabel: 'Bloom'),
    );
  }

  Widget _board({required bool tablet, required bool beside}) {
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

          // Where the cards come from: Bloom's lap. He is to the left of
          // the mat in the wide layout and under its left corner in the
          // narrow one, so the deal always reads as *he* dealt them.
          final tileH = m.tileW / m.ratio;
          final from = beside
              ? Offset(-bleed - 40, m.height * 0.62)
              : Offset(24, m.height + bleed + 40);
          final stagger = DT.motion.memoryDealStagger(_tiles.length);

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
                    itemBuilder: (context, i) {
                      final centre = Offset(
                        (i % m.cols) * (m.tileW + _BoardMetrics.gap) +
                            m.tileW / 2,
                        (i ~/ m.cols) * (tileH + _BoardMetrics.gap) + tileH / 2,
                      );
                      return _TileWidget(
                        key: ValueKey(_tiles[i].tileId),
                        tile: _tiles[i],
                        theme: _theme,
                        dealFrom: from - centre,
                        dealDelay: stagger * i,
                        dealSerial: _dealSerial,
                        onTap: () => _onTap(i),
                      );
                    },
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

  /// Where this card flies in from — Bloom's lap, in this tile's own
  /// coordinates (§4).
  final Offset dealFrom;

  /// Its place in the deal: the stagger keeps sixteen cards inside 720 ms.
  final Duration dealDelay;

  /// Bumped by every deal, so a reused tile flies in again.
  final int dealSerial;

  const _TileWidget({
    super.key,
    required this.tile,
    required this.theme,
    required this.dealFrom,
    required this.dealDelay,
    required this.dealSerial,
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
  late final AnimationController _deal;
  late final AnimationController _nudge;
  Timer? _dealTimer;

  // Track last-processed state to avoid mutable-object comparison issue.
  // _Tile is mutated in-place → old.tile == widget.tile (same ref), so
  // comparing old.tile.isFlipped gives the NEW value, not the old one.
  bool _lastFaceUp = false;
  int _lastKnock = 0;
  int _lastBounce = 0;
  int _lastNudge = 0;
  int _lastDeal = 0;
  bool _knocking = false;
  _NudgeKind _nudgeKind = _NudgeKind.invite;

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
    _deal = AnimationController(vsync: this, duration: DT.motion.memoryDeal);
    _nudge = AnimationController(vsync: this, duration: DT.motion.memoryNudge);
    _lastFaceUp = _faceUp;
    _lastKnock = widget.tile.knock;
    _lastBounce = widget.tile.bounce;
    _lastNudge = widget.tile.nudge;
    _lastDeal = widget.dealSerial;
    if (_faceUp) _flip.value = 1.0;
    if (widget.tile.isMatched) _sticker.value = 1.0;
    _startDeal();
  }

  /// The card flies out of Bloom's lap into its slot and is tappable the
  /// moment it lands — only the cards still in the air are deaf (§4).
  void _startDeal() {
    _dealTimer?.cancel();
    if (_reduce) {
      _deal.value = 1;
      return;
    }
    _deal.value = 0;
    _dealTimer = Timer(widget.dealDelay, () {
      if (mounted) _deal.forward(from: 0);
    });
  }

  bool get _landed => _deal.value >= 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = MotionPolicy.of(context);
    _reduce = policy.reduce;
    _flip.duration = policy.dur(DT.motion.memoryFlip);
    _accent.duration = policy.dur(DT.motion.memoryKnock);
    _sticker.duration = policy.dur(DT.motion.memorySticker);
    _deal.duration = policy.dur(DT.motion.memoryDeal);
    if (_reduce) {
      _dealTimer?.cancel();
      _deal.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    final nowFace = _faceUp;
    if (nowFace != _lastFaceUp) {
      // A peek borrows this controller and slows it down; a real turn is
      // always the turn's own length, whatever interrupted it.
      _flip.duration = _reduce ? Duration.zero : DT.motion.memoryFlip;
      if (nowFace) {
        _flip.forward();
      } else {
        _flip.reverse();
      }
    }
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
    if (widget.tile.nudge != _lastNudge) {
      _lastNudge = widget.tile.nudge;
      _nudgeKind = widget.tile.nudgeKind;
      if (!_reduce && !_faceUp) _playNudge();
    }
    if (widget.dealSerial != _lastDeal) {
      _lastDeal = widget.dealSerial;
      _startDeal();
    }
    if (!widget.tile.isMatched && _sticker.value != 0) _sticker.value = 0;
  }

  /// The board is asking. A `peek` borrows the flip itself — the card
  /// turns to ~110°, so its face shows at an angle, and lies straight
  /// back down; it is never left open and it never speaks, because the
  /// word belongs to the child's own tap.
  void _playNudge() {
    if (_nudgeKind == _NudgeKind.peek) {
      _flip.duration = DT.motion.memoryPeek;
      _flip
          .animateTo(_peekTurn, curve: DT.motion.emphasized)
          .whenCompleteOrCancel(() {
            if (!mounted) return;
            if (_faceUp) {
              _flip.duration = DT.motion.memoryFlip;
              return;
            }
            _flip.reverse().whenCompleteOrCancel(() {
              if (mounted) _flip.duration = DT.motion.memoryFlip;
            });
          });
      return;
    }
    _nudge.forward(from: 0);
  }

  /// 110° of the 180° turn: past the halfway point, so the face is the
  /// side one sees.
  static const _peekTurn = 110 / 180;

  @override
  void dispose() {
    _dealTimer?.cancel();
    _flip.dispose();
    _accent.dispose();
    _sticker.dispose();
    _deal.dispose();
    _nudge.dispose();
    super.dispose();
  }

  /// 0 → peak → 0, so a knock and a bounce both end where they started.
  double get _accentPulse => sin(_accent.value * pi);

  @override
  Widget build(BuildContext context) {
    return KidTap(
      // A card still in the air is not a card yet; everything that has
      // landed answers immediately, even mid-deal.
      onTap: () {
        if (!_landed) return;
        widget.onTap();
      },
      // Paper snap on the way down; the card answers with its word.
      sound: KidSound.flip,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _accent, _deal, _nudge]),
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
          // The nudge: an invitation is a breath (1.03 and a degree and a
          // half); the shake of the actual twin is three small swings.
          final stir = _nudge.isAnimating || _nudge.value > 0
              ? sin(_nudge.value * pi)
              : 0.0;
          final swing = _nudgeKind == _NudgeKind.shake
              ? sin(_nudge.value * pi * 6) * 3 * pi / 180
              : sin(_nudge.value * pi * 2) * 1.5 * pi / 180;

          // The deal: out of Bloom's lap, 0.6 → 1.0, −8° → 0, α 0 → 1.
          final t = _reduce
              ? 1.0
              : DT.motion.emphasized.transform(_deal.value.clamp(0.0, 1.0));
          final landing = 1 - t;

          final scale =
              (1 + lift * 0.06 + pulse * (_knocking ? 0.06 : 0.04)) *
                  (1 - landing * 0.4) +
              stir * 0.03;
          final shift =
              (_knocking ? widget.tile.towardsTwin * 5 * pulse : Offset.zero) +
              widget.dealFrom * landing;

          return Opacity(
            opacity: _deal.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: shift,
              child: Transform.rotate(
                angle: swing - landing * 8 * pi / 180,
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

/// Progress in stars, not dots (§4).
///
/// An outline star per pair fills — with the same pop the sticker on the
/// card makes — when that pair is found. The child is already collecting
/// this exact star on the cards themselves, so the strip at the top is
/// read without being taught: dots were Material's language, not the
/// board's.
class _ProgressStars extends StatelessWidget {
  final int pairs;
  final int matched;
  final BoardTheme theme;
  final MotionPolicy policy;

  const _ProgressStars({
    required this.pairs,
    required this.matched,
    required this.theme,
    required this.policy,
  });

  static const _size = 16.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pairs; i++)
          Padding(
            key: ValueKey('star_$i'),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: i < matched ? 1 : 0),
              duration: policy.dur(DT.motion.memorySticker),
              curve: DT.motion.emphasized,
              builder: (context, t, _) => Transform.scale(
                // The pop of a sticker landing: up past its size and back.
                scale: 1 + sin(t * pi) * 0.25,
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: CustomPaint(
                    painter: _StarPainter(ink: theme.ink, fill: t),
                  ),
                ),
              ),
            ),
          ),
      ],
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

  /// 0 — an empty outline (a pair still to find), 1 — filled sun.
  final double fill;

  const _StarPainter({required this.ink, this.fill = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final path = CardBackPainter.starPath(
      size.center(Offset.zero),
      size.shortestSide / 2,
    );
    if (fill > 0) {
      canvas.drawPath(
        path,
        Paint()..color = DT.sunBurst.withValues(alpha: fill.clamp(0.0, 1.0)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ink.withValues(alpha: fill > 0 ? 1 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.ink != ink || old.fill != fill;
}
