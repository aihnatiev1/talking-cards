import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'card_image.dart';
import 'kid_tap.dart';

/// One secondary step of today's plan, rendered as a 72×72 "stone" under
/// the hero. The [label] is for the grown-up: it shows only under a large
/// text scale and as a long-press tooltip (ux-gap G5 / rule 4).
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

/// The single above-the-fold block on Home (ux-gap G5 «Bloom запрошує»):
/// a 150 dp hero — illustration filling the left ~45 %, Bloom peeking out
/// from behind its right edge, the title and a 72 dp play disc — plus the
/// remaining daily steps as three wordless stones inside the SAME frame.
///
/// Bloom is not built here: the host hands him in as [mascot] so this
/// widget stays free of Riverpod (goldens pass a still `BloomMascot`, the
/// home tab passes the live one). He is painted *under* the illustration in
/// z — the child never sees him cover the picture — and his hit zone stays
/// his own: a tap on Bloom is Bloom's, a tap anywhere else is the hero's.
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

    // Invite breath, 1.0 → 1.02: gentle, because the card is the widest
    // thing on the screen. Stops once the hero's own step is done; under
    // reduced motion it rests at 1.0 — the play disc and the accent frame
    // already say "press me".
    return AmbientLoop(
      period: DT.motion.ambientBreath,
      enabled: !heroDone,
      builder: (_, t, child) => Transform.scale(
        scale: 1.0 + 0.02 * t,
        child: child,
      ),
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
              _HeroPane(
                title: title,
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
    );
  }
}

/// The 150 dp hero row. Stateful only for the illustration bounce on tap
/// (audit A1-9: tap = the word + a bounce, the sheet moves to long-press).
class _HeroPane extends StatefulWidget {
  final String title;
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
    final heroHeight = DT.size.heroHeight;
    final progress = widget.progress;
    // Opaque pane — Bloom's body sits behind it and must not show through
    // a translucent tint.
    final paneColor = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      DT.surfaceWhite,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final artWidth = math.min(
          constraints.maxWidth * DT.size.heroArtFraction,
          DT.size.heroArtMax,
        );

        final art = SizedBox(
          width: artWidth,
          height: heroHeight,
          child: AnimatedBuilder(
            animation: _bounce,
            builder: (_, child) => Transform.scale(
              scale: 1.0 + 0.06 * math.sin(math.pi * _bounce.value),
              child: child,
            ),
            child: Container(
              color: paneColor,
              alignment: Alignment.center,
              // Card-of-the-day may be paid content the asset pack has not
              // delivered yet; CardImage shows the emoji until it lands,
              // then swaps itself for the picture.
              child: CardImage(
                name: widget.image,
                fallbackEmoji: widget.fallbackEmoji,
                size: CardArtSize.hero,
                fit: BoxFit.cover,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        );

        final row = Row(
          children: [
            art,
            Expanded(
              child: Padding(
                // Bloom lives in the lower-left of this column (his box is
                // bottom-aligned to the pane); the title stays in the upper
                // half so the two never meet.
                padding: const EdgeInsets.fromLTRB(
                  DT.sp12,
                  DT.sp16,
                  DT.sp8,
                  DT.sp16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        style: DT.h1.copyWith(
                          fontVariations: DT.kidWeight(900),
                          fontWeight: FontWeight.w900,
                          color: DT.onTint(accent),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: DT.sp8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // The one big affordance: a 72 dp disc a non-reader presses.
            Padding(
              padding: const EdgeInsets.only(right: DT.sp12),
              child: _PlayDisc(accent: accent, done: widget.heroDone),
            ),
          ],
        );

        final mascot = widget.mascot;
        return Semantics(
          button: true,
          label: widget.title,
          child: KidTap(
            onTap: _onTap,
            onLongPress: widget.onLongPress,
            // CardsScreen plays pack_open on entry and the card-of-the-day
            // speaks its word; a tock here too is two sounds for one tap.
            sound: null,
            child: SizedBox(
              height: heroHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Bloom first, so the illustration paints over his body:
                  // he peeks out from behind its right edge, feet on the
                  // pane's bottom line, looking right at the play disc.
                  if (mascot != null)
                    Positioned(
                      left: artWidth - _mascotHidden(context),
                      bottom: -_mascotSlop(context),
                      child: mascot,
                    ),
                  row,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Bloom's figure is centred in a `max(size, tapMin)` hit box; the box
  /// overhangs the figure by this much on every side.
  double _mascotSlop(BuildContext context) {
    final size = DT.size.mascotCompanionOf(context);
    return (math.max(size, DT.size.tapMin) - size) / 2;
  }

  /// How far the mascot box starts left of the illustration's right edge.
  /// Half the figure's square goes behind the picture: the painted body is
  /// narrower than its square, so this is what actually reads as "peeking"
  /// rather than "standing beside".
  double _mascotHidden(BuildContext context) {
    final size = DT.size.mascotCompanionOf(context);
    return size * _hiddenFraction + _mascotSlop(context);
  }

  static const _hiddenFraction = 0.5;
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
        color: done
            ? DT.success.withValues(alpha: 0.12)
            : accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIconView(
        done ? AppIcon.check : AppIcon.play,
        size: 36,
        color: done ? DT.success : accent,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < tasks.length; i++) ...[
          if (i > 0) const SizedBox(width: DT.sp16),
          _Stone(
            key: ValueKey('daily_task_$i'),
            task: tasks[i],
            accent: accent,
            isNext: i == next,
          ),
        ],
      ],
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

    // The caption is for the grown-up: shown only under a large text scale
    // (rule 4 — icons, not words), otherwise reachable by long-press.
    final showLabel = MediaQuery.textScalerOf(context).scale(10) > 12;

    final stone = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: active ? Border.all(color: accent, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      // A done stone keeps its task icon — a bare check says "something
      // happened" but not what; the check rides as a small badge instead.
      child: t.isDone
          ? Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AppIconView(t.icon, size: 36, color: DT.surfaceWhite),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: DT.surfaceWhite,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppIconView(
                      AppIcon.check,
                      size: 16,
                      color: DT.success,
                    ),
                  ),
                ),
              ],
            )
          : Opacity(
              opacity: active || next ? 1.0 : 0.55,
              child: AppIconView(t.icon, size: 36),
            ),
    );

    // Only the active step breathes (1.0 → 1.04). Under reduced motion it
    // keeps its accent border and tint; only the breath is dropped.
    Widget body = AmbientLoop(
      period: DT.motion.ambientPulse,
      enabled: active,
      builder: (_, pulse, child) => Transform.scale(
        scale: 1.0 + 0.04 * pulse,
        child: child,
      ),
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

    if (showLabel) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          const SizedBox(height: DT.sp4),
          SizedBox(
            width: side + DT.sp16,
            child: Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DT.caption.copyWith(
                fontSize: 12,
                color: t.isDone ? DT.success : DT.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

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
