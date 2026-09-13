import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';
import 'card_image.dart';
import 'kid_tap.dart';

/// One secondary step of today's plan, rendered as a compact button under the
/// hero. Replaces the old free-standing "stone" in Today's Plan strip.
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

/// The single above-the-fold block on Home: one hero (Card of the Day, or
/// "Continue" when a pack is half-finished) plus the remaining daily steps as
/// compact buttons inside the SAME frame.
///
/// Before this, Home stacked two separately-framed cards — hero and Today's
/// Plan — which cost ~80dp of vertical space and made the child choose between
/// two equally-loud entry points. Now there is one obvious thing to tap and the
/// plan reads as its follow-up.
class DailyHeroCard extends StatelessWidget {
  /// Small pill above the title, e.g. 'Картка дня' / 'Продовжити'.
  final String badge;

  /// Sticker in front of [badge]; null for a text-only pill.
  final AppIcon? badgeIcon;
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
    this.badgeIcon,
    this.image,
    this.fallbackEmoji = '🃏',
    this.progress,
    this.heroDone = false,
    this.allDone = false,
    this.onAllDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 360;
    const heroHeight = 96.0;
    final badgeIcon = this.badgeIcon;

    final hero = KidTap(
      onTap: onHeroTap,
      // CardsScreen plays pack_open on entry; a tap here too is two sounds
      // for one gesture.
      sound: null,
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
                // Card-of-the-day may be paid content the asset pack has
                // not delivered yet; CardImage shows the emoji until it
                // lands, then swaps itself for the picture.
                child: CardImage(
                  name: image,
                  fallbackEmoji: fallbackEmoji,
                  padding: const EdgeInsets.all(6),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon first, and big enough to be the badge on
                          // its own; the word beside it is for the parent.
                          if (badgeIcon != null) ...[
                            AppIconView(badgeIcon, size: 18),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            badge,
                            style: DT.caption.copyWith(
                              fontSize: 10,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: DT.h1.copyWith(
                          fontVariations: DT.kidWeight(900),
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
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
                  color: heroDone
                      ? DT.success.withValues(alpha: 0.12)
                      : accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIconView(
                  heroDone ? AppIcon.check : AppIcon.play,
                  size: 24,
                  color: heroDone ? DT.success : accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final Widget footer = allDone
        ? _AllDoneRow(isEn: isEn, onTap: onAllDoneTap)
        : Row(
            children: [
              for (int i = 0; i < tasks.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TaskButton(
                    key: ValueKey('daily_task_$i'),
                    task: tasks[i],
                    accent: accent,
                    // When the pending step is the hero itself, no button is
                    // "active" — mark the first unfinished one as up-next so
                    // the row doesn't read as two disabled controls.
                    isNext: i == tasks.indexWhere((t) => !t.isDone),
                  ),
                ),
              ],
            ],
          );

    // Invite breath, 1.0 → 1.02 over 1600 ms — gentler than the old 1.03
    // hero pulse: the card is taller now, so the same ratio read as the
    // whole screen breathing. Stops once the hero's own step is done;
    // under reduced motion it rests at 1.0 — the play-arrow affordance and
    // the accent frame already say "press me" without the breath.
    return AmbientLoop(
      period: const Duration(milliseconds: 1600),
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

class _TaskButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = task;
    final active = t.isActive && !t.isDone;

    final next = isNext && !t.isDone && !active;

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

    return KidTap(
      onTap: t.onTap,
      // Only the active step breathes (1.0 → 1.04, 1200 ms). Under reduced
      // motion it keeps its accent border and tinted background; only the
      // breath is dropped.
      child: AmbientLoop(
        period: const Duration(milliseconds: 1200),
        enabled: active,
        builder: (_, pulse, child) => Transform.scale(
          scale: 1.0 + 0.04 * pulse,
          child: child,
        ),
        // Icon first (G9): the child reads the sticker, the caption under it
        // is for the grown-up. 72dp tall — the kid-zone minimum target.
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: active ? Border.all(color: accent, width: 1.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: t.isDone || active || next ? 1.0 : 0.55,
                    child: AppIconView(t.icon, size: 32),
                  ),
                  if (t.isDone)
                    const Positioned(
                      right: -6,
                      top: -4,
                      child: AppIconView(AppIcon.check, size: 15),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t.label,
                    maxLines: 1,
                    style: DT.caption.copyWith(
                      fontSize: 11,
                      color: t.isDone
                          ? DT.success
                          : (active || next ? DT.textPrimary : DT.textMuted),
                    ),
                  ),
                ),
              ),
            ],
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
    return KidTap(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: DT.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIconView(AppIcon.rewardGift, size: 26),
            const SizedBox(width: 8),
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
