import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/weak_words_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/bloom_mascot.dart';

/// Pop-It-style sensory toy:
/// bubbles drift up from the bottom, child taps to pop, the card image inside
/// zooms with an elastic curve while the recorded word audio plays.
///
/// Two modes — All unlocked packs vs. Tricky words (mistakes ∪ SRS-due).
class BubblePopScreen extends ConsumerStatefulWidget {
  const BubblePopScreen({super.key});

  @override
  ConsumerState<BubblePopScreen> createState() => _BubblePopScreenState();
}

// ─────────────────────────────────────────────
//  Modes & tuning constants
// ─────────────────────────────────────────────

enum BubbleMode { all, tricky }

const _kRoundTargetPops = 20;
const _kRoundDurationSec = 60;
const _kMaxAlive = 3;
const _kMinSpawnMs = 700;
const _kMaxSpawnMs = 1300;
const _kMinBubble = 90.0;
const _kMaxBubble = 160.0;
const _kMinVelY = 50.0; // px/sec — large bubble, slow
const _kMaxVelY = 130.0; // px/sec — small bubble, fast
const _kPopMs = 900;

// Excluded packs (apply to both modes): phrase packs and virtual / seasonal.
const _kExcludedPackIds = {
  'rozmovlyalky',
  'phrases',
  'en_phrases',
};

bool _isExcludedPack(PackModel p) {
  if (p.id.startsWith('_')) return true;
  if (p.id.startsWith('seasonal_')) return true;
  if (_kExcludedPackIds.contains(p.id)) return true;
  return false;
}

// Soft pastel palette — same family as widgets/bubble_pop.dart.
const _kBubblePalette = <Color>[
  Color(0xFFFFB7C5), // pink
  Color(0xFFB7E0FF), // sky
  Color(0xFFC9F2C7), // mint
  Color(0xFFFFE4A8), // butter
  Color(0xFFD4C5F9), // lavender
  Color(0xFFFFD0B0), // peach
];

// ─────────────────────────────────────────────
//  Live bubble (model only — rendered by widget)
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

// ─────────────────────────────────────────────
//  Pop animation data
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  Screen state
// ─────────────────────────────────────────────

class _BubblePopScreenState extends ConsumerState<BubblePopScreen>
    with
        SingleTickerProviderStateMixin,
        ConfettiOverlayMixin<BubblePopScreen> {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  final Random _rng = Random();
  BubbleMode _mode = BubbleMode.all;

  // Cards usable for the current mode (cached on round build).
  List<CardModel> _pool = const [];

  // Live, on-screen bubbles still floating.
  final List<_LiveBubble> _live = [];
  // Currently animating pop requests. Each maps 1-to-1 to a `_PoppingBubble`
  // widget which manages its own AnimationController and removes itself via
  // [_onPopComplete].
  final List<_PopRequest> _popping = [];

  int _nextBubbleId = 1;
  int _popped = 0;
  int _elapsedMs = 0;
  int _msSinceSpawn = 0;
  int _spawnIntervalMs = 900;
  bool _ended = false;
  bool _earlyExit = false; // true when user closed via X (no celebration)

  // Cached at first build because we ticker-update without [setState].
  Size? _screenSize;
  double _topPadding = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Start once the first frame layout is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startRound();
    });
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    disposeConfetti();
    super.dispose();
  }

  // ── Round lifecycle ───────────────────────────

  void _startRound({BubbleMode? mode}) {
    final newMode = mode ?? _mode;
    final pool = _buildPool(newMode);

    // Tricky mode fallback when not enough material yet.
    if (newMode == BubbleMode.tricky && pool.length < 5) {
      final fallback = _buildPool(BubbleMode.all);
      _showSnack(AppS(ref.read(languageProvider) == 'en')(
        'Замало складних слів — переходимо до всіх слів',
        'Not enough tricky words yet — switching to all words',
      ));
      setState(() {
        _mode = BubbleMode.all;
        _pool = fallback;
      });
    } else {
      setState(() {
        _mode = newMode;
        _pool = pool;
      });
    }

    _live.clear();
    _popping.clear();
    _popped = 0;
    _elapsedMs = 0;
    _msSinceSpawn = 0;
    _ended = false;
    _earlyExit = false;
    _spawnIntervalMs = _randomSpawnInterval();
    _lastTick = Duration.zero;

    AnalyticsService.instance.logGameStart('bubble_pop_${_mode.name}');

    if (!_ticker.isActive) _ticker.start();
  }

  /// Stops physics and shows the celebration overlay (unless [earlyExit]).
  void _endRound({bool earlyExit = false}) {
    if (_ended) return;
    _ended = true;
    _earlyExit = earlyExit;
    _ticker.stop();
    _live.clear();

    if (!earlyExit) {
      // Quest + analytics only on natural completion.
      ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
      AnalyticsService.instance
          .logGameComplete('bubble_pop_${_mode.name}', _popped);
      // Burst of confetti behind the celebration card.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showConfetti();
      });
    }

    setState(() {});
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
    return ids
        .map((id) => byId[id])
        .whereType<CardModel>()
        .toList();
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
    if (_live.length < _kMaxAlive && _msSinceSpawn >= _spawnIntervalMs) {
      _msSinceSpawn = 0;
      _spawnIntervalMs = _randomSpawnInterval();
      _spawnBubble(nowMs, size);
    }

    // Update positions, cull off-top.
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
    if (_popped >= _kRoundTargetPops ||
        _elapsedMs >= _kRoundDurationSec * 1000) {
      _endRound();
      return;
    }

    setState(() {}); // single rebuild per frame
  }

  int _randomSpawnInterval() =>
      _kMinSpawnMs + _rng.nextInt(_kMaxSpawnMs - _kMinSpawnMs);

  void _spawnBubble(int nowMs, Size screen) {
    if (_pool.isEmpty) return;
    final card = _pool[_rng.nextInt(_pool.length)];
    final size = _kMinBubble + _rng.nextDouble() * (_kMaxBubble - _kMinBubble);
    // Bigger bubble → slower; map size in [_kMin, _kMax] inversely to velocity.
    final t = (size - _kMinBubble) / (_kMaxBubble - _kMinBubble); // 0..1
    final velY = _kMaxVelY - t * (_kMaxVelY - _kMinVelY);
    final tint = _kBubblePalette[_rng.nextInt(_kBubblePalette.length)];
    final phase = _rng.nextDouble() * 2 * pi;
    // Gentle sideways sway: 18-32px swing, 2.4-3.6s per full cycle. Slow
    // enough for a toddler eye to track without nausea.
    final amplitude = 18.0 + _rng.nextDouble() * 14.0;
    final periodMs = 2400.0 + _rng.nextDouble() * 1200.0;

    final minX = size / 2 + amplitude;
    final maxX = screen.width - size / 2 - amplitude;
    final anchor = minX + _rng.nextDouble() * (maxX - minX);
    final posY = screen.height + size; // start just below the visible area

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

  void _onBubbleTap(_LiveBubble b) {
    if (_ended) return;

    HapticFeedback.mediumImpact();
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
    });

    // End-of-round check on tap (don't wait for the next ticker frame —
    // feels more responsive when the 20th pop ends the game immediately).
    if (_popped >= _kRoundTargetPops) {
      _endRound();
    }
  }

  void _onPopComplete(int id) {
    if (!mounted) return;
    setState(() => _popping.removeWhere((p) => p.id == id));
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
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF), // sky-water
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cache layout for the ticker.
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _topPadding = MediaQuery.of(context).padding.top;

          return Stack(
            children: [
              // Background — soft vertical gradient + subtle radial glow.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFEAF6FF),
                        Color(0xFFFFF6E5),
                      ],
                    ),
                  ),
                ),
              ),

              // Live bubbles.
              for (final b in _live)
                Positioned(
                  left: b.posX - b.size / 2,
                  top: b.posY - b.size / 2,
                  width: b.size,
                  height: b.size,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onBubbleTap(b),
                    child: _LiveBubbleVisual(bubble: b),
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
                      onComplete: () => _onPopComplete(p.id),
                    ),
                  ),
                ),

              // Top bar.
              Positioned(
                left: 0,
                right: 0,
                top: _topPadding,
                child: _TopBar(
                  isEn: isEn,
                  mode: _mode,
                  popped: _popped,
                  secondsRemaining: _secondsRemaining,
                  onClose: () => Navigator.of(context).pop(),
                  onModeChanged: (m) {
                    if (m == _mode) return;
                    _startRound(mode: m);
                  },
                ),
              ),

              // Celebration overlay.
              if (_ended && !_earlyExit)
                Positioned.fill(
                  child: _CelebrationOverlay(
                    s: s,
                    popped: _popped,
                    childName: _childName,
                    onAgain: () {
                      // Restart with the same mode.
                      _startRound(mode: _mode);
                    },
                    onDone: () => Navigator.of(context).pop(),
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

  int get _secondsRemaining {
    final left = _kRoundDurationSec - (_elapsedMs ~/ 1000);
    return left.clamp(0, _kRoundDurationSec);
  }
}

// ─────────────────────────────────────────────
//  Live bubble visual
// ─────────────────────────────────────────────

class _LiveBubbleVisual extends StatelessWidget {
  final _LiveBubble bubble;
  const _LiveBubbleVisual({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final size = bubble.size;
    final tint = bubble.tint;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            tint.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 1.0],
          center: const Alignment(-0.3, -0.3),
        ),
        border: Border.all(
          color: tint.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card image inside — the key WOW element.
          Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: bubble.card.image != null
                  ? Image.asset(
                      'assets/images/webp/${bubble.card.image}.webp',
                      fit: BoxFit.contain,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Top-left highlight dot.
          const Align(
            alignment: Alignment(-0.4, -0.4),
            child: FractionallySizedBox(
              widthFactor: 0.28,
              heightFactor: 0.28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Popping bubble — owns its own AnimationController
// ─────────────────────────────────────────────

class _PoppingBubble extends StatefulWidget {
  final _PopRequest request;
  final VoidCallback onComplete;

  const _PoppingBubble({
    super.key,
    required this.request,
    required this.onComplete,
  });

  @override
  State<_PoppingBubble> createState() => _PoppingBubbleState();
}

class _PoppingBubbleState extends State<_PoppingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // Pre-computed droplet directions (8 radial slots) — randomly jittered.
  late final List<double> _dropletAngles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _dropletAngles = List.generate(8, (i) {
      final base = i * (2 * pi / 8);
      return base + (rng.nextDouble() - 0.5) * 0.3;
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kPopMs),
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 0..0.2 — bubble glass dissolves ────────────────────────────
            if (t < 0.2)
              _BubbleGlassFade(
                size: req.size,
                tint: req.tint,
                t: t / 0.2, // 0..1
              ),

            // ── 0..0.2 — droplets fly outward ──────────────────────────────
            if (t < 0.2)
              ..._buildDroplets(req: req, dropT: t / 0.2),

            // ── 0..1.0 — card image animates through scale → hover → fade ─
            _CardInside(
              card: req.card,
              boxSize: req.size,
              t: t,
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
    final dist = 50.0 * eased;
    final opacity = (1 - dropT).clamp(0.0, 1.0);
    final dropSize = req.size * 0.08; // 8-12dp range for 90-160 bubbles
    return [
      for (final angle in _dropletAngles)
        Positioned(
          left: req.size / 2 + cos(angle) * dist - dropSize / 2,
          top: req.size / 2 + sin(angle) * dist - dropSize / 2,
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

// Bubble glass fade-out: scale 1.0 → 1.4, opacity 1 → 0.
class _BubbleGlassFade extends StatelessWidget {
  final double size;
  final Color tint;
  final double t; // 0..1
  const _BubbleGlassFade({
    required this.size,
    required this.tint,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + 0.4 * t;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  tint.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 1.0],
                center: const Alignment(-0.3, -0.3),
              ),
              border: Border.all(
                color: tint.withValues(alpha: 0.9),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Card image animation — the WOW moment.
//   0.00..0.40 → scale 0.7 → 1.4 (elasticOut) + tiny wobble
//   0.40..0.80 → hold scale 1.4 + lift -10px
//   0.80..1.00 → scale 1.4 → 0 (easeIn) + fade
class _CardInside extends StatelessWidget {
  final CardModel card;
  final double boxSize;
  final double t; // 0..1

  const _CardInside({
    required this.card,
    required this.boxSize,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    double scale;
    double translateY;
    double opacity;
    double rotation;

    if (t < 0.4) {
      final p = (t / 0.4).clamp(0.0, 1.0);
      final eased = Curves.elasticOut.transform(p);
      scale = 0.7 + (1.4 - 0.7) * eased;
      translateY = 0;
      opacity = 1;
      rotation = sin(p * 2 * pi) * 0.05;
    } else if (t < 0.8) {
      scale = 1.4;
      final p = ((t - 0.4) / 0.4).clamp(0.0, 1.0);
      // Lift up to -10px and gently settle.
      translateY = -10 * sin(p * pi);
      opacity = 1;
      rotation = 0;
    } else {
      final p = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      final eased = Curves.easeIn.transform(p);
      scale = 1.4 - 1.4 * eased;
      translateY = -10 * (1 - p);
      opacity = (1 - eased).clamp(0.0, 1.0);
      rotation = 0;
    }

    if (card.image == null) return const SizedBox.shrink();

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
                  width: boxSize * 0.64,
                  height: boxSize * 0.64,
                  child: Image.asset(
                    'assets/images/webp/${card.image}.webp',
                    fit: BoxFit.contain,
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
//  Top bar: close, mode chips, counter, timer
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isEn;
  final BubbleMode mode;
  final int popped;
  final int secondsRemaining;
  final VoidCallback onClose;
  final ValueChanged<BubbleMode> onModeChanged;

  const _TopBar({
    required this.isEn,
    required this.mode,
    required this.popped,
    required this.secondsRemaining,
    required this.onClose,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Close X.
              _TopChip(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    size: 22, color: DT.textPrimary),
              ),
              const Spacer(),
              // Counter.
              _TopPill(
                child: Text(
                  '🫧 $popped/$_kRoundTargetPops',
                  style: DT.h2.copyWith(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              // Timer.
              _TopPill(
                child: Text(
                  '⏱ $secondsRemaining',
                  style: DT.h2.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mode toggle chips, centered.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(
                label: isEn ? 'All words' : 'Всі слова',
                selected: mode == BubbleMode.all,
                onTap: () => onModeChanged(BubbleMode.all),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: isEn ? 'Tricky words' : 'Складні слова',
                selected: mode == BubbleMode.tricky,
                onTap: () => onModeChanged(BubbleMode.tricky),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TopChip({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: DT.shadowSoft(kAccent),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final Widget child;
  const _TopPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DT.shadowSoft(kAccent),
      ),
      child: child,
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kAccent : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? kAccent : kAccent.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: selected ? DT.shadowSoft(kAccent) : null,
        ),
        child: Text(
          label,
          style: DT.tileTitle.copyWith(
            fontSize: 14,
            color: selected ? Colors.white : DT.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Celebration overlay
// ─────────────────────────────────────────────

class _CelebrationOverlay extends StatelessWidget {
  final AppS s;
  final int popped;
  final String childName;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  const _CelebrationOverlay({
    required this.s,
    required this.popped,
    required this.childName,
    required this.onAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop.
        const Positioned.fill(
          child: ColoredBox(color: Color(0xCC000000)),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 320,
              minWidth: 0,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: DT.shadowLift(kAccent),
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BloomMascot(
                  size: 96 * screenScale(context).clamp(1.0, 1.2),
                  emotion: BloomEmotion.waving,
                ),
                const SizedBox(height: 16),
                Text(
                  s('Молодець, $childName!', 'Great job, $childName!'),
                  textAlign: TextAlign.center,
                  style: DT.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  s(
                    'Ти лопнув $popped бульок!',
                    'You popped $popped bubbles!',
                  ),
                  textAlign: TextAlign.center,
                  style: DT.body.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: DT.tileTitle,
                    ),
                    child: Text(s('Ще раз', 'Again')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onDone,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccent,
                      side: BorderSide(
                        color: kAccent.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: DT.tileTitle,
                    ),
                    child: Text(s('Готово', 'Done')),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }
}
