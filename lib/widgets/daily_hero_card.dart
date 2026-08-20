import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/design_tokens.dart';

/// One secondary step of today's plan, rendered as a compact button under the
/// hero. Replaces the old free-standing "stone" in Today's Plan strip.
class DailyTask {
  final String emoji;
  final String label;
  final bool isDone;
  final bool isActive;
  final VoidCallback onTap;

  const DailyTask({
    required this.emoji,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.onTap,
  });
}

/// The single above-the-fold block on Home: one hero (Card of the Day, or
/// "Continue" when a pack is half-finished) plus the remaining daily steps as
/// compact buttons inside the SAME frame.
///
/// Before this, Home stacked two separately-framed cards — hero and Today's
/// Plan — which cost ~80dp of vertical space and made the child choose between
/// two equally-loud entry points. Now there is one obvious thing to tap and the
/// plan reads as its follow-up.
class DailyHeroCard extends StatefulWidget {
  /// Small pill above the title, e.g. '🔊 Картка дня' / '▶ Продовжити'.
  final String badge;
  final String title;
  final Color accent;

  /// webp asset name (without path/extension); falls back to [fallbackEmoji].
  final String? image;
  final String fallbackEmoji;

  /// 0..1 progress for the "Continue" flavour; null hides the bar.
  final double? progress;

  /// The hero's own daily task is already done — swaps the affordance icon
  /// for a check and stops the invite pulse.
  final bool heroDone;
  final VoidCallback onHeroTap;

  /// Daily steps NOT represented by the hero itself.
  final List<DailyTask> tasks;

  /// Every step (including hidden quest tasks) is finished today.
  final bool allDone;
  final VoidCallback? onAllDoneTap;

  final bool isEn;

  const DailyHeroCard({
    super.key,
    required this.badge,
    required this.title,
    required this.accent,
    required this.onHeroTap,
    required this.tasks,
    required this.isEn,
    this.image,
    this.fallbackEmoji = '🃏',
    this.progress,
    this.heroDone = false,
    this.allDone = false,
    this.onAllDoneTap,
  });

  @override
  State<DailyHeroCard> createState() => _DailyHeroCardState();
}

class _DailyHeroCardState extends State<DailyHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Gentler than the old 1.03 hero pulse: the card is taller now, so the
    // same ratio read as the whole screen breathing.
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant DailyHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroDone != widget.heroDone) _syncPulse();
  }

  void _syncPulse() {
    if (widget.heroDone) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final narrow = MediaQuery.of(context).size.width < 360;
    const heroHeight = 96.0;

    final hero = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onHeroTap();
      },
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: SizedBox(
          height: heroHeight,
          child: Row(
            children: [
              // Illustration pane — fixed width keeps intrinsic sizing bounded
              // so the webp never balloons to its natural resolution.
              SizedBox(
                width: narrow ? 78 : 94,
                height: heroHeight,
                child: Container(
                  color: accent.withValues(alpha: 0.10),
                  alignment: Alignment.center,
                  child: widget.image != null
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/webp/${widget.image}.webp',
                            height: heroHeight - 12,
                            fit: BoxFit.contain,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            widget.fallbackEmoji,
                            style: const TextStyle(fontSize: 44),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badge,
                          style: TextStyle(
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
                          widget.title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (widget.progress != null) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.progress!.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: accent.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Affordance: a non-reader needs a visible "press me" mark.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.heroDone
                        ? DT.success.withValues(alpha: 0.12)
                        : accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.heroDone
                        ? Icons.check_rounded
                        : Icons.play_arrow_rounded,
                    size: 24,
                    color: widget.heroDone ? DT.success : accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget footer = widget.allDone
        ? _AllDoneRow(isEn: widget.isEn, onTap: widget.onAllDoneTap)
        : Row(
            children: [
              for (int i = 0; i < widget.tasks.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TaskButton(
                    key: ValueKey('daily_task_$i'),
                    task: widget.tasks[i],
                    accent: accent,
                    // When the pending step is the hero itself, no button is
                    // "active" — mark the first unfinished one as up-next so
                    // the row doesn't read as two disabled controls.
                    isNext: i == widget.tasks.indexWhere((t) => !t.isDone),
                  ),
                ),
              ],
            ],
          );

    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: accent.withValues(alpha: 0.22), width: 1.5),
          boxShadow: DT.shadowSoft(accent),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DT.rLg - 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              hero,
              // Hairline instead of a second frame: the plan belongs to the
              // hero, it isn't a separate card.
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black.withValues(alpha: 0.05),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskButton extends StatefulWidget {
  final DailyTask task;
  final Color accent;

  /// First unfinished step in the row — readable, but without the active
  /// pulse/outline that belongs to a single element at a time.
  final bool isNext;

  const _TaskButton({
    super.key,
    required this.task,
    required this.accent,
    this.isNext = false,
  });

  @override
  State<_TaskButton> createState() => _TaskButtonState();
}

class _TaskButtonState extends State<_TaskButton>
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
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _TaskButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.isActive != widget.task.isActive ||
        oldWidget.task.isDone != widget.task.isDone) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = widget.task.isActive && !widget.task.isDone;
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
    final t = widget.task;
    final active = t.isActive && !t.isDone;
    final accent = widget.accent;

    final next = widget.isNext && !t.isDone && !active;

    final Color bg;
    if (t.isDone) {
      bg = DT.success.withValues(alpha: 0.10);
    } else if (active) {
      bg = accent.withValues(alpha: 0.14);
    } else if (next) {
      bg = accent.withValues(alpha: 0.07);
    } else {
      bg = Colors.black.withValues(alpha: 0.04);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        t.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: ScaleTransition(
          scale: active ? _scale : const AlwaysStoppedAnimation(1.0),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: active ? Border.all(color: accent, width: 1.5) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: t.isDone || active || next ? 1.0 : 0.55,
                  child: Text(
                    t.emoji,
                    style: const TextStyle(fontSize: 22, height: 1),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.isDone
                            ? DT.success
                            : (active || next
                                ? DT.textPrimary
                                : DT.textMuted),
                      ),
                    ),
                  ),
                ),
                if (t.isDone) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_rounded, size: 15, color: DT.success),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDoneRow extends StatelessWidget {
  final bool isEn;
  final VoidCallback? onTap;

  const _AllDoneRow({required this.isEn, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: DT.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 24, height: 1)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isEn ? 'All done today! 🎁' : 'Все на сьогодні готово! 🎁',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
