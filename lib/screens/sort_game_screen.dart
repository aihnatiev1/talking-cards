import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../utils/l10n.dart';
import '../utils/constants.dart';

class SortGameScreen extends ConsumerStatefulWidget {
  final PackModel packA;
  final PackModel packB;

  const SortGameScreen({
    super.key,
    required this.packA,
    required this.packB,
  });

  @override
  ConsumerState<SortGameScreen> createState() => _SortGameScreenState();
}

class _SortGameScreenState extends ConsumerState<SortGameScreen>
    with TickerProviderStateMixin {
  late List<_SortCard> _remaining;
  int _score = 0;
  bool _done = false;
  bool _questDone = false;
  bool _showHint = true; // shown until first successful drag

  // Shake animation controller for wrong drops
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  // Hint bounce animation
  late AnimationController _hintController;
  late Animation<double> _hintAnim;

  String? _shakingCardId;
  String? _highlightZone; // 'a' or 'b' when hovering

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        setState(() => _shakingCardId = null);
      }
    });

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _hintAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    _initCards();
  }

  void _initCards() {
    final cardsA = List<CardModel>.from(widget.packA.cards)
      ..shuffle()
      ..take(3);
    final cardsB = List<CardModel>.from(widget.packB.cards)
      ..shuffle()
      ..take(3);

    final picked = [
      ...cardsA.take(3).map((c) => _SortCard(card: c, belongsToPackA: true)),
      ...cardsB.take(3).map((c) => _SortCard(card: c, belongsToPackA: false)),
    ]..shuffle();

    setState(() {
      _remaining = picked;
      _score = 0;
      _done = false;
      _showHint = true;
    });
  }

  void _onCorrectDrop(String cardId) {
    HapticFeedback.lightImpact();
    setState(() {
      _remaining.removeWhere((s) => s.card.id == cardId);
      _score++;
      _showHint = false; // hide hint after first success
      if (_remaining.isEmpty) _done = true;
    });
    if (_done && !_questDone) {
      _questDone = true;
      ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard);
      ref.read(gameStatsProvider.notifier).record('sort', _score);
      Future.delayed(const Duration(milliseconds: 300), _showCompletion);
    }
  }

  void _onWrongDrop(String cardId) {
    HapticFeedback.mediumImpact();
    setState(() => _shakingCardId = cardId);
    _shakeController.forward();
  }

  void _showCompletion() {
    if (!mounted) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                s('Все розкладено!', 'All sorted!'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 32)),
                  Text('⭐', style: TextStyle(fontSize: 32)),
                  Text('⭐', style: TextStyle(fontSize: 32)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _initCards();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    s('Ще раз! 🔄', 'Play again! 🔄'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: Text(
                  s('Додому', 'Home'),
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');
    const total = 6;
    final sorted = _score;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.packA.icon, style: const TextStyle(fontSize: 22)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.swap_horiz_rounded, size: 20),
            ),
            Text(widget.packB.icon, style: const TextStyle(fontSize: 22)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? sorted / total : 0,
                        minHeight: 7,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(kAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$sorted/$total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Cards ─────────────────────────────────
            if (_remaining.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('✅', style: TextStyle(fontSize: 56)),
              )
            else ...[
              AnimatedOpacity(
                opacity: _showHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s('Перетягни у правильну купку 👇',
                        'Drag to the right bin 👇'),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _remaining.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _buildDraggableCard(_remaining[i]),
                ),
              ),
              // Bouncing arrow
              AnimatedOpacity(
                opacity: _showHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedBuilder(
                  animation: _hintAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _hintAnim.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 26,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // ── Drop zones — fill all remaining space ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: _buildDropZone(
                            pack: widget.packA, isZoneA: true, s: s)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildDropZone(
                            pack: widget.packB, isZoneA: false, s: s)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableCard(_SortCard sc) {
    final card = sc.card;
    final isShaking = _shakingCardId == card.id;

    Widget cardWidget = _CardChip(card: card);

    if (isShaking) {
      cardWidget = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) {
          final offset =
              8 * (0.5 - (_shakeAnim.value % 0.25) / 0.25).abs() * 2 - 4;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: cardWidget,
      );
    }

    return Draggable<_SortCard>(
      data: sc,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: Opacity(opacity: 0.9, child: _CardChip(card: card)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _CardChip(card: card)),
      onDragStarted: () => setState(() => _showHint = false),
      child: cardWidget,
    );
  }

  Widget _buildDropZone({
    required PackModel pack,
    required bool isZoneA,
    required AppS s,
  }) {
    final zoneKey = isZoneA ? 'a' : 'b';
    final isHighlighted = _highlightZone == zoneKey;

    return DragTarget<_SortCard>(
      onWillAcceptWithDetails: (details) {
        setState(() => _highlightZone = zoneKey);
        return true;
      },
      onLeave: (_) => setState(() => _highlightZone = null),
      onAcceptWithDetails: (details) {
        setState(() => _highlightZone = null);
        final sc = details.data;
        final isCorrect = isZoneA ? sc.belongsToPackA : !sc.belongsToPackA;
        if (isCorrect) {
          _onCorrectDrop(sc.card.id);
        } else {
          _onWrongDrop(sc.card.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isHighlighted
                ? pack.color.withValues(alpha: 0.18)
                : pack.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHighlighted
                  ? pack.color
                  : pack.color.withValues(alpha: 0.3),
              width: isHighlighted ? 3 : 1.5,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: pack.color.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isHighlighted ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(pack.icon,
                      style: const TextStyle(fontSize: 52)),
                ),
                const SizedBox(height: 10),
                Text(
                  pack.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: pack.color,
                  ),
                ),
                if (isHighlighted) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: pack.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s('Кидай! 🎯', 'Drop! 🎯'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────

class _SortCard {
  final CardModel card;
  final bool belongsToPackA;
  _SortCard({required this.card, required this.belongsToPackA});
}

// ─────────────────────────────────────────────
//  Card chip widget
// ─────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final CardModel card;

  const _CardChip({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 95,
      height: 105,
      decoration: BoxDecoration(
        color: card.colorBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (card.image != null)
            SizedBox(
              height: 54,
              child: Image.asset(
                'assets/images/webp/${card.image}.webp',
                fit: BoxFit.contain,
              ),
            )
          else
            Text(card.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              card.sound,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: card.colorAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
