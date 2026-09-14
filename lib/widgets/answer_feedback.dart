import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'confetti_burst.dart';

/// What a game tile is showing about the answer it holds.
///
/// There is deliberately no `wrong` value (ux-gap-audit 2026-09-13 G10;
/// competitor benchmark §5.2): a miss is a moment — the tile nudges once
/// and settles back to its rest look — not a state a child sits in.
enum AnswerMark {
  /// Rest: the tile's own pack colours.
  none,

  /// The right answer, tapped (motion audit T0): `DT.success` frame, white
  /// check sticker, a pop and a small burst from the tile's own centre.
  correct,

  /// The right answer, *not yet* tapped, after the second miss: the tile
  /// glows [DT.hint] amber and wears a lightbulb so the child knows where
  /// to look. Never named "wrong" anywhere — and never in the card's own
  /// colour, which on a red card said exactly that.
  hint,
}

/// Per-question miss counter shared by every choice game.
///
/// After [hintAfter] misses the screen marks the right tile
/// [AnswerMark.hint]; [justCrossed] is true on exactly that miss so the
/// `FeedbackEvent.lockedHint` cue plays once. Call [reset] on every new
/// question.
class MissTracker {
  static const hintAfter = 2;

  int misses = 0;

  void miss() => misses++;

  void reset() => misses = 0;

  bool get showHint => misses >= hintAfter;

  bool get justCrossed => misses == hintAfter;
}

/// The one answer look for every game tile (guess, odd one out, opposites,
/// memory): owns the tile's decoration in all three [AnswerMark]s, the
/// miss nudge, the success pop, the corner stickers and the tile-centre
/// confetti — so a right or wrong tap reads the same in every game.
///
/// * [nudge] is a counter: every increment plays one gentle ±12 px shake
///   ([DT.motion.nudge]) with **no** colour change — the tile is back to
///   its rest look the moment the shake ends.
/// * [AnswerMark.correct] frames the tile in [DT.success], pops it
///   1 → 1.10 → 1 ([DT.motion.successPop], [DTMotion.emphasized]), shows a
///   white [AppIcon.check] sticker and fires a 12-piece [ConfettiBurst]
///   from the tile's own centre. Reduced motion: frame + check only.
/// * [AnswerMark.hint] glows in [DT.hint] — one amber for every card, so
///   the nudge never arrives as a red frame on a red card — on an
///   [AmbientLoop] of
///   [DT.motion.hintPulse] that settles after [DT.motion.hintSettle], and
///   shows an [AppIcon.hint] sticker. Reduced motion: static glow + sticker.
///
/// Wrap the frame in `KidTap`, not the other way round, so the press scale
/// and the pop compose and the confetti origin is the frame's own box.
class AnswerFrame extends StatefulWidget {
  final Widget child;

  /// Tile surface — usually the card's `colorBg`.
  final Color background;

  /// Pack / card accent — the resting border. The hint has its own colour
  /// ([DT.hint]); see [AnswerMark.hint].
  final Color accent;

  final AnswerMark mark;

  /// Bump to nudge. Only increases count; the value itself is opaque.
  final int nudge;

  final double radius;
  final EdgeInsetsGeometry padding;

  /// Set false when the screen already owns a bigger burst for this moment.
  final bool confetti;

  const AnswerFrame({
    super.key,
    required this.child,
    required this.background,
    required this.accent,
    this.mark = AnswerMark.none,
    this.nudge = 0,
    this.radius = DT.rLg,
    this.padding = EdgeInsets.zero,
    this.confetti = true,
  });

  /// Horizontal travel of one nudge.
  static const nudgeAmplitude = 12.0;

  /// Peak of the success pop.
  static const popScale = 1.10;

  /// Pieces in the tile-centre burst.
  static const burstCount = 12;

  @override
  State<AnswerFrame> createState() => _AnswerFrameState();
}

class _AnswerFrameState extends State<AnswerFrame>
    with TickerProviderStateMixin {
  late final AnimationController _nudgeCtrl = AnimationController(
    vsync: this,
    duration: DT.motion.nudge,
  );
  late final Animation<double> _nudgeDx = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -AnswerFrame.nudgeAmplitude),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -AnswerFrame.nudgeAmplitude,
        end: AnswerFrame.nudgeAmplitude,
      ),
      weight: 2,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: AnswerFrame.nudgeAmplitude,
        end: -AnswerFrame.nudgeAmplitude * 0.5,
      ),
      weight: 2,
    ),
    TweenSequenceItem(
      tween: Tween(begin: -AnswerFrame.nudgeAmplitude * 0.5, end: 0.0),
      weight: 1,
    ),
  ]).animate(_nudgeCtrl);

  late final AnimationController _popCtrl = AnimationController(
    vsync: this,
    duration: DT.motion.successPop,
  );
  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: AnswerFrame.popScale)
          .chain(CurveTween(curve: DT.motion.emphasized)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: AnswerFrame.popScale, end: 1.0)
          .chain(CurveTween(curve: DT.motion.standard)),
      weight: 1,
    ),
  ]).animate(_popCtrl);

  OverlayEntry? _burst;

  @override
  void didUpdateWidget(covariant AnswerFrame old) {
    super.didUpdateWidget(old);
    final reduce = MotionPolicy.of(context).reduce;
    if (widget.nudge > old.nudge && !reduce) {
      _nudgeCtrl.forward(from: 0);
    }
    if (widget.mark == AnswerMark.correct && old.mark != AnswerMark.correct) {
      if (!reduce) {
        _popCtrl.forward(from: 0);
        if (widget.confetti) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showBurst());
        }
      }
    }
  }

  void _showBurst() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (box == null || !box.hasSize || overlay == null) return;
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    _burst?.remove();
    final entry = OverlayEntry(
      builder: (_) => ConfettiBurst(
        origin: origin,
        count: AnswerFrame.burstCount,
      ),
    );
    _burst = entry;
    overlay.insert(entry);
    Future<void>.delayed(DT.motion.confettiBurst + DT.motion.quick, () {
      if (_burst == entry) {
        entry.remove();
        _burst = null;
      }
    });
  }

  @override
  void dispose() {
    _burst?.remove();
    _burst = null;
    _nudgeCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    final mark = widget.mark;
    final radius = BorderRadius.circular(widget.radius);

    return AnimatedBuilder(
      animation: Listenable.merge([_nudgeCtrl, _popCtrl]),
      builder: (_, child) => Transform.translate(
        offset: Offset(_nudgeCtrl.isAnimating ? _nudgeDx.value : 0, 0),
        child: Transform.scale(scale: _pop.value, child: child),
      ),
      child: AmbientLoop(
        period: DT.motion.hintPulse,
        settleAfter: DT.motion.hintSettle,
        enabled: mark == AnswerMark.hint,
        builder: (_, t, content) => DecoratedBox(
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: radius,
            border: Border.all(
              color: switch (mark) {
                AnswerMark.none => widget.accent.withValues(alpha: 0.3),
                AnswerMark.correct => DT.success,
                AnswerMark.hint => DT.hint,
              },
              width: mark == AnswerMark.none ? 1.5 : 3,
            ),
            boxShadow: switch (mark) {
              AnswerMark.none => [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              AnswerMark.correct => [
                  BoxShadow(
                    color: DT.success.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              // t = 0 is still a visible glow — the rest pose under
              // reduced motion and after the loop settles.
              AnswerMark.hint => [
                  BoxShadow(
                    color: DT.hint.withValues(alpha: 0.28 + 0.32 * t),
                    blurRadius: 14 + 10 * t,
                    spreadRadius: 1 + 3 * t,
                  ),
                ],
            },
          ),
          child: content,
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(padding: widget.padding, child: widget.child),
            Positioned(
              top: DT.sp8,
              right: DT.sp8,
              child: AnimatedScale(
                scale: mark == AnswerMark.none ? 0 : 1,
                duration: policy.dur(DT.motion.quick),
                curve: DT.motion.emphasized,
                child: switch (mark) {
                  AnswerMark.none => const SizedBox.shrink(),
                  AnswerMark.correct => const _CheckSticker(),
                  AnswerMark.hint => AppIconView(
                      AppIcon.hint,
                      size: DT.size.iconMd,
                      sticker: true,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White check on a [DT.success] plate — the one "yes" every game shows.
class _CheckSticker extends StatelessWidget {
  const _CheckSticker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DT.size.iconMd,
      height: DT.size.iconMd,
      decoration: BoxDecoration(
        color: DT.success,
        shape: BoxShape.circle,
        boxShadow: DT.shadowSoft(DT.success),
      ),
      alignment: Alignment.center,
      child: AppIconView(
        AppIcon.check,
        size: DT.size.iconSm - 4,
        color: Colors.white,
      ),
    );
  }
}
