import 'package:flutter/material.dart';

/// Shared gradient card shell used by Card of the Day and Treasure hero widgets.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: constraints,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
