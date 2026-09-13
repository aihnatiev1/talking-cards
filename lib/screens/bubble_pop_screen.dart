import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
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
/// Two modes — All unlocked packs vs. Tricky words (mistakes ∪ SRS-due).
/// The child entry always starts in "all words"; there is no in-game mode
/// switch (an adult control does not live in the child's play zone). Pace
/// comes from the profile: [BubbleTuning.forLevel].
class BubblePopScreen extends ConsumerStatefulWidget {
  final BubbleMode mode;

  const BubblePopScreen({super.key, this.mode = BubbleMode.all});

  @override
  ConsumerState<BubblePopScreen> createState() => _BubblePopScreenState();
}

enum BubbleMode { all, tricky }

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

  static BubbleTuning forLevel(int level, BubbleDeviceClass device) {
    final f = device.sizeFactor;
    final pop = DT.motion.bubblePop;
    return switch (level) {
      <= 1 => BubbleTuning(
          level: 1,
          device: device,
          targetPops: 8,
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

  /// The spawn zone keeps this far from Bloom's box, so a bubble is never
  /// born behind him or slides out from under his ears.
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

  /// Anchor X for a new bubble of [size] swinging ±[amplitude]: the whole
  /// swing stays inside the width and left of Bloom's column. When the
  /// screen is too narrow for that (a 320 dp phone with an L1 bubble),
  /// the width wins — the bubble may pass over Bloom rather than not
  /// exist; he is under the bubbles anyway.
  static double spawnAnchorX({
    required Random rng,
    required double width,
    required double size,
    required double amplitude,
    required Rect bloom,
  }) {
    final half = size / 2 + amplitude;
    final minX = half;
    var maxX = width - half;
    final leftOfBloom = bloom.left - bloomMargin - half;
    if (leftOfBloom > minX) maxX = min(maxX, leftOfBloom);
    if (maxX <= minX) return width / 2;
    return minX + rng.nextDouble() * (maxX - minX);
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
  });
}

class _PopRequest {
  final int id; // matches the live bubble id (recycled OK — local to round)
  final CardModel card;
  final double size;
  final Color tint;
  final double posX;
  final double posY;

  const _PopRequest({
    required this.id,
    required this.card,
    required this.size,
    required this.tint,
    required this.posX,
    required this.posY,
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

  /// Bumped once per ticker frame; only the bubble layer listens.
  final ValueNotifier<int> _frame = ValueNotifier(0);
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
  int _popped = 0;

  /// Praise currently on screen, and a sequence number so two cheers in a
  /// row restart the animation instead of reusing the same element.
  String? _praise;
  int _praiseSeq = 0;
  int _lastPraiseIndex = -1;

  int _elapsedMs = 0;
  int _msSinceSpawn = 0;
  int _spawnIntervalMs = 900;
  bool _ended = false;

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
  void dispose() {
    _celebrationTimer?.cancel();
    _bloom.sceneLeft(_bloomScene);
    _ticker.stop();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── Round lifecycle ───────────────────────────

  /// [silent] — the quiet restart after a round with no pops (spec §5):
  /// same deck, no analytics, no snack; the child was only watching.
  void _startRound({BubbleMode? mode, bool silent = false}) {
    final newMode = mode ?? _mode;
    final pool = _buildPool(newMode);
    final level = ref.read(profileProvider).active?.level ?? 2;
    final tuning = BubbleTuning.forLevel(level, _device);

    // Tricky mode fallback when not enough material yet.
    if (newMode == BubbleMode.tricky && pool.length < 5) {
      final fallback = _buildPool(BubbleMode.all);
      if (!silent) {
        _showSnack(AppS(ref.read(languageProvider) == 'en')(
          'Замало складних слів — переходимо до всіх слів',
          'Not enough tricky words yet — switching to all words',
        ));
      }
      setState(() {
        _mode = BubbleMode.all;
        _pool = fallback;
        _tuning = tuning;
      });
    } else {
      setState(() {
        _mode = newMode;
        _pool = pool;
        _tuning = tuning;
      });
    }

    _live.clear();
    _popping.clear();
    _ripples.clear();
    _deck.clear();
    _popped = 0;
    _praise = null;
    _elapsedMs = 0;
    _msSinceSpawn = 0;
    _ended = false;
    _celebrating = false;
    _lastPopPitch = null;
    _spawnIntervalMs = _randomSpawnInterval();
    _lastTick = Duration.zero;

    if (!silent) {
      AnalyticsService.instance.logGameStart('bubble_pop_${_mode.name}');
    }

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

  /// Stops physics; on a natural finish Bloom cheers in the scene, then the
  /// shared round celebration takes over (unless [earlyExit]).
  void _endRound({bool earlyExit = false}) {
    if (_ended) return;
    _ended = true;
    _ticker.stop();
    _live.clear();
    _praise = null;

    if (!earlyExit) {
      // Quest + analytics only on natural completion.
      ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
      AnalyticsService.instance
          .logGameComplete('bubble_pop_${_mode.name}', _popped);
      // Bloom's three hops on the grass first; the shared card (tada +
      // praise, "again" pill) follows once the cheer has landed.
      _bloom.success(BloomSuccessTier.round);
      _celebrationTimer?.cancel();
      _celebrationTimer = Timer(
        _reduce ? Duration.zero : DT.motion.bloomCheer + DT.motion.base,
        _showCelebration,
      );
    }

    setState(() {});
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

    if (mode == BubbleMode.all) {
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

    final size = _screenSize;
    if (size == null) return;

    final nowMs = elapsed.inMilliseconds;

    // Spawn?
    if (_live.length < _tuning.maxAlive && _msSinceSpawn >= _spawnIntervalMs) {
      _msSinceSpawn = 0;
      _spawnIntervalMs = _randomSpawnInterval();
      _spawnBubble(nowMs, size);
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

      if (b.posY + b.size < 0) {
        _live.removeAt(i);
      }
    }

    // End conditions.
    if (_popped >= _tuning.targetPops) {
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

  int _randomSpawnInterval() => _tuning.spawnMinMs +
      _rng.nextInt(_tuning.spawnMaxMs - _tuning.spawnMinMs);

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
    final idx = _deck.lastIndexWhere((c) => !liveIds.contains(c.id));
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
  void _spawnBubble(int nowMs, Size screen, {double? startYFactor}) {
    if (_pool.isEmpty) return;
    final t = _tuning;
    final card = _drawCard();
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

    final anchor = BubbleStage.spawnAnchorX(
      rng: _rng,
      width: screen.width,
      size: size,
      amplitude: amplitude,
      bloom: BubbleStage.bloomRect(screen, _device),
    );
    // Default: start just below the visible area.
    final posY = startYFactor != null
        ? screen.height * startYFactor
        : screen.height + size;

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
    ));
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

  void _popBubble(_LiveBubble b) {
    if (_ended) return;
    if (!_live.any((x) => x.id == b.id)) return; // two fingers, one bubble

    // Pop + medium bump on pointer-down, then the word — the pop never
    // cuts the narrator off (FeedbackService plays over, not through).
    FeedbackService.instance.event(
      FeedbackEvent.bubblePop,
      pitch: _pitchFor(b.size),
    );
    AudioService.instance.playWordOnly(b.card.audioKey, b.card.sound);

    setState(() {
      _live.removeWhere((x) => x.id == b.id);
      _popping.add(_PopRequest(
        id: b.id,
        card: b.card,
        size: b.size,
        tint: b.tint,
        posX: b.posX,
        posY: b.posY,
      ));
      _popped++;
      // The last pop hands over to the celebration; cheering underneath
      // it would just be two rewards fighting for the screen.
      if (_popped % _tuning.praiseEvery == 0 &&
          _popped < _tuning.targetPops) {
        _showPraise();
      }
    });

    // End-of-round check on tap (don't wait for the next ticker frame —
    // feels more responsive when the last pop ends the game immediately).
    if (_popped >= _tuning.targetPops) {
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
    FeedbackService.instance.event(FeedbackEvent.emptyTap);
    if (_reduce) return;
    setState(() {
      if (_ripples.length >= _maxRipples) _ripples.removeAt(0);
      _ripples.add(_RippleRequest(id: _nextRippleId++, at: at));
    });
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

    // Shell: close top-left, wordless fill-up pill under the header, the
    // count as the one piece of text a three-year-old can already read.
    return KidScreen.game(
      accent: DT.brand,
      background: DT.sceneSkyTop,
      progress: (_popped / _tuning.targetPops).clamp(0.0, 1.0),
      trailing: _CountPill(popped: _popped, target: _tuning.targetPops),
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
              // Scene: sky, clouds, meadow — static, rasterised once.
              const Positioned.fill(child: _BubbleScene()),

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

              // Bloom on the grass, under the bubbles. Interactive: a tap
              // hops and giggles (through his brain), never navigates.
              Positioned.fromRect(
                rect: bloomRect,
                child: AnimatedOpacity(
                  opacity: _celebrating ? 0 : 1,
                  duration: policy.dur(DT.motion.bloomFade),
                  child: BloomMascot(
                    size: bloomRect.width,
                    semanticsLabel: 'Bloom',
                  ),
                ),
              ),

              // Live bubbles — isolated in their own subtree that rebuilds
              // per ticker frame; the rest of the screen stays untouched.
              // Hit zone = diameter + 2·slop; the glass is drawn centred.
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => Stack(
                    children: [
                      for (final b in _live)
                        Positioned(
                          key: ValueKey('bubble_${b.id}'),
                          left: b.posX - b.size / 2 - slop,
                          top: b.posY - b.size / 2 - slop,
                          width: b.size + 2 * slop,
                          height: b.size + 2 * slop,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _popBubble(b),
                            child: Padding(
                              padding: EdgeInsets.all(slop),
                              child: RepaintBoundary(
                                child: _BubbleGlass(
                                  card: b.card,
                                  tint: b.tint,
                                  rimWidth: _device.rimWidth,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
class _BubbleScene extends StatelessWidget {
  const _BubbleScene();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _MeadowPainter(),
        isComplex: true,
        willChange: false,
        child: SizedBox.expand(),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  const _MeadowPainter();

  /// The meadow band: 23 % of the height, never under 150 dp.
  static double meadowHeight(double h) => max(0.23 * h, 150.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    // L0 — sky. Cool at the top, a paper-warm horizon; the warmth is the
    // only "sun" — a yellow disc would read as one more target.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DT.sceneSkyTop, DT.sceneSkyMid, DT.sceneSkyHorizon],
          stops: [0.0, 0.62, 1.0],
        ).createShader(full),
    );

    // L1 — paper grain: asset-only (see _BubbleScene). Nothing drawn.

    // L2 — three soft clouds in the upper third: white on the sky at low
    // local contrast, no outline, no face. The flight zone stays calm.
    _cloud(canvas, Offset(w * 0.18, h * 0.10), w * 0.11);
    _cloud(canvas, Offset(w * 0.72, h * 0.17), w * 0.13);
    _cloud(canvas, Offset(w * 0.46, h * 0.29), w * 0.08);

    // L3 — meadow: far hill, near hill, a shaded foreground band, a bush
    // and a handful of flower blots. Everything with colour and edge lives
    // in this bottom band; the sky above belongs to the bubbles.
    final mh = meadowHeight(h);
    final top = h - mh;

    final far = Path()
      ..moveTo(0, top + mh * 0.30)
      ..quadraticBezierTo(w * 0.5, top + mh * 0.02, w, top + mh * 0.26)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = DT.sceneGrassFar);

    final near = Path()
      ..moveTo(0, top + mh * 0.58)
      ..quadraticBezierTo(w * 0.32, top + mh * 0.28, w * 0.66, top + mh * 0.50)
      ..quadraticBezierTo(w * 0.86, top + mh * 0.62, w, top + mh * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = DT.sceneGrassNear);

    final shade = Path()
      ..moveTo(0, h - mh * 0.16)
      ..quadraticBezierTo(w * 0.5, h - mh * 0.30, w, h - mh * 0.14)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(shade, Paint()..color = DT.sceneGrassShade);

    // Bush — two tones, left of centre, away from Bloom's corner.
    final bushC = Offset(w * 0.14, top + mh * 0.66);
    final bushR = mh * 0.17;
    canvas.drawCircle(
      bushC + Offset(bushR * 0.55, bushR * 0.18),
      bushR * 0.9,
      Paint()..color = DT.sceneBushDark,
    );
    canvas.drawCircle(bushC, bushR, Paint()..color = DT.sceneBushLight);
    canvas.drawCircle(
      bushC + Offset(-bushR * 0.7, bushR * 0.3),
      bushR * 0.6,
      Paint()..color = DT.sceneBushLight,
    );

    // Flowers — colour blots without outline (spec: coral 55 %, sunBurst
    // 60 %, violet 45 %). Positions are fixed so the meadow is the same
    // meadow every round.
    final k = (mh / 150).clamp(1.0, 1.6);
    for (final f in _flowers) {
      canvas.drawCircle(
        Offset(w * f.$1, top + mh * f.$2),
        f.$4 * k,
        Paint()..color = f.$3,
      );
    }
  }

  static final _coral = DT.coral.withValues(alpha: 0.55);
  static final _sun = DT.sunBurst.withValues(alpha: 0.60);
  static final _violet = DT.violet.withValues(alpha: 0.45);

  /// (x fraction of width, y fraction of the meadow band, colour, radius).
  static final _flowers = <(double, double, Color, double)>[
    (0.06, 0.82, _coral, 6),
    (0.24, 0.90, _sun, 5),
    (0.34, 0.76, _violet, 6),
    (0.47, 0.86, _coral, 5),
    (0.58, 0.74, _sun, 7),
    (0.66, 0.92, _violet, 5),
    (0.30, 0.96, _sun, 4),
    (0.52, 0.96, _coral, 4),
  ];

  void _cloud(Canvas canvas, Offset c, double r) {
    void puff(Offset centre, double radius) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              DT.sceneCloud.withValues(alpha: 0.85),
              DT.sceneCloud.withValues(alpha: 0.0),
            ],
            stops: const [0.45, 1.0],
          ).createShader(rect),
      );
    }

    puff(c, r);
    puff(c + Offset(-r * 0.9, r * 0.25), r * 0.75);
    puff(c + Offset(r * 0.95, r * 0.2), r * 0.8);
  }

  @override
  bool shouldRepaint(covariant _MeadowPainter oldDelegate) => false;
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

  const _BubbleGlass({
    required this.card,
    required this.tint,
    required this.rimWidth,
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
            CustomPaint(painter: _GlassPainter(tint: tint, rimWidth: rimWidth)),
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
      ..forward();
  }

  @override
  void dispose() {
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
              _CardInside(card: req.card, boxSize: req.size, t: t, reduce: true),
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
            _CardInside(card: req.card, boxSize: req.size, t: t, reduce: false),
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

/// The card, whole (`contain`), for the child to see while the word plays.
///   0.00..0.40 → scale 0.7 → 1.25 (elasticOut) + tiny wobble
///   0.40..0.80 → hold at 1.25, lift −8 px and settle
///   0.80..1.00 → scale → 0.85 (easeIn) + fade, in place
class _CardInside extends StatelessWidget {
  final CardModel card;
  final double boxSize;
  final double t; // 0..1
  final bool reduce;

  const _CardInside({
    required this.card,
    required this.boxSize,
    required this.t,
    required this.reduce,
  });

  @override
  Widget build(BuildContext context) {
    double scale;
    double translateY;
    double opacity;
    double rotation;

    if (reduce) {
      scale = 1.25;
      translateY = 0;
      rotation = 0;
      opacity = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
    } else if (t < 0.4) {
      final p = (t / 0.4).clamp(0.0, 1.0);
      final eased = Curves.elasticOut.transform(p);
      scale = 0.7 + (1.25 - 0.7) * eased;
      translateY = 0;
      opacity = 1;
      rotation = sin(p * 2 * pi) * 0.05;
    } else if (t < 0.8) {
      scale = 1.25;
      final p = ((t - 0.4) / 0.4).clamp(0.0, 1.0);
      translateY = -8 * sin(p * pi);
      opacity = 1;
      rotation = 0;
    } else {
      final p = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      final eased = Curves.easeIn.transform(p);
      scale = 1.25 - (1.25 - 0.85) * eased;
      translateY = 0;
      opacity = (1 - eased).clamp(0.0, 1.0);
      rotation = 0;
    }

    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: boxSize * 0.76,
                  height: boxSize * 0.76,
                  child: CardImage.forCard(card, padding: EdgeInsets.zero),
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
//  Top bar: count pill
// ─────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  final int popped;
  final int target;

  const _CountPill({required this.popped, required this.target});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: DT.brand,
            borderRadius: BorderRadius.circular(20),
            boxShadow: DT.shadowSoft(DT.brand),
          ),
          child: Text(
            '$popped/$target',
            style: const TextStyle(
              fontFamily: DT.kidFont,
              fontVariations: [FontVariation('wght', 900)],
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
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
