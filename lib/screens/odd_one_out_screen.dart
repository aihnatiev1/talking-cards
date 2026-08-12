import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';
import '../widgets/game_celebration_overlay.dart';

class OddOneOutScreen extends ConsumerStatefulWidget {
  final List<PackModel> packs;

  const OddOneOutScreen({super.key, required this.packs});

  @override
  ConsumerState<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends ConsumerState<OddOneOutScreen>
    with
        TickerProviderStateMixin,
        ShakeAnimationMixin,
        ConfettiOverlayMixin,
        GameStateMixin {
  @override
  String get gameId => 'odd_one_out';

  // 5 rounds ≈ 30-60s — a 2-year-old's full attention span.
  @override
  int get maxRounds => 5;

  bool _answered = false;
  String? _tappedId;
  late List<_Slot> _slots;

  @override
  void initState() {
    super.initState();
    initShake();
    startGame();
    _buildRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'odd_one_out',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  @override
  void dispose() {
    disposeShake();
    disposeConfetti();
    super.dispose();
  }

  void _buildRound() {
    final rng = Random();
    final pool = List<PackModel>.from(widget.packs)..shuffle(rng);
    final majority = pool[0];
    final oddPack = pool[1];

    final majorityCards = List<CardModel>.from(majority.cards)..shuffle(rng);
    final oddCards = List<CardModel>.from(oddPack.cards)..shuffle(rng);

    final three = majorityCards.take(3).toList();
    final one = oddCards.first;

    final slots = [
      ...three.map((c) => _Slot(card: c, pack: majority, isOdd: false)),
      _Slot(card: one, pack: oddPack, isOdd: true),
    ]..shuffle(rng);

    setState(() {
      _slots = slots;
      _answered = false;
      _tappedId = null;
    });
  }

  void _onTap(_Slot slot) {
    if (_answered) return;
    _tappedId = slot.card.id;

    // Play the tapped card's word — child hears the item they're evaluating,
    // which anchors the sort-by-category reasoning in speech, not silence.
    AudioService.instance.playWordOnly(slot.card.audioKey, slot.card.sound);

    if (slot.isOdd) {
      HapticFeedback.lightImpact();
      AudioService.instance.playSfx('ding');
      AudioService.instance
          .playPraise(isEn: ref.read(languageProvider) == 'en');
      setState(() {
        _answered = true;
        scorePoint();
      });
      showConfetti();
      if (score >= maxRounds) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          completeGame();
          _showCelebration();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _buildRound();
        });
      }
    } else {
      // Gentle redirection — soft shake only, no harsh error feedback.
      HapticFeedback.mediumImpact();
      shake(id: slot.card.id);
    }
  }

  void _showCelebration() {
    showGameCelebration(
      context,
      lang: ref.read(languageProvider),
      childName: ref.read(profileProvider).active?.name ?? '',
      onAgain: () {
        resetGame();
        _buildRound();
      },
      onDone: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider));

    // Determine majority pack for the hint header
    final majorityPack = _slots.firstWhere((sl) => !sl.isOdd).pack;
    final majorityCards =
        _slots.where((sl) => !sl.isOdd).map((sl) => sl.card).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      appBar: AppBar(
        title: Text(
          s('Знайди зайве', 'Odd one out'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Hint — small thumbnails of the actual majority cards + "?"
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(majorityPack.id),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c in majorityCards) ...[
                          _HintThumb(card: c),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 6),
                        const Text('❓',
                            style: TextStyle(fontSize: 36)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s('Яка картка зайва?', 'Which is odd?'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: majorityPack.color,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 2×2 card grid
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.88,
                  children: _slots
                      .map((sl) => _buildCard(sl, s))
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_Slot sl, AppS s) {
    final card = sl.card;
    final isCorrect = _answered && sl.isOdd;
    final isWrong = _answered && _tappedId == card.id && !sl.isOdd;

    final chip = _CardChip(
      card: card,
      isCorrect: isCorrect,
      isWrong: isWrong,
    );

    return GestureDetector(
      onTap: () => _onTap(sl),
      child: wrapShake(chip, id: card.id),
    );
  }

}

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Slot {
  final CardModel card;
  final PackModel pack;
  final bool isOdd;
  _Slot({required this.card, required this.pack, required this.isOdd});
}

// ─────────────────────────────────────────────
//  Hint thumbnail — small webp of a majority card
// ─────────────────────────────────────────────

class _HintThumb extends StatelessWidget {
  final CardModel card;
  const _HintThumb({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.colorAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: card.image != null
          ? Image.asset(
              'assets/images/webp/${card.image}.webp',
              fit: BoxFit.contain,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: card.colorBg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  Card chip
// ─────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final CardModel card;
  final bool isCorrect;
  final bool isWrong;

  const _CardChip({
    required this.card,
    this.isCorrect = false,
    this.isWrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCorrect
            ? const Color(0xFFE8F5E9)
            : isWrong
                ? const Color(0xFFFFEBEE)
                : card.colorBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF43A047)
              : isWrong
                  ? const Color(0xFFE53935)
                  : card.colorAccent.withValues(alpha: 0.3),
          width: isCorrect || isWrong ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Real webp only — plain placeholder if an unsanitized card
                // ever slips through (never emoji in gameplay).
                if (card.image != null)
                  SizedBox(
                    height: 70,
                    child: Image.asset(
                      'assets/images/webp/${card.image}.webp',
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: card.colorAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    card.sound,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCorrect
                          ? const Color(0xFF2E7D32)
                          : isWrong
                              ? const Color(0xFFC62828)
                              : card.colorAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCorrect)
            const Positioned(
              top: 8,
              right: 8,
              child: Text('✅', style: TextStyle(fontSize: 20)),
            ),
          if (isWrong)
            const Positioned(
              top: 8,
              right: 8,
              child: Text('❌', style: TextStyle(fontSize: 20)),
            ),
        ],
      ),
    );
  }
}
