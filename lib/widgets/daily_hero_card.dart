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
  final VoidCallback? onLongPress;

  const DailyTask({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
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

  /// Steps of today's route, as `2 з 5 виконано`. This is the line that
  /// answers "how much is left" — minutes are a guess, steps are a fact.
  /// Null on the first visit, where there is no progress to show yet.
  final int? stepsDone;
  final int stepsTotal;

  /// Rough minutes left, shown small under the steps. Secondary on
  /// purpose: a parent plans by it, a child does not read it.
  final int? minutesLeft;

  /// Nothing has been done on this profile yet: the card stops being a
  /// progress report and becomes an invitation — a shorter first session
  /// (3 minutes, 4 words) and no progress bar, because a bar at 0 % is a
  /// worse greeting than no bar at all.
  final bool firstVisit;

  /// The one short line Bloom says inside the card, and it always names
  /// the next action ("Далі: скажи «жаба»"), never motivation for its own
  /// sake. Null hides the line.
  final String? bloomLine;

  final bool isEn;
  final String? actionLabel;
  final bool collapseTasks;

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
    this.stepsDone,
    this.stepsTotal = 5,
    this.minutesLeft,
    this.firstVisit = false,
    this.bloomLine,
    this.actionLabel,
    this.collapseTasks = false,
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
                  actionLabel: actionLabel,
                  isEn: isEn,
                  accent: accent,
                  image: image,
                  fallbackEmoji: fallbackEmoji,
                  progress: progress,
                  heroDone: heroDone,
                  mascot: mascot,
                  onTap: onHeroTap,
                  onLongPress: onHeroLongPress,
                  stepsDone: stepsDone,
                  stepsTotal: stepsTotal,
                  minutesLeft: minutesLeft,
                  firstVisit: firstVisit,
                  bloomLine: bloomLine,
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
                    DT.sp8,
                  ),
                  child: collapseTasks && !allDone
                      ? ExpansionTile(
                          expansionAnimationStyle: AnimationStyle(
                            duration: MotionPolicy.of(
                              context,
                            ).dur(DT.motion.base),
                          ),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          childrenPadding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                          ),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            isEn
                                ? 'Choose another activity'
                                : 'Обрати інше заняття',
                            style: DT.caption,
                          ),
                          children: [footer],
                        )
                      : footer,
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
  final String? actionLabel;
  final bool isEn;
  final Color accent;
  final String? image;
  final String fallbackEmoji;
  final double? progress;
  final bool heroDone;
  final Widget? mascot;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? stepsDone;
  final int stepsTotal;
  final int? minutesLeft;
  final bool firstVisit;
  final String? bloomLine;

  const _HeroPane({
    required this.title,
    required this.actionLabel,
    required this.isEn,
    required this.accent,
    required this.image,
    required this.fallbackEmoji,
    required this.progress,
    required this.heroDone,
    required this.mascot,
    required this.onTap,
    required this.onLongPress,
    required this.stepsDone,
    required this.stepsTotal,
    required this.minutesLeft,
    required this.firstVisit,
    required this.bloomLine,
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
        final roomy = bounds.maxWidth >= 560;
        final heading = widget.firstVisit
            ? (widget.isEn ? 'Starting out' : 'Починаємо')
            : widget.heroDone
            ? (widget.isEn ? 'Well done!' : 'Молодець!')
            : (widget.isEn ? 'Today' : 'Сьогодні');
        final done = widget.stepsDone;
        final fact = done == null
            ? null
            : widget.isEn
            ? '$done of ${widget.stepsTotal} done'
            : '$done з ${widget.stepsTotal} виконано';
        final action =
            widget.actionLabel ??
            (widget.heroDone
                ? (widget.isEn ? 'Play again' : 'Ще раз')
                : (widget.isEn ? 'Let’s play' : 'Нумо грати'));
        final art = SizedBox(
          height: roomy ? 230 : 158,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: .16),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -.055,
                child: AnimatedBuilder(
                  animation: _bounce,
                  builder: (_, child) => Transform.scale(
                    scale: 1 + .04 * math.sin(math.pi * _bounce.value),
                    child: child,
                  ),
                  child: Container(
                    width: roomy ? 154 : 138,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .16),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CardImage(
                        name: widget.image,
                        fallbackEmoji: widget.fallbackEmoji,
                        size: CardArtSize.hero,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.mascot != null)
                Positioned(
                  right: roomy ? 2 : 28,
                  bottom: 0,
                  child: SizedBox(
                    width: roomy ? 100 : 80,
                    height: roomy ? 112 : 90,
                    child: FittedBox(child: widget.mascot!),
                  ),
                ),
            ],
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heading, style: DT.caption.copyWith(color: DT.textSecondary)),
            const SizedBox(height: 6),
            Text(
              widget.title,
              style: DT.h1.copyWith(
                fontSize: roomy ? 28 : 24,
                height: 1.15,
                color: DT.onTint(accent),
              ),
            ),
            if (widget.bloomLine != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.bloomLine!,
                style: DT.caption.copyWith(fontSize: 14, height: 1.4),
              ),
            ],
            if (fact != null) ...[
              const SizedBox(height: 14),
              Text(fact, style: DT.caption.copyWith(color: DT.onTint(accent))),
            ],
            if (!widget.firstVisit && progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: MotionPolicy.of(
                    context,
                  ).dur(DT.motion.heroProgress),
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 7,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: .10),
                  ),
                ),
              ),
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (roomy)
                Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    SizedBox(width: 230, child: art),
                  ],
                )
              else ...[
                art,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: copy),
              ],
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: action,
                child: KidTap(
                  onTap: _onTap,
                  onLongPress: widget.onLongPress,
                  sound: null,
                  child: Container(
                    key: const ValueKey('daily-primary-action'),
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Color.lerp(accent, Colors.black, .22)!,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            action,
                            textAlign: TextAlign.center,
                            style: DT.tileTitle.copyWith(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const AppIconView(
                          AppIcon.play,
                          size: 26,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        );
      },
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
        final scaler = MediaQuery.textScalerOf(context);
        final largeText = scaler.scale(14) > 21;
        final three = math.min(tasks.length, 3);
        final threeWide = three == 0
            ? box.maxWidth
            : (box.maxWidth - (three - 1) * 10) / three;
        // A fixed text-scale threshold let «Adventure» break into
        // «Adventur / e» on a 390 pt phone at iOS XXL (≈×1.3, below the
        // ×1.5 cut-off). Words are never split: if the longest word of any
        // label cannot fit a third of the row, the stones stack instead.
        final count =
            largeText ||
                box.maxWidth < 290 ||
                !_wordsFit(tasks, threeWide - _Stone.horizontalChrome, scaler)
            ? 1
            : three;
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

/// Whether every word of every label fits [inner] on one line, at the
/// text scale the child's device asks for.
bool _wordsFit(List<DailyTask> tasks, double inner, TextScaler scaler) {
  for (final t in tasks) {
    for (final word in t.label.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: _Stone.labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > inner) return false;
    }
  }
  return true;
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

  /// The label's style — shared with [_StoneRow], which measures it.
  static final TextStyle labelStyle = DT.caption.copyWith(
    fontSize: 13,
    height: 1.2,
    color: DT.textPrimary,
    fontWeight: FontWeight.w800,
  );

  /// Horizontal padding (12 + 12) and border (1 + 1) around the label.
  static const double horizontalChrome = 26;

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
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxWidth < 140;
          final icon = Stack(
            clipBehavior: Clip.none,
            children: [
              AppIconView(t.icon, size: compact ? 36 : 32),
              if (t.isDone)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: DT.surfaceWhite,
                      shape: BoxShape.circle,
                    ),
                    child: const AppIconView(
                      AppIcon.check,
                      size: 16,
                      color: DT.success,
                    ),
                  ),
                ),
            ],
          );
          final label = Text(
            t.label,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: _Stone.labelStyle,
          );
          return compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(height: 8), label],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: label),
                  ],
                );
        },
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
      child: KidTap(onTap: t.onTap, onLongPress: t.onLongPress, child: body),
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

/// The end of the day: what was done, a quiet way into the library, and
/// what waits tomorrow.
///
/// It used to be one green bar saying "All done today!" and it is still
/// that shape — but the control is now secondary and named ("Обрати гру"),
/// because a card that says "finished" and then pushes another lesson is
/// arguing with itself.
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
            const AppIconView(AppIcon.navGames, size: 26),
            const SizedBox(width: DT.sp8),
            Flexible(
              child: Text(
                isEn ? 'Pick a game' : 'Обрати гру',
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
