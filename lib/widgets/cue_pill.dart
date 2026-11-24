import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// A frosted pill behind a game's one line of cue text, so the line stays
/// readable over a painted backdrop (rainbow, forest, nursery wall).
class CuePill extends StatelessWidget {
  const CuePill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DT.surfaceWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(DT.rLg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: child,
      ),
    );
  }
}
