import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// Compact daily-quest progress tile shown next to [CardOfDayHero].
///
/// Shows a small progress ring around the chest so the child sees how close
/// they are to "opening" today's reward.
class TreasureCard extends StatefulWidget {
  final int done;
  final int total;
  final bool isEn;
  final VoidCallback onTap;

  const TreasureCard({
    super.key,
    required this.done,
    required this.total,
    required this.onTap,
    this.isEn = false,
  });

  @override
  State<TreasureCard> createState() => _TreasureCardState();
}

class _TreasureCardState extends State<TreasureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  late final Animation<double> _bobOffset;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _bobOffset = Tween<double>(begin: 0, end: -3).animate(
      CurvedAnimation(parent: _bob, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = DT.peach;
    final allDone = widget.done >= widget.total;
    final progress =
        widget.total > 0 ? (widget.done / widget.total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(
              color: accent.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: DT.shadowSoft(accent),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DT.rLg - 2),
            child: Row(
              children: [
                // Chest pane — progress ring around a bobbing treasure
                SizedBox(
                  width: 92,
                  child: Container(
                    color: accent.withValues(alpha: 0.12),
                    child: Center(
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 68,
                              height: 68,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor:
                                    accent.withValues(alpha: 0.22),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _bobOffset,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _bobOffset.value),
                                child: child,
                              ),
                              child: Text(
                                allDone ? '🏆' : '🎁',
                                style: const TextStyle(fontSize: 34),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.isEn ? '🗺️ Quest' : '🗺️ Скарб',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            allDone
                                ? (widget.isEn ? 'Done! 🎉' : 'Готово!')
                                : '${widget.done} / ${widget.total}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
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
