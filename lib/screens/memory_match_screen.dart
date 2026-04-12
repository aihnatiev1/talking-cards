import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../utils/l10n.dart';

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

  const MemoryMatchScreen({
    super.key,
    required this.pack,
    required this.cards,
  });

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  static const _pairCount = 6; // 4×3 grid

  late List<_Tile> _tiles;
  int? _firstIndex; // index of first flipped tile awaiting a pair
  bool _isLocked = false; // true while showing a mismatch before flipping back
  int _attempts = 0;
  int _matched = 0;
  bool _done = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  // ── Setup ───────────────────────────────────

  void _initGame() {
    final playable = widget.cards
        .where((c) => c.audioKey != null)
        .toList();
    // Prefer cards with audio; fall back to all cards if not enough
    final pool = playable.length >= _pairCount ? playable : widget.cards;
    final picks = (List<CardModel>.from(pool)..shuffle(Random()))
        .take(_pairCount)
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
      _attempts = 0;
      _matched = 0;
      _done = false;
      _startTime = DateTime.now();
    });
  }

  // ── Interaction ─────────────────────────────

  void _onTap(int index) {
    if (_isLocked) return;
    final tile = _tiles[index];
    if (tile.isFlipped || tile.isMatched) return;

    HapticFeedback.lightImpact();
    AudioService.instance.playSound(tile.card.audioKey);

    setState(() => _tiles[index].isFlipped = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    // Second tile tapped — evaluate the pair
    final first = _firstIndex!;
    _firstIndex = null;
    _attempts++;

    if (_tiles[first].pairId == tile.pairId) {
      _onMatch(first, index);
    } else {
      _onMismatch(first, index);
    }
  }

  void _onMatch(int a, int b) {
    HapticFeedback.mediumImpact();
    setState(() {
      _tiles[a].isMatched = true;
      _tiles[b].isMatched = true;
      _matched++;
    });
    if (_matched == _pairCount) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _done = true);
        ref
            .read(dailyQuestProvider.notifier)
            .completeTask(QuestTask.playQuiz); // memory counts as the game task
      });
    }
  }

  void _onMismatch(int a, int b) {
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

  // ── Helpers ─────────────────────────────────

  int get _stars {
    if (_attempts <= _pairCount) return 3;
    if (_attempts <= (_pairCount * 1.5).ceil()) return 2;
    return 1;
  }

  Duration get _elapsed =>
      _startTime == null ? Duration.zero : DateTime.now().difference(_startTime!);

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _ResultScreen(
        pack: widget.pack,
        stars: _stars,
        attempts: _attempts,
        elapsed: _elapsed,
        onPlayAgain: _initGame,
      );
    }

    final s = AppS(ref.read(languageProvider) == 'en');
    final color = widget.pack.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : color.withValues(alpha: 0.06),
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
                          color: color, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            s('Знайди пару', 'Find the pair'),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.pack.title,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
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
                        '$_matched/$_pairCount',
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
                  children: List.generate(_pairCount, (i) {
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
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

              // ── Attempts counter ───────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 14,
                        color: color.withValues(alpha: 0.5)),
                    const SizedBox(width: 5),
                    Text(
                      s('Спроб: $_attempts', 'Tries: $_attempts'),
                      style: TextStyle(
                        fontSize: 13,
                        color: color.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
    final now = _faceUp;
    if (now && !_lastFaceUp) _ctrl.forward();
    if (!now && _lastFaceUp) _ctrl.reverse();
    _lastFaceUp = now;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: packColor.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: packColor.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pack icon as hint
          Text(packIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          // Big round "?" in pack color
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: packColor,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
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
          if (matched)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50), size: 14),
            ),
          Text(
            tile.card.emoji,
            style: TextStyle(fontSize: matched ? 28 : 30),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              tile.card.sound,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: matched
                    ? const Color(0xFF4CAF50)
                    : tile.card.colorAccent,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Result screen
// ─────────────────────────────────────────────

class _ResultScreen extends ConsumerWidget {
  final PackModel pack;
  final int stars;
  final int attempts;
  final Duration elapsed;
  final VoidCallback onPlayAgain;

  const _ResultScreen({
    required this.pack,
    required this.stars,
    required this.attempts,
    required this.elapsed,
    required this.onPlayAgain,
  });

  String _timeLabel(bool isEn) {
    final sec = elapsed.inSeconds;
    final min = elapsed.inMinutes;
    if (min > 0) return isEn ? '${min}m ${sec % 60}s' : '${min}хв ${sec % 60}с';
    return isEn ? '${sec}s' : '${sec}с';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.read(languageProvider) == 'en';
    final s = AppS(isEn);
    return Scaffold(
      backgroundColor: pack.color.withValues(alpha: 0.05),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                stars == 3
                    ? s('Чудово!', 'Excellent!')
                    : stars == 2
                        ? s('Молодець!', 'Well done!')
                        : s('Гарна спроба!', 'Good try!'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: pack.color,
                ),
              ),
              const SizedBox(height: 24),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 48,
                      color: filled
                          ? const Color(0xFFFFD700)
                          : Colors.grey[300],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                      icon: Icons.touch_app_rounded,
                      label: s('Спроб', 'Attempts'),
                      value: '$attempts',
                      color: pack.color),
                  const SizedBox(width: 16),
                  _StatChip(
                      icon: Icons.timer_rounded,
                      label: s('Час', 'Time'),
                      value: _timeLabel(isEn),
                      color: pack.color),
                ],
              ),
              const SizedBox(height: 40),
              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPlayAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s('Грати знову', 'Play again'),
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pack.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  s('Назад', 'Back'),
                  style: TextStyle(
                      color: pack.color.withValues(alpha: 0.7),
                      fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
