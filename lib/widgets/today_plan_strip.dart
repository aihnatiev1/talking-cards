import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import 'bloom_mascot.dart';

/// One node in the Today's Plan path.
class TodayPlanStone {
  final String emoji;
  final String label;
  final bool isDone;
  final bool isActive;
  final VoidCallback onTap;

  const TodayPlanStone({
    required this.emoji,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.onTap,
  });
}

/// Lingokids-style "Today's Plan" strip — 3 stones showing today's core path.
///
/// Maps to [QuestTask.listenCardOfDay], [QuestTask.viewCards3], [QuestTask.playQuiz]
/// so the strip is backed by [dailyQuestProvider] state (no new state).
class TodayPlanStrip extends StatelessWidget {
  final List<TodayPlanStone> stones;
  final String lang;
  final VoidCallback onViewAll;

  const TodayPlanStrip({
    super.key,
    required this.stones,
    required this.lang,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(lang);
    final scale = screenScale(context);

    return Container(
      height: 118 * scale.clamp(1.0, 1.15),
      decoration: BoxDecoration(
        color: DT.surfaceWhite,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: DT.shadowSoft(kAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: label badge + "View all" chevron (parent-facing).
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s('📅 Сьогодні', '📅 Today\'s Plan'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kAccent,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onViewAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      s('Деталі ›', 'View all ›'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: _StoneRow(stones: stones),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, warm done-state card shown instead of the strip once the daily
/// plan is finished. Stays alive instead of going dead: Bloom waves, and the
/// whole card is one big tap target — treasure box if the child already has
/// learned words, the day's reward otherwise.
class TodayPlanDoneCard extends StatelessWidget {
  final String lang;

  /// Child has at least one learned word — the card advertises and opens
  /// the treasure box.
  final bool hasTreasure;
  final VoidCallback onTap;

  const TodayPlanDoneCard({
    super.key,
    required this.lang,
    required this.hasTreasure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(lang);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        // Kid-sized tap target; roughly half the old 118dp done block.
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAccent.withValues(alpha: 0.14),
              kTeal.withValues(alpha: 0.20),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(
            color: kAccent.withValues(alpha: 0.25),
            width: 2,
          ),
          boxShadow: DT.shadowSoft(kAccent),
        ),
        child: Row(
          children: [
            const BloomMascot(
              size: 48,
              emotion: BloomEmotion.waving,
              interactive: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s('Молодець! Завтра — нова пригода',
                        'All done! New adventure tomorrow'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kAccent,
                      height: 1.2,
                    ),
                  ),
                  if (hasTreasure) ...[
                    const SizedBox(height: 2),
                    Text(
                      s('Зазирни у скарбничку', 'Peek in your treasure box'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hasTreasure ? '🎁' : '🎉',
              style: const TextStyle(fontSize: 24, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoneRow extends StatelessWidget {
  final List<TodayPlanStone> stones;

  const _StoneRow({required this.stones});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < stones.length; i++) ...[
          if (i > 0) const _Connector(),
          Expanded(
            child: _StoneCircle(
              key: ValueKey('stone_$i'),
              stone: stones[i],
            ),
          ),
        ],
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    // Tiny dashed trail between stones — purely decorative.
    final dotColor = Colors.grey[300];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '·',
                style: TextStyle(
                  fontSize: 18,
                  color: dotColor,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoneCircle extends StatefulWidget {
  final TodayPlanStone stone;

  const _StoneCircle({super.key, required this.stone});

  @override
  State<_StoneCircle> createState() => _StoneCircleState();
}

class _StoneCircleState extends State<_StoneCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _StoneCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stone.isActive != widget.stone.isActive ||
        oldWidget.stone.isDone != widget.stone.isDone) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = widget.stone.isActive && !widget.stone.isDone;
    if (shouldPulse) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
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
    final s = widget.stone;
    final isActive = s.isActive && !s.isDone;
    final isPending = !s.isActive && !s.isDone;

    // Circle style varies by state so the active stone clearly "invites" tap.
    final Color circleBg;
    final double emojiOpacity;
    final Border? border;
    final List<BoxShadow>? shadow;
    if (s.isDone) {
      circleBg = kAccent.withValues(alpha: 0.15);
      emojiOpacity = 1.0;
      border = null;
      shadow = null;
    } else if (isActive) {
      circleBg = kAccent.withValues(alpha: 0.20);
      emojiOpacity = 1.0;
      border = Border.all(color: kAccent, width: 2);
      shadow = DT.shadowSoft(kAccent);
    } else {
      // pending
      circleBg = kAccent.withValues(alpha: 0.10);
      emojiOpacity = 0.5;
      border = null;
      shadow = null;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        s.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: ScaleTransition(
          scale: isActive ? _scale : const AlwaysStoppedAnimation(1.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: circleBg,
                        shape: BoxShape.circle,
                        border: border,
                        boxShadow: shadow,
                      ),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: emojiOpacity,
                        child: Text(
                          s.emoji,
                          style: const TextStyle(fontSize: 28, height: 1),
                        ),
                      ),
                    ),
                    if (s.isDone)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green[400],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPending ? Colors.grey[500] : DT.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
