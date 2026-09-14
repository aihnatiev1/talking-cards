import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/sfx.dart';

export '../utils/sfx.dart' show KidSound;

/// One answer to every child tap: a light haptic and the [sound] the
/// instant the finger lands, a squeeze that starts on `pointerDown` (not
/// on `tap`), and a springy release with a hint of overshoot.
///
/// Children aged 1–4 do not read, so a tap that changes nothing they can
/// feel or hear reads as "not counted" and is repeated, which is how a
/// single tap on a pack tile became two navigations. The motion audit
/// (docs/motion-audit-2026-09-13.md §2.1) found eight different press
/// implementations and eight silent targets; this widget is the one
/// press language for the kid zone. Spec: §6 of the same document.
///
/// Feedback channels, in order of arrival (haptic and sound are one row
/// of [FeedbackService] — `tap` by default — so every child tap in the app
/// is one sound):
///  * down — light haptic + [sound], scale 1→[pressScale] in
///    [DT.pressDownMs] with `easeOutCubic`. The sound is on the way *down*
///    so it reaches the ear ≤ 100 ms after the touch even through a
///    Bluetooth speaker (sound_palette §3.4);
///  * up — spring back (`mass 1, stiffness 420, damping 22`) with a small
///    overshoot to ~1.01, then [onTap];
///  * cancel / long-press start — the same spring back, so a wobble or
///    favourite never looks "stuck pressed".
///
/// [sound] is a palette role: `KidSound.tap` for a button, `cardTouch` for
/// a flash card, `packOpen` where the tile itself should sound like the
/// box (today the screen plays it, so the tile passes `null`). `null` is
/// for targets that speak for themselves — the speaker button plays the
/// clip, Bloom giggles — so no tock piles onto the voice.
///
/// Reduced motion (`MediaQuery.disableAnimationsOf`) drops the scale and
/// keeps the haptic and the sound. The ticker only runs while a press is
/// in flight, so a grid of idle tiles costs nothing.
class KidTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale at the bottom of the press. Defaults to [DT.pressScale].
  final double pressScale;
  final KidSound? sound;
  final bool haptic;
  final HitTestBehavior behavior;

  const KidTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = DT.pressScale,
    this.sound = KidSound.tap,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  /// The release spring: stiff enough to be back in ~200 ms, damped just
  /// under critical so the child sees the tile "bounce" rather than glide.
  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 22);

  /// The haptic and the tock alone, for a widget that already animates its
  /// own press (Material buttons with `NoSplash`, for instance).
  static void feedback() => FeedbackService.instance.event(FeedbackEvent.tap);

  /// The tock by itself, pitch-varied so twenty taps are not one sound.
  static void playTap() =>
      FeedbackService.instance.event(FeedbackEvent.tap, haptic: false);

  @override
  State<KidTap> createState() => _KidTapState();
}

class _KidTapState extends State<KidTap> with SingleTickerProviderStateMixin {
  // The controller's value IS the scale; unbounded so the spring may
  // overshoot past 1.0 on the way back.
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  bool _pressed = false;

  /// Read once per press, on the way down: the release may arrive while
  /// the element is already on its way out (route pop under the finger),
  /// when the inherited MediaQuery is no longer safe to look up.
  bool _reduceMotion = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    _pressed = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _feedback();
    if (_reduceMotion) return;
    _scale.animateTo(
      widget.pressScale,
      duration: DT.pressDownMs,
      curve: Curves.easeOutCubic,
    );
  }

  /// Spring back to rest. Idempotent: tap-cancel followed by long-press
  /// start releases once, and a release at rest starts no ticker.
  void _release() {
    if (!_pressed) return;
    _pressed = false;
    if (_reduceMotion) {
      if (_scale.value != 1.0) _scale.value = 1.0;
      return;
    }
    if (!_scale.isAnimating && _scale.value == 1.0) return;
    final sim = SpringSimulation(
      KidTap.spring,
      _scale.value,
      1.0,
      _scale.velocity,
      // Looser than the default tolerance: the last thousandths of the
      // settle are invisible, and stopping there frees the ticker sooner.
      tolerance: const Tolerance(distance: 0.001, velocity: 0.02),
    );
    // Land exactly on 1.0 once the spring has died out; a cancelled ticker
    // never completes this future, so a new press is never overwritten.
    _scale.animateWith(sim).then((_) {
      if (mounted && !_scale.isAnimating) _scale.value = 1.0;
    });
  }

  /// Haptic and sound together, on the way down. A role with an event row
  /// (`tap`, `cardTouch`, `packOpen`) goes through [FeedbackService.event]
  /// so Bloom hears it too; any other role plays as itself.
  void _feedback() {
    final sound = widget.sound;
    final event = sound == null ? null : FeedbackService.eventOf(sound);
    if (event != null) {
      FeedbackService.instance.event(event, haptic: widget.haptic);
      return;
    }
    if (widget.haptic) {
      FeedbackService.instance.event(FeedbackEvent.tap, sound: false);
    }
    if (sound != null) FeedbackService.instance.play(sound);
  }

  void _tap() => widget.onTap?.call();

  void _longPress() {
    _release();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? _down : null,
      onTapUp: enabled ? (_) => _release() : null,
      onTapCancel: enabled ? _release : null,
      onTap: widget.onTap == null ? null : _tap,
      onLongPress: widget.onLongPress == null ? null : _longPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Pads a drawing that is smaller than a child target out to [min]
/// (default [DTSize.tapMin]) without changing how it looks.
///
/// Header chips (streak, profile) are deliberately small — they ride a row
/// with a title — but they open child destinations, so the *finger* still
/// gets its 72 dp. Guarded by `test/architecture/tap_targets_test.dart`.
class KidHitBox extends StatelessWidget {
  const KidHitBox({super.key, required this.child, this.min});

  final Widget child;
  final double? min;

  @override
  Widget build(BuildContext context) {
    final edge = min ?? DT.size.tapMin;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: edge, minHeight: edge),
      // Shrink-wrapping centre: the box is the child's size until the
      // minimum kicks in, so a chip never stretches to the row's height.
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
