import 'package:flutter/material.dart';

import '../models/pack_model.dart';
import '../utils/motion.dart';
import 'card_image.dart';

/// The pack illustration's flight from the home tile to the `CardsScreen`
/// header (motion audit 2026-09-13 §5, "home → пак").
///
/// Both ends wrap their picture in this so the tag, the shuttle and the
/// placeholder are defined once. The shuttle is a [CardImage] at
/// [CardArtSize.tile] — the same decode the tile already holds, so the
/// flight costs no new pixels — and the placeholder is the pack tint, so
/// neither end flashes white while the picture is in the air.
///
/// Only the home grid (`PackGridCard`) and the pack header take part. The
/// quest map's pack picker and the "continue" hero card deliberately do
/// not: two live heroes with one tag in one route is a `FlutterError`, and
/// the favourites / review virtual packs can appear in more than one list.
class PackCoverHero extends StatelessWidget {
  final PackModel pack;

  /// Corner radius of the picture at *this* end; the shuttle uses the same
  /// radius so the clip does not jump at take-off or landing.
  final BorderRadius borderRadius;

  /// Whether a back-swipe (iOS) may also fly the hero. The header side sets
  /// this to false: the tile it would land on may have scrolled away.
  final bool transitionOnUserGestures;

  final Widget child;

  const PackCoverHero({
    super.key,
    required this.pack,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.transitionOnUserGestures = true,
  });

  static String tagFor(String packId) => 'pack-cover-$packId';

  /// Key of the widget the flight builds in the overlay — the one handle a
  /// test has on "the picture is in the air right now".
  static Key shuttleKeyFor(String packId) => ValueKey('pack-flight-$packId');

  /// The picture a pack shows for itself — the same rule `PackGridCard`
  /// uses for its thumbnail, so the shuttle carries the picture that was
  /// on the tile. Cover first; else the first card with an illustration;
  /// virtual packs (`_favorites`, `_review`) keep their semantic emoji.
  static String? coverOf(PackModel pack) {
    if (pack.cover != null) return pack.cover;
    if (pack.id.startsWith('_')) return null;
    for (final card in pack.cards) {
      if (card.image != null) return card.image;
    }
    return null;
  }

  Color get _tint => pack.color.withValues(alpha: 0.12);

  @override
  Widget build(BuildContext context) {
    // Under reduced motion (and in widget tests) the route itself is
    // instant, so a flight would be a one-frame flicker of a picture over
    // a screen that already changed. `HeroMode` switches the Hero off
    // rather than the widget disappearing, so both ends keep their layout.
    return HeroMode(
      enabled: !MotionPolicy.of(context).reduce,
      child: _hero(),
    );
  }

  Widget _hero() {
    return Hero(
      tag: tagFor(pack.id),
      transitionOnUserGestures: transitionOnUserGestures,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      placeholderBuilder: (_, __, ___) => DecoratedBox(
        decoration: BoxDecoration(color: _tint, borderRadius: borderRadius),
      ),
      flightShuttleBuilder: (_, __, ___, ____, _____) => ClipRRect(
        key: shuttleKeyFor(pack.id),
        borderRadius: borderRadius,
        child: ColoredBox(
          color: _tint,
          child: CardImage(
            name: coverOf(pack),
            fallbackEmoji: pack.icon,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      child: child,
    );
  }
}
