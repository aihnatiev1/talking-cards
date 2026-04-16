import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

class OddOneOutScreen extends ConsumerStatefulWidget {
  final List<PackModel> packs;

  const OddOneOutScreen({super.key, required this.packs});

  @override
  ConsumerState<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends ConsumerState<OddOneOutScreen>
    with SingleTickerProviderStateMixin {
  int _score = 0;
  int _total = 0;
  bool _answered = false;
  String? _tappedId;
  late List<_Slot> _slots;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  // Shake for wrong
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingId;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _shakeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _shakeCtrl.reset();
        setState(() => _shakingId = null);
      }
    });
    AnalyticsService.instance.logGameStart('odd_one_out');
    _buildRound();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _confettiEntry?.remove();
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
      _shakingId = null;
    });
  }

  void _onTap(_Slot slot) {
    if (_answered) return;
    _tappedId = slot.card.id;

    if (slot.isOdd) {
      HapticFeedback.lightImpact();
      setState(() {
        _answered = true;
        _score++;
        _total++;
      });
      _showConfetti();
      Future.delayed(const Duration(milliseconds: 300), () {
        final isEn = ref.read(languageProvider) == 'en';
        TtsService.instance.speak(
          isEn ? 'Great!' : 'Молодець!',
          locale: isEn ? 'en-US' : 'uk-UA',
        );
      });
      if (!_questDone && _score >= 3) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
        AnalyticsService.instance.logGameComplete('odd_one_out', _score);
        ref.read(gameStatsProvider.notifier).record('odd_one_out', _score);
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _buildRound();
      });
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _total++;
        _shakingId = slot.card.id;
      });
      _shakeCtrl.forward();
    }
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    _confettiEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(origin: Offset(size.width / 2, size.height / 3)),
      ),
    );
    Overlay.of(context).insert(_confettiEntry!);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _confettiEntry?.remove();
      _confettiEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

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
                '⭐ $_score',
                style: const TextStyle(
                  fontSize: 16,
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
                        Text('❓',
                            style: const TextStyle(fontSize: 40)),
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
    final isShaking = _shakingId == card.id;

    Widget chip = _CardChip(
      card: card,
      isCorrect: isCorrect,
      isWrong: isWrong,
    );

    if (isShaking) {
      chip = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) {
          final offset =
              8 * (0.5 - (_shakeAnim.value % 0.25) / 0.25).abs() * 2 - 4;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: chip,
      );
    }

    return GestureDetector(
      onTap: () => _onTap(sl),
      child: chip,
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
