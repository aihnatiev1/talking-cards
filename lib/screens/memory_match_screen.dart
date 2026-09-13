import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/app_review_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../widgets/answer_feedback.dart';
import '../widgets/card_image.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Tile {
  final CardModel card;
  final int pairId; // same for the two tiles that form a pair
  final int tileId; // unique across the board
  bool isFlipped = false;
  bool isMatched = false;

  /// Mismatch counter — every increment nudges the face-up tile once.
  int nudge = 0;

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

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
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
        isEn: ref.read(languageProvider) == 'en',
      );
    });
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

    // Light haptic already fired on pointer-down inside KidTap (v2); a
    // second one here felt like a double-tap.
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
    FeedbackService.instance.event(FeedbackEvent.correct);
    setState(() {
      _tiles[a].isMatched = true;
      _tiles[b].isMatched = true;
      _matched++;
    });
    // Both tiles pop, frame in success and burst from their own centre
    // (AnswerFrame) — immediate reinforcement for every pair, not just
    // the final match.
    if (_matched < _activePairs) {
      AudioService.instance
          .playPraise(isEn: ref.read(languageProvider) == 'en');
    } else {
      // The last pair: no extra accent here — the round celebration below
      // brings the tada + haptic (FeedbackEvent.roundDone).
      _wins++;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        AnalyticsService.instance.logGameComplete('memory_match', _matched);
        ref
            .read(dailyQuestProvider.notifier)
            .completeTask(QuestTask.playQuiz);
        // See GameStateMixin._complete: the first finished game is the one
        // automatic review ask that English-market families actually reach.
        final firstGame = isFirstGame(ref);
        ref.read(gameStatsProvider.notifier).record('memory', _matched);
        if (firstGame) {
          ref.read(appReviewControllerProvider).noteFirstGameFinished();
        }
        // Any completion is a full win — no attempts, no stars, no time.
        showGameCelebration(
          context,
          isEn: ref.read(languageProvider) == 'en',
          childName: ref.read(profileProvider).active?.name ?? '',
          onAgain: _initGame,
          onDone: () => Navigator.of(context).pop(),
        );
      });
    }
  }

  void _onMismatch(int a, int b) {
    // Soft pop + one nudge of both cards, then they simply turn back —
    // no cross, no red (G10).
    FeedbackService.instance.event(FeedbackEvent.wrong);
    setState(() {
      _tiles[a].nudge++;
      _tiles[b].nudge++;
    });
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
    final color = widget.pack.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The kid zone has no dark palette by design; the one dark surface is
    // the parent scaffold's, reused here so a dark-mode tablet is not
    // blinding at bedtime.
    return KidScreen.game(
      accent: color,
      background: isDark ? DT.bgDark : DT.bgWarm,
      // No title: cards may come from several packs, so naming one would be
      // wrong, and "Find the pair" is spoken, not read.
      trailing: SizedBox(
        width: 72,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
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
                  // SliverGridDelegateWithFixedCrossAxisCount derives a
                  // tile's HEIGHT from its width, so on a wide screen the
                  // rows grow past the box — and with
                  // NeverScrollableScrollPhysics they are then simply
                  // clipped. On an 11" iPad the bottom row was cut in half
                  // and its two cards could not be tapped at all.
                  //
                  // Size the board from the box instead: keep the designed
                  // tile proportions, take the largest board that fits both
                  // dimensions, and centre it. Correct on a phone, a
                  // tablet, and either rotation.
                  child: LayoutBuilder(
                    builder: (context, box) {
                      const gap = 12.0;
                      // 3 pairs → 2×3 grid with big toddler tiles; bigger
                      // boards keep the classic 3-column layout.
                      final cols = _activePairs <= 3 ? 2 : 3;
                      final rows = (_tiles.length / cols).ceil();
                      final ratio = _activePairs <= 3 ? 0.9 : 0.82;

                      final tileW = min(
                        (box.maxWidth - gap * (cols - 1)) / cols,
                        (box.maxHeight - gap * (rows - 1)) / rows * ratio,
                      );
                      if (tileW <= 0) return const SizedBox.shrink();

                      return Center(
                        child: SizedBox(
                          width: tileW * cols + gap * (cols - 1),
                          height: tileW / ratio * rows + gap * (rows - 1),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                              childAspectRatio: ratio,
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
                      );
                    },
                  ),
                ),
              ),

            ],
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  // Track last-processed state to avoid mutable-object comparison issue.
  // _Tile is mutated in-place → old.tile == widget.tile (same ref), so
  // comparing old.tile.isFlipped gives the NEW value, not the old one.
  bool _lastFaceUp = false;

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
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    final nowFace = _faceUp;
    if (nowFace && !_lastFaceUp) _ctrl.forward();
    if (!nowFace && _lastFaceUp) _ctrl.reverse();
    _lastFaceUp = nowFace;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: widget.onTap,
      // The tile answers with its word (playWordOnly), not a pop.
      sound: KidSound.none,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * pi;
          final showFront = angle > pi / 2;
          // The success pop and the miss nudge live on the front face's
          // AnswerFrame — the same look as every other game tile.
          Widget face = showFront
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _FrontFace(
                      tile: widget.tile, packColor: widget.packColor),
                )
              : _BackFace(
                  packColor: widget.packColor, packIcon: widget.packIcon);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: face,
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
    return AnswerFrame(
      background: matched ? Colors.white : tile.card.colorBg,
      accent: tile.card.colorAccent,
      mark: matched ? AnswerMark.correct : AnswerMark.none,
      nudge: tile.nudge,
      radius: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Real webp illustration — pools are sanitized upstream, the null
          // branch is only a defensive plain placeholder (never emoji).
          if (tile.card.image != null)
            // The height moves to the box: CardImage fills whatever it is
            // given, and this Column hands out unbounded height.
            SizedBox(
              height: 58,
              child: CardImage.forCard(
                tile.card,
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                color: matched ? DT.success : tile.card.colorAccent,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

