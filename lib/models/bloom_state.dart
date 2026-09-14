import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../widgets/bloom/bloom_pose.dart';

export '../widgets/bloom/bloom_pose.dart' show BloomEmotion, BloomProp;

/// Which resting state Bloom returns to after a one-shot
/// (docs/design/bloom_character.md §5.3): `sleep` < `idle` < `listen`.
enum BloomLevel { sleep, idle, listen }

/// What the host allows Bloom to do with the motion budget (§2.4).
///
/// * [breathe] — nothing else on screen moves continuously; Bloom may
///   breathe (3.0 s) and blink.
/// * [blinkOnly] — the learning object owns the budget (a word pulses,
///   bubbles drift); Bloom only blinks.
/// * [still] — overlays, splash, tests: no blink either.
enum BloomAmbient { breathe, blinkOnly, still }

/// Bloom's own sounds (§6). Files live in `assets/audio_sfx/bloom_*.wav`;
/// until they are recorded `AudioService.playBloom` is a silent no-op.
enum BloomSound {
  hi('bloom_hi', 0.5),
  bye('bloom_bye', 0.4),
  giggle('bloom_giggle_1', 0.6),
  hmm('bloom_hmm', 0.4),
  yay('bloom_yay', 0.6),
  zzz('bloom_zzz', 0.3),
  blow('bloom_blow', 0.5);

  const BloomSound(this.file, this.volume);

  /// File stem under `assets/audio_sfx/`.
  final String file;

  /// Playback volume — always under the word (1.0).
  final double volume;
}

/// What a screen declares about itself when Bloom is on it (§5.4).
///
/// The notifier never learns it is on "the cards screen"; it learns what is
/// permitted here. Hosts update it on the fly (cards: `hintsEnabled =
/// !autoPlay`; home: `ambient = heroDone ? breathe : blinkOnly`).
@immutable
class BloomScene {
  final BloomAmbient ambient;

  /// Whether idle hints (`point`) may fire at all.
  final bool hintsEnabled;

  /// Time without a touch before Bloom falls asleep; `null` = never.
  final Duration? sleepAfter;

  /// Bloom is the only actor (cards, home) — his hint sound may play. In a
  /// game the object makes the sound and Bloom stays quiet.
  final bool soloActor;

  /// Whether the second hint demonstrates a swipe (paw slides sideways).
  final bool swipeHint;

  /// What Bloom holds on this stage — the bubble wand in the bubble game.
  final BloomProp prop;

  /// What a tap on Bloom himself means here. `happy` everywhere by
  /// default — the hop and the giggle of §5.1. A stage where Bloom is the
  /// *cause* of what the child plays with says so: in «Лопай бульбашки»
  /// the tap blows a bubble out of the wand, so the pose is `blow`
  /// (bubble_pop_redesign §2). Without this the `happy` of `bloomTapped`
  /// outranks `blow` (6 > 5) and the pose could never be seen.
  final BloomEmotion tapEmotion;

  const BloomScene({
    this.ambient = BloomAmbient.blinkOnly,
    this.hintsEnabled = false,
    this.sleepAfter,
    this.soloActor = false,
    this.swipeHint = false,
    this.prop = BloomProp.none,
    this.tapEmotion = BloomEmotion.happy,
  });

  /// The cards screen: hints, a 30 s nap, the swipe demo, Bloom alone.
  static const cards = BloomScene(
    ambient: BloomAmbient.blinkOnly,
    hintsEnabled: true,
    sleepAfter: Duration(seconds: 30),
    soloActor: true,
    swipeHint: true,
  );

  /// The home tab: hints towards the hero, a 45 s nap.
  static const home = BloomScene(
    ambient: BloomAmbient.blinkOnly,
    hintsEnabled: true,
    sleepAfter: Duration(seconds: 45),
    soloActor: true,
  );

  /// «Лопай бульбашки» (docs/design/bubble_pop_redesign.md §2): the
  /// bubbles own the motion budget, no idle hints, no nap, the object
  /// makes the sound — and Bloom holds the wand the bubbles come from.
  static const bubbles = BloomScene(
    ambient: BloomAmbient.blinkOnly,
    prop: BloomProp.wand,
    tapEmotion: BloomEmotion.blow,
  );

  /// «Знайди пару» (docs/design/memory_match_redesign.md §2, §3): the
  /// board owns the motion budget and makes the sounds, so Bloom sits
  /// beside the mat and only reacts. No idle hints (the board's own
  /// two-step nudge is wave 2) and no nap — a mascot that falls asleep
  /// mid-round reads as "the game ended".
  static const memory = BloomScene(ambient: BloomAmbient.blinkOnly);

  /// Overlays and tests: nothing ticks.
  static const still = BloomScene(ambient: BloomAmbient.still);

  BloomScene copyWith({
    BloomAmbient? ambient,
    bool? hintsEnabled,
    Duration? sleepAfter,
    bool clearSleep = false,
    bool? soloActor,
    bool? swipeHint,
    BloomProp? prop,
    BloomEmotion? tapEmotion,
  }) {
    return BloomScene(
      ambient: ambient ?? this.ambient,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      sleepAfter: clearSleep ? null : (sleepAfter ?? this.sleepAfter),
      soloActor: soloActor ?? this.soloActor,
      swipeHint: swipeHint ?? this.swipeHint,
      prop: prop ?? this.prop,
      tapEmotion: tapEmotion ?? this.tapEmotion,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BloomScene &&
      other.ambient == ambient &&
      other.hintsEnabled == hintsEnabled &&
      other.sleepAfter == sleepAfter &&
      other.soloActor == soloActor &&
      other.swipeHint == swipeHint &&
      other.prop == prop &&
      other.tapEmotion == tapEmotion;

  @override
  int get hashCode => Object.hash(ambient, hintsEnabled, sleepAfter, soloActor,
      swipeHint, prop, tapEmotion);
}

/// Bloom right now (§5.2). A value: the widget compares it with the last
/// one and decides which transition to play. [serial] increments on every
/// one-shot so a repeated `happy` still reads as a new hop.
@immutable
class BloomState {
  final BloomEmotion emotion;
  final BloomLevel level;

  /// Hops for `cheer` (1 or 3) and `happy` (1; 0 = face only, no hop).
  final int hops;

  /// Where the pupils look, `-1..1` per axis; `null` = straight ahead.
  final Alignment? lookAt;

  /// Direction of the `point` gesture, from Bloom towards the target.
  final Alignment? hintDirection;

  /// `point` demonstrates a swipe: the paw slides 24 dp sideways instead of
  /// reaching towards the target.
  final bool swipeGesture;

  final BloomProp prop;
  final BloomAmbient ambient;
  final int serial;

  const BloomState({
    this.emotion = BloomEmotion.idle,
    this.level = BloomLevel.idle,
    this.hops = 1,
    this.lookAt,
    this.hintDirection,
    this.swipeGesture = false,
    this.prop = BloomProp.none,
    this.ambient = BloomAmbient.blinkOnly,
    this.serial = 0,
  });

  /// A frozen pose for overlays, goldens and marketing renders.
  const BloomState.still(
    this.emotion, {
    this.prop = BloomProp.none,
    this.lookAt,
    this.hops = 1,
  })  : level = BloomLevel.idle,
        hintDirection = null,
        swipeGesture = false,
        ambient = BloomAmbient.still,
        serial = 0;

  BloomState copyWith({
    BloomEmotion? emotion,
    BloomLevel? level,
    int? hops,
    Alignment? lookAt,
    bool clearLookAt = false,
    Alignment? hintDirection,
    bool clearHint = false,
    bool? swipeGesture,
    BloomProp? prop,
    BloomAmbient? ambient,
    int? serial,
  }) {
    return BloomState(
      emotion: emotion ?? this.emotion,
      level: level ?? this.level,
      hops: hops ?? this.hops,
      lookAt: clearLookAt ? null : (lookAt ?? this.lookAt),
      hintDirection:
          clearHint ? null : (hintDirection ?? this.hintDirection),
      swipeGesture: swipeGesture ?? this.swipeGesture,
      prop: prop ?? this.prop,
      ambient: ambient ?? this.ambient,
      serial: serial ?? this.serial,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BloomState &&
      other.emotion == emotion &&
      other.level == level &&
      other.hops == hops &&
      other.lookAt == lookAt &&
      other.hintDirection == hintDirection &&
      other.swipeGesture == swipeGesture &&
      other.prop == prop &&
      other.ambient == ambient &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(
        emotion,
        level,
        hops,
        lookAt,
        hintDirection,
        swipeGesture,
        prop,
        ambient,
        serial,
      );

  @override
  String toString() =>
      'BloomState($emotion, level: $level, hops: $hops, serial: $serial)';
}

/// How big the success was (§5.1 `success.tier`).
enum BloomSuccessTier { micro, round }

/// Everything a screen may tell Bloom (§5.1). Screens describe what
/// happened; `BloomReactions` decides what Bloom does about it.
sealed class BloomEvent {
  const BloomEvent();
}

/// Home is on screen and the intro-modal queue is empty.
final class BloomAppEntered extends BloomEvent {
  final bool firstOfDay;
  const BloomAppEntered({this.firstOfDay = false});
}

/// The app came back to the foreground after [away].
final class BloomAppResumed extends BloomEvent {
  final Duration away;
  const BloomAppResumed(this.away);
}

/// The app left the foreground: every timer stops.
final class BloomAppPaused extends BloomEvent {
  const BloomAppPaused();
}

/// A host mounted (or changed what it allows). [key] identifies the host
/// so a screen pushed over another can leave and hand the stage back.
final class BloomSceneEntered extends BloomEvent {
  final Object key;
  final BloomScene scene;
  const BloomSceneEntered(this.key, this.scene);
}

final class BloomSceneLeft extends BloomEvent {
  final Object key;
  const BloomSceneLeft(this.key);
}

/// The cards screen opened a pack: a curious look at the first card.
final class BloomPackOpened extends BloomEvent {
  const BloomPackOpened();
}

/// The page moved forward to [index].
final class BloomCardAdvanced extends BloomEvent {
  final int index;
  const BloomCardAdvanced(this.index);
}

/// The learning object was tapped (a card, a game option). Activity only;
/// the pose will come from `isSpeaking`.
final class BloomObjectTapped extends BloomEvent {
  const BloomObjectTapped();
}

final class BloomSuccess extends BloomEvent {
  final BloomSuccessTier tier;
  const BloomSuccess(this.tier);
}

final class BloomMiss extends BloomEvent {
  final int countInRound;
  const BloomMiss(this.countInRound);
}

/// A pack was played through: the big cheer.
final class BloomPackCompleted extends BloomEvent {
  const BloomPackCompleted();
}

/// Any pointer down on a child screen.
final class BloomUserTouch extends BloomEvent {
  final Offset? position;
  const BloomUserTouch([this.position]);
}

/// The child tapped Bloom himself.
final class BloomTapped extends BloomEvent {
  const BloomTapped();
}

/// Where a `point` should aim, from Bloom towards the target.
final class BloomHintTargetChanged extends BloomEvent {
  final Alignment? target;
  const BloomHintTargetChanged(this.target);
}

/// Home / Done / back: a goodbye wave, voiced only when the host says so.
final class BloomSessionEnding extends BloomEvent {
  final bool withSound;
  const BloomSessionEnding({this.withSound = false});
}
