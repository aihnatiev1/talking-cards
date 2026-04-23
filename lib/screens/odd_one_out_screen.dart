import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';

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

  bool _answered = false;
  String? _tappedId;
  late List<_Slot> _slots;

  @override
  void initState() {
    super.initState();
    initShake();
    startGame();
    _buildRound();
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
      setState(() {
        _answered = true;
        scorePoint();
      });
      showConfetti();
      if (score >= maxRounds) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          completeGame();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _buildRound();
        });
      }
    } else {
      HapticFeedback.mediumImpact();
      shake(id: slot.card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    if (finished) return _buildFinishScreen(s);

    // Determine majority pack for the hint header
    final majorityPack = _slots.firstWhere((sl) => !sl.isOdd).pack;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      appBar: AppBar(
        title: Text(
          s('Знайди зайве', 'Odd one out'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $score/$maxRounds',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Hint — big pack icon + short question
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(majorityPack.id),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(majorityPack.icon,
                            style: const TextStyle(fontSize: 40)),
                        Text(majorityPack.icon,
                            style: const TextStyle(fontSize: 40)),
                        Text(majorityPack.icon,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 12),
                        const Text('❓',
                            style: TextStyle(fontSize: 40)),
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

  Widget _buildFinishScreen(AppS s) {
    final pct = score / maxRounds;
    final stars = pct >= 0.8 ? 3 : pct >= 0.5 ? 2 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stars == 3
                      ? s('Чудово! 🎉', 'Excellent! 🎉')
                      : stars == 2
                          ? s('Молодець! 👍', 'Well done! 👍')
                          : s('Спробуй ще! 💪', 'Keep trying! 💪'),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Text(
                      i < stars ? '⭐' : '☆',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s('$score з $maxRounds раундів', '$score of $maxRounds rounds'),
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      s('Готово', 'Done'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    resetGame();
                    _buildRound();
                  },
                  child: Text(
                    s('Грати ще раз 🔄', 'Play again 🔄'),
                    style: TextStyle(color: Colors.grey[600]),
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
//  Data
// ─────────────────────────────────────────────

class _Slot {
  final CardModel card;
  final PackModel pack;
  final bool isOdd;
  _Slot({required this.card, required this.pack, required this.isOdd});
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
                if (card.image != null)
                  SizedBox(
                    height: 70,
                    child: Image.asset(
                      'assets/images/webp/${card.image}.webp',
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Text(card.emoji,
                      style: const TextStyle(fontSize: 52)),
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
