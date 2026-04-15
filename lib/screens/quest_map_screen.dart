import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bonus_cards_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';

import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/share_progress_card.dart';
import 'card_reveal_screen.dart';
import 'cards_screen.dart';
import 'guess_screen.dart';

// ─── Stop definitions ────────────────────────────────────────

class _StopInfo {
  final QuestTask task;
  final String emoji;
  final String label;
  final Color color; // unique color per stop
  const _StopInfo({
    required this.task,
    required this.emoji,
    required this.label,
    required this.color,
  });
}

List<_StopInfo> _buildStops(bool isEn) => [
  _StopInfo(task: QuestTask.listenCardOfDay, emoji: '👂',
      label: isEn ? 'Listen!' : 'Послухай!', color: const Color(0xFFFF7043)),
  _StopInfo(task: QuestTask.viewCards3, emoji: '🎴',
      label: isEn ? 'Find 3\ncards!' : 'Знайди 3\nкартки!', color: const Color(0xFF42A5F5)),
  _StopInfo(task: QuestTask.playQuiz, emoji: '🎵',
      label: isEn ? 'Guess\nthe word!' : 'Вгадай\nзвук!', color: const Color(0xFFAB47BC)),
  _StopInfo(task: QuestTask.viewCards5, emoji: '⭐',
      label: isEn ? '5 more\ncards!' : 'Ще 5\nкарток!', color: const Color(0xFFFFCA28)),
  _StopInfo(task: QuestTask.reviewOldCard, emoji: '🔁',
      label: isEn ? 'Repeat\nafter me!' : 'Повтори\nза мною!', color: const Color(0xFF26A69A)),
];

// Positions aligned to the colored circles in quest_map_bg.png
// (fraction of adventure map widget width/height)
const _stopPositions = [
  Offset(0.40, 0.13),  // Stop 0 — green circle, top
  Offset(0.60, 0.27),  // Stop 1 — orange circle, upper-right
  Offset(0.40, 0.41),  // Stop 2 — purple circle, middle-left
  Offset(0.63, 0.57),  // Stop 3 — blue circle, middle-right
  Offset(0.37, 0.73),  // Stop 4 — yellow circle, lower-left
];
const _treasurePos = Offset(0.47, 0.86);

class QuestMapScreen extends ConsumerStatefulWidget {
  final CardModel? cardOfDay;
  final bool cardOfDayLocked;
  final VoidCallback onCardOfDayTap;

  const QuestMapScreen({
    super.key,
    required this.cardOfDay,
    required this.cardOfDayLocked,
    required this.onCardOfDayTap,
  });

  @override
  ConsumerState<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends ConsumerState<QuestMapScreen>
    with TickerProviderStateMixin {
  CardModel? _lastUnlockedCard;
  PackModel? _lastUnlockedPack;

  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = ref.watch(dailyQuestProvider);
    final packsAsync = ref.watch(packsProvider);
    final packs = packsAsync.valueOrNull ?? [];
    final done = quest.doneCount;
    final total = quest.totalCount;
    final isEn = ref.read(languageProvider) == 'en';
    final s = AppS(isEn);
    final stops = _buildStops(isEn);

    // Restore unlocked card/pack from persisted IDs
    CardModel? rewardCard;
    PackModel? rewardPack;
    if (quest.rewardClaimed &&
        quest.rewardCardId != null &&
        quest.rewardPackId != null &&
        packs.isNotEmpty) {
      rewardPack = packs.where((p) => p.id == quest.rewardPackId).firstOrNull;
      if (rewardPack != null) {
        rewardCard = rewardPack.cards
            .where((c) => c.id == quest.rewardCardId)
            .firstOrNull;
      }
    }
    // Also use locally cached values
    rewardCard ??= _lastUnlockedCard;
    rewardPack ??= _lastUnlockedPack;

    // If reward is claimed and we have the card — show full reveal screen
    if (quest.rewardClaimed && rewardCard != null && rewardPack != null) {
      final bonus = ref.read(bonusCardsProvider)[rewardPack.id] ?? 0;
      final newTotal = PackModel.freePreviewCount + bonus;
      return CardRevealScreen(
        card: rewardCard,
        pack: rewardPack,
        newTotal: newTotal,
        skipAnimation: true,
        onShare: (ctx) {
          final completed = ref.read(completedPacksProvider);
          final allPacks = ref.read(packsProvider).valueOrNull ?? [];
          final progress = ref.read(packProgressProvider);
          shareProgress(
            context: ctx,
            completedPacks: completed.length,
            totalPacks: allPacks.length,
            seenCards: progress.entries
                .where((e) => !e.key.startsWith('_'))
                .fold<int>(0, (s, e) => s + e.value),
            totalCards:
                allPacks.fold<int>(0, (s, p) => s + p.cards.length),
            streak: 0,
            badges: {},
          );
        },
        onGoToPack: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CardsScreen(pack: rewardPack!)),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFB5E5A0),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kStreakOrange, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s('🗺️ Пригода дня', '🗺️ Adventure'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: kStreakOrange,
            fontSize: 19,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildProgress(done, total),
                ),
                const SizedBox(height: 8),

                // The adventure map
                Expanded(
                  child: AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, child) {
                      final dy = sin(_floatCtrl.value * pi) * 4;
                      return Transform.translate(
                        offset: Offset(0, -dy),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: _AdventureMap(
                        quest: quest,
                        stops: stops,
                        onStopTap: (task) =>
                            _handleStopTap(context, task, packs),
                        onClaimTreasure: () =>
                            _showPackPicker(context, packs),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(int done, int total) {
    final s = AppS(ref.read(languageProvider) == 'en');
    final progress = total > 0 ? done / total : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Text(
              s('$done з $total зупинок', '$done of $total stops'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kStreakOrange.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            ...List.generate(total, (i) {
              return Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  i < done ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: i < done
                      ? const Color(0xFFFFB347)
                      : Colors.orange.withValues(alpha: 0.25),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB347)),
          ),
        ),
      ],
    );
  }

  // ─── Business logic (unchanged) ────────────────────────────

  void _handleStopTap(
    BuildContext context,
    QuestTask task,
    List<PackModel> packs,
  ) {
    switch (task) {
      case QuestTask.listenCardOfDay:
        widget.onCardOfDayTap();
        ref
            .read(dailyQuestProvider.notifier)
            .completeTask(QuestTask.listenCardOfDay);
      case QuestTask.viewCards3:
      case QuestTask.viewCards5:
      case QuestTask.reviewOldCard:
        final openPacks =
            packs.where((p) => !p.isLocked && !p.id.startsWith('_')).toList();
        if (openPacks.isNotEmpty) {
          final pack = openPacks[Random().nextInt(openPacks.length)];
          ref
              .read(dailyQuestProvider.notifier)
              .completeTask(QuestTask.reviewOldCard);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
          );
        }
      case QuestTask.playQuiz:
        final allCards = packs.expand((p) => p.cards).toList();
        final lang = ref.read(languageProvider);
        final playable = lang == 'en'
            ? allCards.where((c) => c.image != null).toList()
            : allCards.where((c) => c.audioKey != null).toList();
        final ttsLocale = lang == 'en' ? 'en-US' : null;
        if (playable.length >= 4) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    GuessScreen(cards: playable, ttsLocale: ttsLocale)),
          );
        }
      case QuestTask.reviewSRSCards:
      case QuestTask.speakWords:
        // Bonus tasks — no specific navigation action needed
        break;
    }
  }

  void _showPackPicker(BuildContext context, List<PackModel> packs) {
    final lockedPacks = packs.where((p) => p.isLocked).toList();
    if (lockedPacks.isEmpty) {
      // All packs already unlocked — claim the reward directly
      ref.read(dailyQuestProvider.notifier).claimReward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppS(ref.read(languageProvider) == 'en')(
                '🎉 Усі паки вже відкрито — молодець!',
                '🎉 All packs already unlocked — great job!')),
            backgroundColor: const Color(0xFFFFB347),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final bonusCards = ref.read(bonusCardsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PackPickerSheet(
        lockedPacks: lockedPacks,
        bonusCards: bonusCards,
        onPick: (pack) async {
          Navigator.of(ctx).pop();
          await _unlockAndReveal(pack);
        },
      ),
    );
  }

  Future<void> _unlockAndReveal(PackModel pack) async {
    final bonus = ref.read(bonusCardsProvider)[pack.id] ?? 0;
    final newTotal = PackModel.freePreviewCount + bonus + 1;
    final cardIndex =
        (PackModel.freePreviewCount + bonus).clamp(0, pack.cards.length - 1);
    final card = pack.cards[cardIndex];

    await ref.read(bonusCardsProvider.notifier).unlockOne(pack.id);
    await ref.read(dailyQuestProvider.notifier).claimReward(
      cardId: card.id,
      packId: pack.id,
    );

    setState(() {
      _lastUnlockedCard = card;
      _lastUnlockedPack = pack;
    });

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => CardRevealScreen(
          card: card,
          pack: pack,
          newTotal: newTotal,
          onShare: (ctx) {
            final completed = ref.read(completedPacksProvider);
            final allPacks = ref.read(packsProvider).valueOrNull ?? [];
            final progress = ref.read(packProgressProvider);
            shareProgress(
              context: ctx,
              completedPacks: completed.length,
              totalPacks: allPacks.length,
              seenCards: progress.entries
                  .where((e) => !e.key.startsWith('_'))
                  .fold<int>(0, (s, e) => s + e.value),
              totalCards:
                  allPacks.fold<int>(0, (s, p) => s + p.cards.length),
              streak: 0,
              badges: {},
            );
          },
          onGoToPack: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
            );
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADVENTURE MAP — the main visual piece
// ═══════════════════════════════════════════════════════════════

class _AdventureMap extends StatelessWidget {
  final DailyQuestState quest;
  final void Function(QuestTask) onStopTap;
  final VoidCallback onClaimTreasure;
  final List<_StopInfo> stops;

  const _AdventureMap({
    required this.quest,
    required this.onStopTap,
    required this.onClaimTreasure,
    required this.stops,
  });

  bool _isCurrentStop(int index) {
    if (quest.completed.contains(stops[index].task)) return false;
    for (int i = 0; i < index; i++) {
      if (!quest.completed.contains(stops[i].task)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Calculate absolute positions for stops
        final positions = _stopPositions
            .map((p) => Offset(p.dx * w, p.dy * h))
            .toList();
        final treasureAbs = Offset(
          _treasurePos.dx * w,
          _treasurePos.dy * h,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Background image — fills the entire adventure map area
            Positioned.fill(
              child: Image.asset(
                'assets/images/quest_map_bg.png',
                fit: BoxFit.fill,
              ),
            ),

            // Stop waypoints
            for (int i = 0; i < stops.length; i++)
              Positioned(
                left: positions[i].dx - 44,
                top: positions[i].dy - 38,
                child: _StopWaypoint(
                  info: stops[i],
                  isDone: quest.completed.contains(stops[i].task),
                  isCurrent: _isCurrentStop(i),
                  index: i + 1,
                  onTap: () => onStopTap(stops[i].task),
                ),
              ),

            // Treasure at the end
            Positioned(
              left: treasureAbs.dx - 42,
              top: treasureAbs.dy - 42,
              child: _TreasureWaypoint(
                quest: quest,
                onClaim: onClaimTreasure,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STOP WAYPOINT — a circle on the map path
// ═══════════════════════════════════════════════════════════════

class _StopWaypoint extends ConsumerStatefulWidget {
  final _StopInfo info;
  final bool isDone;
  final bool isCurrent;
  final int index;
  final VoidCallback onTap;

  const _StopWaypoint({
    required this.info,
    required this.isDone,
    required this.isCurrent,
    required this.index,
    required this.onTap,
  });

  @override
  ConsumerState<_StopWaypoint> createState() => _StopWaypointState();
}

class _StopWaypointState extends ConsumerState<_StopWaypoint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StopWaypoint old) {
    super.didUpdateWidget(old);
    if (widget.isCurrent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stopColor = widget.info.color;

    final Color bg;
    final Color border;
    final Color labelColor;

    if (widget.isDone) {
      bg = Colors.white.withValues(alpha: 0.85);
      border = const Color(0xFF66BB6A);
      labelColor = const Color(0xFF2E7D32);
    } else if (widget.isCurrent) {
      bg = Colors.white.withValues(alpha: 0.92);
      border = stopColor;
      labelColor = stopColor;
    } else {
      bg = Colors.white.withValues(alpha: 0.65);
      border = stopColor.withValues(alpha: 0.5);
      labelColor = stopColor;
    }

    Widget circle = GestureDetector(
      onTap: widget.isDone
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
      child: SizedBox(
        width: 88,
        height: 104,
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: border.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  if (widget.isDone)
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.2),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                ],
              ),
              child: Center(
                child: widget.isDone
                    ? const Icon(Icons.check_rounded,
                        color: Color(0xFF43A047), size: 34)
                    : Text(
                        widget.info.emoji,
                        style: TextStyle(
                          fontSize: 30,
                          color: widget.isCurrent
                              ? null
                              : Colors.grey[400],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDone
                  ? AppS(ref.read(languageProvider) == 'en')('Готово! ✅', 'Done! ✅')
                  : widget.info.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: labelColor,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isCurrent) {
      circle = AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale = 1.0 + _pulse.value * 0.08;
          final glowAlpha = 0.15 + _pulse.value * 0.15;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kStreakOrange.withValues(alpha: glowAlpha),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: circle,
      );
    }

    return circle;
  }
}

// ═══════════════════════════════════════════════════════════════
//  TREASURE WAYPOINT — the goal at the end of the path
// ═══════════════════════════════════════════════════════════════

class _TreasureWaypoint extends ConsumerStatefulWidget {
  final DailyQuestState quest;
  final VoidCallback onClaim;

  const _TreasureWaypoint({required this.quest, required this.onClaim});

  @override
  ConsumerState<_TreasureWaypoint> createState() => _TreasureWaypointState();
}

class _TreasureWaypointState extends ConsumerState<_TreasureWaypoint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  bool get _canClaim =>
      widget.quest.allDone && !widget.quest.rewardClaimed;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (_canClaim) _bounce.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TreasureWaypoint old) {
    super.didUpdateWidget(old);
    if (_canClaim && !_bounce.isAnimating) {
      _bounce.repeat(reverse: true);
    } else if (!_canClaim && _bounce.isAnimating) {
      _bounce.stop();
      _bounce.value = 0;
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClaim = _canClaim;
    final claimed = widget.quest.rewardClaimed;

    Widget treasure = GestureDetector(
      onTap: canClaim
          ? () {
              HapticFeedback.mediumImpact();
              widget.onClaim();
            }
          : null,
      child: SizedBox(
        width: 84,
        height: 110,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: canClaim
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE082), Color(0xFFFFD700), Color(0xFFFFA000)],
                      )
                    : null,
                color: canClaim
                    ? null
                    : claimed
                        ? const Color(0xFFE8F5E9)
                        : Colors.white.withValues(alpha: 0.5),
                border: Border.all(
                  color: canClaim
                      ? const Color(0xFFFFAB00)
                      : claimed
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFD0C8BE),
                  width: 3,
                ),
                boxShadow: canClaim
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  claimed ? '✨' : '🎁',
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              () {
                final ts = AppS(ref.read(languageProvider) == 'en');
                return claimed
                    ? ts('Знайдено! 🎉', 'Found! 🎉')
                    : canClaim
                        ? ts('Відкрий\nскарб!', 'Claim\nreward!')
                        : ts('Скарб 🔒', 'Reward 🔒');
              }(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: canClaim
                    ? const Color(0xFFF57C00)
                    : claimed
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFB0A898),
              ),
            ),
          ],
        ),
      ),
    );

    if (canClaim) {
      treasure = AnimatedBuilder(
        animation: _bounce,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + _bounce.value * 0.1,
          child: child,
        ),
        child: treasure,
      );
    }

    return treasure;
  }
}

// ═══════════════════════════════════════════════════════════════
//  CONFETTI RAIN
// ═══════════════════════════════════════════════════════════════

class _ConfettiRain extends StatefulWidget {
  @override
  State<_ConfettiRain> createState() => _ConfettiRainState();
}

class _ConfettiRainState extends State<_ConfettiRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(progress: _ctrl.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  static final _colors = [
    const Color(0xFFFF6B6B),
    const Color(0xFFFFD93D),
    const Color(0xFF6BCB77),
    const Color(0xFF4D96FF),
    const Color(0xFFFF9FF3),
    const Color(0xFFFFA502),
    const Color(0xFF7B68EE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble();
      final color = _colors[rng.nextInt(_colors.length)];
      final w = 3.0 + rng.nextDouble() * 5;
      final h = rng.nextBool() ? (5.0 + rng.nextDouble() * 8) : w;

      final yNorm = ((progress * speed + phase) % 1.0);
      final y = yNorm * (size.height + 40) - 20;
      final wobble = sin((progress * 6 + phase * pi * 2)) * 12;
      final rotation = progress * pi * 4 * (rng.nextBool() ? 1 : -1);

      paint.color = color.withValues(alpha: (1.0 - yNorm * 0.5).clamp(0.2, 0.7));

      canvas.save();
      canvas.translate(x + wobble, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════
//  LEVITATING CARD (after reward)
// ═══════════════════════════════════════════════════════════════

class _LevitatingCard extends ConsumerStatefulWidget {
  final CardModel card;
  final PackModel pack;

  const _LevitatingCard({required this.card, required this.pack});

  @override
  ConsumerState<_LevitatingCard> createState() => _LevitatingCardState();
}

class _LevitatingCardState extends ConsumerState<_LevitatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, child) {
        final offset = sin(_float.value * pi) * 8;
        final tilt = sin(_float.value * pi) * 0.015;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: Transform.rotate(angle: tilt, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.card.colorBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.card.colorAccent.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.pack.color.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(widget.card.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppS(ref.read(languageProvider) == 'en')(
                        'Сьогоднішній скарб', "Today's reward"),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.pack.color,
                    ),
                  ),
                  Text(
                    widget.card.sound,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: widget.card.colorAccent,
                    ),
                  ),
                ],
              ),
            ),
            Text(widget.pack.icon, style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PACK PICKER SHEET
// ═══════════════════════════════════════════════════════════════

class _PackPickerSheet extends ConsumerStatefulWidget {
  final List<PackModel> lockedPacks;
  final Map<String, int> bonusCards;
  final void Function(PackModel pack) onPick;

  const _PackPickerSheet({
    required this.lockedPacks,
    required this.bonusCards,
    required this.onPick,
  });

  @override
  ConsumerState<_PackPickerSheet> createState() => _PackPickerSheetState();
}

class _PackPickerSheetState extends ConsumerState<_PackPickerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('🎁', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          const Text(
            'Обери розділ!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppS(ref.read(languageProvider) == 'en')(
                'Де відкрити нову картку?', 'Where to open the new card?'),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(widget.lockedPacks.length, (i) {
              final pack = widget.lockedPacks[i];
              final bonus = widget.bonusCards[pack.id] ?? 0;
              final available =
                  pack.cards.length - PackModel.freePreviewCount - bonus;
              final allUnlocked = available <= 0;
              final isSelected = _selectedIndex == i;

              return AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) {
                  final delay = i * 0.1;
                  final t = ((_entryCtrl.value - delay) / (1 - delay))
                      .clamp(0.0, 1.0);
                  final scale = Curves.elasticOut.transform(t);
                  return Transform.scale(
                    scale: scale.clamp(0.0, 1.1),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: allUnlocked
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedIndex = i);
                          Future.delayed(
                              const Duration(milliseconds: 300), () {
                            widget.onPick(pack);
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? pack.color.withValues(alpha: 0.2)
                          : pack.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? pack.color
                            : pack.color.withValues(alpha: 0.2),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: Opacity(
                      opacity: allUnlocked ? 0.35 : 1.0,
                      child: Column(
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(pack.icon,
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pack.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pack.color,
                            ),
                          ),
                          Text(
                            allUnlocked
                                ? '✅'
                                : '${PackModel.freePreviewCount + bonus}/${pack.cards.length}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
