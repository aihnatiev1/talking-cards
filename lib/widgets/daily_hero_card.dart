import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'card_image.dart';
import 'kid_tap.dart';

/// A localized daily action with an illustration and a completion badge.
class DailyTask {
  final AppIcon icon;
  final String label;
  final bool isDone;
  final bool isActive;
  final VoidCallback onTap;

  const DailyTask({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.onTap,
  });
}

/// Responsive invitation with a framed illustration, a separate mascot slot,
/// and full-width localized actions. Motion is confined to the play button.
class DailyHeroCard extends StatelessWidget {
  final String title;
  final Color accent;

  /// webp asset name (without path/extension); falls back to [fallbackEmoji].
  final String? image;
  final String fallbackEmoji;

  /// 0..1 progress for the "Continue" flavour; null hides the bar.
  final double? progress;

  /// The hero's own daily task is already done — swaps the play disc for a
  /// check and stops the invite breath.
  final bool heroDone;
  final VoidCallback onHeroTap;

  /// Long-press on the hero — the Card-of-the-Day sheet for the parent
  /// (favourites, listen again). Null disables the gesture.
  final VoidCallback? onHeroLongPress;

  /// Bloom S, or null for a hero without him (tests, empty catalogue).
  final Widget? mascot;

  /// Daily steps NOT represented by the hero itself.
  final List<DailyTask> tasks;

  /// Every step (including hidden quest tasks) is finished today.
  final bool allDone;
  final VoidCallback? onAllDoneTap;

  final bool isEn;

  const DailyHeroCard({
    super.key,
    required this.title,
    required this.accent,
    required this.onHeroTap,
    required this.tasks,
    required this.isEn,
    this.onHeroLongPress,
    this.mascot,
    this.image,
    this.fallbackEmoji = '🃏',
    this.progress,
    this.heroDone = false,
    this.allDone = false,
    this.onAllDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget footer = allDone
        ? _AllDoneRow(isEn: isEn, onTap: onAllDoneTap)
        : _StoneRow(tasks: tasks, accent: accent);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionPolicy.of(context).dur(DT.motion.heroArrive),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: DT.shadowSoft(accent),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DT.rLg - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeroPane(
                  title: title,
                  isEn: isEn,
                  accent: accent,
                  image: image,
                  fallbackEmoji: fallbackEmoji,
                  progress: progress,
                  heroDone: heroDone,
                  mascot: mascot,
                  onTap: onHeroTap,
                  onLongPress: onHeroLongPress,
                ),
                // Hairline instead of a second frame: the stones belong to
                // the hero, they are not a separate card.
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: DT.sp12),
                  color: DT.textPrimary.withValues(alpha: 0.06),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DT.sp12,
                    DT.sp8,
                    DT.sp12,
                    DT.sp12,
                  ),
                  child: footer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 150 dp hero row. Stateful only for the illustration bounce on tap
/// (audit A1-9: tap = the word + a bounce, the sheet moves to long-press).
class _HeroPane extends StatefulWidget {
  final String title;
  final bool isEn;
  final Color accent;
  final String? image;
  final String fallbackEmoji;
  final double? progress;
  final bool heroDone;
  final Widget? mascot;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HeroPane({
    required this.title,
    required this.isEn,
    required this.accent,
    required this.image,
    required this.fallbackEmoji,
    required this.progress,
    required this.heroDone,
    required this.mascot,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_HeroPane> createState() => _HeroPaneState();
}

class _HeroPaneState extends State<_HeroPane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: DT.motion.successPop,
  );

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _onTap() {
    // Zero under reduced motion: the controller completes in one frame and
    // the picture never leaves 1.0.
    _bounce.duration = MotionPolicy.of(context).dur(DT.motion.successPop);
    _bounce.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final progress = widget.progress;
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 400;
        final artWidth = math.min(bounds.maxWidth * .36, 225.0);
        final heading = widget.heroDone
            ? (widget.isEn ? 'Well done!' : 'Молодець!')
            : progress != null
            ? (widget.isEn ? 'Let’s continue' : 'Продовжимо гру')
            : (widget.isEn ? 'Discover today' : 'Відкриваємо світ');
        double textHeight(String text, TextStyle style) {
          final painter =
              TextPainter(
                text: TextSpan(
                  text: text,
                  style: DefaultTextStyle.of(context).style.merge(style),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(
                maxWidth: math.max(
                  1,
                  bounds.maxWidth - artWidth - (compact ? 24 : 42),
                ),
              );
          final height = painter.height;
          painter.dispose();
          return height;
        }

        final paneHeight = math.max(
          compact ? 194.0 : 228.0,
          40 +
              7 +
              16 +
              76 +
              (progress == null ? 0 : 18) +
              textHeight(heading, DT.caption.copyWith(fontSize: 12)) +
              textHeight(
                widget.title,
                DT.h1.copyWith(fontSize: compact ? 21 : 26, height: 1.15),
              ),
        );
        final content = Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 20,
            20,
            compact ? 12 : 22,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                heading,
                style: DT.caption.copyWith(
                  color: DT.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.title,
                style: DT.h1.copyWith(
                  fontSize: compact ? 21 : 26,
                  color: DT.onTint(accent),
                  height: 1.15,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                    duration: MotionPolicy.of(
                      context,
                    ).dur(DT.motion.heroProgress),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: accent.withValues(alpha: .1),
                      color: accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  AmbientLoop(
                    period: DT.motion.heroHop,
                    settleAfter: DT.motion.heroHopSettle,
                    enabled: !widget.heroDone,
                    builder: (_, t, child) => Transform.translate(
                      offset: Offset(0, -3 * t),
                      child: Transform.rotate(
                        angle: -.045 * math.sin(t * math.pi),
                        child: child,
                      ),
                    ),
                    child: _PlayDisc(accent: accent, done: widget.heroDone),
                  ),
                  if (widget.mascot != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 68,
                          height: 76,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: widget.mascot!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
        return Semantics(
          button: true,
          label: widget.title,
          child: KidTap(
            onTap: _onTap,
            onLongPress: widget.onLongPress,
            sound: null,
            child: SizedBox(
              height: paneHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: artWidth,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 18,
                        18,
                        0,
                        18,
                      ),
                      child: AnimatedBuilder(
                        animation: _bounce,
                        builder: (_, child) => Transform.scale(
                          scale: 1.0 + .035 * math.sin(math.pi * _bounce.value),
                          child: child,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 150),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CardImage(
                              name: widget.image,
                              fallbackEmoji: widget.fallbackEmoji,
                              size: CardArtSize.hero,
                              fit: BoxFit.contain,
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayDisc extends StatelessWidget {
  final Color accent;
  final bool done;

  const _PlayDisc({required this.accent, required this.done});

  @override
  Widget build(BuildContext context) {
    final side = DT.size.tapMin;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(done ? DT.success : accent, Colors.white, .25)!,
            done ? DT.success : accent,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .2),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AppIconView(
        done ? AppIcon.check : AppIcon.play,
        size: 36,
        color: Colors.white,
      ),
    );
  }
}

class _StoneRow extends StatelessWidget {
  final List<DailyTask> tasks;
  final Color accent;

  const _StoneRow({required this.tasks, required this.accent});

  @override
  Widget build(BuildContext context) {
    // When the pending step is the hero itself, no stone is "active" — mark
    // the first unfinished one as up-next so the row doesn't read as a set
    // of disabled controls.
    final next = tasks.indexWhere((t) => !t.isDone);
    return LayoutBuilder(
      builder: (context, box) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final count = largeText || box.maxWidth < 290
            ? 1
            : math.min(tasks.length, 3);
        final width = count == 0
            ? box.maxWidth
            : (box.maxWidth - (count - 1) * 10) / count;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < tasks.length; i++)
              SizedBox(
                width: width,
                child: _Stone(
                  key: ValueKey('daily_task_$i'),
                  task: tasks[i],
                  accent: accent,
                  isNext: i == next,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One 72×72 wordless step. Green with a check once done; the moment it
/// turns green *while the child can see it* it pops and sparkles with the
/// small-success sound (spec: `sparkle` → role `successSmall`).
class _Stone extends StatefulWidget {
  final DailyTask task;
  final Color accent;

  /// First unfinished step in the row — readable, but without the active
  /// pulse/outline that belongs to a single element at a time.
  final bool isNext;

  const _Stone({
    super.key,
    required this.task,
    required this.accent,
    this.isNext = false,
  });

  @override
  State<_Stone> createState() => _StoneState();
}

class _StoneState extends State<_Stone> with SingleTickerProviderStateMixin {
  late final AnimationController _sparkle = AnimationController(
    vsync: this,
    duration: DT.motion.celebrate,
    // Rests at the end: the painter draws nothing at t = 1.
    value: 1,
  );

  /// A done-flip arrived while the tab was off stage (the step is usually
  /// finished on another route); the sparkle waits for the child to come
  /// back so the sound lands on a screen she is looking at.
  bool _pending = false;

  @override
  void didUpdateWidget(_Stone old) {
    super.didUpdateWidget(old);
    if (widget.task.isDone && !old.task.isDone) _pending = true;
    if (!widget.task.isDone) _pending = false;
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  void _fire() {
    if (!mounted || !_pending) return;
    _pending = false;
    FeedbackService.instance.event(FeedbackEvent.correct);
    _sparkle.duration = MotionPolicy.of(context).dur(DT.motion.celebrate);
    _sparkle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Registers a dependency: when the tab comes back on stage the build
    // reruns and the deferred sparkle fires.
    if (_pending && TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fire());
    }

    final t = widget.task;
    final accent = widget.accent;
    final active = t.isActive && !t.isDone;
    final next = widget.isNext && !t.isDone && !active;
    final side = DT.size.tapMin;

    final Color bg;
    if (t.isDone) {
      bg = DT.success;
    } else if (active) {
      bg = accent.withValues(alpha: 0.14);
    } else if (next) {
      bg = accent.withValues(alpha: 0.07);
    } else {
      bg = DT.textPrimary.withValues(alpha: 0.05);
    }

    final stone = Container(
      constraints: BoxConstraints(minHeight: side),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: t.isDone ? DT.success.withValues(alpha: .09) : bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (t.isDone ? DT.success : accent).withValues(alpha: .16),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, height: 32, child: AppIconView(t.icon, size: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.label,
              style: DT.caption.copyWith(
                fontSize: 13,
                height: 1.2,
                color: DT.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (t.isDone) ...[
            const SizedBox(width: 4),
            const AppIconView(AppIcon.check, size: 19, color: DT.success),
          ],
        ],
      ),
    );

    // Only the active step breathes (1.0 → 1.04). Under reduced motion it
    // keeps its accent border and tint; only the breath is dropped.
    Widget body = AmbientLoop(
      period: DT.motion.ambientPulse,
      enabled: active,
      settleAfter: const Duration(seconds: 4),
      builder: (_, pulse, child) =>
          Transform.scale(scale: 1.0 + 0.04 * pulse, child: child),
      child: AnimatedBuilder(
        animation: _sparkle,
        builder: (_, child) {
          final v = _sparkle.value;
          // Pop 1 → 1.10 → 1 across the first 40 % of the sparkle.
          final pop = math.sin(math.pi * (v / 0.4).clamp(0.0, 1.0));
          return Transform.scale(
            scale: 1.0 + 0.10 * pop,
            child: CustomPaint(
              foregroundPainter: _SparklePainter(v),
              child: child,
            ),
          );
        },
        child: stone,
      ),
    );

    return Tooltip(
      message: t.label,
      child: KidTap(onTap: t.onTap, child: body),
    );
  }
}

/// Six sparks flying out of the stone and fading; nothing at t = 1.
class _SparklePainter extends CustomPainter {
  final double t;

  const _SparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * (0.45 + 0.5 * t);
    final alpha = (1 - t).clamp(0.0, 1.0);
    final radius = 3.0 * (1 - 0.6 * t);
    final paint = Paint()..color = DT.sunBurst.withValues(alpha: alpha);
    final core = Paint()..color = DT.surfaceWhite.withValues(alpha: alpha);
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawCircle(p, radius, paint);
      canvas.drawCircle(p, radius * 0.4, core);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

class _AllDoneRow extends StatelessWidget {
  final bool isEn;
  final VoidCallback? onTap;

  const _AllDoneRow({required this.isEn, this.onTap});

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: onTap,
      child: Container(
        height: DT.size.tapMin,
        decoration: BoxDecoration(
          color: DT.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DT.rMd),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIconView(AppIcon.rewardGift, size: 26),
            const SizedBox(width: DT.sp8),
            Flexible(
              child: Text(
                isEn ? 'All done today!' : 'Все на сьогодні готово!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // One green: the done-tint's own ink, not the brand indigo.
                style: DT.tileTitle.copyWith(
                  fontSize: 14,
                  color: PackPalette.of(DT.success).onTint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
