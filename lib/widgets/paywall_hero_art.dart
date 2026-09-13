import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import 'bloom_mascot.dart';

/// The paywall's hero illustration: Bloom next to a fan of three cards
/// (ux-gap-audit 2026-09-13 G15).
///
/// The banner used to open with a 48 sp 🎉 — a system emoji as the first
/// thing a paying parent sees, in an app whose every other surface is
/// hand-drawn. This is the same universe instead: the mascot the child
/// already knows, holding out what the money buys.
///
/// Drawn, not shipped: there is no artwork file yet. When the illustrator
/// delivers one it lands as `assets/images/illustrations/paywall_hero.webp`
/// (320×180 @1x/2x/3x — **not** `assets/images/webp/`, which is card art
/// guarded by `test/architecture/asset_access_test.dart`) and only the
/// inside of this widget changes; every call site keeps working.
///
/// Nothing here animates: Bloom is frozen (`BloomState.still`) because the
/// parent is reading a price, not playing.
class PaywallHeroArt extends StatelessWidget {
  /// Localised description for assistive tech — the art carries meaning
  /// ("everything is included"), so it is not decorative.
  final String semanticsLabel;

  /// Total height of the illustration. The cards and Bloom scale with it.
  final double height;

  const PaywallHeroArt({
    super.key,
    required this.semanticsLabel,
    this.height = 112,
  });

  @override
  Widget build(BuildContext context) {
    final bloom = height * 0.78;
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        // On a 320 dp phone the banner is 224 dp wide and the composition
        // wants 225 — scale, never clip or overflow.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BloomMascot(
                size: bloom,
                state: const BloomState.still(BloomEmotion.happy),
                facing: BloomFacing.right,
                interactive: false,
                semanticsLabel: semanticsLabel,
              ),
              const SizedBox(width: DT.sp4),
              _CardFan(height: height),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three paper cards spread like a hand: a picture, the sound it makes,
/// and the star of the new packs that keep coming. The middle card sits
/// upright and in front — it is the one the eye lands on.
class _CardFan extends StatelessWidget {
  final double height;

  const _CardFan({required this.height});

  @override
  Widget build(BuildContext context) {
    final card = Size(height * 0.44, height * 0.62);
    return SizedBox(
      width: card.width * 2.7,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            bottom: height * 0.04,
            child: _FanCard(
              key: const ValueKey('fan-left'),
              size: card,
              icon: AppIcon.stickerButterfly,
              angle: -0.28,
            ),
          ),
          Positioned(
            right: 0,
            bottom: height * 0.04,
            child: _FanCard(
              key: const ValueKey('fan-right'),
              size: card,
              icon: AppIcon.star,
              angle: 0.28,
            ),
          ),
          Positioned(
            bottom: height * 0.18,
            child: _FanCard(
              key: const ValueKey('fan-mid'),
              size: Size(card.width * 1.06, card.height * 1.06),
              icon: AppIcon.sound,
              angle: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FanCard extends StatelessWidget {
  final Size size;
  final AppIcon icon;
  final double angle;

  const _FanCard({
    super.key,
    required this.size,
    required this.icon,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: DT.paper,
          borderRadius: BorderRadius.circular(DT.rSm),
          // The white paper rim of the design language (§5 «Паперова
          // іграшкова кімната») — the cards sit on a tinted banner.
          border: Border.all(color: DT.surfaceWhite, width: 2.5),
          boxShadow: DT.shadowSoft(DT.textPrimary),
        ),
        child: Center(child: AppIconView(icon, size: size.width * 0.56)),
      ),
    );
  }
}
