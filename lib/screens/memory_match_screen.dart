import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../services/audio_service.dart';

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

    return Scaffold(
      backgroundColor: widget.pack.color.withValues(alpha: 0.05),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: widget.pack.color, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              '🧠 Знайди пару',
              style: TextStyle(
                color: widget.pack.color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            Text(
              widget.pack.title,
              style: TextStyle(
                color: widget.pack.color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.pack.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_matched/$_pairCount',
                  style: TextStyle(
                    color: widget.pack.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              // Attempts indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 14,
                      color: widget.pack.color.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Спроб: $_attempts',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.pack.color.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Game board
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _tiles.length,
                  itemBuilder: (context, i) => _TileWidget(
                    tile: _tiles[i],
                    packColor: widget.pack.color,
                    onTap: () => _onTap(i),
                  ),
                ),
              ),
            ],
          ),
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
  final VoidCallback onTap;

  const _TileWidget({
    required this.tile,
    required this.packColor,
    required this.onTap,
  });

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  bool get _faceUp => widget.tile.isFlipped || widget.tile.isMatched;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (_faceUp) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    final was = old.tile.isFlipped || old.tile.isMatched;
    if (_faceUp && !was) _ctrl.forward();
    if (!_faceUp && was) _ctrl.reverse();
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
              : _BackFace(packColor: widget.packColor);

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
  const _BackFace({required this.packColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: packColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: packColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Text(
          '❓',
          style: TextStyle(
            fontSize: 28,
            color: packColor.withValues(alpha: 0.5),
          ),
        ),
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
        color: matched
            ? Colors.green.withValues(alpha: 0.12)
            : tile.card.colorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: matched ? Colors.green : tile.card.colorAccent,
          width: matched ? 2.5 : 1.5,
        ),
        boxShadow: matched
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tile.card.emoji,
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            tile.card.sound,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: matched ? Colors.green[700] : tile.card.colorAccent,
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

class _ResultScreen extends StatelessWidget {
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

  String get _timeLabel {
    final s = elapsed.inSeconds;
    final m = elapsed.inMinutes;
    if (m > 0) return '${m}хв ${s % 60}с';
    return '${s}с';
  }

  @override
  Widget build(BuildContext context) {
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
                    ? 'Чудово!'
                    : stars == 2
                        ? 'Молодець!'
                        : 'Гарна спроба!',
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
                      label: 'Спроб',
                      value: '$attempts',
                      color: pack.color),
                  const SizedBox(width: 16),
                  _StatChip(
                      icon: Icons.timer_rounded,
                      label: 'Час',
                      value: _timeLabel,
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
                  label: const Text('Грати знову',
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
                  'Назад',
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
