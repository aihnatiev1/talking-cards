import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/content_pack_provider.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'app_icon_painters.dart';
import 'card_image.dart';
import 'kid_tap.dart';
import 'pack_cover_hero.dart';

class PackGridCard extends ConsumerStatefulWidget {
  final PackModel pack;
  final VoidCallback onTap;
  final bool isCompleted;
  final int progress;
  final bool isSeasonal;

  const PackGridCard({
    super.key,
    required this.pack,
    required this.onTap,
    this.isCompleted = false,
    this.progress = 0,
    this.isSeasonal = false,
  });

  static TextStyle get titleStyle =>
      DT.tileTitle.copyWith(fontSize: 16, height: 1.25);

  /// Measure real translated labels at the system text size. The grid keeps
  /// the illustration legible instead of squeezing a long title to fit.
  static SliverGridDelegateWithFixedCrossAxisCount gridDelegate(
    BuildContext context,
    double width,
    Iterable<String> titles, {
    bool compact = false,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final columns = width < 300 || scaler.scale(16) > 24
        ? 1
        : width >= 650
        ? 3
        : 2;
    final tileWidth = (width - 16 * (columns - 1)) / columns;
    var titleHeight = scaler.scale(20.0);
    for (final title in titles) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(1, tileWidth - 24));
      titleHeight = math.max(titleHeight, painter.height);
      painter.dispose();
    }
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 18,
      mainAxisExtent:
          math.min(tileWidth * (compact ? .75 : 1), 250) + titleHeight + 35,
    );
  }

  @override
  ConsumerState<PackGridCard> createState() => _PackGridCardState();
}

class _PackGridCardState extends ConsumerState<PackGridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobble;
  late final Animation<double> _wobbleRotation;

  @override
  void initState() {
    super.initState();
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _wobbleRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 1),
    ]).animate(_wobble);
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  void _triggerWobble() {
    HapticFeedback.mediumImpact();
    _wobble.duration = MotionPolicy.of(
      context,
    ).dur(const Duration(milliseconds: 600));
    _wobble
      ..reset()
      ..forward();
  }

  CardModel? _thumb() {
    // Virtual packs (favorites / review / seasonal aliases prefixed with _)
    // own a semantic emoji (❤️ / 🔄) — never replace it with a random card
    // image, otherwise the "Favorites" tile picks whatever the first liked
    // card happens to be.
    if (widget.pack.id.startsWith('_')) return null;
    // Prefer the first card with a real webp illustration — a readable preview
    // for a non-reader. Falls back to the pack emoji when nothing fits.
    for (final c in widget.pack.cards) {
      if (c.image != null) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final total = pack.cards.length;
    final hasProgress = widget.progress > 0 && !widget.isCompleted;
    final thumb = _thumb();
    final accent = pack.color;
    // An owned paid pack whose illustrations are still arriving from Play.
    final downloading =
        !pack.isLocked &&
        !pack.isFree &&
        !ref.watch(contentPackProvider).isReady;

    Widget tile = KidTap(
      // One gesture, one sound: the box opening (`pack_open`, played by
      // CardsScreen on entry) replaces the tock here. The paywall branch
      // of the tap plays its own tock (packs_tab._onPackTap).
      sound: null,
      onTap: widget.onTap,
      onLongPress: _triggerWobble,
      child: Container(
        // One quiet neutral base for every tile: nine differently-tinted
        // frames side by side read as noise. The category colour now lives
        // only in the title (and the progress bar).
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: DT.outline, width: 2),
          boxShadow: const [BoxShadow(color: DT.outline, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DT.rLg - 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Illustration area — takes most of the tile so the webp
              // actually reads at a glance. No inner padding: let the image
              // hug the corners of the tinted pane.
              Expanded(
                flex: 6,
                child: Container(
                  color: accent.withValues(alpha: 0.05),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        // The picture flies to the CardsScreen header on
                        // open (motion audit §5). This tile is the only
                        // take-off point for the tag; see PackCoverHero.
                        child: PackCoverHero(
                          pack: pack,
                          // Cover, else a card thumb, else the pack icon —
                          // and the icon also stands in while the artwork
                          // is still downloading, which this tile used to
                          // render as an empty pane (and a fatal report).
                          // The virtual packs have a painted picture of
                          // their own — the favourites were a ❤️ emoji.
                          child: _virtualArt[pack.id] != null
                              ? Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: AppArt(_virtualArt[pack.id]!),
                                )
                              : CardImage(
                                  name: pack.cover ?? thumb?.image,
                                  fallbackEmoji: pack.icon,
                                  // Sound packs (Р/Л/Ш…) carry a bare letter as
                                  // their icon; while the cover is still on its
                                  // way it is drawn as a paper sticker in the
                                  // pack colour rather than a font glyph.
                                  fallback: isLetterIcon(pack.icon)
                                      ? Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: LetterStickerIcon(
                                            letter: pack.icon,
                                            color: accent,
                                            size: 48,
                                          ),
                                        )
                                      : null,
                                  padding: const EdgeInsets.all(8),
                                ),
                        ),
                      ),
                      // Status badge (top-right)
                      if (widget.isCompleted ||
                          pack.isLocked ||
                          widget.isSeasonal ||
                          downloading)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _StatusBadge(
                            completed: widget.isCompleted,
                            locked: pack.isLocked,
                            seasonal: widget.isSeasonal,
                            downloading: downloading,
                            accent: accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Title strip — compact, anchored at bottom so the image
              // dominates the tile.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pack.title,
                      textAlign: TextAlign.center,
                      style: PackGridCard.titleStyle.copyWith(
                        color: DT.textPrimary,
                      ),
                    ),
                    if (hasProgress) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: total > 0
                              ? (widget.progress / total).clamp(0.0, 1.0)
                              : 0,
                          minHeight: 5,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Long-press wobble: spring-style rotation around tile center.
    Widget wrapped = AnimatedBuilder(
      animation: _wobbleRotation,
      builder: (_, child) => Transform.rotate(
        angle: _wobbleRotation.value,
        alignment: Alignment.center,
        child: child,
      ),
      child: tile,
    );

    // Seasonal shimmer — two glow pulses to catch the eye, then calm (one
    // idle loop per screen). Reduced motion: rests at its base (alpha 0.25,
    // blur 14) and the ✨ badge still marks the tile.
    if (!widget.isSeasonal) return wrapped;
    return AmbientLoop(
      period: const Duration(milliseconds: 1400),
      settleAfter: const Duration(milliseconds: 5600),
      builder: (_, t, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DT.rLg + 4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25 + t * 0.35),
              blurRadius: 14 + t * 10,
              spreadRadius: t * 2,
            ),
          ],
        ),
        child: child,
      ),
      child: wrapped,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool completed;
  final bool locked;
  final bool seasonal;

  /// Unlocked paid pack whose content is still arriving from Play.
  final bool downloading;
  final Color accent;

  const _StatusBadge({
    required this.completed,
    required this.locked,
    required this.seasonal,
    this.downloading = false,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // The lock is the spec's smiling sunBurst padlock with a sticker edge
    // and no disc behind it — never a grey glyph; the star likewise. Only
    // the check and the download ring keep a disc, as a colour field for a
    // white mark and a track for the spinner.
    if (locked) {
      return const AppIconView(AppIcon.lock, size: 30, sticker: true);
    }
    if (!completed && !downloading) {
      return const AppIconView(AppIcon.star, size: 28, sticker: true);
    }
    final Widget child = completed
        ? const AppIconView(AppIcon.check, size: 14, color: Colors.white)
        : SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
          );
    return Container(
      // Deliberately smaller than the other badges: a finished pack shouldn't
      // pull the eye away from the packs the child hasn't opened yet.
      padding: EdgeInsets.all(completed ? 4 : 5),
      decoration: BoxDecoration(
        color: completed ? DT.success : DT.surfaceWhite,
        shape: BoxShape.circle,
        border: completed ? Border.all(color: Colors.white, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Pictures for the packs that are not packs — the child's own sets.
const _virtualArt = <String, String>{
  '_favorites': 'heart',
  '_review': 'restart',
};
