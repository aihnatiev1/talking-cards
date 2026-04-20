import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';

class SortGameScreen extends ConsumerStatefulWidget {
  final List<PackModel> packs;

  const SortGameScreen({
    super.key,
    required this.packs,
  });

  @override
  ConsumerState<SortGameScreen> createState() => _SortGameScreenState();
}

class _SortGameScreenState extends ConsumerState<SortGameScreen>
    with
        TickerProviderStateMixin,
        ShakeAnimationMixin,
        ConfettiOverlayMixin,
        GameStateMixin {
  @override
  String get gameId => 'sort';

  @override
  QuestTask get questTask => QuestTask.reviewOldCard;

  late List<_SortCard> _remaining;
  int _total = 0;
  bool _showHint = true; // hidden after first drag

  // Hint bounce arrow
  late AnimationController _hintController;
  late Animation<double> _hintAnim;

  int? _highlightZone;

  @override
  void initState() {
    super.initState();

    initShake(
      duration: const Duration(milliseconds: 400),
      amplitude: 12,
    );

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _hintAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    startGame();
    _initCards();
  }

  void _initCards() {
    final cardsPerPack = widget.packs.length == 2 ? 3 : 2;
    final picked = <_SortCard>[];
    for (int i = 0; i < widget.packs.length; i++) {
      final cards = List<CardModel>.from(widget.packs[i].cards)..shuffle();
      for (final c in cards.take(cardsPerPack)) {
        picked.add(_SortCard(card: c, packIndex: i));
      }
    }
    picked.shuffle();
    resetGame();
    setState(() {
      _remaining = picked;
      _total = picked.length;
      _showHint = true;
    });
  }

  @override
  void dispose() {
    disposeShake();
    _hintController.dispose();
    disposeConfetti();
    super.dispose();
  }

  void _onCorrectDrop(String cardId) {
    HapticFeedback.lightImpact();
    setState(() {
      _remaining.removeWhere((s) => s.card.id == cardId);
      scorePoint();
      _showHint = false;
    });
    if (_remaining.isEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        completeGame();
        Future.delayed(
          const Duration(milliseconds: 100),
          () => showConfetti(linger: const Duration(milliseconds: 2000)),
        );
      });
    }
  }

  void _onWrongDrop(String cardId) {
    HapticFeedback.mediumImpact();
    shake(id: cardId);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    if (finished) return _buildResultScreen(s);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E8),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.packs.expand((p) => [
            Text(p.icon, style: const TextStyle(fontSize: 22)),
            if (p != widget.packs.last)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.swap_horiz_rounded, size: 18),
              ),
          ]).toList(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _total > 0 ? score / _total : 0,
                        minHeight: 7,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(kAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$score/$_total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Cards (Wrap — all visible, no scroll) ─
            if (_remaining.isNotEmpty) ...[
              AnimatedOpacity(
                opacity: _showHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    s('Перетягни у правильну купку 👇',
                        'Drag to the right bin 👇'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children:
                      _remaining.map((sc) => _buildDraggableCard(sc)).toList(),
                ),
              ),
              // Bouncing hint arrow
              AnimatedOpacity(
                opacity: _showHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedBuilder(
                  animation: _hintAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _hintAnim.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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

            // ── Drop zones ────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.packs.asMap().entries.expand((e) => [
                    Expanded(
                        child: _buildDropZone(
                            pack: e.value, zoneIndex: e.key, s: s)),
                    if (e.key < widget.packs.length - 1)
                      const SizedBox(width: 12),
                  ]).toList(),
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

    final Widget cardWidget = wrapShake(_CardChip(card: card), id: card.id);

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
      onDragStarted: () {
        setState(() => _showHint = false);
        // Play the word so the child hears what they're sorting
        AudioService.instance.playWordOnly(card.audioKey, card.sound);
      },
      child: cardWidget,
    );
  }

  Widget _buildDropZone({
    required PackModel pack,
    required int zoneIndex,
    required AppS s,
  }) {
    final isHighlighted = _highlightZone == zoneIndex;

    return DragTarget<_SortCard>(
      onWillAcceptWithDetails: (details) {
        setState(() => _highlightZone = zoneIndex);
        return true;
      },
      onLeave: (_) => setState(() => _highlightZone = null),
      onAcceptWithDetails: (details) {
        setState(() => _highlightZone = null);
        final sc = details.data;
        if (sc.packIndex == zoneIndex) {
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

  Widget _buildResultScreen(AppS s) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s('Все розкладено! 🎉', 'All sorted! 🎉'),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⭐', style: TextStyle(fontSize: 48)),
                    Text('⭐', style: TextStyle(fontSize: 48)),
                    Text('⭐', style: TextStyle(fontSize: 48)),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _initCards,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      s('Ще раз! 🔄', 'Play again! 🔄'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────

class _SortCard {
  final CardModel card;
  final int packIndex;
  _SortCard({required this.card, required this.packIndex});
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
