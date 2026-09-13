import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/bloom_state.dart';
import '../utils/design_tokens.dart';
import '../utils/sfx.dart';
import 'audio_service.dart';

/// Something the child just did, or that just happened to them.
///
/// Screens name the *event*; the service decides what it sounds and feels
/// like. Before this there were 42 `HapticFeedback.*` calls in 23 files and
/// 25 `playSfx` calls in 11, each picking light/medium and pop/ding on the
/// spot — so a correct answer was medium+ding in one game and light+ding in
/// the next (architecture audit 2026-09-13 §1.5–1.6, F3). The rows are the
/// table of docs/design/sound_palette.md §3.5.
enum FeedbackEvent {
  /// Any child tap that counts — `KidTap`, a pill, a bubble.
  tap,

  /// Picking one option among several (not yet judged right or wrong).
  select,

  /// Finger lands on a flash card: `card_touch` on pointer-down, the word
  /// follows on the release.
  cardTouch,

  /// A page settled after a swipe (`ScrollEndNotification`) — the card lay
  /// down on the table. The 50 % crossing is [swipe] (haptic only).
  pageLanded,

  /// Entering a pack — every way into `CardsScreen`. Replaces [tap] on the
  /// pack tile, so one gesture is one sound.
  packOpen,

  /// A right answer inside a game (T0 micro success).
  correct,

  /// Progress in the main loop: every fifth card, a matched pair. Pitch
  /// climbs a step per occurrence; only ever after the word has ended.
  progressStep,

  /// A wrong answer. Soft, never a buzzer: no haptic, one muted low note.
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

  /// Page swipe crossed 50 % — haptic only; the sound is [pageLanded].
  swipe,

  /// A bubble burst under a finger («Лопай бульбашки»). The game passes
  /// the pitch — large bubble low, small bubble high — so the row keeps
  /// no spread of its own.
  bubblePop,

  /// A tap into empty space inside a game: the screen answers every touch
  /// (rule 2) with a soft "puh" and a selection click, but there is no
  /// judgement in it — not a miss, not a "no".
  emptyTap,
}

/// Haptic kinds the table can ask for. Kept as our own enum so nothing but
/// [FeedbackService] has to import `HapticFeedback`.
enum FeedbackHaptic { none, selection, light, medium, heavy }

/// One row of the feedback table: what an event sounds and feels like.
///
/// Pitch, spread and volume default to the role's own mix ([KidSound]);
/// a row overrides only what makes this event different from the role's
/// plain use (the streak bell is `success_small` lowered and quieter).
@immutable
class FeedbackSpec {
  /// The palette role, or `null` for a row that is silent on purpose.
  final KidSound? sound;

  final double? _pitch;
  final double? _spread;
  final double? _volume;

  /// Pitch added per step of a repeating event (`1.0 + ladder·(k−1)`).
  final double ladder;

  /// Drop the sound while the narrator speaks instead of playing over the
  /// word. Only meaningful for tonal roles; transients always play.
  final bool waitsForVoice;

  final FeedbackHaptic haptic;

  /// Whether a recorded praise clip follows (always — the rate-limited
  /// every-other praise inside games stays a game decision). When no
  /// praise file is bundled, Bloom's `yay` stands in at the same beat.
  final bool praise;

  /// Gap between the sfx and the praise: the voice waits for the fanfare
  /// attack to land instead of speaking over it.
  final Duration praiseAfter;

  const FeedbackSpec({
    required KidSound this.sound,
    double? pitch,
    double? spread,
    double? volume,
    this.ladder = 0.0,
    this.waitsForVoice = false,
    this.haptic = FeedbackHaptic.none,
    this.praise = false,
    this.praiseAfter = Duration.zero,
  })  : _pitch = pitch,
        _spread = spread,
        _volume = volume;

  /// A row that deliberately makes no sound. Named so the table can never
  /// go quiet by accident — a silent event is a choice, not a missing file.
  const FeedbackSpec.silent({this.haptic = FeedbackHaptic.none})
      : sound = null,
        _pitch = null,
        _spread = null,
        _volume = null,
        ladder = 0.0,
        waitsForVoice = false,
        praise = false,
        praiseAfter = Duration.zero;

  bool get isSilent => sound == null;

  /// Playback-speed multiplier at the centre of the pitch range.
  double get pitch => _pitch ?? sound?.pitch ?? 1.0;

  /// Random ± spread around [pitch] so twenty pops are not one pop.
  double get spread => _spread ?? sound?.spread ?? 0.0;

  double get volume => _volume ?? sound?.volume ?? 1.0;
}

/// The one place a child action becomes a sound and a haptic.
///
/// `KidTap` routes its press here; games call [event] with `correct` /
/// `wrong`; `Celebration` calls it once with `roundDone` / `packDone` /
/// `milestone`. Everything is fire-and-forget and silent-safe: the palette
/// files are still placeholders (or not recorded yet) and `AudioService`
/// swallows a missing file, so the pipeline is complete before the sounds
/// are. `test/architecture/feedback_test.dart` keeps `HapticFeedback.` and
/// `playSfx(` out of every other file; `test/services/sfx_palette_test.dart`
/// keeps sound *names* out of every file but the palette.
class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  /// Tests set this to keep the platform channel and SoLoud out of the
  /// loop; every [event] is then appended to [debugLog] instead of played.
  static bool debugMute = false;

  /// Events recorded while [debugMute] is on. Clear it in `setUp`.
  static final List<FeedbackEvent> debugLog = [];

  /// Role sounds asked for through [play] while [debugMute] is on.
  static final List<KidSound> debugSounds = [];

  /// A/B on device (sound_palette §9 п. 5): `card_touch` is the most
  /// frequent sound in the app and lands 80–150 ms before the word. Off
  /// means a flash card keeps the haptic and the word only, as before.
  static bool cardTouchEnabled = true;

  /// Observers of the event stream — `BloomReactions` is one. Notified for
  /// every [event], muted or not, *before* anything is played, so the
  /// mascot reacts to the same events the child hears and nothing has to
  /// subscribe to analytics a second time (architecture audit F3/F4).
  final List<void Function(FeedbackEvent)> _listeners = [];

  void addListener(void Function(FeedbackEvent) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(FeedbackEvent) listener) =>
      _listeners.remove(listener);

  final Random _rng = Random();

  /// The table. One row per event, documented inline; a new event gets a
  /// row here and nowhere else.
  static final Map<FeedbackEvent, FeedbackSpec> table = {
    // A child tap: the wooden tock with a little pitch wobble + the
    // lightest haptic. Under the word, so a tap never covers the narrator.
    FeedbackEvent.tap: const FeedbackSpec(
      sound: KidSound.tap,
      haptic: FeedbackHaptic.light,
    ),
    // Choosing an option is a tap on a button — the same tock.
    FeedbackEvent.select: const FeedbackSpec(
      sound: KidSound.tap,
      haptic: FeedbackHaptic.light,
    ),
    // Finger on paper, on the way down. The one down-sound in the app.
    FeedbackEvent.cardTouch: const FeedbackSpec(
      sound: KidSound.cardTouch,
      haptic: FeedbackHaptic.light,
    ),
    // The card lands: low (weight), quiet. The haptic already happened at
    // the 50 % crossing ([swipe]).
    FeedbackEvent.pageLanded: const FeedbackSpec(sound: KidSound.cardLand),
    // Box lid lifting. The tile's own down-haptic is the touch; here only
    // the sound, from `CardsScreen.initState`.
    FeedbackEvent.packOpen: const FeedbackSpec(sound: KidSound.packOpen),
    // Right answer: two notes up, varied so a five-in-a-row streak
    // sparkles instead of repeating, and a medium bump the hand can feel.
    FeedbackEvent.correct: const FeedbackSpec(
      sound: KidSound.successSmall,
      haptic: FeedbackHaptic.medium,
    ),
    // Fifth card / matched pair: three notes, a step higher each time.
    // After the word only — the pause between words belongs to the word.
    FeedbackEvent.progressStep: const FeedbackSpec(
      sound: KidSound.successMedium,
      ladder: 0.06,
      waitsForVoice: true,
      haptic: FeedbackHaptic.medium,
    ),
    // Wrong answer: one muted low note and *no* haptic. Toddlers read a
    // buzz as punishment; this only says "heard you, try another".
    FeedbackEvent.wrong: const FeedbackSpec(sound: KidSound.miss),
    // Locked tile: felt, not wood — acknowledged, not opened.
    FeedbackEvent.lockedHint: const FeedbackSpec(
      sound: KidSound.tapSoft,
      haptic: FeedbackHaptic.light,
    ),
    // Round over: fanfare + medium bump, then the recorded cheer once the
    // fanfare has landed. Always praise — every finished round is a win.
    FeedbackEvent.roundDone: FeedbackSpec(
      sound: KidSound.successLarge,
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Game over: identical to roundDone until there is a distinct clip.
    FeedbackEvent.gameDone: FeedbackSpec(
      sound: KidSound.successLarge,
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Pack complete: the biggest win a child gets — fanfare, bump, cheer.
    FeedbackEvent.packDone: FeedbackSpec(
      sound: KidSound.successLarge,
      haptic: FeedbackHaptic.medium,
      praise: true,
      praiseAfter: DT.motion.slow,
    ),
    // Streak milestone is read by a parent: the small success, lowered
    // and quieter, light tap, no cheer, no confetti.
    FeedbackEvent.milestone: const FeedbackSpec(
      sound: KidSound.successSmall,
      pitch: 0.85,
      spread: 0.0,
      volume: 0.5,
      haptic: FeedbackHaptic.light,
    ),
    // The quest card is unveiled: fanfare with the heaviest haptic we use.
    // The word itself is content and is spoken by the screen, not here.
    FeedbackEvent.reveal: const FeedbackSpec(
      sound: KidSound.successLarge,
      haptic: FeedbackHaptic.heavy,
    ),
    // Page swipe crossed the middle: the hand feels it; the sound waits
    // for the landing ([pageLanded]) so the word is not preceded by two
    // clicks.
    FeedbackEvent.swipe: const FeedbackSpec.silent(
      haptic: FeedbackHaptic.light,
    ),
    // A bubble pops: the soap-film pop with a medium bump. Pitch comes
    // from the game per bubble size (bubble_pop_redesign §4), so no
    // spread here — the game already makes neighbours differ.
    FeedbackEvent.bubblePop: const FeedbackSpec(
      sound: KidSound.pop,
      spread: 0.0,
      haptic: FeedbackHaptic.medium,
    ),
    // A tap into nothing: felt "puh" plus the lightest click there is.
    // Under the word, no reward, no "no" (bubble_pop_redesign §5).
    FeedbackEvent.emptyTap: const FeedbackSpec(
      sound: KidSound.tapSoft,
      haptic: FeedbackHaptic.selection,
    ),
  };

  /// The row for [e]. Every enum value has one (asserted by the table test).
  FeedbackSpec specOf(FeedbackEvent e) =>
      table[e] ?? const FeedbackSpec.silent();

  /// The event a press with [sound] is, when it is one. `KidTap` asks so a
  /// pack tile or a flash card reports through the same stream Bloom
  /// listens to; roles without an event row play through [play].
  static FeedbackEvent? eventOf(KidSound sound) => switch (sound) {
        KidSound.tap => FeedbackEvent.tap,
        KidSound.cardTouch => FeedbackEvent.cardTouch,
        KidSound.packOpen => FeedbackEvent.packOpen,
        _ => null,
      };

  /// Play [e]. [isEn] picks the praise language when the row has praise.
  ///
  /// [haptic] / [sound] let a caller that already owns one channel drop
  /// it — `KidTap` with `sound: null` feels the finger land and lets the
  /// target speak for itself. [step] is the 1-based occurrence for rows
  /// with a [FeedbackSpec.ladder]; [pitch] overrides the row's centre
  /// (the landing after a swipe *back* is a touch lower).
  void event(
    FeedbackEvent e, {
    bool isEn = false,
    bool haptic = true,
    bool sound = true,
    int step = 1,
    double? pitch,
  }) {
    for (final l in List.of(_listeners)) {
      l(e);
    }
    if (debugMute) {
      debugLog.add(e);
      return;
    }
    final spec = specOf(e);
    if (haptic) _haptic(spec.haptic);
    if (!sound) return;

    final role = spec.sound;
    if (role != null) {
      var p = (pitch ?? spec.pitch) + spec.ladder * (step - 1);
      if (spec.spread > 0) p += (_rng.nextDouble() * 2 - 1) * spec.spread;
      unawaited(
        AudioService.instance.play(
          role,
          volume: spec.volume,
          pitch: p,
          dropIfSpeaking: spec.waitsForVoice,
        ),
      );
    }
    if (spec.praise) {
      if (spec.praiseAfter == Duration.zero) {
        unawaited(_praise(isEn));
      } else {
        Timer(spec.praiseAfter, () => unawaited(_praise(isEn)));
      }
    }
  }

  /// The narrator's cheer, or Bloom's `yay` when no praise clip is bundled
  /// (sound_palette §3.1, bloom_character §6): one voice at the 400 ms
  /// beat, never both, never over a word.
  Future<void> _praise(bool isEn) async {
    final audio = AudioService.instance;
    final spoke = await audio.playPraise(isEn: isEn, always: true);
    if (spoke) return;
    await audio.playBloom(BloomSound.yay.file, volume: BloomSound.yay.volume);
  }

  /// A role by itself, at its own mix — for presses whose sound has no
  /// event row (`KidTap(sound: KidSound.flip)`) and for the speaker-off
  /// tock. Prefer [event] where one exists: Bloom hears events, not roles.
  void play(KidSound sound, {double? pitch, double? volume}) {
    if (debugMute) {
      debugSounds.add(sound);
      return;
    }
    var p = pitch ?? sound.pitch;
    if (pitch == null && sound.spread > 0) {
      p += (_rng.nextDouble() * 2 - 1) * sound.spread;
    }
    unawaited(AudioService.instance.play(sound, pitch: p, volume: volume));
  }

  void _haptic(FeedbackHaptic kind) {
    switch (kind) {
      case FeedbackHaptic.none:
        break;
      case FeedbackHaptic.selection:
        HapticFeedback.selectionClick();
      case FeedbackHaptic.light:
        HapticFeedback.lightImpact();
      case FeedbackHaptic.medium:
        HapticFeedback.mediumImpact();
      case FeedbackHaptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}
