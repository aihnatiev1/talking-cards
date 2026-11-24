import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import 'kid_tap.dart';

/// Shared outlined card with a firm lower edge for daily and treasure heroes.
class AppCardShell extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final BoxConstraints? constraints;

  const AppCardShell({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: onTap,
      child: Container(
        constraints: constraints,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
          boxShadow: DT.shadowSoft(color),
        ),
        child: child,
      ),
    );
  }
}
