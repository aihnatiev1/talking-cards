import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/confetti_burst.dart';

/// Inserts a [ConfettiBurst] into the nearest [Overlay] for celebratory moments
/// (correct answer, game complete), auto-removing after [linger].
///
/// Usage:
/// ```dart
/// class _MyGameState extends ConsumerState<MyGame>
///     with ConfettiOverlayMixin {
///   @override void dispose() { disposeConfetti(); super.dispose(); }
///
///   void _onCorrect() => showConfetti();
/// }
/// ```
mixin ConfettiOverlayMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  OverlayEntry? _confettiEntry;

  /// Shows a confetti burst at [origin] (default: center-upper area of the
  /// screen). [linger] controls how long the overlay stays before removal.
  void showConfetti({
    Offset? origin,
    Duration linger = const Duration(milliseconds: 1500),
    bool ignorePointer = true,
  }) {
    if (!mounted) return;
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    final burstOrigin = origin ?? Offset(size.width / 2, size.height / 3);
    final entry = OverlayEntry(
      builder: (_) {
        final burst = ConfettiBurst(origin: burstOrigin);
        return ignorePointer ? IgnorePointer(child: burst) : burst;
      },
    );
    _confettiEntry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(linger, () {
      if (_confettiEntry == entry) {
        _confettiEntry?.remove();
        _confettiEntry = null;
      }
    });
  }

  void disposeConfetti() {
    _confettiEntry?.remove();
    _confettiEntry = null;
  }
}
