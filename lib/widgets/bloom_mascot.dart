import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bloom_reactions_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'bloom/bloom_painter.dart';
import 'bloom/bloom_pose.dart';
import 'kid_tap.dart';

export '../models/bloom_state.dart';
export 'bloom/bloom_painter.dart' show BloomSilhouettePainter, MascotRenderer;
export 'bloom/bloom_pose.dart';

/// Which way Bloom's asymmetric side (the bent ear) faces. [left] is the
/// drawing as designed; [right] mirrors it.
enum BloomFacing { left, right }

/// Bloom — Skillar's bunny, the child's companion in the app
/// (docs/design/bloom_character.md). Zero asset weight, crisp at any size,
/// nine emotions from one rig ([BloomPose]).
///
/// The widget only *renders*. Without [state] it watches
/// [bloomReactionsProvider] — one brain, one Bloom per route; with [state]
/// it is frozen for overlays, goldens and marketing renders.
///
/// Inside: a `RepaintBoundary`, a hit zone of at least [DTSize.tapMin]
/// whatever the drawing size, one `AnimationController` for the pose
/// transition and one for the one-shot gesture (their tickers run only
/// while something moves), a `Timer` for the blink, and the breathing
/// through [AmbientLoop] so it obeys `MotionPolicy` and `TickerMode` like
/// every other idle loop. Under reduced motion poses swap instantly and
/// nothing translates, scales or rotates.
class BloomMascot extends StatelessWidget {
  /// Drawing size in dp. The hit zone is `max(size, DT.size.tapMin)`.
  final double size;

  /// Frozen state for overlays and tests; `null` follows the provider.
  final BloomState? state;

  final BloomFacing facing;

  /// A tap on Bloom hops and giggles (through the provider). Never
  /// navigates. `false` for a purely decorative placement. A frozen
  /// [state] has no brain to hop with, so it is never interactive.
  final bool interactive;

  /// Accessibility label; hosts pass the localised name.
  final String semanticsLabel;

  /// Wave-0 API: a fixed emotion. Prefer [state]; kept so old call sites
  /// compile.
  @Deprecated('pass state: BloomState.still(emotion) instead')
  final BloomEmotion? emotion;

  const BloomMascot({
    super.key,
    this.size = 120,
    this.state,
    this.facing = BloomFacing.left,
    this.interactive = true,
    this.semanticsLabel = 'Bloom',
    @Deprecated('pass state: BloomState.still(emotion) instead') this.emotion,
  });

  /// Extra room the hop needs above the drawing (§4.2: −14 dp + margin).
  static const double hopClearance = 16;

  // ignore: deprecated_member_use_from_same_package
  BloomEmotion? get _legacyEmotion => emotion;

  @override
  Widget build(BuildContext context) {
    final frozen = state ?? switch (_legacyEmotion) {
          null => null,
          final e => BloomState.still(e),
        };
    if (frozen != null) {
      return _BloomBody(
        state: frozen,
        size: size,
        facing: facing,
        semanticsLabel: semanticsLabel,
        onTap: null,
      );
    }
    // Only the live Bloom needs a ProviderScope — a frozen one renders in
    // any tree (overlays pushed outside the scope, goldens, marketing).
    return Consumer(
      builder: (context, ref, _) => _BloomBody(
        state: ref.watch(bloomReactionsProvider),
        size: size,
        facing: facing,
        semanticsLabel: semanticsLabel,
        onTap: interactive
            ? () => ref.read(bloomReactionsProvider.notifier).bloomTapped()
            : null,
      ),
    );
  }
}

/// The animated body: pose lerp, gesture, blink, breath.
class _BloomBody extends StatefulWidget {
  final BloomState state;
  final double size;
  final BloomFacing facing;
  final String semanticsLabel;
  final VoidCallback? onTap;

  const _BloomBody({
    required this.state,
    required this.size,
    required this.facing,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  State<_BloomBody> createState() => _BloomBodyState();
}

class _BloomBodyState extends State<_BloomBody>
    with TickerProviderStateMixin {
  late final AnimationController _pose =
      AnimationController(vsync: this, duration: DT.motion.bloomPose);
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: DT.motion.celebrate);

  BloomState _shown = const BloomState();
  BloomPose _from = BloomPose.idle;
  BloomPose _to = BloomPose.idle;

  /// Which gesture [_motion] is playing.
  _Gesture _gesture = _Gesture.none;
  int _hops = 1;

  Timer? _blinkTimer;
  double _eyeOpen = 1;
  bool _reduce = false;
  bool _tickers = true;

  @override
  void initState() {
    super.initState();
    _shown = widget.state;
    _to = _poseOf(_shown);
    _from = _to;
    _pose.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MotionPolicy.of(context).reduce;
    _tickers = TickerMode.valuesOf(context).enabled;
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(_BloomBody old) {
    super.didUpdateWidget(old);
    if (widget.state != old.state) _apply(widget.state);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _pose.dispose();
    _motion.dispose();
    super.dispose();
  }

  static BloomPose _poseOf(BloomState s) => BloomPose.of(s.emotion, prop: s.prop);

  /// Apply a new state: lerp the pose if it changed, restart the gesture
  /// if a new one-shot began, nod when a word ends.
  void _apply(BloomState next) {
    if (!mounted) return;
    final prev = _shown;
    final poseChanged = next.emotion != prev.emotion || next.prop != prev.prop;
    setState(() => _shown = next);

    if (poseChanged) {
      _from = _currentPose();
      _to = _poseOf(next);
      if (_reduce || !_tickers) {
        _pose.value = 1;
      } else {
        _pose.forward(from: 0);
      }
    }

    final newShot = next.serial != prev.serial;
    if (newShot && !next.emotion.isLevel) {
      _playGesture(_gestureFor(next.emotion, next.hops), next.hops);
    } else if (poseChanged &&
        next.emotion == BloomEmotion.listen &&
        prev.emotion != BloomEmotion.listen) {
      _playGesture(_Gesture.squash, 1);
    } else if (poseChanged &&
        prev.emotion == BloomEmotion.listen &&
        next.emotion == BloomEmotion.idle) {
      _playGesture(_Gesture.nod, 1);
    }
    _scheduleBlink();
  }

  BloomPose _currentPose() =>
      _pose.isCompleted ? _to : BloomPose.lerp(_from, _to, _pose.value);

  static _Gesture _gestureFor(BloomEmotion e, int hops) => switch (e) {
        BloomEmotion.wave => _Gesture.wave,
        BloomEmotion.happy => hops > 0 ? _Gesture.hop : _Gesture.none,
        BloomEmotion.cheer => _Gesture.cheer,
        BloomEmotion.curious => _Gesture.lean,
        BloomEmotion.point => _Gesture.point,
        BloomEmotion.blow => _Gesture.blow,
        BloomEmotion.idle ||
        BloomEmotion.listen ||
        BloomEmotion.sleep =>
          _Gesture.none,
      };

  Duration _gestureLength(_Gesture g, int hops) => switch (g) {
        _Gesture.none => Duration.zero,
        _Gesture.wave => DT.motion.bloomWave,
        _Gesture.hop => DT.motion.celebrate,
        _Gesture.cheer =>
          hops >= 3 ? DT.motion.bloomCheerBig : DT.motion.bloomCheer,
        _Gesture.lean => DT.motion.bloomCurious,
        _Gesture.point => DT.motion.bloomPoint,
        _Gesture.blow => DT.motion.bloomBlow,
        _Gesture.squash => DT.motion.bloomSquash,
        _Gesture.nod => DT.motion.bloomNod,
      };

  void _playGesture(_Gesture g, int hops) {
    if (g == _Gesture.none || _reduce || !_tickers) {
      _gesture = _Gesture.none;
      _motion.value = 0;
      return;
    }
    _gesture = g;
    _hops = hops;
    _motion
      ..duration = _gestureLength(g, hops)
      ..forward(from: 0);
  }

  // ── Blink: a rare discrete event, never a loop ────────────────────────

  bool get _mayBlink =>
      !_reduce &&
      _tickers &&
      _shown.ambient != BloomAmbient.still &&
      _to.eyes == BloomEyes.open;

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (!_mayBlink) {
      if (_eyeOpen != 1) setState(() => _eyeOpen = 1);
      return;
    }
    // Somewhere between the two token bounds — a random gap, not a beat.
    final min = DT.motion.bloomBlinkMin;
    final max = DT.motion.bloomBlinkMax;
    final gap = min + (max - min) * math.Random().nextDouble();
    _blinkTimer = Timer(gap, _blink);
  }

  void _blink() {
    if (!mounted || !_mayBlink) return;
    setState(() => _eyeOpen = 0);
    _blinkTimer = Timer(DT.motion.bloomBlink, () {
      if (!mounted) return;
      setState(() => _eyeOpen = 1);
      _scheduleBlink();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hit = math.max(widget.size, DT.size.tapMin);
    final flip = widget.facing == BloomFacing.right;
    final look = _shown.lookAt;
    final lookOffset = look == null
        ? Offset.zero
        : Offset(flip ? -look.x : look.x, look.y);

    Widget figure = AnimatedBuilder(
      animation: Listenable.merge([_pose, _motion]),
      builder: (context, _) {
        final base = _currentPose();
        final frame = _MotionFrame.at(
          _gesture,
          _motion.isAnimating ? _motion.value : (_motion.value >= 1 ? 1 : 0),
          hops: _hops,
          hint: _shown.hintDirection,
          swipe: _shown.swipeGesture,
          reachScale: PaintedBloom.designSize / widget.size,
        );
        final pose = frame.adjust(base);
        Widget child = RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: BloomPainter(pose: pose, look: lookOffset, eyeOpen: _eyeOpen),
          ),
        );
        if (frame.isIdentity) return child;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(0, frame.dy, 0, 1)
            ..rotateZ(frame.tilt)
            ..scaleByDouble(frame.scaleX, frame.scaleY, 1, 1),
          child: child,
        );
      },
    );

    if (flip) figure = Transform.flip(flipX: true, child: figure);

    // Breathing: only when the host says nothing else moves continuously,
    // never while a gesture plays. AmbientLoop owns the loop.
    final breathe = _shown.ambient == BloomAmbient.breathe ||
        _shown.emotion == BloomEmotion.sleep;
    figure = AmbientLoop(
      period: _shown.emotion == BloomEmotion.sleep
          ? DT.motion.bloomSleepBreath
          : DT.motion.bloomBreath,
      enabled: breathe && _shown.emotion.isLevel,
      builder: (_, t, child) => Transform.scale(
        scaleY: 1 + 0.02 * t,
        scaleX: 1 + 0.01 * t,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: figure,
    );

    Widget box = SizedBox.square(
      dimension: hit,
      child: Center(child: figure),
    );

    final onTap = widget.onTap;
    if (onTap != null) {
      box = KidTap(onTap: onTap, sound: KidSound.none, child: box);
    }

    return Semantics(
      label: widget.semanticsLabel,
      button: onTap != null,
      child: box,
    );
  }
}

enum _Gesture { none, wave, hop, cheer, lean, point, blow, squash, nod }

/// One frame of a gesture: transforms applied over the `RepaintBoundary`
/// and paw offsets folded into the pose. Every curve here is `t` in 0..1.
class _MotionFrame {
  final double dy;
  final double scaleX;
  final double scaleY;
  final double tilt;
  final Offset pawRightDelta;
  final double pawRightSwing;

  const _MotionFrame({
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.tilt = 0,
    this.pawRightDelta = Offset.zero,
    this.pawRightSwing = 0,
  });

  static const identity = _MotionFrame();

  bool get isIdentity =>
      dy == 0 && scaleX == 1 && scaleY == 1 && tilt == 0;

  BloomPose adjust(BloomPose p) {
    if (pawRightDelta == Offset.zero && pawRightSwing == 0) return p;
    return p.copyWith(
      pawRight: p.pawRight + pawRightDelta,
      pawRightAngle: p.pawRightAngle + pawRightSwing,
    );
  }

  /// [reachScale] converts dp to design units for paw travel.
  static _MotionFrame at(
    _Gesture g,
    double t, {
    required int hops,
    required Alignment? hint,
    required bool swipe,
    required double reachScale,
  }) {
    if (t <= 0 || t >= 1) return identity;
    final arc = math.sin(math.pi * t); // 0 → 1 → 0
    switch (g) {
      case _Gesture.none:
        return identity;
      case _Gesture.squash:
        return _MotionFrame(scaleY: 1 - 0.06 * arc, scaleX: 1 + 0.03 * arc);
      case _Gesture.nod:
        return _MotionFrame(dy: 3 * arc);
      case _Gesture.hop:
        // Up on easeOutBack, down on easeIn (§2.2 happy).
        final up = t < 0.5
            ? Curves.easeOutBack.transform(t * 2)
            : 1 - Curves.easeIn.transform((t - 0.5) * 2);
        return _MotionFrame(
          dy: -8 * up,
          scaleY: 1 + 0.06 * up,
          scaleX: 1 - 0.06 * up,
        );
      case _Gesture.cheer:
        final n = hops.clamp(1, 3);
        final phase = (t * n) % 1;
        final h = math.sin(math.pi * phase);
        return _MotionFrame(dy: -14 * h, scaleY: 1 + 0.06 * h, scaleX: 1 - 0.06 * h);
      case _Gesture.wave:
        // Squash on the start, paw swings 0.25 ↔ 0.55 twice around 0.4.
        final start = t < 0.2 ? math.sin(math.pi * t / 0.2) : 0.0;
        final swing = 0.15 * math.sin(2 * math.pi * 2 * t);
        return _MotionFrame(
          scaleY: 1 - 0.05 * start,
          scaleX: 1 + 0.025 * start,
          pawRightSwing: swing,
        );
      case _Gesture.lean:
        return _MotionFrame(tilt: 0.05 * arc);
      case _Gesture.point:
        final dir = hint ?? const Alignment(0.7, -0.8);
        if (swipe) {
          // The paw slides 24 dp sideways and back, twice.
          final slide = math.sin(2 * math.pi * 2 * t).abs();
          return _MotionFrame(
            pawRightDelta: Offset(dir.x.sign * 24 * reachScale * slide, 0),
          );
        }
        final len = math.sqrt(dir.x * dir.x + dir.y * dir.y);
        final unit = len == 0 ? const Offset(0.7, -0.7) : Offset(dir.x / len, dir.y / len);
        final reach = 12 * reachScale * arc;
        final nod = 2 * math.sin(2 * math.pi * 2 * t).abs();
        return _MotionFrame(
          dy: nod,
          pawRightDelta: unit * reach,
        );
      case _Gesture.blow:
        final s = t < 0.4 ? 1 - 0.04 * (t / 0.4) : 0.96 + 0.07 * ((t - 0.4) / 0.6);
        return _MotionFrame(scaleY: s, scaleX: 2 - s);
    }
  }
}
