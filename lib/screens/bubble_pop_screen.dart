import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../models/semantic_group.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/weak_words_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/card_image.dart';
import '../widgets/celebration.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/kid_screen.dart';

/// «Лопай бульбашки» — a sensory toy (docs/design/bubble_pop_redesign.md).
///
/// Card illustrations float up inside glass bubbles over a sunny meadow;
/// the child pops them on pointer-down, hears the word, and every N-th
/// pop Bloom — sitting on the grass with his bubble wand — cheers with a
/// word of praise that rises from over his head.
///
/// Layers, bottom to top: scene → miss detector → ripples → Bloom →
/// live bubbles → popping bubbles → praise. Bloom sits **under** the
/// bubbles so he never covers the learning object.
///
/// Three modes — all unlocked packs, tricky words (mistakes ∪ SRS-due),
/// and «Знайди бульбашку», where Bloom holds up a sign and exactly one of
/// the bubbles in the sky is the thing on it. There is no in-game mode
/// switch (an adult control does not live in the child's play zone): the
/// mode comes from the tile, the pace from the profile
/// ([BubbleTuning.forLevel]).
class BubblePopScreen extends ConsumerStatefulWidget {
  final BubbleMode mode;

  const BubblePopScreen({super.key, this.mode = BubbleMode.all});

  @override
  ConsumerState<BubblePopScreen> createState() => _BubblePopScreenState();
}

enum BubbleMode {
  /// Free popping: every bubble is a word, every pop counts.
  all,

  /// The same game over the mistakes ∪ SRS-due pool.
  tricky,

  /// «Знайди бульбашку» (spec §5, experience audit п. 23): Bloom holds a
  /// sign with one card on it and exactly one live bubble carries that
  /// picture. Popping any *other* bubble still pops, still says its word
  /// and still costs nothing — the counter simply waits. There is no
  /// punishment anywhere in this game, and a missed bubble is not a
  /// mistake, so free popping (mode [all]) stays exactly as it was and
  /// keeps its own tile.
  find,
}

// ─────────────────────────────────────────────
//  Tuning — spec §5, one table for age × device
// ─────────────────────────────────────────────

/// Device class by the shortest side (spec §3): sizes scale up on tablets
/// so an 11" iPad is not three small bubbles in a field of nothing.
enum BubbleDeviceClass {
  phone,
  tabletS,
  tabletL;

  static BubbleDeviceClass of(double shortestSide) {
    if (shortestSide >= 800) return tabletL;
    if (shortestSide >= 600) return tabletS;
    return phone;
  }

  /// Diameter multiplier over the phone numbers.
  double get sizeFactor => switch (this) {
        phone => 1.0,
        tabletS => 1.2,
        tabletL => 1.35,
      };

  /// Bubble rim stroke.
  double get rimWidth => this == phone ? 3 : 4;

  /// Bloom S on the grass (spec §2: 112 / 150 / 176 dp).
  double get bloomSize => switch (this) {
        phone => 112,
        tabletS => 150,
        tabletL => 176,
      };

  /// Droplets per pop.
  int get droplets => this == phone ? 8 : 10;

  bool get isTablet => this != phone;
}

/// Every number the round depends on, from the table in spec §5.
///
/// Two independent axes: the *mode* comes from the tile, the *pace* from
/// `ProfileModel.level` (1 = 1–2 y, 2 = 2–3, 3–4 = 3+; L3 and L4 share a
/// preset). Speed is a *time to cross the play area*, not px/s, so a
/// phone and a tablet — either orientation — feel the same.
@immutable
class BubbleTuning {
  const BubbleTuning({
    required this.level,
    required this.device,
    required this.targetPops,
    required this.findPops,
    required this.roundSeconds,
    required this.minDiameter,
    required this.maxDiameter,
    required this.crossSlowSec,
    required this.crossFastSec,
    required this.maxAlive,
    required this.spawnMinMs,
    required this.spawnMaxMs,
    required this.swayMin,
    required this.swayMax,
    required this.hitSlop,
    required this.praiseEvery,
    required this.idleHintSec,
    required this.missesToCurious,
    required this.minHold,
    required this.popDuration,
  });

  /// Normalised level: 1, 2 or 3.
  final int level;
  final BubbleDeviceClass device;

  /// Pops that end the round.
  final int targetPops;

  /// Finds that end a «Знайди бульбашку» round (spec §5: 3 / 4 / 6). A
  /// find costs several pops and a look around, so the round is counted
  /// in finds and not in pops.
  final int findPops;

  /// Round time limit.
  final int roundSeconds;

  /// Bubble diameter range, already multiplied for [device].
  final double minDiameter;
  final double maxDiameter;

  /// Seconds for the largest / smallest bubble to cross the play area.
  final double crossSlowSec;
  final double crossFastSec;

  /// Bubbles alive at once.
  final int maxAlive;

  /// Gap between spawns.
  final int spawnMinMs;
  final int spawnMaxMs;

  /// Sideways sway amplitude, px.
  final double swayMin;
  final double swayMax;

  /// Extra tappable ring around the drawn bubble.
  final double hitSlop;

  /// Praise every N-th pop.
  final int praiseEvery;

  /// Idle hint after (wave 2).
  final int idleHintSec;

  /// Misses in 4 s before Bloom goes `curious` (wave 3).
  final int missesToCurious;

  /// The revealed card holds at least this long (wave 2 hold logic).
  final Duration minHold;

  /// Whole pop animation.
  final Duration popDuration;

  /// Pops (or finds) that end the round in [mode].
  int goalFor(BubbleMode mode) =>
      mode == BubbleMode.find ? findPops : targetPops;

  /// Praise every N-th step of the counter. A find is rare and big: every
  /// one of them is worth a cheer, except the last (the celebration).
  int praiseBeatFor(BubbleMode mode) =>
      mode == BubbleMode.find ? 1 : praiseEvery;

  static BubbleTuning forLevel(int level, BubbleDeviceClass device) {
    final f = device.sizeFactor;
    final pop = DT.motion.bubblePop;
    return switch (level) {
      <= 1 => BubbleTuning(
          level: 1,
          device: device,
          targetPops: 8,
          findPops: 3,
          roundSeconds: 45,
          minDiameter: 120 * f,
          maxDiameter: 176 * f,
          crossSlowSec: 20,
          crossFastSec: 14,
          maxAlive: switch (device) {
            BubbleDeviceClass.phone => 2,
            BubbleDeviceClass.tabletS => 3,
            BubbleDeviceClass.tabletL => 4,
          },
          spawnMinMs: 900,
          spawnMaxMs: 1500,
          swayMin: 10,
          swayMax: 16,
          hitSlop: 28,
          praiseEvery: 3,
          idleHintSec: 4,
          missesToCurious: 2,
          minHold: pop * 0.7,
          popDuration: pop * 1.2,
        ),
      2 => BubbleTuning(
          level: 2,
          device: device,
          targetPops: 12,
          findPops: 4,
          roundSeconds: 50,
          minDiameter: 104 * f,
          maxDiameter: 160 * f,
          crossSlowSec: 15,
          crossFastSec: 10,
          maxAlive: switch (device) {
            BubbleDeviceClass.phone => 3,
            BubbleDeviceClass.tabletS => 4,
            BubbleDeviceClass.tabletL => 5,
          },
          spawnMinMs: 800,
          spawnMaxMs: 1300,
          swayMin: 14,
          swayMax: 24,
          hitSlop: 20,
          praiseEvery: 4,
          idleHintSec: 5,
          missesToCurious: 3,
          minHold: pop * 0.5,
          popDuration: pop,
        ),
      _ => BubbleTuning(
          level: 3,
          device: device,
          targetPops: 20,
          findPops: 6,
          roundSeconds: 60,
          minDiameter: 88 * f,
          maxDiameter: 144 * f,
          crossSlowSec: 12,
          crossFastSec: 7,
          maxAlive: switch (device) {
            BubbleDeviceClass.phone => 3,
            BubbleDeviceClass.tabletS => 5,
            BubbleDeviceClass.tabletL => 6,
          },
          spawnMinMs: device == BubbleDeviceClass.tabletL ? 500 : 600,
          spawnMaxMs: device == BubbleDeviceClass.tabletL ? 900 : 1100,
          swayMin: 18,
          swayMax: 32,
          hitSlop: 12,
          praiseEvery: 5,
          idleHintSec: 6,
          missesToCurious: 3,
          minHold: pop * 0.4,
          popDuration: pop * 0.9,
        ),
    };
  }
}

/// Where Bloom sits in the play area, and where bubbles may be born.
abstract final class BubbleStage {
  /// Bloom's offsets from the play area's right and bottom edges (spec
  /// §2; the body already sits inside the safe area).
  static const double bloomInsetRight = DT.sp16;
  static const double bloomInsetBottom = DT.sp24;

  /// How far a spawn prefers to stay from Bloom's box, so a bubble does
  /// not slide out from under his ears. A preference — see
  /// [spawnAnchorX] — not a boundary.
  static const double bloomMargin = DT.sp24;

  static Rect bloomRect(Size body, BubbleDeviceClass device) {
    final s = device.bloomSize;
    return Rect.fromLTWH(
      body.width - bloomInsetRight - s,
      body.height - bloomInsetBottom - s,
      s,
      s,
    );
  }

  /// How far apart two anchors are kept while both bubbles are still low
  /// on the screen (spec §3: `size/2 + 24 dp`), and how many tries that
  /// gets before the spawn happens anyway — a round must never stall
  /// because the sky is crowded.
  static const double spreadMargin = DT.sp24;
  static const int spreadAttempts = 4;

  /// Anchor X for a new bubble of [size] swinging ±[amplitude].
  ///
  /// The whole floor, not a lane. This used to hard-clamp every spawn to
  /// the left of Bloom's column, which on a 390 dp phone left a band of
  /// about 90 dp: every bubble rose out of the same spot, and a child
  /// aiming at one hit its neighbour. Bloom is painted *under* the
  /// bubbles anyway, so passing over him costs nothing.
  ///
  /// What is left is a preference, not a wall: a few re-rolls try to find
  /// an X that is both clear of his box and not on top of a bubble still
  /// low on the screen (two bubbles born together read as one object).
  /// Whatever the last roll gives is accepted — a round must never stall
  /// because the sky is crowded.
  static double spawnAnchorX({
    required Random rng,
    required double width,
    required double size,
    required double amplitude,
    required Rect bloom,
    List<double> avoid = const [],
  }) {
    final half = size / 2 + amplitude;
    final minX = half;
    final maxX = width - half;
    if (maxX <= minX) return width / 2;

    final keep = size / 2 + spreadMargin;
    bool clearOfBloom(double x) =>
        x + half <= bloom.left - bloomMargin ||
        x - half >= bloom.right + bloomMargin;
    bool clearOfOthers(double x) =>
        avoid.every((other) => (other - x).abs() >= keep);

    var x = minX + rng.nextDouble() * (maxX - minX);
    for (var i = 0; i < spreadAttempts; i++) {
      if (clearOfBloom(x) && clearOfOthers(x)) break;
      x = minX + rng.nextDouble() * (maxX - minX);
    }
    return x;
  }
}

// Excluded packs (apply to both modes): phrase/verse/babble packs (shared
// PackModel.nonWordPackIds) plus virtual / seasonal.
bool _isExcludedPack(PackModel p) {
  if (p.id.startsWith('_')) return true;
  if (p.id.startsWith('seasonal_')) return true;
  if (PackModel.nonWordPackIds.contains(p.id)) return true;
  return false;
}

/// How many different pictures «Знайди бульбашку» needs before it is a
/// game and not the same card again: six keeps two targets in a row
/// visibly different even in a small catalogue.
const int _kMinFindTargets = 6;

/// Rim colours: six saturated accents (spec §3), distinct enough for the
/// future "collect the yellow ones" mode. `DT.pink` is left out — too hot.
const _kRims = <Color>[
  DT.coral,
  DT.sky,
  DT.mint,
  DT.sunBurst,
  DT.violet,
  DT.peach,
];

// ─────────────────────────────────────────────
//  The narrator's queue (spec §3)
// ─────────────────────────────────────────────

/// One card's turn to be said, and whether it has come yet.
///
/// The revealed card holds until [started] flips, so the picture a child
/// is looking at is always the picture they are hearing. [dropped] means a
/// newer pop replaced this one in the queue — its card finishes the
/// animation silently rather than waiting for a word that will never come.
class BubbleWord {
  BubbleWord(this.card);

  final CardModel card;
  final ValueNotifier<bool> started = ValueNotifier(false);
  final ValueNotifier<bool> dropped = ValueNotifier(false);

  void dispose() {
    started.dispose();
    dropped.dispose();
  }
}

/// A queue of depth one over the narrator.
///
/// `playWordOnly` calls `stop()`, so before this a second pop inside a
/// second cut the first word in half and the child heard two beginnings
/// (spec §3). The rule instead:
///
///  * the channel is free → the word plays after [cue], the 80 ms that
///    keep the pop transient off the first consonant (this is a speech
///    therapy app);
///  * the channel is busy → the card becomes *the* pending one; a third
///    pop replaces it, and the replaced card finishes silently;
///  * when the narrator falls quiet, the pending word starts.
///
/// [maxWait] is the safety net: a card with no recording never makes
/// `isSpeaking` true at all, and the queue must not hang on it.
class BubbleWordQueue {
  BubbleWordQueue({
    required this.speaking,
    required this.play,
    required this.cue,
    required this.maxWait,
  }) {
    speaking.addListener(_onSpeaking);
  }

  final ValueListenable<bool> speaking;
  final void Function(CardModel card) play;
  final Duration cue;
  final Duration maxWait;

  Timer? _cueTimer;
  Timer? _guard;
  BubbleWord? _current;
  BubbleWord? _pending;
  bool _disposed = false;

  /// Whether a word is on its way to the speaker or coming out of it.
  bool get busy => _current != null;

  /// Test seam: the word waiting for the channel, if any.
  @visibleForTesting
  BubbleWord? get pending => _pending;

  /// Ask for [card]'s word. The returned ticket tells the reveal when the
  /// picture and the voice are together.
  BubbleWord say(CardModel card) {
    final word = BubbleWord(card);
    if (_disposed) {
      word.dropped.value = true;
      return word;
    }
    if (busy) {
      _pending?.dropped.value = true;
      _pending = word;
      return word;
    }
    _start(word);
    return word;
  }

  void _start(BubbleWord word) {
    _current = word;
    _cueTimer?.cancel();
    _cueTimer = Timer(cue, () {
      _cueTimer = null;
      if (_disposed || _current != word) return;
      play(word.card);
      word.started.value = true;
      // The narrator may take a moment to report itself speaking (and a
      // card without a recording never will) — hold the channel for the
      // grace of one cue, then let [maxWait] end it if nothing speaks.
      _guard?.cancel();
      _guard = Timer(maxWait, () => _finish(word));
    });
  }

  void _onSpeaking() {
    if (_disposed || speaking.value) return;
    final word = _current;
    // Only a word that has actually started can be finished by silence;
    // before that, `speaking == false` is just the channel being free.
    if (word != null && word.started.value) _finish(word);
  }

  void _finish(BubbleWord word) {
    if (_current != word) return;
    _guard?.cancel();
    _guard = null;
    _current = null;
    final next = _pending;
    _pending = null;
    if (next != null && !_disposed) _start(next);
  }

  /// Forget everything without playing it — a new round, or the screen
  /// going away mid-word.
  void clear() {
    _cueTimer?.cancel();
    _cueTimer = null;
    _guard?.cancel();
    _guard = null;
    _pending?.dropped.value = true;
    _pending = null;
    _current = null;
  }

  void dispose() {
    _disposed = true;
    clear();
    speaking.removeListener(_onSpeaking);
  }
}

// ─────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────

class _LiveBubble {
  final int id;
  final CardModel card;
  final double size;
  final Color tint;
  final double velocityY; // px/sec, positive = up
  final double driftPhase; // sine offset
  final double driftAmplitude; // sideways swing in pixels
  final double driftPeriodMs; // ms per full sideways oscillation
  final double anchorX; // x around which the sideways drift oscillates
  final int bornAtMs;
  double posX;
  double posY;

  /// Spawn settle, 0 → 1 over [DTMotion.bubbleSpawn]; 1 from the first
  /// frame when the level (L3+) or reduced motion skips the arrival.
  double spawnT;

  /// Idle-hint wiggle-glow, 0 → 1 over [DTMotion.bloomPoint]; `null` when
  /// this bubble is not the one Bloom is pointing at.
  double? hintT;

  bool get isHinted => hintT != null;

  _LiveBubble({
    required this.id,
    required this.card,
    required this.size,
    required this.tint,
    required this.velocityY,
    required this.driftPhase,
    required this.driftAmplitude,
    required this.driftPeriodMs,
    required this.anchorX,
    required this.bornAtMs,
    required this.posX,
    required this.posY,
    required this.spawnT,
  });
}

class _PopRequest {
  final int id; // matches the live bubble id (recycled OK — local to round)
  final CardModel card;
  final double size;
  final Color tint;
  final double posX;
  final double posY;

  /// Where the revealed card sits relative to the burst: the card is
  /// bigger than the bubble, so its centre is nudged back inside the play
  /// area when the bubble popped near an edge or under the top bar (§3).
  final Offset cardShift;

  /// This pop's place in the narrator's queue; `null` for a cascade pop
  /// at the end of a round, which is a sound and not a lesson.
  final BubbleWord? word;

  const _PopRequest({
    required this.id,
    required this.card,
    required this.size,
    required this.tint,
    required this.posX,
    required this.posY,
    this.cardShift = Offset.zero,
    this.word,
  });
}

class _RippleRequest {
  final int id;
  final Offset at;
  const _RippleRequest({required this.id, required this.at});
}

// ─────────────────────────────────────────────
//  Screen state
// ─────────────────────────────────────────────

class _BubblePopScreenState extends ConsumerState<BubblePopScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Bumped once per ticker frame. Nothing *rebuilds* on it: the bubble
  /// layer is a [Flow] whose delegate repaints from it, so a frame costs
  /// one paint of one layer instead of a Stack rebuilt 60 times a second.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// Bumped when the cast changes — a bubble born, popped or gone over
  /// the top edge, or the hint moving to another one. This is the only
  /// thing that rebuilds the bubble layer's children (~1/s).
  final ValueNotifier<int> _population = ValueNotifier(0);
  Duration _lastTick = Duration.zero;

  final Random _rng = Random();
  BubbleMode _mode = BubbleMode.all;

  // Cards usable for the current mode (cached on round build).
  List<CardModel> _pool = const [];
  // Shuffled draw order over [_pool] — a card can't repeat until the whole
  // pool has been shown once (refilled + reshuffled when exhausted).
  final List<CardModel> _deck = [];

  // Live, on-screen bubbles still floating.
  final List<_LiveBubble> _live = [];
  // Currently animating pop requests. Each maps 1-to-1 to a `_PoppingBubble`
  // widget which manages its own AnimationController and removes itself via
  // [_onPopComplete].
  final List<_PopRequest> _popping = [];
  // Ripples of taps into empty sky; ≤ [_maxRipples] at once.
  final List<_RippleRequest> _ripples = [];
  static const _maxRipples = 4;

  int _nextBubbleId = 1;
  int _nextRippleId = 1;

  /// The counter under the pill: pops in [BubbleMode.all] / [tricky],
  /// finds in [BubbleMode.find].
  int _popped = 0;

  /// Calibration aggregates of the round (spec §5, wave 3.3): every
  /// bubble that burst under a finger, every tap that hit nothing, and
  /// when the first pop happened. Nothing here identifies anybody — they
  /// leave as four numbers on `game_complete`, the same class of data as
  /// the score that has always been sent, and they answer one question:
  /// is this level's bubble big enough and slow enough for these hands.
  int _pops = 0;
  int _misses = 0;
  int? _firstPopMs;

  // ── «Знайди бульбашку» (§5) ─────────────────
  /// The card on Bloom's sign. Exactly one live bubble carries its
  /// picture; every other bubble is still a word and still pops.
  CardModel? _target;

  /// Cards the target may be drawn from: one per illustration (the same
  /// picture lives in several packs), drawn from [SemanticGroup]s where
  /// the catalogue has enough of them, so two targets in a row are two
  /// visibly different things.
  List<CardModel> _targetPool = const [];

  /// Bumped on every change of [_target] — the sign turns over on it.
  int _targetSeq = 0;

  /// Names the first target only after the spoken instruction has had
  /// its say, so the two voices never overlap.
  Timer? _introTimer;

  // ── Misses in a row (§2, wave 3.2) ──────────
  /// Misses inside the current [DTMotion.bubbleMissWindow], the clock of
  /// the last one, and how many such runs this round has had — the first
  /// run gets Bloom's `curious`, the next ones get his pointing paw.
  int _missRun = 0;
  int _lastMissMs = 0;
  int _noticedMissRuns = 0;

  /// Praise currently on screen, and a sequence number so two cheers in a
  /// row restart the animation instead of reusing the same element.
  String? _praise;
  int _praiseSeq = 0;
  int _lastPraiseIndex = -1;

  int _elapsedMs = 0;

  /// The ticker's own clock — the time base of the sideways drift.
  int _nowMs = 0;
  int _msSinceSpawn = 0;
  int _spawnIntervalMs = 900;
  bool _ended = false;

  /// Idle clock for Bloom's hint (spec §2): milliseconds since the last
  /// touch of any kind, how many hints this round has had, and whether
  /// the spoken instruction has already been repeated (once per round).
  int _msSinceTouch = 0;
  int _hints = 0;
  bool _instructionRepeated = false;

  /// Elapsed ticker time of the last bubble blown out of Bloom's wand —
  /// the 1.5 s rate limit of §2.
  int? _lastWandMs;

  /// The closing cascade: every live bubble pops left to right, then the
  /// shared celebration card comes up.
  Timer? _cascadeTimer;
  bool _finale = false;

  /// The narrator's queue (§3). Depth one: the child hears whole words.
  late final BubbleWordQueue _words = BubbleWordQueue(
    speaking: AudioService.instance.isSpeaking,
    play: (card) =>
        AudioService.instance.playWordOnly(card.audioKey, card.sound),
    cue: DT.motion.instant,
    maxWait: DT.motion.bubbleWordWait,
  );

  /// Tablets lock the orientation for the round (spec §9): a device that
  /// flips mid-round throws every bubble to a new place. Phones are
  /// portrait-only from `main.dart` and must stay that way, so the lock —
  /// and the restore — only ever happen on a tablet.
  bool _orientationLocked = false;

  /// The shared overlay is up; the in-scene Bloom fades so there is one
  /// Bloom on screen (bloom_character.md §4.2).
  bool _celebrating = false;
  Timer? _celebrationTimer;

  /// Pitch of the previous pop — the next one must differ (spec §4).
  double? _lastPopPitch;
  Color? _lastTint;

  // Cached at build because we ticker-update without [setState].
  Size? _screenSize;
  BubbleDeviceClass _device = BubbleDeviceClass.phone;
  BubbleTuning _tuning =
      BubbleTuning.forLevel(2, BubbleDeviceClass.phone);
  bool _reduce = false;

  /// Whether the physics ticker may run. Off under `MotionMode.test` only:
  /// the drift is the game, not decoration, so OS reduce-motion keeps it —
  /// but a ticker that never stops would hang `pumpAndSettle` in every
  /// widget test that touches this screen.
  bool _physics = true;

  /// This screen's stage in Bloom's brain; left in [dispose]. Resolved
  /// once in [initState]: `ref` is already closed by the time `dispose`
  /// runs, and the stage must still be handed back.
  final Object _bloomScene = Object();
  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _ticker = createTicker(_onTick);
    _bloom.sceneEntered(_bloomScene, BloomScene.bubbles);
    // Start once the first frame layout is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'bubbles',
        isEn: ref.read(languageProvider) == 'en',
      );
      _startRound();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockOrientation();
  }

  /// Freeze the orientation the round started in. Only on tablets: on a
  /// phone the app is portrait-only already, and restoring
  /// [DeviceOrientation.values] there would hand a toddler a landscape
  /// layout no phone screen of this app is built for.
  void _lockOrientation() {
    if (_orientationLocked) return;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 600) return;
    _orientationLocked = true;
    SystemChrome.setPreferredOrientations(
      size.width >= size.height
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  @override
  void dispose() {
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _celebrationTimer?.cancel();
    _cascadeTimer?.cancel();
    _introTimer?.cancel();
    _words.dispose();
    _bloom.sceneLeft(_bloomScene);
    _ticker.stop();
    _ticker.dispose();
    _frame.dispose();
    _population.dispose();
    super.dispose();
  }

  // ── Round lifecycle ───────────────────────────

  /// [silent] — the quiet restart after a round with no pops (spec §5):
  /// same deck, no analytics, no snack; the child was only watching.
  void _startRound({BubbleMode? mode, bool silent = false}) {
    var newMode = mode ?? _mode;
    var pool = _buildPool(newMode);
    final level = ref.read(profileProvider).active?.level ?? 2;
    final tuning = BubbleTuning.forLevel(level, _device);
    final isEn = ref.read(languageProvider) == 'en';

    // Tricky mode fallback when not enough material yet.
    if (newMode == BubbleMode.tricky && pool.length < 5) {
      newMode = BubbleMode.all;
      pool = _buildPool(BubbleMode.all);
      if (!silent) {
        _showSnack(AppS(isEn)(
          'Замало складних слів — переходимо до всіх слів',
          'Not enough tricky words yet — switching to all words',
        ));
      }
    }

    // Find mode needs enough *different pictures* to keep changing the
    // sign; without them the honest thing is free popping, not a round
    // that shows the same cat three times.
    var targets = const <CardModel>[];
    if (newMode == BubbleMode.find) {
      targets = _findTargets(pool);
      if (targets.length < _kMinFindTargets) {
        newMode = BubbleMode.all;
        targets = const [];
        if (!silent) {
          _showSnack(AppS(isEn)(
            'Замало різних карток — просто лопаємо бульбашки',
            'Not enough different cards yet — just popping bubbles',
          ));
        }
      }
    }

    setState(() {
      _mode = newMode;
      // One bubble per illustration. The same picture lives in several
      // packs under different card ids, so a bag that only avoided
      // repeating an *id* floated the same rocket four times in one round
      // — a child does not see ids. With 400+ pictures there is no reason
      // to ever show one twice.
      _pool = _byPicture(pool);
      _targetPool = targets;
      _tuning = tuning;
    });

    _cascadeTimer?.cancel();
    _introTimer?.cancel();
    _introTimer = null;
    _words.clear();
    _live.clear();
    _popping.clear();
    _ripples.clear();
    _deck.clear();
    _popped = 0;
    _pops = 0;
    _misses = 0;
    _firstPopMs = null;
    _missRun = 0;
    _lastMissMs = 0;
    _noticedMissRuns = 0;
    _target = null;
    _praise = null;
    _elapsedMs = 0;
    _msSinceSpawn = 0;
    _msSinceTouch = 0;
    _hints = 0;
    _instructionRepeated = false;
    _lastWandMs = null;
    _ended = false;
    _finale = false;
    _celebrating = false;
    _lastPopPitch = null;
    _spawnIntervalMs = _randomSpawnInterval();
    _lastTick = Duration.zero;
    _population.value++;

    if (!silent) {
      AnalyticsService.instance.logGameStart('bubble_pop_${_mode.name}');
    }

    if (_mode == BubbleMode.find) _nextTarget(announce: !silent, delayed: true);

    // Pre-seed two bubbles mid-screen so the round doesn't open on an empty
    // sky — the first bottom spawn otherwise takes several seconds to drift
    // into view. Screen size is known: _startRound runs post-first-frame.
    final screen = _screenSize;
    if (screen != null) {
      _spawnBubble(0, screen, startYFactor: 0.55);
      _spawnBubble(0, screen, startYFactor: 0.8);
    }

    if (_physics && !_ticker.isActive) _ticker.start();
  }

  /// Stops physics; on a natural finish the sky empties in a cascade while
  /// Bloom cheers on the grass, and only then does the shared celebration
  /// card come up (spec §6). [earlyExit] — the X — takes none of it.
  void _endRound({bool earlyExit = false}) {
    if (_ended) return;
    _ended = true;
    _ticker.stop();
    _words.clear();
    _praise = null;

    if (earlyExit) {
      _live.clear();
      setState(() {});
      return;
    }

    // Quest + analytics only on natural completion.
    ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
    // Calibration (spec §5): how many of the taps found a bubble, and how
    // long the first one took. Aggregates of this round only.
    final taps = _pops + _misses;
    AnalyticsService.instance.logGameComplete(
      'bubble_pop_${_mode.name}',
      _popped,
      hitRate: taps == 0 ? 0 : _pops / taps,
      timeToFirstPopMs: _firstPopMs,
      level: _tuning.level,
      deviceClass: _device.name,
    );
    // Bloom's three hops on the grass and the confetti from his corner;
    // the shared card (tada + praise, "again" pill) follows once the
    // cheer has landed.
    _bloom.success(BloomSuccessTier.round);
    _finale = true;
    final cascade = _startCascade();
    _celebrationTimer?.cancel();
    _celebrationTimer = Timer(
      _reduce ? Duration.zero : cascade + DT.motion.bloomCheer,
      _showCelebration,
    );
    setState(() {});
  }

  /// Pops every bubble still in the sky, left to right, pitch falling
  /// 1.35 → 0.85 — no words, no droplets, just the sky emptying. Returns
  /// how long the cascade will take.
  Duration _startCascade() {
    final left = List.of(_live)..sort((a, b) => a.posX.compareTo(b.posX));
    _live.clear();
    _population.value++;
    if (left.isEmpty) return Duration.zero;
    final step = _reduce ? Duration.zero : DT.motion.bubbleCascade;

    void burst(int i) {
      if (!mounted || i >= left.length) return;
      final b = left[i];
      final k = left.length == 1 ? 0.0 : i / (left.length - 1);
      FeedbackService.instance.event(
        FeedbackEvent.bubblePop,
        pitch: 1.35 - 0.5 * k,
        haptic: false, // one hand-felt bump per finger, not per bubble
      );
      setState(() => _popping.add(_popRequestFor(b)));
      if (i + 1 < left.length) {
        _cascadeTimer = Timer(step, () => burst(i + 1));
      } else {
        _cascadeTimer = null;
      }
    }

    burst(0);
    return step * left.length;
  }

  void _showCelebration() {
    _celebrationTimer = null;
    if (!mounted) return;
    setState(() => _celebrating = true);
    final s = AppS(ref.read(languageProvider) == 'en');
    // No subtitle with the count: the shared card carries no scores, and
    // the child has already seen the number in the pill.
    celebrate(
      context,
      tier: CelebrationTier.round,
      isEn: s.isEn,
      childName: _childName,
      onAgain: () => _startRound(mode: _mode),
      onDone: () => Navigator.of(context).pop(),
    );
  }

  // ── Pool building ─────────────────────────────

  List<CardModel> _buildPool(BubbleMode mode) {
    final packs = ref.read(packsProvider).valueOrNull ?? const <PackModel>[];

    // Cards must have BOTH recorded audio (so playWordOnly is real) and a
    // webp illustration (because the bubble renders the image, not emoji).
    bool isPlayable(CardModel c) => c.audioKey != null && c.image != null;

    final allowedPacks =
        packs.where((p) => !p.isLocked && !_isExcludedPack(p)).toList();

    // Find plays over the same open catalogue as free popping; only the
    // *targets* are chosen with more care (see [_findTargets]).
    if (mode != BubbleMode.tricky) {
      return allowedPacks.expand((p) => p.cards).where(isPlayable).toList();
    }

    // Tricky: union of weak words + SRS due, mapped back to CardModel via
    // the same allowed-pack filter.
    final mistakes = ref
        .read(weakWordsProvider.notifier)
        .topMistakes(20)
        .map((e) => e.key);
    final due = ref.read(srsProvider).dueIds;
    final ids = <String>{...mistakes, ...due};

    final allowedCards =
        allowedPacks.expand((p) => p.cards).where(isPlayable).toList();
    final byId = {for (final c in allowedCards) c.id: c};
    return ids.map((id) => byId[id]).whereType<CardModel>().toList();
  }

  // ── «Знайди бульбашку»: the target (§5) ───────

  /// The cards the sign may show, one per illustration.
  ///
  /// The same picture appears in several packs under several ids, and two
  /// of them in the sky at once would make the question unanswerable — so
  /// the pool is keyed by [CardModel.image], exactly like
  /// [SemanticGroup]s are.
  ///
  /// Where the open catalogue has enough of them, targets come only from
  /// curated groups (animals, food, things that drive…). That is not
  /// about the category: it is that those pictures are the ones a child
  /// can name and point at, and belonging to a group is what lets the
  /// next target be *visibly* different from the last one
  /// ([SemanticGroups.contrast]). When the catalogue is thin — one small
  /// free pack — every distinct picture is fair game.
  List<CardModel> _findTargets(List<CardModel> pool) {
    final byImage = <String, CardModel>{};
    for (final card in pool) {
      final image = card.image;
      if (image != null) byImage.putIfAbsent(image, () => card);
    }
    final all = byImage.values.toList();
    final grouped = [
      for (final card in all)
        if (SemanticGroups.of(card) != null) card,
    ];
    return grouped.length >= _kMinFindTargets ? grouped : all;
  }

  /// Whether [card] is the thing on the sign. By picture, not by id: two
  /// packs share the illustration and the child sees only the picture.
  bool _isTarget(CardModel card) {
    final target = _target;
    return target != null && card.image == target.image;
  }

  /// Turn the sign over to the next thing to find.
  ///
  /// Never the same picture twice running, and — when the groups are
  /// there — never a picture the last one could be confused with: a cat
  /// then a dog is a change of word, not a change of task.
  ///
  /// [announce] says the new word; [delayed] holds it back until the
  /// round's spoken instruction has finished (start of a round only).
  void _nextTarget({bool announce = true, bool delayed = false}) {
    if (_targetPool.isEmpty) return;
    final prev = _target;
    final prevGroup = prev == null ? null : SemanticGroups.of(prev);
    final fresh = [
      for (final c in _targetPool)
        if (c.image != prev?.image) c,
    ];
    final pool = fresh.isEmpty ? _targetPool : fresh;
    final contrasting = prevGroup == null
        ? const <CardModel>[]
        : [
            for (final c in pool)
              if (SemanticGroups.of(c) case final g?
                  when SemanticGroups.contrast(prevGroup, g))
                c,
          ];
    final from = contrasting.isEmpty ? pool : contrasting;

    _target = from[_rng.nextInt(from.length)];
    _targetSeq++;
    if (!announce) return;
    _introTimer?.cancel();
    if (delayed) {
      _introTimer = Timer(DT.motion.bubbleFindIntro, () {
        _introTimer = null;
        if (mounted && !_ended) _sayTarget();
      });
    } else {
      _sayTarget();
    }
  }

  /// Say the word on the sign. Through the same queue as a pop, so it
  /// waits its turn instead of cutting the word of the bubble that has
  /// just burst.
  void _sayTarget() {
    final target = _target;
    if (target != null) _words.say(target);
  }

  // ── Ticker ─────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_ended) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    final dt = dtMs / 1000.0; // seconds

    _elapsedMs += dtMs.round();
    _msSinceSpawn += dtMs.round();
    _msSinceTouch += dtMs.round();

    final size = _screenSize;
    if (size == null) return;

    final nowMs = elapsed.inMilliseconds;
    _nowMs = nowMs;
    var cast = false; // whether the bubble layer needs new children

    // Spawn?
    if (_live.length < _tuning.maxAlive && _msSinceSpawn >= _spawnIntervalMs) {
      _msSinceSpawn = 0;
      _spawnIntervalMs = _randomSpawnInterval();
      _spawnBubble(nowMs, size);
      cast = true;
    }

    // Update positions, cull off-top. A bubble that escapes has no
    // consequence — no sound, no lost progress (spec §5).
    for (int i = _live.length - 1; i >= 0; i--) {
      final b = _live[i];
      b.posY -= b.velocityY * dt;
      // Position-based sine: posX = anchorX + sin(t) * amplitude. Computing
      // position directly (vs adding velocity*dt of a sin) avoids cumulative
      // drift and frame-rate-dependent jitter — bubble traces a clean wave.
      final age = nowMs - b.bornAtMs;
      final phase = age / b.driftPeriodMs * 2 * pi + b.driftPhase;
      b.posX = b.anchorX + sin(phase) * b.driftAmplitude;

      // Keep it within horizontal bounds (soft clamp so it doesn't escape).
      final minX = b.size / 2;
      final maxX = size.width - b.size / 2;
      if (b.posX < minX) b.posX = minX;
      if (b.posX > maxX) b.posX = maxX;

      // Arrival (spec §2.7) and the hint's wiggle-glow: both are plain
      // 0 → 1 clocks the Flow delegate reads, so nothing rebuilds.
      if (b.spawnT < 1) {
        b.spawnT =
            min(1.0, b.spawnT + dtMs / DT.motion.bubbleSpawn.inMilliseconds);
      }
      final hint = b.hintT;
      if (hint != null) {
        final next = hint + dtMs / DT.motion.bloomPoint.inMilliseconds;
        if (next >= 1) {
          b.hintT = null;
          cast = true;
        } else {
          b.hintT = next;
        }
      }

      if (b.posY + b.size < 0) {
        _live.removeAt(i);
        cast = true;
      }
    }

    // Idle: Bloom points at the biggest bubble and it wiggles (spec §2).
    if (_msSinceTouch >= _idleHintGapMs) {
      _msSinceTouch = 0;
      if (_giveHint()) cast = true;
    }

    if (cast) _population.value++;

    // End conditions.
    if (_popped >= _goal) {
      _endRound();
      return;
    }
    if (_elapsedMs >= _tuning.roundSeconds * 1000) {
      if (_popped == 0) {
        // The child only watched: no celebration, no interruption — the
        // same round starts over, until a parent taps X.
        _startRound(mode: _mode, silent: true);
      } else {
        _endRound();
      }
      return;
    }

    // Repaint only the bubble layer (see ListenableBuilder in build) —
    // a full-screen setState per frame kept the whole tree rebuilding
    // at 60fps on the old tablets this app targets.
    _frame.value++;
  }

  /// What ends the round: pops, or finds in [BubbleMode.find].
  int get _goal => _tuning.goalFor(_mode);

  int _randomSpawnInterval() => _tuning.spawnMinMs +
      _rng.nextInt(_tuning.spawnMaxMs - _tuning.spawnMinMs);

  /// Time without a touch before the (first / next) hint: the tuning
  /// table for the first one, then every 8 s (spec §2).
  int get _idleHintGapMs => _hints == 0
      ? _tuning.idleHintSec * 1000
      : DT.motion.bubbleHintRepeat.inMilliseconds;

  /// Bloom waves a paw towards the biggest bubble in the sky and that
  /// bubble wiggles and glows. The second hint of a round also repeats
  /// the spoken instruction — once per round, never again.
  ///
  /// Returns whether the cast of the bubble layer changed.
  bool _giveHint() {
    if (_ended || _live.isEmpty) return false;
    final target = _live.reduce((a, b) => b.size > a.size ? b : a);
    _hints++;
    for (final b in _live) {
      b.hintT = b.id == target.id ? 0.0 : null;
    }
    final body = _screenSize;
    if (body != null) {
      final bloom = BubbleStage.bloomRect(body, _device).center;
      // From Bloom towards the bubble, in his own -1..1 space.
      _bloom.pointAt(Alignment(
        ((target.posX - bloom.dx) / (body.width / 2)).clamp(-1.0, 1.0),
        ((target.posY - bloom.dy) / (body.height / 2)).clamp(-1.0, 1.0),
      ));
    }
    if (_mode == BubbleMode.find) {
      // The sign already says what to look for; the reminder is its word.
      _sayTarget();
      return true;
    }
    if (_hints >= 2 && !_instructionRepeated) {
      _instructionRepeated = true;
      AudioService.instance.playInstruction(
        'bubbles',
        isEn: ref.read(languageProvider) == 'en',
      );
    }
    return true;
  }

  /// A tap on Bloom: one bubble leaves the wand (spec §2). The hop and
  /// the giggle are his own — `BloomMascot` reports the tap to his brain —
  /// so this adds only the thing the child made happen in the sky.
  /// One per [DTMotion.bubbleWand], and never more than one bubble over
  /// the level's limit.
  void _blowFromWand() {
    _msSinceTouch = 0;
    if (_ended) return;
    final body = _screenSize;
    if (body == null || _pool.isEmpty) return;
    if (_live.length >= _tuning.maxAlive + 1) return;
    final now = _elapsedMs;
    final last = _lastWandMs;
    if (last != null && now - last < DT.motion.bubbleWand.inMilliseconds) {
      return;
    }
    _lastWandMs = now;
    final bloom = BubbleStage.bloomRect(body, _device);
    _spawnBubble(
      _nowMs,
      body,
      at: Offset(bloom.left + bloom.width * 0.1, bloom.top),
    );
    _population.value++;
  }

  /// One card per illustration, keeping the first of each picture. Cards
  /// without art keep their own identity — they have nothing to repeat.
  static List<CardModel> _byPicture(List<CardModel> cards) {
    final seen = <String>{};
    return [
      for (final c in cards)
        if (c.image == null || seen.add(c.image!)) c,
    ];
  }

  /// Next card from the shuffle-bag: no repeats until [_pool] is exhausted.
  CardModel _drawCard() {
    if (_deck.isEmpty) {
      _deck
        ..addAll(_pool)
        ..shuffle(_rng);
    }
    // After a reshuffle a card still floating on screen could come up again
    // immediately — skip it when there is an alternative (matters for the
    // small tricky-mode pools; with 200+ cards this never triggers).
    final liveIds = {for (final b in _live) b.card.id};
    // In find mode the target enters the sky only when [_spawnBubble]
    // asks for it by name: drawing it here as well could put two of the
    // same picture up at once, and then there is no right bubble.
    final blocked = _mode == BubbleMode.find ? _target?.image : null;
    var idx = _deck.lastIndexWhere(
      (c) => !liveIds.contains(c.id) && (blocked == null || c.image != blocked),
    );
    if (idx < 0 && blocked != null) {
      idx = _deck.lastIndexWhere((c) => c.image != blocked);
    }
    return idx >= 0 ? _deck.removeAt(idx) : _deck.removeLast();
  }

  Color _nextTint() {
    var tint = _kRims[_rng.nextInt(_kRims.length)];
    if (tint == _lastTint) tint = _kRims[(_kRims.indexOf(tint) + 1) % _kRims.length];
    _lastTint = tint;
    return tint;
  }

  /// [startYFactor] places the bubble at a fraction of screen height instead
  /// of just below the bottom edge — used to pre-seed the round start.
  /// [at] puts it at an exact point: the ring of Bloom's wand.
  void _spawnBubble(
    int nowMs,
    Size screen, {
    double? startYFactor,
    Offset? at,
  }) {
    if (_pool.isEmpty) return;
    final t = _tuning;
    final card = _findCardToSpawn() ?? _drawCard();
    final size = t.minDiameter + _rng.nextDouble() * (t.maxDiameter - t.minDiameter);
    // Bigger bubble → slower: the crossing time interpolates between the
    // small/fast and large/slow ends of the table, and the velocity is
    // whatever crosses this play area in that time.
    final k = (size - t.minDiameter) / (t.maxDiameter - t.minDiameter); // 0..1
    final crossSec = t.crossFastSec + k * (t.crossSlowSec - t.crossFastSec);
    final velY = screen.height / crossSec;
    final tint = _nextTint();
    final phase = _rng.nextDouble() * 2 * pi;
    // Gentle sideways sway, 2.4–3.6 s per full cycle: slow enough for a
    // toddler eye to track without nausea.
    final amplitude = t.swayMin + _rng.nextDouble() * (t.swayMax - t.swayMin);
    final periodMs = 2400.0 + _rng.nextDouble() * 1200.0;

    final anchor = at?.dx ??
        BubbleStage.spawnAnchorX(
          rng: _rng,
          width: screen.width,
          size: size,
          amplitude: amplitude,
          bloom: BubbleStage.bloomRect(screen, _device),
          // Only the bubbles still low on the screen crowd a newborn.
          avoid: [
            for (final b in _live)
              if (b.posY > screen.height * 0.7) b.anchorX,
          ],
        );
    // Default: start just below the visible area.
    final posY = at?.dy ??
        (startYFactor != null
            ? screen.height * startYFactor
            : screen.height + size);

    // The arrival is worth seeing for the youngest two levels; L3+ play
    // fast enough that a bubble growing in would be one more thing to
    // wait for. Reduced motion keeps the fade only (handled in paint).
    _live.add(_LiveBubble(
      id: _nextBubbleId++,
      card: card,
      size: size,
      tint: tint,
      velocityY: velY,
      driftPhase: phase,
      driftAmplitude: amplitude,
      driftPeriodMs: periodMs,
      anchorX: anchor,
      bornAtMs: nowMs,
      posX: anchor,
      posY: posY,
      spawnT: t.level >= 3 ? 1.0 : 0.0,
    ));
    _precacheDeck();
  }

  /// The target, when this spawn is the one that must carry it.
  ///
  /// §5 allows it to arrive by the second spawn after the sign turns
  /// over; it takes the first, because "second" is not a promise the sky
  /// can keep. Bubbles stop being born once [BubbleTuning.maxAlive] are
  /// up, and at L3 one takes seven to twelve seconds to cross — so a
  /// spawn that passed the target over could be followed by no spawn at
  /// all, and a three-year-old would be searching a sky that has nothing
  /// to find in it. Null in every other mode, and whenever the target is
  /// already up there.
  CardModel? _findCardToSpawn() {
    if (_mode != BubbleMode.find) return null;
    final target = _target;
    if (target == null) return null;
    return _live.any((b) => _isTarget(b.card)) ? null : target;
  }

  /// Warm the next two cards of the deck so a new bubble never shows the
  /// emoji stand-in for a frame. Only what is actually on the device:
  /// precaching an asset still inside an undelivered Play pack throws,
  /// and `precacheImage` hands that to `FlutterError.onError` — which
  /// `main.dart` files as a fatal crash.
  void _precacheDeck() {
    if (!mounted) return;
    for (var i = 0; i < 2 && i < _deck.length; i++) {
      CardImage.precache(context, _deck[_deck.length - 1 - i]);
    }
  }

  // ── Pop interaction ───────────────────────────

  /// Pop pitch by size (spec §4): smallest → 1.35, largest → 0.85, ±0.05
  /// jitter, and never within 0.06 of the previous pop so a run of pops
  /// is a little tune rather than one sound.
  double _pitchFor(double size) {
    final t = _tuning;
    final span = t.maxDiameter - t.minDiameter;
    final k = span <= 0 ? 0.5 : ((size - t.minDiameter) / span).clamp(0.0, 1.0);
    var p = 1.35 - 0.5 * k + (_rng.nextDouble() * 2 - 1) * 0.05;
    final last = _lastPopPitch;
    if (last != null && (p - last).abs() < 0.06) {
      p += p <= last ? -0.1 : 0.1;
    }
    p = p.clamp(0.8, 1.4);
    _lastPopPitch = p;
    return p;
  }

  /// The revealed card is bigger than the bubble it came out of: nudge it
  /// back inside the play area so its top never hides under the top bar
  /// and its sides stay 16 dp in (spec §3).
  Offset _cardShift(double size, double posX, double posY) {
    final body = _screenSize;
    if (body == null) return Offset.zero;
    final w = size * _CardInside.widthFactor * _CardInside.peakScale;
    final h = w * _CardInside.cardAspect;
    final minX = w / 2 + DT.sp16;
    final maxX = body.width - w / 2 - DT.sp16;
    final minY = h / 2 + DT.sp8;
    final maxY = body.height - h / 2 - DT.sp8;
    final cx = maxX >= minX ? posX.clamp(minX, maxX) : body.width / 2;
    final cy = maxY >= minY ? posY.clamp(minY, maxY) : body.height / 2;
    return Offset(cx - posX, cy - posY);
  }

  _PopRequest _popRequestFor(_LiveBubble b, {BubbleWord? word}) => _PopRequest(
        id: b.id,
        card: b.card,
        size: b.size,
        tint: b.tint,
        posX: b.posX,
        posY: b.posY,
        cardShift: _cardShift(b.size, b.posX, b.posY),
        word: word,
      );

  void _popBubble(_LiveBubble b) {
    if (_ended) return;
    if (!_live.any((x) => x.id == b.id)) return; // two fingers, one bubble

    // Pop + medium bump on pointer-down, then the word — through the
    // queue, so a fast run of pops is whole words and not beginnings.
    final found = _isTarget(b.card);
    FeedbackService.instance.event(
      FeedbackEvent.bubblePop,
      pitch: _pitchFor(b.size),
    );
    // The thing on the sign: one warm note over the pop. The hand has
    // already been answered by the pop's own bump.
    if (found) {
      FeedbackService.instance.event(FeedbackEvent.correct, haptic: false);
    }
    final word = _words.say(b.card);
    _msSinceTouch = 0;
    // A pop is a hand that works: whatever run of misses was building up
    // is over, and the calibration counters take note.
    _missRun = 0;
    _pops++;
    _firstPopMs ??= _elapsedMs;
    // Bloom hops with the child (spec §2). His own debounce keeps a hop
    // already in the air from restarting, so three pops a second on L3
    // read as one happy rabbit and not a shiver.
    _bloom.success(BloomSuccessTier.micro);

    // In find mode the counter belongs to the sign. A bubble that was
    // not the one still pops, still says its word and still teaches —
    // the child simply keeps looking (audit п. 23: no punishment, and
    // nothing taken away).
    final counts = _mode != BubbleMode.find || found;

    setState(() {
      _live.removeWhere((x) => x.id == b.id);
      _population.value++;
      _popping.add(_popRequestFor(b, word: word));
      if (counts) _popped++;
      // The last pop hands over to the celebration; cheering underneath
      // it would just be two rewards fighting for the screen.
      if (counts &&
          _popped % _tuning.praiseBeatFor(_mode) == 0 &&
          _popped < _goal) {
        _showPraise();
      }
    });

    // The sign turns over to the next thing, and names it — after the
    // word of the bubble just popped, through the same queue.
    if (found && _popped < _goal) _nextTarget();

    // End-of-round check on tap (don't wait for the next ticker frame —
    // feels more responsive when the last pop ends the game immediately).
    if (_popped >= _goal) {
      _endRound();
    }
  }

  /// Picks a cheer, never the same one twice running. Bloom cheers at the
  /// same beat — one source of praise, two channels (spec §6).
  void _showPraise() {
    final s = AppS(ref.read(languageProvider) == 'en');
    final words = s.isEn
        ? const ['Yay!', 'Great!', 'Nice!', 'Cool!', 'Wow!', 'More!']
        : const ['Молодець!', 'Ура!', 'Клас!', 'Круто!', 'Вау!', 'Ще!'];
    var i = _rng.nextInt(words.length);
    if (i == _lastPraiseIndex) i = (i + 1) % words.length;
    _lastPraiseIndex = i;
    _praise = words[i];
    _praiseSeq++;
    _bloom.praised();
  }

  void _onPopComplete(int id) {
    if (!mounted) return;
    setState(() => _popping.removeWhere((p) => p.id == id));
  }

  // ── Miss ──────────────────────────────────────

  /// A tap into empty sky: a ripple at the finger, a soft sound and a
  /// click. Nothing is judged; the counter does not move (spec §5).
  void _onMiss(Offset at, Rect bloom) {
    if (_ended) return;
    // Bloom's own hit zone sits above this layer; belt and braces.
    if (bloom.contains(at)) return;
    // A miss is still the child being here: it resets the idle clock.
    _msSinceTouch = 0;
    _misses++;
    _noteMissRun();
    FeedbackService.instance.event(FeedbackEvent.emptyTap);
    if (_reduce) return;
    setState(() {
      if (_ripples.length >= _maxRipples) _ripples.removeAt(0);
      _ripples.add(_RippleRequest(id: _nextRippleId++, at: at));
    });
  }

  /// A run of misses inside [DTMotion.bubbleMissWindow] (spec §2, §5:
  /// two for a one-year-old, three from two years up).
  ///
  /// One miss earns nothing — a toddler's finger lands next to things all
  /// day. A run of them means the child is trying and not getting there,
  /// and the answer is help, not judgement: Bloom tilts his head
  /// (`curious`) and the biggest bubble in the sky wiggles and glows.
  /// Should the run repeat, he stops wondering and points.
  void _noteMissRun() {
    if (_elapsedMs - _lastMissMs >
        DT.motion.bubbleMissWindow.inMilliseconds) {
      _missRun = 0;
    }
    _lastMissMs = _elapsedMs;
    _missRun++;
    if (_missRun < _tuning.missesToCurious) return;
    _missRun = 0;
    _noticedMissRuns++;
    _hintBiggest();
  }

  /// Bloom notices, and the biggest bubble answers for itself. Shares the
  /// wiggle-glow of the idle hint but not its clock: this one is about
  /// aim, not about waiting, so it does not repeat the instruction and
  /// does not count as an idle hint.
  void _hintBiggest() {
    if (_ended || _live.isEmpty) return;
    final target = _live.reduce((a, b) => b.size > a.size ? b : a);
    for (final b in _live) {
      b.hintT = b.id == target.id ? 0.0 : null;
    }
    _population.value++;
    final body = _screenSize;
    if (body != null) {
      final bloom = BubbleStage.bloomRect(body, _device).center;
      // Give his brain the direction first: the second run of misses is
      // a pointed paw, and a paw needs somewhere to point.
      _bloom.hintTargetChanged(Alignment(
        ((target.posX - bloom.dx) / (body.width / 2)).clamp(-1.0, 1.0),
        ((target.posY - bloom.dy) / (body.height / 2)).clamp(-1.0, 1.0),
      ));
    }
    // First run of the round → `curious`; the ones after → the paw.
    _bloom.miss(_noticedMissRuns);
  }

  /// The finger is down and travelling: pop whatever it passes through.
  /// Same hit zone as a tap (diameter + slop) and the same [_popBubble],
  /// so a wiped bubble is a pop in every way — word, sound, counter.
  /// One bubble per move event: two bubbles that overlap under one finger
  /// are two separate answers, a frame apart.
  void _onWipe(PointerMoveEvent e) {
    if (_ended || _tuning.level > 1 || _live.isEmpty) return;
    final at = e.localPosition;
    for (final b in List.of(_live)) {
      final reach = b.size / 2 + _tuning.hitSlop;
      if ((Offset(b.posX, b.posY) - at).distanceSquared <= reach * reach) {
        _popBubble(b);
        return;
      }
    }
  }

  void _onRippleDone(int id) {
    if (!mounted) return;
    setState(() => _ripples.removeWhere((r) => r.id == id));
  }

  // ── UI ────────────────────────────────────────

  void _showSnack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    _reduce = policy.reduce;
    _physics = policy.mode != MotionMode.test;
    _device = BubbleDeviceClass.of(MediaQuery.sizeOf(context).shortestSide);

    // Shell: close top-left (the shell's drawn X, not a Material glyph),
    // the water tube in the title slot, the count on the right as the one
    // piece of text a three-year-old can already read. The shell's own
    // 8 dp pill is off: a tube in the header keeps all three controls on
    // one line and off the sky (spec §8, 2.9).
    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      title: _ProgressTube(value: (_popped / _goal).clamp(0.0, 1.0)),
      trailing: KidCountPill(label: '$_popped/$_goal'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cache layout for the ticker. The box is the play area under the
          // shell's header, so bubbles no longer drift under the controls.
          final body = Size(constraints.maxWidth, constraints.maxHeight);
          _screenSize = body;
          final bloomRect = BubbleStage.bloomRect(body, _device);
          final slop = _tuning.hitSlop;

          return Stack(
            children: [
              // Miss detector: everything the bubbles and Bloom do not
              // catch lands here.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onMiss(e.localPosition, bloomRect),
                ),
              ),

              for (final r in _ripples)
                Positioned(
                  key: ValueKey('ripple_${r.id}'),
                  left: r.at.dx - _Ripple.extent / 2,
                  top: r.at.dy - _Ripple.extent / 2,
                  width: _Ripple.extent,
                  height: _Ripple.extent,
                  child: IgnorePointer(
                    child: _Ripple(onDone: () => _onRippleDone(r.id)),
                  ),
                ),

              // Bloom on the grass, under the bubbles. Interactive: the
              // tap hops and giggles (through his brain) and blows one
              // more bubble out of the wand — it never navigates. The
              // Listener sits outside the mascot's own gesture, so both
              // answers happen on the same touch.
              Positioned.fromRect(
                rect: bloomRect,
                child: AnimatedOpacity(
                  opacity: _celebrating ? 0 : 1,
                  duration: policy.dur(DT.motion.bloomFade),
                  child: Listener(
                    onPointerDown: (_) => _blowFromWand(),
                    child: BloomMascot(
                      size: bloomRect.width,
                      semanticsLabel: 'Bloom',
                    ),
                  ),
                ),
              ),

              // The sign Bloom holds up: the thing to find, as a picture
              // (rule 4 — a two-word label would be for the parent, not
              // for the child). It sits over his head, out of the flight
              // zone, and under the bubbles like he is. A tap on it says
              // the word again and is not a miss.
              if (_target case final target? when _mode == BubbleMode.find)
                Positioned.fromRect(
                  key: const ValueKey('find_sign'),
                  rect: _TargetSign.rectFor(body, bloomRect, _device),
                  child: AnimatedOpacity(
                    opacity: _celebrating || _finale ? 0 : 1,
                    duration: policy.dur(DT.motion.bloomFade),
                    child: _TargetSign(
                      card: target,
                      seq: _targetSeq,
                      onTap: _sayTarget,
                    ),
                  ),
                ),

              // Live bubbles. The children change when the cast does
              // (~1/s); the positions are a repaint of one Flow layer per
              // frame, and each bubble is its own RepaintBoundary, so the
              // glass rasterises once and the compositor only moves it.
              // Hit zone = diameter + 2·slop; the glass is drawn centred.
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _population,
                  builder: (_, _) {
                    final cast = List.of(_live);
                    if (cast.isEmpty) return const SizedBox.shrink();
                    return Flow(
                      delegate: _BubbleFlowDelegate(
                        bubbles: cast,
                        slop: slop,
                        reduce: _reduce,
                        repaint: _frame,
                      ),
                      children: [
                        for (final b in cast)
                          RepaintBoundary(
                            key: ValueKey('bubble_${b.id}'),
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (_) => _popBubble(b),
                              child: Padding(
                                padding: EdgeInsets.all(slop),
                                child: _BubbleGlass(
                                  card: b.card,
                                  tint: b.tint,
                                  rimWidth: _device.rimWidth,
                                  highlight: b.isHinted,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Wiping (spec 3.5, rule 3 — forgiving input). A
              // one-year-old does not tap, they sweep: the finger lands
              // somewhere and travels, and every bubble it goes through
              // bursts. Translucent, so a pointer-down still reaches the
              // bubble underneath and nothing about tapping changes.
              if (_tuning.level <= 1)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerMove: _onWipe,
                  ),
                ),

              // Popping bubbles (own animation controllers).
              for (final p in _popping)
                Positioned(
                  left: p.posX - p.size / 2,
                  top: p.posY - p.size / 2,
                  width: p.size,
                  height: p.size,
                  child: IgnorePointer(
                    child: _PoppingBubble(
                      key: ValueKey(p.id),
                      request: p,
                      tuning: _tuning,
                      reduce: _reduce,
                      onComplete: () => _onPopComplete(p.id),
                    ),
                  ),
                ),

              // The round's last beat: confetti out of Bloom's corner
              // while he cheers, before the shared card arrives.
              if (_finale && !_celebrating)
                Positioned.fill(
                  child: ConfettiBurst(origin: bloomRect.center),
                ),

              // Praise: Bloom's line, rising from over his head. Above the
              // bubbles so it reads, below the celebration overlay, and
              // IgnorePointer inside so it never swallows a bubble tap.
              if (_praise case final praise? when !_ended)
                Positioned.fill(
                  child: _PraiseFlash(
                    key: ValueKey(_praiseSeq),
                    text: praise,
                    color: DT.brand,
                    anchor: Offset(bloomRect.center.dx, bloomRect.top + DT.sp4),
                    tablet: _device.isTablet,
                    reduce: _reduce,
                    onDone: () {
                      if (mounted) setState(() => _praise = null);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String get _childName {
    final p = ref.read(profileProvider).active;
    final isEn = ref.read(languageProvider) == 'en';
    final fallback = isEn ? 'Kiddo' : 'Малюк';
    final n = p?.name.trim();
    return (n == null || n.isEmpty) ? fallback : n;
  }
}

// ─────────────────────────────────────────────
//  Scene (spec §1) — code-drawn v1
// ─────────────────────────────────────────────

/// Sky + clouds + meadow, painted once per size inside a `RepaintBoundary`
/// so the compositor only copies the layer while the bubbles move above.
///
/// v1 is code-drawn as a placeholder in the watercolour spirit of the
/// cards. When the art lands, the layers become assets in
/// `assets/images/scene/` (add the directory to `pubspec.yaml`; bundled,
/// never in `pad_content`):
///  * L1 `paper_tile.webp` — `ImageRepeat.repeat` at 7 % over the sky;
///  * L2 `bubble_clouds.webp` — `BoxFit.fitWidth`, pinned under the top
///    bar, ≤ 35 % of the height;
///  * L3 `bubble_meadow.webp` 3072×640 — `BoxFit.cover`,
///    `Alignment.bottomCenter`, in a box `max(0.23·H, 150 dp)` tall.
/// Each with an `errorBuilder` falling back to what this painter draws.
// ─────────────────────────────────────────────
//  The bubble layer (spec §3, "performance")
// ─────────────────────────────────────────────

/// Places every live bubble by matrix instead of by `Positioned`.
///
/// The list is the round's own [_LiveBubble] objects: the ticker mutates
/// their `posX/posY/spawnT/hintT` and bumps `repaint`, so a frame is one
/// paint of one layer — no build, no layout, no 60-per-second Stack. The
/// children only change when a bubble is born or leaves.
class _BubbleFlowDelegate extends FlowDelegate {
  _BubbleFlowDelegate({
    required this.bubbles,
    required this.slop,
    required this.reduce,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_LiveBubble> bubbles;
  final double slop;
  final bool reduce;

  /// Turns of the hint wiggle, and how far it leans.
  static const double _wiggleTurns = 3;
  static const double _wiggleAngle = 0.06;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(bubbles[i].size + 2 * slop));

  @override
  void paintChildren(FlowPaintingContext context) {
    for (var i = 0; i < context.childCount && i < bubbles.length; i++) {
      final b = bubbles[i];
      final box = context.getChildSize(i) ?? Size.square(b.size + 2 * slop);
      final t = b.spawnT;

      // Arrival: 0.6 → 1.08 → 1.0 with a fade (spec §3). Reduced motion
      // keeps the fade only — the bubble still has to be seen arriving,
      // it just does not spring.
      final scale = (reduce || t >= 1)
          ? 1.0
          : 0.6 + 0.4 * Curves.elasticOut.transform(t);
      final fade = t >= 1
          ? 1.0
          : (reduce ? t : min(1.0, t / 0.4));

      final hint = b.hintT;
      final wiggle = (hint == null || reduce)
          ? 0.0
          : sin(hint * _wiggleTurns * 2 * pi) * _wiggleAngle * (1 - hint);

      final m = Matrix4.identity()
        ..translateByDouble(
          b.posX - box.width / 2,
          b.posY - box.height / 2,
          0,
          1,
        )
        ..translateByDouble(box.width / 2, box.height / 2, 0, 1)
        ..rotateZ(wiggle)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-box.width / 2, -box.height / 2, 0, 1);
      context.paintChild(i, transform: m, opacity: fade);
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleFlowDelegate old) =>
      old.bubbles != bubbles || old.slop != slop || old.reduce != reduce;
}

// ─────────────────────────────────────────────
//  The sign over Bloom's head (spec §5, «Знайди бульбашку»)
// ─────────────────────────────────────────────

/// What to look for, held up over Bloom: the card itself, 72×96 dp on a
/// phone and 96×128 on a tablet, cover-cropped like the bubbles so the
/// picture on the sign and the picture in the sky are the same picture.
///
/// No caption. A three-year-old does not read, and the word is already
/// spoken — by Bloom when the sign turns over, by the idle hint, and by
/// a tap on the sign itself (rule 4, rule 2).
class _TargetSign extends StatelessWidget {
  const _TargetSign({
    required this.card,
    required this.seq,
    required this.onTap,
  });

  final CardModel card;

  /// Bumped on every change of target: the sign turns over on it.
  final int seq;
  final VoidCallback onTap;

  /// Sign width by device; the height is [_CardInside.cardAspect] of it.
  static double widthFor(BubbleDeviceClass device) =>
      device == BubbleDeviceClass.phone ? 72 : 96;

  /// Where the sign hangs: centred over [bloom], its foot [DT.sp8] above
  /// his ears, kept inside the play area on both sides.
  static Rect rectFor(Size body, Rect bloom, BubbleDeviceClass device) {
    final w = widthFor(device);
    final h = w * _CardInside.cardAspect;
    final left =
        (bloom.center.dx - w / 2).clamp(DT.sp8, max(DT.sp8, body.width - w - DT.sp8));
    final top = max(DT.sp8, bloom.top - DT.sp8 - h);
    return Rect.fromLTWH(left.toDouble(), top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final flip = MotionPolicy.of(context).dur(DT.motion.bubbleSignFlip);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.sp12),
          border: Border.all(color: DT.surfaceWhite, width: 3),
          boxShadow: DT.shadowSoft(DT.brand),
        ),
        child: ClipRRect(
          // The white border is the frame: the picture is clipped just
          // inside it.
          borderRadius: BorderRadius.circular(DT.sp12 - 3),
          child: AnimatedSwitcher(
            duration: flip,
            switchInCurve: DT.motion.standard,
            switchOutCurve: DT.motion.standard,
            transitionBuilder: (child, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, inner) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1 - animation.value) * pi / 2),
                child: inner,
              ),
              child: child,
            ),
            child: CardImage.forCard(
              card,
              key: ValueKey(seq),
              fit: BoxFit.cover,
              alignment: _BubbleGlass.artAlignment,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bubble glass (spec §3)
// ─────────────────────────────────────────────

/// A card illustration filling the whole circle (`BoxFit.cover`), glass
/// on top: a feather that melts the picture into the rim, the rim itself,
/// a white "edge of glass", two highlights and a soft shadow.
class _BubbleGlass extends StatelessWidget {
  final CardModel card;
  final Color tint;
  final double rimWidth;

  /// Bloom is pointing at this one (idle hint, spec §2): the rim thickens
  /// and the glass glows. The wiggle is the layer's job; the glow is the
  /// whole hint under reduced motion.
  final bool highlight;

  const _BubbleGlass({
    required this.card,
    required this.tint,
    required this.rimWidth,
    this.highlight = false,
  });

  /// The subjects of the cards sit a little above centre.
  static const artAlignment = Alignment(0, -0.1);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          if (highlight)
            BoxShadow(
              color: DT.surfaceWhite.withValues(alpha: 0.9),
              blurRadius: 18,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Only CardImage may draw a card (architecture test): it copes
            // with art that is still downloading or missing.
            CardImage.forCard(
              card,
              fit: BoxFit.cover,
              alignment: artAlignment,
              padding: EdgeInsets.zero,
            ),
            // Feather: the picture dissolves into the glass near the rim,
            // so it reads as "inside the ball" without a mask.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    tint.withValues(alpha: 0.0),
                    tint.withValues(alpha: 0.0),
                    tint.withValues(alpha: 0.30),
                    tint.withValues(alpha: 0.70),
                  ],
                  stops: const [0.0, 0.62, 0.86, 1.0],
                ),
              ),
            ),
            CustomPaint(
              painter: _GlassPainter(
                tint: tint,
                rimWidth: highlight ? rimWidth * 1.6 : rimWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rim, inner white edge, the two highlights.
class _GlassPainter extends CustomPainter {
  final Color tint;
  final double rimWidth;

  const _GlassPainter({required this.tint, required this.rimWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.shortestSide;
    final r = d / 2;
    final c = size.center(Offset.zero);

    // Rim — the one high-contrast element in the sky.
    canvas.drawCircle(
      c,
      r - rimWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..color = tint.withValues(alpha: 0.95),
    );
    // Edge of glass just inside the rim.
    canvas.drawCircle(
      c,
      r - rimWidth - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = DT.surfaceWhite.withValues(alpha: 0.60),
    );

    // Main highlight: an ellipse 28 % × 16 % of the diameter, upper left,
    // tilted −35°, soft edge through a radial gradient (no blur).
    canvas.save();
    canvas.translate(c.dx - 0.45 * r, c.dy - 0.5 * r);
    canvas.rotate(-35 * pi / 180);
    final hi = Rect.fromCenter(center: Offset.zero, width: 0.28 * d, height: 0.16 * d);
    canvas.drawOval(
      hi,
      Paint()
        ..shader = RadialGradient(
          colors: [
            DT.surfaceWhite.withValues(alpha: 0.75),
            DT.surfaceWhite.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 1.0],
        ).createShader(hi),
    );
    canvas.restore();

    // Second, smaller highlight lower right.
    canvas.drawCircle(
      c + Offset(0.55 * r, 0.6 * r),
      0.04 * d,
      Paint()..color = DT.surfaceWhite.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) =>
      old.tint != tint || old.rimWidth != rimWidth;
}

// ─────────────────────────────────────────────
//  Popping bubble — owns its own AnimationController
// ─────────────────────────────────────────────

/// Timeline (fractions of [BubbleTuning.popDuration], spec §3):
///  * 0–0.06 — squash: glass scaleX 1.10 / scaleY 0.90 (tension);
///  * 0.06–0.20 — the glass ring scales 1 → 1.6 and fades; droplets fly
///    out radially and drop a little; a white ring thins out to nothing;
///  * 0–0.40 — the card grows in (elastic), holds with a soft lift, and
///    in the last 20 % shrinks to 0.85 and fades in place.
/// Reduced motion: no droplets, no rings; the glass is gone in the first
/// 12 %; the card appears at full size, holds, fades.
class _PoppingBubble extends StatefulWidget {
  final _PopRequest request;
  final BubbleTuning tuning;
  final bool reduce;
  final VoidCallback onComplete;

  const _PoppingBubble({
    super.key,
    required this.request,
    required this.tuning,
    required this.reduce,
    required this.onComplete,
  });

  @override
  State<_PoppingBubble> createState() => _PoppingBubbleState();
}

class _PoppingBubbleState extends State<_PoppingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // Pre-computed droplet directions, randomly jittered.
  late final List<double> _dropletAngles;

  static const _squashEnd = 0.06;
  static const _burstEnd = 0.20;
  static const _ringEnd = 0.30;

  /// Which of the two holds has already been taken.
  bool _waitedForWord = false;
  bool _waitedMinHold = false;
  Timer? _holdCap;
  VoidCallback? _resume;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final n = widget.tuning.device.droplets;
    _dropletAngles = List.generate(n, (i) {
      final base = i * (2 * pi / n);
      return base + (rng.nextDouble() - 0.5) * 0.3;
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.tuning.popDuration,
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      })
      ..addListener(_hold)
      ..forward();
  }

  /// The picture waits for its word (spec §3): when the reveal has landed
  /// and the queue has not reached this card yet, the card simply stays —
  /// a child never sees one card while hearing another. The cap is
  /// [DTMotion.bubbleWordWait]; a card whose word was replaced in the
  /// queue finishes silently and on time.
  ///
  /// The second hold is [BubbleTuning.minHold]: the youngest children get
  /// the picture for longer than the animation alone would give it.
  void _hold() {
    if (widget.reduce || _resume != null) return;
    final t = _ctrl.value;
    if (!_waitedForWord && t >= _CardInside.holdStart) {
      _waitedForWord = true;
      final word = widget.request.word;
      if (word != null && !word.started.value && !word.dropped.value) {
        _pause(DT.motion.bubbleWordWait, until: [word.started, word.dropped]);
        return;
      }
    }
    if (!_waitedMinHold && t >= _CardInside.exitStart) {
      _waitedMinHold = true;
      final shown = widget.tuning.popDuration *
          (_CardInside.exitStart - _CardInside.holdStart);
      final owed = widget.tuning.minHold - shown;
      if (owed > Duration.zero) _pause(owed);
    }
  }

  void _pause(Duration cap, {List<ValueListenable<bool>> until = const []}) {
    _ctrl.stop();
    late final VoidCallback resume;
    resume = () {
      if (_resume == null) return;
      _resume = null;
      for (final l in until) {
        l.removeListener(resume);
      }
      _holdCap?.cancel();
      _holdCap = null;
      if (mounted) _ctrl.forward();
    };

    _resume = resume;
    for (final l in until) {
      l.addListener(resume);
    }
    _holdCap = Timer(cap, resume);
  }

  @override
  void dispose() {
    _holdCap?.cancel();
    final word = widget.request.word;
    final resume = _resume;
    if (word != null && resume != null) {
      word.started.removeListener(resume);
      word.dropped.removeListener(resume);
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final rim = widget.tuning.device.rimWidth;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        if (widget.reduce) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (t < 0.12)
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - t / 0.12).clamp(0.0, 1.0),
                    child: _BubbleGlass(card: req.card, tint: req.tint, rimWidth: rim),
                  ),
                ),
              _CardInside(
                card: req.card,
                boxSize: req.size,
                t: t,
                shift: req.cardShift,
                reduce: true,
              ),
            ],
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Squash, then burst.
            if (t < _squashEnd)
              Positioned.fill(
                child: Transform.scale(
                  scaleX: 1 + 0.10 * (t / _squashEnd),
                  scaleY: 1 - 0.10 * (t / _squashEnd),
                  child: _BubbleGlass(card: req.card, tint: req.tint, rimWidth: rim),
                ),
              )
            else if (t < _burstEnd)
              _RimBurst(
                tint: req.tint,
                rimWidth: rim,
                t: (t - _squashEnd) / (_burstEnd - _squashEnd),
              ),
            if (t >= _squashEnd && t < _ringEnd)
              _WhiteRing(t: (t - _squashEnd) / (_ringEnd - _squashEnd)),
            if (t >= _squashEnd && t < _burstEnd)
              ..._buildDroplets(
                req: req,
                dropT: (t - _squashEnd) / (_burstEnd - _squashEnd),
              ),
            _CardInside(
              card: req.card,
              boxSize: req.size,
              t: t,
              shift: req.cardShift,
              reduce: false,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDroplets({
    required _PopRequest req,
    required double dropT,
  }) {
    final eased = Curves.easeOut.transform(dropT.clamp(0.0, 1.0));
    final dist = 0.55 * req.size * eased;
    final gravity = 18.0 * dropT * dropT;
    final opacity = (1 - dropT).clamp(0.0, 1.0);
    final dropSize = req.size * 0.085;
    return [
      for (final angle in _dropletAngles)
        Positioned(
          left: req.size / 2 + cos(angle) * dist - dropSize / 2,
          top: req.size / 2 + sin(angle) * dist - dropSize / 2 + gravity,
          width: dropSize,
          height: dropSize,
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: req.tint.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: req.tint.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}

/// The rim alone, scaling 1 → 1.6 and fading — the glass bursting.
class _RimBurst extends StatelessWidget {
  final Color tint;
  final double rimWidth;
  final double t; // 0..1

  const _RimBurst({required this.tint, required this.rimWidth, required this.t});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: (1.0 - t).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1.0 + 0.6 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: tint.withValues(alpha: 0.95),
                width: rimWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White ring: stroke 3 → 0, scale 1 → 1.7.
class _WhiteRing extends StatelessWidget {
  final double t; // 0..1

  const _WhiteRing({required this.t});

  @override
  Widget build(BuildContext context) {
    final stroke = 3.0 * (1 - t);
    if (stroke <= 0.1) return const SizedBox.shrink();
    return Positioned.fill(
      child: Transform.scale(
        scale: 1.0 + 0.7 * t,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: DT.surfaceWhite.withValues(alpha: 0.9 * (1 - t)),
              width: stroke,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card the bubble was carrying, revealed (spec §3).
///
/// The circle does not cross-fade into a rectangle — it *becomes* one:
/// the clip is `ShapeBorder.lerp(CircleBorder, RoundedRectangleBorder)`
/// over a box whose aspect goes 1:1 → 3:4, and the illustration hands
/// over from `cover` (the crop that made a recognisable target in flight)
/// to `contain` (the whole picture, which is the lesson). Then it holds
/// with a soft lift while the word plays, and leaves in place.
///
///   0.00..0.40 → morph + scale 1.0 → 1.25 (elasticOut)
///   0.40..0.80 → hold, lift −8 px and settle (the hold is stretched by
///                [_PoppingBubble] until the word has actually started)
///   0.80..1.00 → scale → 0.85 (easeIn) + fade, in place
///
/// Reduced motion: no morph and no spring — the whole card is simply
/// there at full size, holds, and fades.
class _CardInside extends StatelessWidget {
  final CardModel card;
  final double boxSize;
  final double t; // 0..1

  /// Keeps the card inside the play area when the bubble popped near an
  /// edge or just under the top bar.
  final Offset shift;
  final bool reduce;

  const _CardInside({
    required this.card,
    required this.boxSize,
    required this.t,
    required this.shift,
    required this.reduce,
  });

  /// Card width as a share of the bubble's diameter, its 3:4 shape, and
  /// how much bigger than the bubble it grows. [_BubblePopScreenState]
  /// reads these to clamp the reveal against the edges.
  static const double widthFactor = 0.95;
  static const double cardAspect = 4 / 3;
  static const double peakScale = 1.25;

  /// Corner radius as a share of the card's width.
  static const double _radiusFactor = 0.14;

  /// Beats of the pop, as fractions of [BubbleTuning.popDuration].
  static const double revealEnd = 0.4;
  static const double holdStart = 0.4;
  static const double exitStart = 0.8;

  @override
  Widget build(BuildContext context) {
    // How far the circle has turned into a card, 0..1.
    final morph = reduce
        ? 1.0
        : Curves.easeOut.transform((t / revealEnd).clamp(0.0, 1.0));

    double scale;
    double translateY;
    double opacity;

    if (reduce) {
      scale = peakScale;
      translateY = 0;
      opacity = t < exitStart
          ? 1.0
          : (1 - (t - exitStart) / (1 - exitStart)).clamp(0.0, 1.0);
    } else if (t < holdStart) {
      final p = (t / holdStart).clamp(0.0, 1.0);
      scale = 1.0 + (peakScale - 1.0) * Curves.elasticOut.transform(p);
      translateY = 0;
      opacity = 1;
    } else if (t < exitStart) {
      scale = peakScale;
      final p = ((t - holdStart) / (exitStart - holdStart)).clamp(0.0, 1.0);
      translateY = -8 * sin(p * pi);
      opacity = 1;
    } else {
      final p = ((t - exitStart) / (1 - exitStart)).clamp(0.0, 1.0);
      final eased = Curves.easeIn.transform(p);
      scale = peakScale - (peakScale - 0.85) * eased;
      translateY = 0;
      opacity = (1 - eased).clamp(0.0, 1.0);
    }

    // The box: a circle of the bubble's own diameter at 0, a 3:4 card at 1.
    final width = boxSize * (1 - morph * (1 - widthFactor));
    final height = boxSize * (1 + morph * (widthFactor * cardAspect - 1));

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: shift + Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: width,
                height: height,
                child: ClipPath(
                  clipper: ShapeBorderClipper(
                    shape: ShapeBorder.lerp(
                      const CircleBorder(),
                      RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(width * _radiusFactor),
                      ),
                      morph,
                    )!, // lerp of two non-null ShapeBorders is never null
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The flight crop hands over to the whole picture.
                      if (morph < 1)
                        Opacity(
                          opacity: 1 - morph,
                          child: CardImage.forCard(
                            card,
                            fit: BoxFit.cover,
                            alignment: _BubbleGlass.artAlignment,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      Opacity(
                        opacity: morph,
                        child: CardImage.forCard(
                          card,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────
//  Ripple — a tap into empty sky
// ─────────────────────────────────────────────

/// A ring growing 20 → 72 dp and fading over [DTMotion.bubbleRipple]:
/// the screen answering a touch that hit nothing.
class _Ripple extends StatefulWidget {
  final VoidCallback onDone;

  const _Ripple({required this.onDone});

  static const double extent = 72;

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DT.motion.bubbleRipple,
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _RipplePainter(Curves.easeOut.transform(_ctrl.value)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t;
  const _RipplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = 10 + (size.shortestSide / 2 - 10) * t;
    final fade = (1 - t).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r,
      Paint()..color = DT.sky.withValues(alpha: 0.15 * fade),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = DT.surfaceWhite.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

// ─────────────────────────────────────────────
//  Top bar: the progress tube
// ─────────────────────────────────────────────

/// The round's progress as a tube of water (spec §8, 2.9).
///
/// A flat bar reads as "loading" — and on an 11" tablet a full-width one
/// read as *nothing at all*. This is 12 dp of glass with water rising
/// through it and a droplet at the front of the fill, capped at 360 dp so
/// it stays an object on the shelf rather than a stripe across the sky.
/// The count pill keeps its place to the right of it.
class _ProgressTube extends StatelessWidget {
  const _ProgressTube({required this.value});

  /// 0..1.
  final double value;

  static const double height = 12;
  static const double maxWidth = 360;

  @override
  Widget build(BuildContext context) {
    final t = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Semantics(
          value: '${(t * 100).round()}%',
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: t),
            duration: MotionPolicy.of(context).dur(DT.motion.base),
            curve: DT.motion.standard,
            builder: (context, filled, _) => CustomPaint(
              painter: _TubePainter(filled),
              size: const Size(double.infinity, height),
              child: const SizedBox(height: height, width: double.infinity),
            ),
          ),
        ),
      ),
    );
  }
}

class _TubePainter extends CustomPainter {
  const _TubePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final tube = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    // Glass.
    canvas.drawRRect(tube, Paint()..color = DT.sceneSkyMid);
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = DT.surfaceWhite.withValues(alpha: 0.8),
    );
    if (t <= 0) return;

    // Water: the two blues of the scene, lit along the top edge.
    final w = size.width * t;
    final fill = Rect.fromLTWH(0, 0, w, size.height);
    canvas.save();
    canvas.clipRRect(tube);
    canvas.drawRect(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DT.sky, DT.brand],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, max(0, w - 4), size.height * 0.28),
        Radius.circular(size.height * 0.14),
      ),
      Paint()..color = DT.surfaceWhite.withValues(alpha: 0.35),
    );
    canvas.restore();

    // The droplet riding the front of the water.
    final c = Offset(w.clamp(r, size.width - r), r);
    canvas.drawCircle(c, r * 1.25, Paint()..color = DT.sky);
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DT.surfaceWhite,
    );
    canvas.drawCircle(
      c + Offset(-r * 0.3, -r * 0.35),
      r * 0.28,
      Paint()..color = DT.surfaceWhite.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _TubePainter old) => old.t != t;
}

// ─────────────────────────────────────────────
//  Praise — Bloom's line (spec §6)
// ─────────────────────────────────────────────

/// A word of praise that starts over Bloom's head (scale 0.6), pops to
/// full size in the first 150 ms, rises 100 dp (160 on a tablet) while
/// drifting 40 dp towards the centre, holds, and fades with a last lift.
/// Runs [DTMotion.bloomCheer] — the same beat as Bloom's `cheer`, so text
/// and pose are one accent. Its right edge never comes closer than 24 dp
/// to the screen edge.
///
/// Reduced motion: appears at the end position, fades in, holds, fades.
class _PraiseFlash extends StatefulWidget {
  final String text;
  final Color color;

  /// Top-centre of Bloom's head in the play area.
  final Offset anchor;
  final bool tablet;
  final bool reduce;
  final VoidCallback onDone;

  const _PraiseFlash({
    super.key,
    required this.text,
    required this.color,
    required this.anchor,
    required this.tablet,
    required this.reduce,
    required this.onDone,
  });

  @override
  State<_PraiseFlash> createState() => _PraiseFlashState();
}

class _PraiseFlashState extends State<_PraiseFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DT.motion.bloomCheer,
  )..forward().whenComplete(widget.onDone);

  /// Beats as fractions of the run: pop-in ends at 150 ms, hold until
  /// 700 ms, out by 900 ms.
  static const _inEnd = 150 / 900;
  static const _holdEnd = 700 / 900;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = widget.tablet ? 160.0 : 100.0;
    const shift = 40.0;
    // Bloom sits at the right edge; "towards the centre" is leftwards.
    const towardsCentre = -1.0;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;
          double scale;
          double fade;
          double dy;
          double dx;
          if (widget.reduce) {
            scale = 1;
            dy = -rise;
            dx = towardsCentre * shift;
            fade = t < _inEnd
                ? t / _inEnd
                : t < _holdEnd
                    ? 1
                    : 1 - (t - _holdEnd) / (1 - _holdEnd);
          } else {
            scale = t < _inEnd
                ? 0.6 + 0.4 * Curves.easeOutBack.transform(t / _inEnd)
                : 1.0;
            final travel = Curves.easeOut.transform(min(t / _holdEnd, 1.0));
            dy = -rise * travel;
            dx = towardsCentre * shift * travel;
            if (t < _holdEnd) {
              fade = 1;
            } else {
              final out = (t - _holdEnd) / (1 - _holdEnd);
              fade = 1 - out;
              dy -= 30 * out;
            }
          }
          return CustomSingleChildLayout(
            delegate: _PraiseLayout(
              anchor: widget.anchor + Offset(dx, dy),
              edge: DT.sp24,
            ),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: DT.kidFont,
            fontVariations: const [FontVariation('wght', 900)],
            fontSize: widget.tablet ? 60 : 48,
            fontWeight: FontWeight.w900,
            color: widget.color,
            shadows: const [
              Shadow(color: DT.surfaceWhite, blurRadius: 12),
              Shadow(color: DT.surfaceWhite, blurRadius: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places the praise with its bottom-centre at [anchor], clamped so it
/// stays [edge] inside the play area on both sides and never above it.
class _PraiseLayout extends SingleChildLayoutDelegate {
  final Offset anchor;
  final double edge;

  const _PraiseLayout({required this.anchor, required this.edge});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - edge - childSize.width;
    final left = (anchor.dx - childSize.width / 2)
        .clamp(min(edge, maxLeft), max(edge, maxLeft))
        .toDouble();
    final maxTop = max(0.0, size.height - childSize.height);
    final top = (anchor.dy - childSize.height).clamp(0.0, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _PraiseLayout old) =>
      old.anchor != anchor || old.edge != edge;
}
