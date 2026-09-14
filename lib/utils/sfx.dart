/// The SFX palette — one role per sound (docs/design/sound_palette.md §2).
///
/// A screen never names a file. It names an event (`FeedbackService`) or,
/// for a press, a role (`KidTap(sound: KidSound.cardTouch)`); this enum is
/// the only place the role becomes a filename, a level and a pitch range.
/// The three synthesized placeholders that shipped in v1 (`pop`, `ding`,
/// `tada`) are still the only files on disk, so every role also names the
/// placeholder that stands in for it. `AudioService.play` tries the role's
/// own file first and drops to the placeholder once per session when the
/// file is not there — the day the studio WAVs land in
/// `assets/audio_sfx/`, nothing in code changes.
///
/// Levels are the `volume:` column of §2.1 / §3.5: files are normalised per
/// class (§4.3) and the *mix* lives here, so the owner can audition all
/// files at one gain and the app still keeps every SFX under the word.
enum KidSound {
  /// Wooden "tock" of a fingertip on a block — every plain button.
  tap('tap', fallback: 'pop', volume: 0.6, spread: 0.10, transient: true),

  /// Finger lands on thick paper. The one sound played on pointer-down and
  /// the one SFX that may sit under the start of a word (it is over in
  /// 40 ms).
  cardTouch(
    'card_touch',
    fallback: 'pop',
    volume: 0.35,
    spread: 0.06,
    transient: true,
  ),

  /// Felt "puh" — a tap into nothing, a locked tile. Never a "no".
  tapSoft(
    'tap_soft',
    fallback: 'pop',
    volume: 0.4,
    spread: 0.10,
    fallbackPitch: 0.8,
    transient: true,
  ),

  /// A card laid on a wooden table: the page landing after a swipe
  /// (0.85 = the sound of weight) or an element appearing (1.0).
  cardLand(
    'card_land',
    fallback: 'pop',
    volume: 0.4,
    pitch: 0.85,
    spread: 0.03,
    transient: true,
  ),

  /// Paper snap of a card turning over.
  flip('flip', fallback: 'pop', volume: 0.5, transient: true),

  /// Wooden tock + the lid of a cardboard box lifting. Every entry into
  /// `CardsScreen`; it *replaces* `tap` on the pack tile.
  packOpen('pack_open', fallback: 'pop', volume: 0.6, spread: 0.04),

  /// Two xylophone notes up — a right answer.
  successSmall('success_small', fallback: 'ding', volume: 0.7, spread: 0.08),

  /// Three notes up — the fifth card, a matched pair. Pitch climbs
  /// 0.06 per step (the `ladder` in `FeedbackService`).
  successMedium('success_medium', fallback: 'ding', volume: 0.7),

  /// Five-note toy fanfare — a pack, a round. Plays at 0 ms of the
  /// celebration; the narrator's praise (or `bloom_yay`) follows at 400.
  successLarge('success_large', fallback: 'tada', volume: 0.8),

  /// One muted low marimba note. The placeholder pop is dropped to 0.7 so
  /// a miss still reads lower than a tap until the real file arrives.
  miss(
    'miss',
    fallback: 'pop',
    volume: 0.4,
    spread: 0.05,
    fallbackPitch: 0.7,
  ),

  /// A real soap bubble. Games only — never a button.
  pop('pop', fallback: 'pop', volume: 0.7, transient: true, variants: 3),

  /// Wooden latch + short glockenspiel run up — something opened.
  unlock('unlock', fallback: 'tada', volume: 0.7),

  /// A pencil tick on the table — autoplay anticipation.
  tick('tick', fallback: 'pop', volume: 0.3, transient: true);

  const KidSound(
    this.file, {
    required this.fallback,
    required this.volume,
    this.pitch = 1.0,
    this.spread = 0.0,
    this.fallbackPitch = 1.0,
    this.transient = false,
    this.variants = 1,
  });

  /// File stem under `assets/audio_sfx/` — `success_medium.wav`.
  final String file;

  /// One of the three v1 placeholders that stands in while [file] is not
  /// on disk. Always one of [placeholders].
  final String fallback;

  /// The `volume:` of the play call — the mix, relative to the word at
  /// 1.0 (§3.2).
  final double volume;

  /// Centre of the playback-speed range (1.0 = as recorded).
  final double pitch;

  /// Random ± around [pitch] so twenty taps are not one tap (§1 п. 5).
  final double spread;

  /// Extra pitch multiplier applied only when the placeholder plays, so a
  /// role whose character differs from its stand-in (a low `miss` vs the
  /// bright `pop`) still reads right before its file exists.
  final double fallbackPitch;

  /// Class A of §3.1 — a transient ≤ 120 ms that may start over a word
  /// without masking it. Tonal roles (B/C) are `false` and are dropped by
  /// `AudioService.play(dropIfSpeaking: true)` while the narrator speaks.
  final bool transient;

  /// How many recordings of this role exist, numbered from 1
  /// (`pop_1.wav`, `pop_2.wav`, `pop_3.wav`). More than one because pitch
  /// alone cannot hide repetition in the sound a child triggers most: a
  /// bubble round is twenty pops, and the third identical one has already
  /// stopped being a reward. 1 means a single unnumbered file.
  final int variants;

  /// The files the v1 build shipped; every [fallback] is one of these.
  static const placeholders = {'pop', 'ding', 'tada'};

  /// Where the palette lives — the base module, never the Play asset pack
  /// (§4.2): a child's first minute does not wait for a download.
  static const dir = 'assets/audio_sfx';

  String get assetPath => '$dir/$file.wav';

  /// Path of variant [i] (1-based), or [assetPath] for a single-take role.
  String variantPath(int i) => variants == 1 ? assetPath : '$dir/${file}_$i.wav';
  String get fallbackPath => '$dir/$fallback.wav';

  /// The seven roles `AudioService.warmSfx` decodes on the splash so the
  /// first tap of a session is not the one that pays the Android
  /// asset-copy latency (§4.6).
  static const warm = [
    tap,
    cardTouch,
    cardLand,
    packOpen,
    successSmall,
    successLarge,
  ];
}
