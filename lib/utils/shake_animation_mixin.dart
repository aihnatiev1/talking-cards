import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adds a horizontal shake animation (wrong-answer feedback) to a game screen.
///
/// Host must mix in [TickerProviderStateMixin] (or [SingleTickerProviderStateMixin]
/// if the screen has no other controllers).
///
/// Usage:
/// ```dart
/// class _MyGameState extends ConsumerState<MyGame>
///     with TickerProviderStateMixin, ShakeAnimationMixin {
///   @override void initState() { super.initState(); initShake(); }
///   @override void dispose() { disposeShake(); super.dispose(); }
///
///   void _onWrong(CardModel c) => shake(id: c.id);
///
///   Widget _buildTile(CardModel c) => wrapShake(MyTile(c), id: c.id);
/// }
/// ```
mixin ShakeAnimationMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late AnimationController shakeController;
  late Animation<double> shakeOffset;
  String? _shakingId;
  String? get shakingId => _shakingId;

  void initShake({
    Duration duration = const Duration(milliseconds: 380),
    double amplitude = 14.0,
  }) {
    shakeController = AnimationController(
      vsync: this as TickerProvider,
      duration: duration,
    );
    shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -amplitude), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -amplitude, end: amplitude), weight: 2),
      TweenSequenceItem(tween: Tween(begin: amplitude, end: -amplitude), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -amplitude, end: amplitude), weight: 2),
      TweenSequenceItem(tween: Tween(begin: amplitude, end: 0.0), weight: 1),
    ]).animate(shakeController);
    shakeController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        shakeController.reset();
        if (mounted) setState(() => _shakingId = null);
      }
    });
  }

  void disposeShake() {
    shakeController.dispose();
  }

  /// Starts a shake. If [id] is provided, [shakingId] is set so the matching
  /// tile can render with translation; it's cleared when the animation ends.
  void shake({String? id}) {
    if (id != null) {
      setState(() => _shakingId = id);
    }
    shakeController.forward();
  }

  /// Wrap [child] with a translating [AnimatedBuilder] that only moves when
  /// [id] matches the currently-shaking id (or when both are null).
  Widget wrapShake(Widget child, {String? id}) {
    return AnimatedBuilder(
      animation: shakeController,
      builder: (_, c) {
        final dx = (id == _shakingId || (id == null && _shakingId == null))
            ? shakeOffset.value
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }
}
