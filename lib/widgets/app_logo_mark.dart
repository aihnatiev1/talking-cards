import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'bloom_mascot.dart';

/// The app's mark: Bloom in a rounded tile, the way the launcher icon shows
/// him (ux-gap-audit 2026-09-13 G15).
///
/// Used where the app introduces itself to a parent — the About sheet
/// today. The generic book avatar that stood here said "some reading app";
/// the character the child already greets says which one.
///
/// Drawn, not shipped: when a real lockup file exists it lands as
/// `assets/images/illustrations/logo_mark.webp` (**not**
/// `assets/images/webp/`, which is card art) and only this widget changes.
class AppLogoMark extends StatelessWidget {
  /// Side of the tile.
  final double size;

  /// Localised name of the app for assistive tech.
  final String semanticsLabel;

  const AppLogoMark({
    super.key,
    this.size = 64,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DT.violetTint,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: DT.surfaceWhite, width: 2),
          boxShadow: DT.shadowSoft(DT.brand),
        ),
        // Bloom's hit zone is always at least 72 dp; inside a 64 dp tile
        // it simply adopts the tighter box — the drawing stays centred.
        child: BloomMascot(
          size: size * 0.78,
          state: const BloomState.still(BloomEmotion.happy),
          interactive: false,
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}
