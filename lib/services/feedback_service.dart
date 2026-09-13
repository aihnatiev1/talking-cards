import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/design_tokens.dart';
import 'audio_service.dart';

/// Something the child just did, or that just happened to them.
///
/// Screens name the *event*; the service decides what it sounds and feels
/// like. Before this there were 42 `HapticFeedback.*` calls in 23 files and
/// 25 `playSfx` calls in 11, each picking light/medium and pop/ding on the
/// spot — so a correct answer was medium+ding in one game and light+ding in
/// the next (architecture audit 2026-09-13 §1.5–1.6, F3).
enum FeedbackEvent {
  /// Any child tap that counts — `KidTap`, a pill, a bubble.
  tap,

  /// Picking one option among several (not yet judged right or wrong).
  select,

  /// A right answer inside a game (T0 micro success).
  correct,

  /// A wrong answer. Soft, never a buzzer: no haptic, a low quiet pop.
  wrong,

  /// A locked tile / gated action was tapped: "not this one, but heard".
  lockedHint,

  /// End of a game round (T1).
  roundDone,

  /// End of a whole game session — same voice as [roundDone] today.
  gameDone,

  /// A pack fully played through (T4).
  packDone,

  /// A parent-facing milestone such as a streak (T3): quiet bell, no cheer.
  milestone,

  /// The daily-quest card is unveiled (T2 open moment).
  reveal,

  /// Page swipe between cards.
  swipe,
}

/// Haptic kinds the table can ask for. Kept as our own enum so nothing but
/// [FeedbackService] has to import `HapticFeedback`.
enum FeedbackHaptic { none, light, medium, heavy }

/// One row of the feedback table: what an event sounds and feels like.
@immutable
class FeedbackSpec {
  /// File stem under `assets/audio_sfx/` (`pop`, `ding`, `tada`).
  final String? sfx;

  /// Playback-speed multiplier at the centre of the pitch range.
  final double pitch;

  /// Random ± spread around [pitch] so twenty pops are not one pop.
  final double spread;

  final double volume;
  final FeedbackHaptic haptic;

  /// Whether a recorded praise clip follows (always — the rate-limited
  /// every-other praise inside games stays a game decision).
  final bool praise;

  /// Gap between the sfx and the praise: the voice waits for the tada
  /// attack to land instead of speaking over it.
  final Duration praiseAfter;

  const FeedbackSpec({
    required String this.sfx,
    this.pitch = 1.0,
    this.spread = 0.0,
    this.volume = 1.0,
    this.haptic = FeedbackHaptic.none,
    this.praise = false,
    this.praiseAfter = Duration.zero,
  });

  /// A row that deliberately makes no sound. Named so the table can never
  /// go quiet by accident — a silent event is a choice, not a missing file.
  const FeedbackSpec.silent({this.haptic = FeedbackHaptic.none})
      : sfx = null,
        pitch = 1.0,
        spread = 0.0,
        volume = 1.0,
        praise = false,
        praiseAfter = Duration.zero;

  bool get isSilent => sfx == null;
}

/// The one place a child action becomes a sound and a haptic.
///
/// `KidTap` routes its press here; games call [event] with `correct` /
/// `wrong`; `Celebration` calls it once with `roundDone` / `packDone` /
/// `milestone`. Everything is fire-and-forget and silent-safe: the SFX and
/// praise clips are placeholders (or not recorded yet) and `AudioService`
/// swallows a missing file, so the pipeline is complete before the sounds
/// are. `test/architecture/feedback_test.dart` keeps `HapticFeedback.` and
/// `playSfx(` out of every other file.
class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  /// Tests set this to keep the platform channel and SoLoud out of the
  /// loop; every [event] is then appended to [debugLog] instead of played.
  static bool debugMute = false;

  /// Events recorded while [debugMute] is on. Clear it in `setUp`.
  static final List<FeedbackEvent> debugLog = [];

  final Random _rng = Random();

  /// The table. One row per event, documented inline; a new event gets a
  /// row here and nowhere else.
  static final Map<FeedbackEvent, FeedbackSpec> table = {
    // A child tap: a soft pop with a little pitch wobble + the lightest
    // haptic. Volume under the word so a tap never covers the narrator.
    FeedbackEvent.tap: const FeedbackSpec(
      sfx: 'pop',
      volume: 0.6,
      spread: 0.1,
      haptic: FeedbackHaptic.light,
    ),
    // Choosing an option: a slightly lower pop so it reads as "taken",
    // distinct from the plain tap of a button.
    FeedbackEvent.select: const FeedbackSpec(
      sfx: 'pop',
      pitch: 0.9,
      haptic: FeedbackHaptic.light,
    ),
    // Right answer: the ding, varied so a five-in-a-row streak sparkles
    // instead of repeating, and a medium bump the hand can feel.
    FeedbackEvent.correct: const FeedbackSpec(
      sfx: 'ding',
      spread: 0.08,
      haptic: FeedbackHaptic.medium,
    ),
    // Wrong answer: a low quiet pop and *no* haptic. Toddlers read a buzz
    // as punishment; this only says "heard you, try another".
    FeedbackEvent.wrong: const FeedbackSpec(
      sfx: 'pop',
      pitch: 0.7,
      volume: 0.4,
    ),
    // Locked tile: a muted pop + light tap — acknowledged, not opened.
    FeedbackEvent.lockedHint: const FeedbackSpec(
      sfx: 'pop',
      pitch: 0.8,
      haptic: FeedbackHaptic.light,
    ),
    // Round over: tada + medium bump, then a recorded cheer once the tada
    // has landed. Always praise — every finished round is a full win.
    FeedbackEvent.roundDone: FeedbackSpec(
      sfx: 'tada',
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Game over: identical to roundDone until there is a distinct clip.
    FeedbackEvent.gameDone: FeedbackSpec(
      sfx: 'tada',
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Pack complete: the biggest win a child gets — tada, bump, cheer.
    FeedbackEvent.packDone: FeedbackSpec(
      sfx: 'tada',
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Streak milestone is read by a parent: a soft low bell, light tap, no
    // cheer, no confetti.
    FeedbackEvent.milestone: const FeedbackSpec(
      sfx: 'ding',
      pitch: 0.85,
      haptic: FeedbackHaptic.light,
    ),
    // The quest card is unveiled: tada with the heaviest haptic we use.
    // The word itself is content and is spoken by the screen, not here.
    FeedbackEvent.reveal: const FeedbackSpec(
      sfx: 'tada',
      haptic: FeedbackHaptic.heavy,
    ),
    // Page swipe: a barely-there low pop so paging has a texture without
    // competing with the word that is about to play.
    FeedbackEvent.swipe: const FeedbackSpec(
      sfx: 'pop',
      pitch: 0.8,
      volume: 0.3,
      haptic: FeedbackHaptic.light,
    ),
  };

  /// The row for [e]. Every enum value has one (asserted by the table test).
  FeedbackSpec specOf(FeedbackEvent e) =>
      table[e] ?? const FeedbackSpec.silent();

  /// Play [e]. [isEn] picks the praise language when the row has praise.
  ///
  /// [haptic] / [sound] let a caller that already owns one channel drop
  /// it — `KidTap` feels the finger land (haptic only) and hears the tap
  /// count (sound only) at two different moments of the same press.
  void event(
    FeedbackEvent e, {
    bool isEn = false,
    bool haptic = true,
    bool sound = true,
  }) {
    if (debugMute) {
      debugLog.add(e);
      return;
    }
    final spec = specOf(e);
    if (haptic) _haptic(spec.haptic);
    if (!sound) return;

    final sfx = spec.sfx;
    if (sfx != null) {
      final pitch = spec.spread == 0
          ? spec.pitch
          : spec.pitch + (_rng.nextDouble() * 2 - 1) * spec.spread;
      unawaited(
        AudioService.instance.playSfx(sfx, volume: spec.volume, pitch: pitch),
      );
    }
    if (spec.praise) {
      if (spec.praiseAfter == Duration.zero) {
        unawaited(AudioService.instance.playPraise(isEn: isEn, always: true));
      } else {
        Timer(spec.praiseAfter, () {
          unawaited(
            AudioService.instance.playPraise(isEn: isEn, always: true),
          );
        });
      }
    }
  }

  void _haptic(FeedbackHaptic kind) {
    switch (kind) {
      case FeedbackHaptic.none:
        break;
      case FeedbackHaptic.light:
        HapticFeedback.lightImpact();
      case FeedbackHaptic.medium:
        HapticFeedback.mediumImpact();
      case FeedbackHaptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}
