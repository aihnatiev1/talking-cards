import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/l10n.dart';
import '../widgets/game_celebration_overlay.dart';

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Tile {
  final CardModel card;
  final int pairId; // same for the two tiles that form a pair
  final int tileId; // unique across the board
  bool isFlipped = false;
  bool isMatched = false;

  _Tile({
    required this.card,
    required this.pairId,
    required this.tileId,
  });
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────

class MemoryMatchScreen extends ConsumerStatefulWidget {
  final PackModel pack;
  final List<CardModel> cards;

  /// Pairs on the board. Toddler entry (games tab) passes 3 (2×3 grid);
  /// the screen escalates to 4 by itself after 2 wins in one session.
  final int pairCount;

  const MemoryMatchScreen({
    super.key,
    required this.pack,
    required this.cards,
    this.pairCount = 6,
  });

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen>
    with ConfettiOverlayMixin {
  late List<_Tile> _tiles;
  int? _firstIndex; // index of first flipped tile awaiting a pair
  bool _isLocked = false; // true while showing a mismatch before flipping back
  int _matched = 0;
  int _wins = 0; // completions this session — drives pair escalation

  /// Pairs on the current board — stable for the whole round.
  late int _activePairs;

  /// Escalate small (toddler) boards to 4 pairs after 2 wins in one session.
  int get _nextPairCount =>
      (_wins >= 2 && widget.pairCount < 4) ? 4 : widget.pairCount;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('memory_match');
    _initGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'memory',
        lang: ref.read(languageProvider),
      );
    });
  }

  @override
  void dispose() {
    disposeConfetti();
    super.dispose();
  }

  // ── Setup ───────────────────────────────────

  void _initGame() {
    _activePairs = _nextPairCount;
    final playable = widget.cards
        .where((c) => c.audioKey != null)
        .toList();
    // Prefer cards with audio; fall back to all cards if not enough
    final pool = playable.length >= _activePairs ? playable : widget.cards;
    final picks = (List<CardModel>.from(pool)..shuffle(Random()))
        .take(_activePairs)
        .toList();

    final tiles = <_Tile>[];
    for (int i = 0; i < picks.length; i++) {
      tiles.add(_Tile(card: picks[i], pairId: i, tileId: i * 2));
      tiles.add(_Tile(card: picks[i], pairId: i, tileId: i * 2 + 1));
    }
    tiles.shuffle(Random());

    setState(() {
      _tiles = tiles;
      _firstIndex = null;
      _isLocked = false;
      _matched = 0;
    });
  }

  // ── Interaction ─────────────────────────────

  void _onTap(int index) {
    if (_isLocked) return;
    final tile = _tiles[index];
    if (tile.isFlipped || tile.isMatched) return;

    HapticFeedback.lightImpact();
    AudioService.instance.playWordOnly(tile.card.audioKey, tile.card.sound);

    setState(() => _tiles[index].isFlipped = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    // Second tile tapped — evaluate the pair
    final first = _firstIndex!;
    _firstIndex = null;

    if (_tiles[first].pairId == tile.pairId) {
      _onMatch(first, index);
    } else {
      _onMismatch(first, index);
    }
  }

  void _onMatch(int a, int b) {
    HapticFeedback.mediumImpact();
    AudioService.instance.playSfx('ding');
    setState(() {
      _tiles[a].isMatched = true;
      _tiles[b].isMatched = true;
      _matched++;
    });
    // Mini-celebration for every successful pair (not just the final match)
    // — toddlers need immediate reinforcement to learn the loop.
    if (_matched < _activePairs) {
      AudioService.instance
          .playPraise(lang: ref.read(languageProvider));
      final size = MediaQuery.of(context).size;
      showConfetti(
        origin: Offset(size.width / 2, size.height / 2.2),
        linger: const Duration(milliseconds: 700),
      );
    } else {
      HapticFeedback.heavyImpact();
      final size = MediaQuery.of(context).size;
      showConfetti(
        origin: Offset(size.width / 2, size.height / 2),
        linger: const Duration(milliseconds: 2000),
      );
      _wins++;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        AnalyticsService.instance.logGameComplete('memory_match', _matched);
        ref
            .read(dailyQuestProvider.notifier)
            .completeTask(QuestTask.playQuiz);
        ref.read(gameStatsProvider.notifier).record('memory', _matched);
        // Any completion is a full win — no attempts, no stars, no time.
        showGameCelebration(
          context,
          lang: ref.read(languageProvider),
          childName: ref.read(profileProvider).active?.name ?? '',
          onAgain: _initGame,
          onDone: () => Navigator.of(context).pop(),
        );
      });
    }
  }

  void _onMismatch(int a, int b) {
    HapticFeedback.mediumImpact();
    _isLocked = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _tiles[a].isFlipped = false;
        _tiles[b].isFlipped = false;
        _isLocked = false;
      });
    });
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider));
    final color = widget.pack.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFFAFAFF), // neutral — pack color used as accent only
      body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // No pack subtitle — cards may come from several packs,
                    // so naming one pack here would simply be wrong.
                    Expanded(
                      child: Text(
                        s('Знайди пару', 'Find the pair'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Matched pairs badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // ── Pair progress dots ─────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_activePairs, (i) {
                    final done = i < _matched;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
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

              // ── Game board ──────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // 3 pairs → 2×3 grid with big toddler tiles; bigger
                      // boards keep the classic 3-column layout.
                      crossAxisCount: _activePairs <= 3 ? 2 : 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: _activePairs <= 3 ? 0.9 : 0.82,
                    ),
                    itemCount: _tiles.length,
                    itemBuilder: (context, i) => _TileWidget(
                      tile: _tiles[i],
                      packColor: color,
                      packIcon: widget.pack.icon,
                      onTap: () => _onTap(i),
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
//  Tile widget with 3D flip animation
// ─────────────────────────────────────────────

class _TileWidget extends StatefulWidget {
  final _Tile tile;
  final Color packColor;
  final String packIcon;
  final VoidCallback onTap;

  const _TileWidget({
    required this.tile,
    required this.packColor,
    required this.packIcon,
    required this.onTap,
  });

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

  // Track last-processed state to avoid mutable-object comparison issue.
  // _Tile is mutated in-place → old.tile == widget.tile (same ref), so
  // comparing old.tile.isFlipped gives the NEW value, not the old one.
  bool _lastFaceUp = false;
  bool _lastMatched = false;

  bool get _faceUp => widget.tile.isFlipped || widget.tile.isMatched;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _lastFaceUp = _faceUp;
    if (_faceUp) _ctrl.value = 1.0;

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
    _lastMatched = widget.tile.isMatched;
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    final nowFace = _faceUp;
    if (nowFace && !_lastFaceUp) _ctrl.forward();
    if (!nowFace && _lastFaceUp) _ctrl.reverse();
    _lastFaceUp = nowFace;

    final nowMatched = widget.tile.isMatched;
    if (nowMatched && !_lastMatched) _bounceCtrl.forward(from: 0);
    _lastMatched = nowMatched;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_anim, _bounceCtrl]),
        builder: (_, __) {
          final angle = _anim.value * pi;
          final showFront = angle > pi / 2;
          Widget face = showFront
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _FrontFace(
                      tile: widget.tile, packColor: widget.packColor),
                )
              : _BackFace(
                  packColor: widget.packColor, packIcon: widget.packIcon);

          return Transform.scale(
            scale: _bounceScale.value,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: face,
            ),
          );
        },
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  final Color packColor;
  final String packIcon;
  const _BackFace({required this.packColor, required this.packIcon});

  @override
  Widget build(BuildContext context) {
    // Derive a darker shade for gradient bottom
    final darker = Color.lerp(packColor, Colors.black, 0.25)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [packColor, darker],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: packColor.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle corner pattern
          Positioned(
            top: -6, left: -6,
            child: Text(packIcon,
                style: TextStyle(
                    fontSize: 28,
                    color: Colors.white.withValues(alpha: 0.12))),
          ),
          Positioned(
            bottom: -6, right: -6,
            child: Text(packIcon,
                style: TextStyle(
                    fontSize: 28,
                    color: Colors.white.withValues(alpha: 0.12))),
          ),
          // White inner border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
          ),
          // Center icon
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(packIcon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  '✨',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  final _Tile tile;
  final Color packColor;
  const _FrontFace({required this.tile, required this.packColor});

  @override
  Widget build(BuildContext context) {
    final matched = tile.isMatched;
    return Container(
      decoration: BoxDecoration(
        color: matched ? Colors.white : tile.card.colorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: matched
              ? const Color(0xFF4CAF50)
              : tile.card.colorAccent.withValues(alpha: 0.5),
          width: matched ? 2.5 : 1.5,
        ),
        boxShadow: [
          if (matched)
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: tile.card.colorAccent.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Real webp illustration — pools are sanitized upstream, the null
          // branch is only a defensive plain placeholder (never emoji).
          if (tile.card.image != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Image.asset(
                'assets/images/webp/${tile.card.image}.webp',
                height: 58,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: tile.card.colorAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              tile.card.sound,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: matched
                    ? const Color(0xFF4CAF50)
                    : tile.card.colorAccent,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

