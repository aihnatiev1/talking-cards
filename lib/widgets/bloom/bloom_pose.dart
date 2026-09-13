import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Bloom's nine emotions (docs/design/bloom_character.md §2.2).
///
/// Three are *levels* Bloom rests at — [sleep] < [idle] < [listen] — the
/// rest are one-shots that return to the highest active level. There is no
/// `sad`, and there will not be one: Bloom never reacts to a mistake with
/// anything but curiosity.
enum BloomEmotion {
  /// Default. Eyes open, pupils on the last target, an occasional blink.
  idle,

  /// Hello and goodbye: right paw up and swinging twice.
  wave,

  /// A word is playing: ears pricked, head tilted to the card, no motion.
  listen,

  /// Micro-success or a tap on Bloom: one small hop, eyes `^^`.
  happy,

  /// A pack, a round, a streak: both paws up, wide `D` mouth, 1–3 hops.
  cheer,

  /// Something new: one ear forward, a small "o" mouth, head leaned in.
  curious,

  /// The hint: right paw stretched toward the target, two nods.
  point,

  /// 30 s without a touch: eyes shut downward, ears down, a `z` doodle.
  sleep,

  /// Bubble Pop: cheeks puffed, wand up, one exhale.
  blow;

  /// Wave-0 alias. The old widget knew two poses; `waving` is now [wave].
  @Deprecated('use BloomEmotion.wave')
  static const BloomEmotion waving = wave;

  /// Memory-spec alias: `excited` is the shared [cheer].
  @Deprecated('use BloomEmotion.cheer')
  static const BloomEmotion excited = cheer;

  /// Whether this is a resting level rather than a one-shot.
  bool get isLevel => this == idle || this == listen || this == sleep;
}

/// What Bloom holds in the right paw (§2.3). Costumes are not props.
enum BloomProp { none, wand }

/// Eye shape. [open] eyes blink and carry the pupil offset; the two closed
/// shapes are fixed arcs.
enum BloomEyes {
  /// Round ink eyes with a highlight; the default.
  open,

  /// `^^` — the old always-on face, now reserved for happy / cheer / blow.
  happyClosed,

  /// `˘˘` — arcs pointing down; only in sleep.
  sleepClosed,
}

/// Mouth shape (§2.1: four forms).
enum BloomMouth {
  /// The smile arc.
  smile,

  /// A small "o" (curious, blow).
  o,

  /// A filled "D" with a tongue (cheer).
  cheerD,

  /// A short flat line (sleep).
  line,
}

/// One drawable pose in the 120×120 design space — the rig.
///
/// Every emotion is a constant [BloomPose]; a transition is
/// [BloomPose.lerp]. Continuous fields interpolate, discrete ones
/// ([eyes], [mouth], [zzz], [puffCheeks], [prop]) switch at t = 0.5 under
/// the squash the widget plays across the swap, so no frame shows half a
/// mouth. Nothing here knows about time or the widget tree.
@immutable
class BloomPose {
  /// Ear rotation in radians; negative leans the left ear outward.
  final double earLeft;
  final double earRight;

  /// Vertical shift of both ears in design units (negative = up, "pricked").
  final double earShift;

  /// Bend of the right ear's upper third, in radians. The silhouette's
  /// one asymmetry — keep it in every pose so Bloom reads at 16 px.
  final double earBend;

  final BloomEyes eyes;

  /// How tightly the closed arcs are squeezed (cheer squeezes harder).
  final double eyeSqueeze;

  final BloomMouth mouth;

  /// Scale of the mouth around its centre (`listen` is a touch smaller).
  final double mouthScale;

  /// Cheek scale (1.0 = 14×8 ovals).
  final double cheekScale;

  /// Puffed cheeks for `blow`: big ovals beside the mouth.
  final bool puffCheeks;

  /// Paw centres and rotations. Paws at rest sit at y ≈ 112.
  final Offset pawLeft;
  final double pawLeftAngle;
  final Offset pawRight;
  final double pawRightAngle;

  /// Head tilt in radians, applied around the neck.
  final double headTilt;

  /// Body squash (scaleY around the base line).
  final double bodySquash;

  /// Sleep doodle above the right ear.
  final bool zzz;

  final BloomProp prop;

  const BloomPose({
    this.earLeft = -0.22,
    this.earRight = 0.22,
    this.earShift = 0,
    this.earBend = 0.35,
    this.eyes = BloomEyes.open,
    this.eyeSqueeze = 0,
    this.mouth = BloomMouth.smile,
    this.mouthScale = 1,
    this.cheekScale = 1,
    this.puffCheeks = false,
    this.pawLeft = const Offset(40, 112),
    this.pawLeftAngle = 0,
    this.pawRight = const Offset(80, 112),
    this.pawRightAngle = 0,
    this.headTilt = 0,
    this.bodySquash = 1,
    this.zzz = false,
    this.prop = BloomProp.none,
  });

  /// Where the raised right paw sits when waving / pointing up.
  static const Offset raisedRight = Offset(92, 58);
  static const Offset raisedLeft = Offset(28, 58);

  // ── The nine poses (§2.2) ─────────────────────────────────────────────

  static const idle = BloomPose();

  static const wave = BloomPose(
    earLeft: -0.10,
    earRight: 0.10,
    eyes: BloomEyes.happyClosed,
    pawRight: raisedRight,
    pawRightAngle: 0.4,
  );

  static const listen = BloomPose(
    earLeft: -0.08,
    earRight: 0.08,
    earShift: -3,
    mouthScale: 0.85,
  );

  static const happy = BloomPose(
    earLeft: -0.16,
    earRight: 0.16,
    eyes: BloomEyes.happyClosed,
  );

  static const cheer = BloomPose(
    earLeft: -0.08,
    earRight: 0.08,
    eyes: BloomEyes.happyClosed,
    eyeSqueeze: 1,
    mouth: BloomMouth.cheerD,
    cheekScale: 1.2,
    pawLeft: raisedLeft,
    pawLeftAngle: -0.4,
    pawRight: raisedRight,
    pawRightAngle: 0.4,
    headTilt: 0.08,
  );

  static const curious = BloomPose(
    earLeft: -0.42,
    earRight: 0.22,
    mouth: BloomMouth.o,
    headTilt: 0.105, // 6°
  );

  static const point = BloomPose(
    earLeft: -0.14,
    earRight: 0.14,
    headTilt: 0.052, // 3°
    pawRight: Offset(92, 74),
    pawRightAngle: -0.6,
  );

  static const sleep = BloomPose(
    earLeft: -0.6,
    earRight: 0.6,
    earShift: 6,
    eyes: BloomEyes.sleepClosed,
    mouth: BloomMouth.line,
    pawLeft: Offset(46, 108),
    headTilt: -0.14, // 8°
    bodySquash: 0.97,
    zzz: true,
  );

  static const blow = BloomPose(
    earLeft: -0.35,
    earRight: 0.35,
    eyes: BloomEyes.happyClosed,
    mouth: BloomMouth.o,
    puffCheeks: true,
    pawRight: raisedRight,
    pawRightAngle: 0.4,
    prop: BloomProp.wand,
  );

  /// The constant pose of [emotion], carrying [prop] into the right paw.
  static BloomPose of(BloomEmotion emotion, {BloomProp prop = BloomProp.none}) {
    final base = switch (emotion) {
      BloomEmotion.idle => idle,
      BloomEmotion.wave => wave,
      BloomEmotion.listen => listen,
      BloomEmotion.happy => happy,
      BloomEmotion.cheer => cheer,
      BloomEmotion.curious => curious,
      BloomEmotion.point => point,
      BloomEmotion.sleep => sleep,
      BloomEmotion.blow => blow,
    };
    if (prop == base.prop) return base;
    return base.copyWith(prop: prop);
  }

  BloomPose copyWith({
    double? earLeft,
    double? earRight,
    double? earShift,
    double? earBend,
    BloomEyes? eyes,
    double? eyeSqueeze,
    BloomMouth? mouth,
    double? mouthScale,
    double? cheekScale,
    bool? puffCheeks,
    Offset? pawLeft,
    double? pawLeftAngle,
    Offset? pawRight,
    double? pawRightAngle,
    double? headTilt,
    double? bodySquash,
    bool? zzz,
    BloomProp? prop,
  }) {
    return BloomPose(
      earLeft: earLeft ?? this.earLeft,
      earRight: earRight ?? this.earRight,
      earShift: earShift ?? this.earShift,
      earBend: earBend ?? this.earBend,
      eyes: eyes ?? this.eyes,
      eyeSqueeze: eyeSqueeze ?? this.eyeSqueeze,
      mouth: mouth ?? this.mouth,
      mouthScale: mouthScale ?? this.mouthScale,
      cheekScale: cheekScale ?? this.cheekScale,
      puffCheeks: puffCheeks ?? this.puffCheeks,
      pawLeft: pawLeft ?? this.pawLeft,
      pawLeftAngle: pawLeftAngle ?? this.pawLeftAngle,
      pawRight: pawRight ?? this.pawRight,
      pawRightAngle: pawRightAngle ?? this.pawRightAngle,
      headTilt: headTilt ?? this.headTilt,
      bodySquash: bodySquash ?? this.bodySquash,
      zzz: zzz ?? this.zzz,
      prop: prop ?? this.prop,
    );
  }

  /// Interpolate [a] → [b]. Discrete fields switch at t = 0.5.
  static BloomPose lerp(BloomPose a, BloomPose b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final late = t >= 0.5;
    double d(double x, double y) => lerpDouble(x, y, t) ?? y;
    return BloomPose(
      earLeft: d(a.earLeft, b.earLeft),
      earRight: d(a.earRight, b.earRight),
      earShift: d(a.earShift, b.earShift),
      earBend: d(a.earBend, b.earBend),
      eyes: late ? b.eyes : a.eyes,
      eyeSqueeze: d(a.eyeSqueeze, b.eyeSqueeze),
      mouth: late ? b.mouth : a.mouth,
      mouthScale: d(a.mouthScale, b.mouthScale),
      cheekScale: d(a.cheekScale, b.cheekScale),
      puffCheeks: late ? b.puffCheeks : a.puffCheeks,
      pawLeft: Offset.lerp(a.pawLeft, b.pawLeft, t) ?? b.pawLeft,
      pawLeftAngle: d(a.pawLeftAngle, b.pawLeftAngle),
      pawRight: Offset.lerp(a.pawRight, b.pawRight, t) ?? b.pawRight,
      pawRightAngle: d(a.pawRightAngle, b.pawRightAngle),
      headTilt: d(a.headTilt, b.headTilt),
      bodySquash: d(a.bodySquash, b.bodySquash),
      zzz: late ? b.zzz : a.zzz,
      prop: late ? b.prop : a.prop,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BloomPose &&
      other.earLeft == earLeft &&
      other.earRight == earRight &&
      other.earShift == earShift &&
      other.earBend == earBend &&
      other.eyes == eyes &&
      other.eyeSqueeze == eyeSqueeze &&
      other.mouth == mouth &&
      other.mouthScale == mouthScale &&
      other.cheekScale == cheekScale &&
      other.puffCheeks == puffCheeks &&
      other.pawLeft == pawLeft &&
      other.pawLeftAngle == pawLeftAngle &&
      other.pawRight == pawRight &&
      other.pawRightAngle == pawRightAngle &&
      other.headTilt == headTilt &&
      other.bodySquash == bodySquash &&
      other.zzz == zzz &&
      other.prop == prop;

  @override
  int get hashCode => Object.hashAll([
        earLeft,
        earRight,
        earShift,
        earBend,
        eyes,
        eyeSqueeze,
        mouth,
        mouthScale,
        cheekScale,
        puffCheeks,
        pawLeft,
        pawLeftAngle,
        pawRight,
        pawRightAngle,
        headTilt,
        bodySquash,
        zzz,
        prop,
      ]);
}
