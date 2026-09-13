
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/content_pack_provider.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
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
    final downloading = !pack.isLocked &&
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
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                          child: CardImage(
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
                            padding: EdgeInsets.zero,
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
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shrink-to-fit on one line: «Протилежності» used to
                    // wrap to two lines and look heavier than «Дії».
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      pack.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      // Parents pick a pack by its name, so the title stays;
                      // set in the tile face on the pack's own ink (G7/G9).
                      style: DT.tileTitle.copyWith(
                        fontSize: 12.5,
                        color: PackPalette.of(accent).onTint,
                        height: 1.1,
                      ),
                    ),
                    ),
                    if (hasProgress) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value:
                              total > 0 ? widget.progress / total : 0,
                          minHeight: 3,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accent),
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
        border: completed
            ? Border.all(color: Colors.white, width: 1.5)
            : null,
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
