import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../providers/streak_provider.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../utils/uk_grammar.dart';
import '../widgets/app_icon_painters.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// The child's sticker album (ux-gap-audit 2026-09-13 G14).
///
/// It used to be a "Badges / Bonus cards" board of 🥉🥈🥇🏆 and ❓🔒 — two
/// grids of the same four milestones, read by nobody under four. An album
/// is the form children already know from Khan Kids and Duolingo ABC:
/// drawn stickers on paper, the ones you have in colour, the ones you do
/// not as a **silhouette** — never a padlock, because a padlock says
/// "forbidden" where a silhouette says "there is something here and it can
/// be yours".
///
/// [RewardsAlbum] is the page itself so it can live both as its own route
/// ([RewardsScreen]) and as the «Наліпки» tab of the treasure box
/// (`KidWordWallScreen`).
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) => const KidScreen(
        accent: DT.peach,
        body: RewardsAlbum(),
      );
}

/// The album page: Bloom holding it in the header, then the sticker sheet.
class RewardsAlbum extends ConsumerWidget {
  const RewardsAlbum({super.key, this.showHeader = true});

  /// The tab inside the treasure box already has a header of its own, so
  /// it asks for the sheet alone.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final earned = streak.unlockedRewards;

    return ListView(
      padding: const EdgeInsets.fromLTRB(DT.sp16, DT.sp8, DT.sp16, DT.sp24),
      children: [
        if (showHeader) ...[
          _AlbumHeader(streak: streak.currentStreak, isEn: isEn),
          const SizedBox(height: DT.sp16),
        ],
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: DT.sp12,
          crossAxisSpacing: DT.sp12,
          childAspectRatio: 0.92,
          children: [
            for (final m in milestones)
              _StickerPage(
                key: ValueKey('sticker_${m.days}'),
                milestone: m,
                earned: earned.contains(m.id),
                isEn: isEn,
              ),
          ],
        ),
      ],
    );
  }
}

/// Bloom **L** holding the album, with the streak count beside him.
///
/// Bloom has no "album" prop in the rig (§2.3 knows `none` and `wand`), so
/// the book is a drawn sticker tucked against his right paw — the read is
/// "he is holding it", without inventing a rig state this one screen would
/// be the only user of.
class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.streak, required this.isEn});

  final int streak;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final palette = PackPalette.of(DT.peach);
    return Container(
      padding: const EdgeInsets.fromLTRB(DT.sp16, DT.sp8, DT.sp16, DT.sp8),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(DT.rXl),
        border: Border.all(color: palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DT.size.mascotLg,
            height: DT.size.mascotLg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                BloomMascot(
                  size: DT.size.mascotLg,
                  state: const BloomState.still(BloomEmotion.happy),
                  interactive: false,
                ),
                Positioned(
                  left: 0,
                  bottom: DT.sp12,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: const AppIconView(
                      AppIcon.stickerAlbum,
                      size: 56,
                      sticker: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DT.sp12),
          if (streak > 0)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const AppIconView(AppIcon.streakFlame, size: 36),
                      const SizedBox(width: DT.sp4),
                      Text(
                        '$streak',
                        style: DT.display.copyWith(color: palette.onTint),
                      ),
                    ],
                  ),
                  Text(
                    isEn
                        ? (streak == 1 ? 'day in a row' : 'days in a row')
                        : '${dayWord(streak)} поспіль',
                    style: DT.caption,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The page's tint and label colour. Mostly the sticker's own accent
/// ([defaultColorOf]), except where that accent is a pale tint chosen for
/// the drawing (the unicorn's coat) and would leave the page and its name
/// without contrast.
Color _pageAccent(AppIcon sticker) => switch (sticker) {
      AppIcon.stickerUnicorn => DT.pink,
      _ => defaultColorOf(sticker),
    };

/// One page of the album: the sticker (or its silhouette) and its name.
///
/// Earned → a tap bounces it and plays the success row of
/// [FeedbackService]; it is the only reward on the screen that answers a
/// finger, which is the whole point of collecting them. Not earned → the
/// paper shape; a tap answers with the soft "heard you, not this one" row
/// and moves nothing. How it is earned («3 дні поспіль») is a parent's
/// sentence, so it lives behind a long-press.
class _StickerPage extends StatefulWidget {
  const _StickerPage({
    super.key,
    required this.milestone,
    required this.earned,
    required this.isEn,
  });

  final Milestone milestone;
  final bool earned;
  final bool isEn;

  @override
  State<_StickerPage> createState() => _StickerPageState();
}

class _StickerPageState extends State<_StickerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: DT.motion.celebrate,
  );

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!widget.earned) {
      // Not a lock, not a miss: the album simply has nothing to give here
      // yet. One quiet note so the tap is never silent (CLAUDE.md rule 2).
      FeedbackService.instance.event(FeedbackEvent.lockedHint);
      return;
    }
    FeedbackService.instance.event(FeedbackEvent.correct);
    if (MotionPolicy.of(context).reduce) return;
    _bounce
      ..reset()
      ..forward();
  }

  void _onLongPress() {
    final m = widget.milestone;
    final s = AppS(widget.isEn);
    final days = widget.isEn
        ? '${m.days} days in a row'
        : '${m.days} ${dayWord(m.days)} поспіль';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.earned
                ? s('Отримано за $days', 'Earned for $days')
                : s('З’явиться за $days', 'Appears after $days'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final palette = PackPalette.of(_pageAccent(m.sticker));
    return KidTap(
      // The sticker itself is the sound (success row / quiet "not yet"),
      // so no tock piles on top of it.
      sound: null,
      haptic: false,
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: widget.earned ? palette.tint : Colors.white,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(
            color: widget.earned ? palette.border : DT.textMuted.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: widget.earned ? DT.shadowSoft(palette.accent) : DT.shadowRest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) {
                // One hop: up to 1.22 and back, with a small tilt — the
                // sticker "peels" off the page and settles again.
                final t = _bounce.value;
                final pop = math.sin(t * math.pi);
                return Transform.rotate(
                  angle: 0.12 * math.sin(t * math.pi * 2),
                  child: Transform.scale(scale: 1 + 0.22 * pop, child: child),
                );
              },
              child: widget.earned
                  ? AppIconView(
                      m.sticker,
                      size: 72,
                      semanticLabel: m.name(widget.isEn),
                    )
                  : AppIconView(
                      m.sticker,
                      size: 72,
                      // The paper shape: dark enough to be an object, pale
                      // enough to read as "not here yet".
                      silhouette: DT.textMuted.withValues(alpha: 0.30),
                      semanticLabel: m.name(widget.isEn),
                    ),
            ),
            const SizedBox(height: DT.sp8),
            Text(
              m.name(widget.isEn),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.tileTitle.copyWith(
                fontSize: responsiveFont(context, 15),
                color: widget.earned ? palette.onTint : DT.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
