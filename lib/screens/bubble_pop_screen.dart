import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../services/feedback_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';

/// Pop-It-style sensory toy:
/// bubbles drift up from the bottom, child taps to pop, the card image inside
/// zooms with an elastic curve while the recorded word audio plays.
///
/// Two modes — All unlocked packs vs. Tricky words (mistakes ∪ SRS-due).
/// The child entry always starts in "all words"; a future hard-words entry
/// point can pass [mode] explicitly (there is no in-game mode switch — that
/// was an adult control living in the child's play zone).
class BubblePopScreen extends ConsumerStatefulWidget {
  final BubbleMode mode;

  const BubblePopScreen({super.key, this.mode = BubbleMode.all});

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

// Excluded packs (apply to both modes): phrase/verse/babble packs (shared
// PackModel.nonWordPackIds) plus virtual / seasonal.
bool _isExcludedPack(PackModel p) {
  if (p.id.startsWith('_')) return true;
  if (p.id.startsWith('seasonal_')) return true;
  if (PackModel.nonWordPackIds.contains(p.id)) return true;
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

  int _nextBubbleId = 1;
  int _popped = 0;

  /// Praise currently on screen, and a sequence number so two cheers in a
  /// row restart the animation instead of reusing the same element.
  String? _praise;
  int _praiseSeq = 0;
  int _lastPraiseIndex = -1;

  /// Every fifth pop. Often enough that a child connects it to what they
  /// did, rare enough that it stays a reward and not wallpaper.
  static const _praiseEvery = 5;
  int _elapsedMs = 0;
  int _msSinceSpawn = 0;
  int _spawnIntervalMs = 900;
  bool _ended = false;

  // Cached at first build because we ticker-update without [setState].
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _ticker = createTicker(_onTick);
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
    _ticker.stop();
    _ticker.dispose();
    _frame.dispose();
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
    _deck.clear();
    _popped = 0;
    _elapsedMs = 0;
    _msSinceSpawn = 0;
    _ended = false;
    _spawnIntervalMs = _randomSpawnInterval();
    _lastTick = Duration.zero;

    AnalyticsService.instance.logGameStart('bubble_pop_${_mode.name}');

    // Pre-seed two bubbles mid-screen so the round doesn't open on an empty
    // sky — the first bottom spawn otherwise takes several seconds to drift
    // into view. Screen size is known: _startRound runs post-first-frame.
    final screen = _screenSize;
    if (screen != null) {
      _spawnBubble(0, screen, startYFactor: 0.55);
      _spawnBubble(0, screen, startYFactor: 0.8);
    }

    if (!_ticker.isActive) _ticker.start();
  }

  /// Stops physics and shows the round celebration (unless [earlyExit]).
  void _endRound({bool earlyExit = false}) {
    if (_ended) return;
    _ended = true;
    _ticker.stop();
    _live.clear();

    if (!earlyExit) {
      // Quest + analytics only on natural completion.
      ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
      AnalyticsService.instance
          .logGameComplete('bubble_pop_${_mode.name}', _popped);
      // The shared round celebration (confetti, Bloom, tada + praise) over
      // the finished board; it pops itself before calling back.
      final popped = _popped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = AppS(ref.read(languageProvider) == 'en');
        showGameCelebration(
          context,
          isEn: s.isEn,
          childName: _childName,
          subtitle: s(
            'Ти лопнув $popped бульок!',
            'You popped $popped bubbles!',
          ),
          onAgain: () => _startRound(mode: _mode),
          onDone: () => Navigator.of(context).pop(),
        );
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

    // Repaint only the bubble layer (see ListenableBuilder in build) —
    // a full-screen setState per frame kept the whole tree rebuilding
    // at 60fps on the old tablets this app targets.
    _frame.value++;
  }

  int _randomSpawnInterval() =>
      _kMinSpawnMs + _rng.nextInt(_kMaxSpawnMs - _kMinSpawnMs);

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

  /// [startYFactor] places the bubble at a fraction of screen height instead
  /// of just below the bottom edge — used to pre-seed the round start.
  void _spawnBubble(int nowMs, Size screen, {double? startYFactor}) {
    if (_pool.isEmpty) return;
    final card = _drawCard();
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

  void _onBubbleTap(_LiveBubble b) {
    if (_ended) return;

    // Instant pop + haptic layered over the narrator — never cuts the word
    // off (FeedbackEvent.tap: a pitch-varied pop, so twenty pops differ).
    FeedbackService.instance.event(FeedbackEvent.tap);
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
      // The last pop hands over to the celebration overlay; cheering
      // underneath it would just be two rewards fighting for the screen.
      if (_popped % _praiseEvery == 0 && _popped < _kRoundTargetPops) {
        _showPraise();
      }
    });

    // End-of-round check on tap (don't wait for the next ticker frame —
    // feels more responsive when the 20th pop ends the game immediately).
    if (_popped >= _kRoundTargetPops) {
      _endRound();
    }
  }

  /// Picks a cheer, never the same one twice running.
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
    // Shell: close top-left, wordless fill-up pill under the header, the
    // count as the one piece of text a three-year-old can already read.
    return KidScreen.game(
      accent: kAccent,
      background: DT.skyTint,
      progress: (_popped / _kRoundTargetPops).clamp(0.0, 1.0),
      trailing: _CountPill(popped: _popped, target: _kRoundTargetPops),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cache layout for the ticker. The box is the play area under the
          // shell's header, so bubbles no longer drift under the controls.
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);

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

              // Live bubbles — isolated in their own subtree that rebuilds
              // per ticker frame; the rest of the screen stays untouched.
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, __) => Stack(
                    children: [
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
                      onComplete: () => _onPopComplete(p.id),
                    ),
                  ),
                ),

              // Praise flash. Above the bubbles so it reads, below the
              // celebration overlay, and IgnorePointer inside so it can
              // never swallow a tap meant for a bubble.
              if (_praise != null && !_ended)
                Positioned.fill(
                  child: _PraiseFlash(
                    key: ValueKey(_praiseSeq),
                    text: _praise!,
                    color: kAccent,
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
      // ClipOval keeps the (portrait) card illustration inside the glass —
      // unclipped it pokes out past the circle on tall images.
      child: ClipOval(
        child: Stack(
          children: [
            // Card image inside — the key WOW element.
            Center(
              child: bubble.card.image != null
                  ? CardImage.forCard(
                      bubble.card,
                      padding: EdgeInsets.all(size * 0.18),
                    )
                  : const SizedBox.shrink(),
            ),
            // Top-left highlight dot — translucent so it reads as glass
            // shine instead of covering the illustration underneath.
            Align(
              alignment: const Alignment(-0.4, -0.4),
              child: FractionallySizedBox(
                widthFactor: 0.28,
                heightFactor: 0.28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
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
//  Top bar: close button + fill-up progress bar
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
            color: kAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: DT.shadowSoft(kAccent),
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

/// A word of praise that flashes over the play area and leaves.
///
/// The round deliberately has no scoreboard, but on a tablet that left a
/// near-empty screen with a strip of progress across the top, which reads
/// as "nothing is happening" rather than as play. This is the reward the
/// child can see, next to the one they hear — brief, huge, and gone before
/// it becomes chrome.
class _PraiseFlash extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;

  const _PraiseFlash({
    super.key,
    required this.text,
    required this.color,
    required this.onDone,
  });

  @override
  State<_PraiseFlash> createState() => _PraiseFlashState();
}

class _PraiseFlashState extends State<_PraiseFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value;
            // Pops in with a bounce, holds, then lifts away — the shape of
            // a cheer rather than of a notification.
            final scale = t < 0.3
                ? Curves.easeOutBack.transform(t / 0.3)
                : 1.0;
            final fade = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -30 * (t < 0.7 ? 0 : (t - 0.7) / 0.3)),
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
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: widget.color,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 12),
                Shadow(color: Colors.white, blurRadius: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
