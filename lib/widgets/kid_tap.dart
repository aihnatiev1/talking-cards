import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../utils/design_tokens.dart';

/// One answer to every child tap: a light haptic, a soft pop and a press
/// scale — before whatever the tap does.
///
/// Children aged 1–4 do not read, so a tap that changes nothing they can
/// feel or hear reads as "not counted" and is repeated, which is how a
/// single tap on a pack tile became two navigations. The design audit
/// (docs/design-audit-2026-09-08.md, #13) found tiles, chips, the tab bar
/// and game tiles all silent. Wrap the target in [KidTap], or call
/// [KidTap.feedback] from a widget that already animates its own press.
class KidTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  const KidTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
  });

  /// The feedback alone, for widgets with their own press animation.
  static void feedback() {
    HapticFeedback.lightImpact();
    unawaited(AudioService.instance.playSfx('pop', volume: 0.6));
  }

  @override
  State<KidTap> createState() => _KidTapState();
}

class _KidTapState extends State<KidTap> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              KidTap.feedback();
              widget.onTap?.call();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
