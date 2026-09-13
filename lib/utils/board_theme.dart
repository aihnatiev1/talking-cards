import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import 'design_tokens.dart';

/// The colour system of the memory board (docs/design/memory_match_redesign
/// §0). Everything on the table — the card back, the mat, the stitches, the
/// matched frame — is derived from **one** colour, so twenty-one packs need
/// one painter and one formula instead of twenty-one drawings.
///
/// The base colour is the pack's own only when the board really belongs to
/// one pack: the games tab deals cards from *all* unlocked packs and hands
/// the screen the first unlocked pack merely as a carrier, so tinting that
/// board "in the pack's colour" would be a lie. A mixed board takes
/// [DT.mint] — the colour of the «Знайди пару» tile the child just tapped.
@immutable
class BoardTheme {
  /// The pack colour (or [DT.mint]) before normalisation.
  final Color base;

  /// The one saturated ink of the board: the stamp, the matched frame, the
  /// doodles. [base] with lightness and saturation clamped, so a pale
  /// yellow pack still carries a cream silhouette at ≥ 3:1 and a near-black
  /// one does not turn the whole table grey.
  final Color seal;

  /// Line work: the pencil frames on the back, the stitches on the mat.
  final Color ink;

  /// The paper a card is printed on.
  final Color paper;

  /// The field of the card back — about 20 % of the theme.
  final Color wash;

  /// The mat the cards lie on — about 14 %.
  final Color mat;

  /// The room behind the mat.
  final Color bg;

  const BoardTheme._({
    required this.base,
    required this.seal,
    required this.ink,
    required this.paper,
    required this.wash,
    required this.mat,
    required this.bg,
  });

  /// Lightness window of [seal]: light pack colours darken until a cream
  /// silhouette reads on them, deep ones lighten until the wash has hue.
  static const minLightness = 0.40;
  static const maxLightness = 0.58;
  static const minSaturation = 0.45;
  static const maxSaturation = 0.85;

  /// [base] pulled into the window above. Deterministic and total: any
  /// colour in, one usable ink out.
  static Color normalize(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(hsl.lightness.clamp(minLightness, maxLightness))
        .withSaturation(hsl.saturation.clamp(minSaturation, maxSaturation))
        .toColor();
  }

  /// The theme of a board built from [cards] that were offered as [pack]'s.
  factory BoardTheme.of(
    PackModel pack,
    List<CardModel> cards, {
    Color background = DT.bgWarm,
  }) {
    final own = pack.cards.map((c) => c.id).toSet();
    final singlePack =
        cards.isNotEmpty && cards.every((c) => own.contains(c.id));
    return BoardTheme.from(
      singlePack ? pack.color : DT.mint,
      background: background,
    );
  }

  /// The theme of one colour — the seam tests and goldens use.
  factory BoardTheme.from(Color base, {Color background = DT.bgWarm}) {
    final seal = normalize(base);
    const paper = DT.paper;
    return BoardTheme._(
      base: base,
      seal: seal,
      ink: DT.onTint(seal),
      paper: paper,
      wash: Color.lerp(seal, paper, 0.80)!,
      mat: Color.lerp(seal, background, 0.86)!,
      bg: background,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BoardTheme &&
      other.base == base &&
      other.seal == seal &&
      other.bg == bg;

  @override
  int get hashCode => Object.hash(base, seal, bg);
}
