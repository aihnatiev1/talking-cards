import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared design tokens for the kid-facing UI.
///
/// Distilled from competitor research (Khan Kids, Lingokids, Sago Mini, Toca
/// Boca) plus toddler UX heuristics: warm off-white backgrounds, saturated
/// pastel accents, soft shadows, rounded 20+ dp cards, and text large enough
/// for a non-reader's parent to scan at arm's length.
///
/// This file is the *only* place a raw `Color(0x…)` or the `'Nunito'` family
/// name may appear (guarded by `test/architecture/design_tokens_test.dart`).
/// Everything else reads a token — that is what turns a palette into a
/// contract (architecture-gap-audit 2026-09-13, §1.1 / F1).
class DT {
  DT._();

  // ── Surfaces ─────────────────────────────────
  /// The one screen background. The native launch screens (Android
  /// `launch_background` / `windowSplashScreenBackground`, iOS
  /// `LaunchScreen.storyboard`) carry the same hex so the hand-off into the
  /// Flutter splash is seamless — change all four together.
  static const bgWarm = Color(0xFFFFFBF0); // primary screen background
  static const bgCard = Color(0xFFFFF4E0); // peach cream for cards

  /// The paper a printed card is made of (memory_match_redesign §1): less
  /// peach than [bgCard], so a watercolour illustration sits on the same
  /// cream it was painted on instead of on a tinted card.
  static const paper = Color(0xFFFBF4E6);
  static const surfaceWhite = Colors.white;

  /// Parent-zone dark scaffold only (`buildAppDarkTheme`). Deep indigo
  /// instead of the M3 near-black default — keeps the brand's warm feel and
  /// lets the white content cards float. The kid zone has no dark palette
  /// by design (road-to-9 §6).
  static const bgDark = Color(0xFF1E1B2A);

  // ── Text ────────────────────────────────────
  static const textPrimary = Color(0xFF3F3635); // warm charcoal, not black
  static const textSecondary = Color(0xFF6B605B);
  static const textMuted = Color(0xFF9E948E);

  // ── Brand ───────────────────────────────────
  /// Indigo seed of the Material colour scheme and the parent-zone accent.
  /// Formerly `DT.brand` in constants.dart; those names are now aliases.
  static const brand = Color(0xFF6C63FF);

  /// The lit end of a [brand] gradient — the top-left of a round button
  /// that should look like it has a light on it.
  static const brandLit = Color(0xFF9784FF);
  static const teal = Color(0xFF4ECDC4); // formerly DT.teal
  static const soundRed = Color(0xFFD63031); // formerly DT.soundRed
  static const streakOrange = Color(0xFFE17055); // formerly DT.streakOrange

  // ── Brand accents ───────────────────────────
  static const coral = Color(0xFFFF6B6B);
  static const sunBurst = Color(0xFFFFD93D);
  static const mint = Color(0xFF6BCB77);
  static const sky = Color(0xFF4D96FF);
  static const violet = Color(0xFFA78BFA);
  static const peach = Color(0xFFFF8C42);
  static const pink = Color(0xFFE91E8C);

  // Soft tints (use as card backgrounds paired with the accent above)
  static const coralTint = Color(0xFFFFE3E3);
  static const sunTint = Color(0xFFFFF8D6);
  static const mintTint = Color(0xFFE8F5E9);
  static const skyTint = Color(0xFFE3F2FD);
  static const violetTint = Color(0xFFF3E8FF);
  static const peachTint = Color(0xFFFFF3E0);
  static const pinkTint = Color(0xFFFCE4EC);

  // ── Semantic ────────────────────────────────
  static const success = Color(0xFF43A047);

  /// "Look here" — the hint glow and its lightbulb, in every choice game.
  ///
  /// It used to be the card's own accent, which meant the hint on a card
  /// called ЧЕРВОНИЙ was a red frame: the one colour a child (and a
  /// parent) reads as "you got it wrong", on the tile that is in fact the
  /// right answer. One warm amber for every card instead — the colour of
  /// the bulb sitting on it.
  static const hint = Color(0xFFF2A93B);
  static const warning = Color(0xFFE17055);
  static const error = Color(0xFFE53935);

  // ── Bloom (the mascot) ───────────────────────
  /// Bloom's own palette (docs/design/bloom_character.md §2.1). Brand cream,
  /// pink and warm ink — never repainted to a pack accent. `bloomBody` is a
  /// shade deeper than the old `#FFF1E0` so the figure separates from
  /// [bgWarm] at 56 dp; the ink outline sits at [bloomInkAlpha].
  static const bloomBody = Color(0xFFFFEBD2);
  static const bloomShade = Color(0xFFF5E2C7);
  static const bloomEarInside = Color(0xFFFFB7C5);
  static const bloomCheek = Color(0xFFFFC4D0);
  static const bloomNose = Color(0xFFE38DA8);
  static const bloomInk = Color(0xFF3A2E2A);
  static const bloomShadow = Color(0x14000000);
  static const bloomHighlight = Color(0x22FFFFFF);
  static const bloomEyeShine = Colors.white;
  static const double bloomInkAlpha = 0.45;

  // ── Scene: the bubble meadow ─────────────────
  /// Sky and meadow of «Лопай бульбашки» (docs/design/bubble_pop_redesign.md
  /// §1 «Кольори сцени»). The grass shades continue the quest map's
  /// landscape; the sky is deliberately low-contrast — it is a backdrop,
  /// the bubbles are the only high-contrast objects in it.
  static const sceneSkyTop = Color(0xFFD9EDFB);
  static const sceneSkyMid = Color(0xFFEEF4F0);
  static const sceneSkyHorizon = Color(0xFFF7F1DE);
  static const sceneCloud = Colors.white;
  static const sceneGrassFar = Color(0xFFDCEBC7);
  static const sceneGrassNear = Color(0xFFCEE5BC);
  static const sceneGrassShade = Color(0xFFACC991);
  static const sceneBushLight = Color(0xFF90C39A);
  static const sceneBushDark = Color(0xFF6BA989);

  // ── Overlay barriers ────────────────────────
  /// Behind celebrations and full-screen overlays: dark enough to lift the
  /// mascot, light enough that the scene the child was in stays legible.
  static const barrier = Color(0x66000000);

  /// Behind bottom sheets (parent settings, paywall doors) — a lighter veil
  /// because the sheet itself already covers most of the screen.
  static const barrierSheet = Color(0x33000000);

  // ── Spacing scale ───────────────────────────
  static const sp4 = 4.0;
  static const sp8 = 8.0;
  static const sp12 = 12.0;
  static const sp16 = 16.0;
  static const sp20 = 20.0;
  static const sp24 = 24.0;
  static const sp32 = 32.0;

  // ── Radius scale ────────────────────────────
  static const rSm = 12.0;
  static const rMd = 16.0;
  static const rLg = 22.0; // cards / tiles
  static const rXl = 28.0; // heroes

  // ── Sizes ───────────────────────────────────
  /// Tap targets, icons and mascot sizes. `tapMin` is the CLAUDE.md 72dp
  /// rule, encoded once instead of `72`, `56`, `64` written by hand.
  static const size = DTSize._();

  // ── Shadows / elevation ─────────────────────
  /// Text-on-tint colour for a pack/card accent. Accents are picked for
  /// backgrounds and borders; as *text* on their own tint they land at
  /// 2.3–3:1 (audit 2026-09-08, #3), below AA. Darkening by a third keeps
  /// the hue and clears AAA for the 26sp+ words a toddler's parent reads
  /// from arm's length.
  static Color onTint(Color accent) =>
      Color.lerp(accent, textPrimary, 0.35) ?? accent;

  /// WCAG AA for body text and for icons/controls at large sizes.
  static const double aaContrast = 4.5;

  /// [accent] darkened until **white on it** clears [aaContrast].
  ///
  /// The kid zone paints text dark-on-white almost everywhere (see
  /// `KidCountPill`), but a primary button still wants to be a block of the
  /// pack's colour. Raw accents cannot carry white: mint is 2.0:1 and
  /// sunBurst 1.4:1 — a yellow "Unlock" button with a white label is, for
  /// practical purposes, blank. This walks the accent's lightness down in
  /// HSL — hue and saturation untouched, so the pack still looks like
  /// itself — until the pair is legible. Deterministic and total: every
  /// colour in, a usable fill out (mint → `#2E8339`, sunBurst → `#8F7300`).
  ///
  /// Use for filled surfaces under white; for text *on* a tint use
  /// [onTint], and for text on white use [textPrimary].
  static Color solid(Color accent) {
    var hsl = HSLColor.fromColor(accent);
    // ~45 steps at most, each one a handful of `pow` calls — cheap enough
    // for a build, and there is nowhere earlier to cache it per pack.
    while (hsl.lightness > 0.10 &&
        contrastRatio(surfaceWhite, hsl.toColor()) < aaContrast) {
      hsl = hsl.withLightness(hsl.lightness - 0.02);
    }
    return hsl.toColor();
  }

  /// WCAG 2.x contrast ratio of two opaque colours, `1.0…21.0`.
  static double contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static double _relativeLuminance(Color c) {
    double channel(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  /// Three elevation levels: rest (flat), soft (tiles at rest), lift
  /// (pressed / hero), float (overlays and sheets above the scene).
  static const List<BoxShadow> shadowRest = [];

  static List<BoxShadow> shadowSoft(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> shadowLift(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> shadowFloat(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  // ── Motion ──────────────────────────────────
  /// Duration and curve scale — see [DTMotion]. `MotionPolicy` (F2) decides
  /// whether these run at all; this is the only place the numbers live.
  static const motion = DTMotion._();

  /// Press language for every child target — see `KidTap` and
  /// docs/motion-audit-2026-09-13.md §6. Down is a quick squeeze; up is a
  /// spring (`KidTap.spring`) that is visually back in about [pressUpMs].
  static const pressScale = 0.94;
  static const pressDownMs = Duration(milliseconds: 90);
  static const pressUpMs = Duration(milliseconds: 200);
  @Deprecated('use pressDownMs/pressUpMs')
  static const pressMs = Duration(milliseconds: 140);

  /// Alias of [DTMotion.enter] kept for existing call sites.
  static const enterMs = _kEnter;

  // ── Type ────────────────────────────────────
  /// Rounded face for everything a child looks at (audit 2026-09-08, #28):
  /// words on cards, headings, tile titles. Parents' body copy stays on the
  /// system Roboto. Nunito is a variable font, so the weight has to travel
  /// as a variation axis — [kidWeight] — or the engine renders the default
  /// instance whatever fontWeight says.
  static const kidFont = 'Nunito';
  static List<FontVariation> kidWeight(double wght) =>
      [FontVariation('wght', wght)];
  static const _kid600 = [FontVariation('wght', 600)];
  static const _kid700 = [FontVariation('wght', 700)];
  static const _kid800 = [FontVariation('wght', 800)];
  static const _kid900 = [FontVariation('wght', 900)];

  // ── Text styles (use these, not inline) ─────
  static const display = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid900,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -0.3,
  );

  static const h1 = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid800,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.15,
  );

  static const h2 = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid800,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.2,
  );

  static const tileTitle = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid800,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  /// The word on a flash card (G7): the one piece of text a child actually
  /// looks at. 32sp base; letter cards («Аа») and the EN side scale it via
  /// `copyWith(fontSize:)`, colour comes from `onTint(pack accent)`.
  static const word = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid900,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.0,
    height: 1.1,
  );

  /// Label inside a kid-zone button (G7): 20sp Nunito 800, white by
  /// default because the button carries the accent.
  static const kidButton = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid800,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.15,
  );

  /// Body copy in the child's half of the app.
  ///
  /// Nunito like every other kid style: these two were left on the system
  /// face when the headings moved, so a screen read as one voice at the
  /// top and a different, cheaper one underneath. The parent zone wraps
  /// itself in its own Roboto theme and does not use these.
  static const body = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid600,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    height: 1.35,
  );

  static const caption = TextStyle(
    fontFamily: kidFont,
    fontVariations: _kid700,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    height: 1.2,
  );
}

// Shared between `DT.enterMs` (legacy alias) and `DT.motion.enter`, so the
// two can never drift apart.
const _kEnter = Duration(milliseconds: 260);

/// Motion scale. Reached as `DT.motion.quick`, `DT.motion.standard`.
///
/// Six content durations cover every in-place change; the route/sheet/overlay
/// pairs are what `KidRoutes` (F2) hands to its `PageRouteBuilder`s so that
/// every screen enters and leaves with the same rhythm. Curves: `standard`
/// for anything that moves, `emphasized` for something arriving with a bit
/// of overshoot, `playful` for reward moments only (elastic reads as
/// "broken" on ordinary layout), `exit` for leaving — fast out, no bounce.
class DTMotion {


  /// From the page crossing to the landing sound. `onPageChanged` fires as
  /// the card passes the halfway mark; this is roughly when it arrives.
  ///
  /// The sound used to hang off `ScrollEndNotification`, which for a
  /// critically damped spring means *fully settled* — one to two seconds
  /// after the card visually stopped, long after the word had spoken. The
  /// crossing is late enough to be a landing and early enough to still be
  /// the swipe.
  final Duration landingAfterCrossing = const Duration(milliseconds: 150);

  /// From the landing sound to the word. `card_land` is ~200 ms; the word
  /// starts once it has cleared, so the two read as cause and effect
  /// rather than as a collision.
  final Duration wordAfterLanding = const Duration(milliseconds: 220);

  /// From opening a pack to its first word. `pack_open` runs ~510 ms and
  /// the route fade is ~280; the word waited only for the route, so the
  /// lid was still creaking when the card started talking.
  final Duration wordAfterPackOpen = const Duration(milliseconds: 560);

  /// Gap between the tap transient and the word it triggers. `card_touch`
  /// is 30 ms; without this the click sat on the word's first consonant.
  final Duration wordAfterTap = const Duration(milliseconds: 60);  const DTMotion._();

  // Content
  final Duration instant = const Duration(milliseconds: 80);
  final Duration quick = const Duration(milliseconds: 140);
  final Duration base = const Duration(milliseconds: 220);
  final Duration enter = _kEnter;
  final Duration slow = const Duration(milliseconds: 400);
  final Duration celebrate = const Duration(milliseconds: 600);

  // Routes
  final Duration routeEnter = const Duration(milliseconds: 280);
  final Duration routeExit = const Duration(milliseconds: 220);
  final Duration gameEnter = const Duration(milliseconds: 260);
  final Duration gameExit = const Duration(milliseconds: 200);
  final Duration sheetEnter = const Duration(milliseconds: 320);
  final Duration sheetExit = const Duration(milliseconds: 240);
  final Duration overlayEnter = const Duration(milliseconds: 200);
  final Duration overlayExit = const Duration(milliseconds: 160);
  final Duration replace = const Duration(milliseconds: 320);

  /// Cross-fade between the three home tabs inside the `IndexedStack`
  /// (ux-gap-audit G11). Half of it fades the old tab out, half fades the
  /// new one in, so the swap itself is invisible.
  final Duration tabFade = const Duration(milliseconds: 180);

  // Entrance stagger (ux-gap-audit G11). A grid that appears all at once
  // reads as a page load; one that arrives tile by tile reads as someone
  // laying cards on a table. `StaggerScope` / `StaggeredEntrance` own it.
  /// Delay added per item index before its [enter] fade begins.
  final Duration stagger = const Duration(milliseconds: 40);

  /// The wave never runs longer than this, however many items the list
  /// has: a 21-pack grid would otherwise take 840 ms to finish arriving.
  final Duration staggerCap = const Duration(milliseconds: 320);

  // Celebration beats (motion audit 2026-09-13 §4). `Celebration` runs one
  // master controller of [celebrationTotal] and derives every `Interval`
  // from these, so a beat is a token here and not a literal in the widget.
  /// Whole choreography: Bloom drops back to idle and the rain ends here.
  final Duration celebrationTotal = const Duration(milliseconds: 2500);

  /// Bloom's cue — the mascot reacts a beat after the card lands.
  final Duration celebrationCue = const Duration(milliseconds: 120);

  /// Bloom's two hops.
  final Duration celebrationBounce = const Duration(milliseconds: 700);

  /// Pack cover: when it starts growing, and for how long.
  final Duration celebrationCoverIn = const Duration(milliseconds: 150);
  final Duration celebrationCover = const Duration(milliseconds: 300);

  /// Confetti: one wave from a point ([confettiBurst]) or from the top
  /// edge ([confettiRain]). Both one-shot — nothing here loops.
  final Duration confettiBurst = const Duration(milliseconds: 1000);
  final Duration confettiRain = const Duration(milliseconds: 2500);

  /// What a one-shot collapses to under reduced motion when it cannot be
  /// zero (a card that must still visibly arrive).
  final Duration reducedFade = const Duration(milliseconds: 150);

  // Answer feedback (ux-gap-audit 2026-09-13 G10, motion audit T0).
  // `AnswerFrame` (lib/widgets/answer_feedback.dart) is the one owner of
  // these four beats — every game tile answers a tap the same way.
  /// A miss: one gentle side-to-side nudge of the tapped tile. No colour.
  final Duration nudge = const Duration(milliseconds: 380);

  /// A hit: the tile pops 1 → 1.10 → 1 on [emphasized].
  final Duration successPop = const Duration(milliseconds: 240);

  /// After the second miss the right tile breathes at this period…
  final Duration hintPulse = const Duration(milliseconds: 900);

  /// …and calms down (static glow + sticker stay) after this long.
  final Duration hintSettle = const Duration(milliseconds: 3000);

  // Bloom (docs/design/bloom_character.md §2.2). The mascot's every beat
  // is a token here; `BloomMascot` and `BloomReactions` read them and the
  // widget never spells a millisecond.
  /// Pose-to-pose lerp (160–220 in the spec; one value).
  final Duration bloomPose = const Duration(milliseconds: 180);

  /// Squash on entering `listen`, and the mask under a discrete face swap.
  final Duration bloomSquash = const Duration(milliseconds: 120);

  /// One blink: two frames, eyes shut for this long.
  final Duration bloomBlink = const Duration(milliseconds: 120);

  /// Random gap between blinks — a discrete event, not a loop.
  final Duration bloomBlinkMin = const Duration(seconds: 3);
  final Duration bloomBlinkMax = const Duration(seconds: 6);

  /// The "heard you" nod when a word ends; also how long the pupils follow
  /// a swipe before settling back.
  final Duration bloomNod = const Duration(milliseconds: 200);

  /// `speaking → false` is honoured only after this gap (a phrase has
  /// tiny silences inside it).
  final Duration bloomListenRelease = const Duration(milliseconds: 150);

  /// `wave`: two paw swings.
  final Duration bloomWave = const Duration(milliseconds: 700);

  /// `cheer` with one hop, and with three.
  final Duration bloomCheer = const Duration(milliseconds: 900);
  final Duration bloomCheerBig = const Duration(milliseconds: 1400);

  /// The happy face Bloom keeps after a cheer, before idle.
  final Duration bloomAfterglow = const Duration(milliseconds: 600);

  /// `curious`: lean towards the object and back.
  final Duration bloomCurious = const Duration(milliseconds: 700);

  /// `point`: paw out, two nods, paw back.
  final Duration bloomPoint = const Duration(milliseconds: 900);

  /// `blow`: one exhale.
  final Duration bloomBlow = const Duration(milliseconds: 300);

  // Memory match (docs/design/memory_match_redesign.md §4). The board is a
  // table: a press answers in [quick], every transition lands inside the
  // 220–320 ms window of the experience audit (п. 11), and the word never
  // waits for a transition.
  /// One card turning over, and the same beat backwards after a miss.
  final Duration memoryFlip = const Duration(milliseconds: 320);

  /// The word starts while the card is still turning.
  final Duration memoryWordCue = const Duration(milliseconds: 120);

  /// Two cards "finding each other": 5 dp towards one another + 1.06.
  final Duration memoryKnock = const Duration(milliseconds: 200);

  /// The star sticker popping onto a matched card.
  final Duration memorySticker = const Duration(milliseconds: 220);

  /// The local spark burst of a match — a particle effect, not a
  /// transition, so it may run past 320 ms (п. 12: it finishes by itself).
  final Duration memorySparkle = const Duration(milliseconds: 500);

  /// The second card of a miss starts turning back this much later.
  final Duration memoryMissStagger = const Duration(milliseconds: 60);

  /// Silence after the word before the miss pair may turn back.
  final Duration memoryVoiceGrace = const Duration(milliseconds: 200);

  /// A tap during the miss hold cuts it short once this much of it has
  /// been seen — earlier than that the child never saw the second card.
  final Duration memoryHoldCut = const Duration(milliseconds: 500);

  /// Tap on a card that is already face up: it bounces and repeats itself.
  final Duration memoryBounce = const Duration(milliseconds: 180);

  /// The preview ("знайомство") before the cards go face down, and the
  /// stagger of them going down.
  final Duration memoryPreviewL1 = const Duration(milliseconds: 2000);
  final Duration memoryPreviewL2 = const Duration(milliseconds: 1500);
  final Duration memoryPreviewStagger = const Duration(milliseconds: 60);

  /// Between the last pair landing and the celebration card.
  final Duration memoryRoundEnd = const Duration(milliseconds: 1200);

  /// The deal — the one "show" of a round (§4). A card flies out of
  /// Bloom's lap into its slot; the stagger keeps even sixteen cards
  /// inside 720 ms, and a card is tappable the moment it lands.
  final Duration memoryDeal = const Duration(milliseconds: 280);

  /// `min(40 ms, 440 / tiles)` — the whole deal stays an accent, never a
  /// wait, however big the board is.
  Duration memoryDealStagger(int tiles) => Duration(
        microseconds: tiles <= 0
            ? 0
            : (440000 ~/ tiles).clamp(0, 40000),
      );

  /// A nudge: one card stirs — the invitation (scale 1.03 + a 1.5° tilt)
  /// and the shake of the actual twin are the same beat.
  final Duration memoryNudge = const Duration(milliseconds: 320);

  /// Level 1's nudge instead of a shake: the twin turns up to ~110°, so
  /// its face is visible at an angle, and lies back down.
  final Duration memoryPeek = const Duration(milliseconds: 500);

  /// Nothing touched for this long: one closed card stirs, silently —
  /// "there is something to do here" (§6). Wave 1's board was still.
  Duration memoryNudgeInvite(int level) => switch (level) {
        <= 1 => const Duration(seconds: 4),
        2 => const Duration(seconds: 5),
        3 => const Duration(seconds: 8),
        _ => const Duration(seconds: 10),
      };

  /// Still nothing: the card that *is* the pair stirs, with a sound. Only
  /// this step counts as a hint towards the confidence of the round.
  Duration memoryNudgeHint(int level) => switch (level) {
        <= 1 => const Duration(seconds: 7),
        2 => const Duration(seconds: 9),
        3 => const Duration(seconds: 12),
        _ => const Duration(seconds: 15),
      };

  /// How long a mismatched pair stays visible, by profile level — the
  /// younger the child, the longer they get to look (§6).
  Duration memoryHold(int level) => switch (level) {
        <= 1 => const Duration(milliseconds: 1400),
        2 => const Duration(milliseconds: 1200),
        3 => const Duration(milliseconds: 900),
        _ => const Duration(milliseconds: 800),
      };

  // «Вгадай звук» and «Повтори за мною» (experience audit 2026-09-13
  // §19, §21). Both games are a loop of word → answer → word, so their
  // beats are gaps between sounds rather than transitions: they exist so
  // two voice lines never talk over each other.
  /// Between the entry instruction and the first word of a game.
  final Duration gameInstructionGap = const Duration(milliseconds: 400);

  /// The right tile keeps its success frame this long before the next
  /// question is dealt.
  final Duration quizAnswerHold = const Duration(milliseconds: 900);

  /// The big speaker breathes at this period while a word is playing.
  final Duration speakerPulse = const Duration(milliseconds: 800);

  /// Silence between a dealt question and its word.
  final Duration quizQuestionGap = const Duration(milliseconds: 300);

  /// After a miss the word is said again — not immediately, or it lands
  /// on top of the miss cue.
  final Duration quizRetell = const Duration(milliseconds: 600);

  /// The repeat-game card sliding out on its way to the next word.
  final Duration repeatCardExit = const Duration(milliseconds: 320);

  /// How long «Вийшло!» is celebrated before the next word arrives.
  final Duration repeatPraiseHold = const Duration(milliseconds: 1400);

  /// Idle breathing — one half-cycle (rest → peak); `AmbientLoop` reverses,
  /// so the full period is 3.0 s. Asleep it is twice as slow.
  final Duration bloomBreath = const Duration(milliseconds: 1500);
  final Duration bloomSleepBreath = const Duration(milliseconds: 3000);

  /// `happy` debounce: a hop already in the air is not restarted.
  final Duration bloomHappyDebounce = const Duration(milliseconds: 350);

  /// Host Bloom fades out when an overlay brings its own.
  final Duration bloomFade = const Duration(milliseconds: 150);

  // «Зайвий» / «Протилежності» (experience audit 2026-09-13, п. 22). The
  // answer is not the end of the question: the board spends one short beat
  // showing *why* — the group closes ranks, the odd one drifts off; the two
  // opposites come to stand side by side. Wordless, and never long enough
  // to feel like a wait for the next question.
  /// The sort demonstration: three cards move together, one moves away.
  final Duration sortDemo = const Duration(milliseconds: 760);

  /// From a right answer to the next question — the demo's whole window.
  final Duration sortRoundGap = const Duration(milliseconds: 900);

  /// The pair sliding together under the question.
  final Duration pairReveal = const Duration(milliseconds: 320);

  /// The second word of the pair, so the child hears both in order.
  final Duration pairEcho = const Duration(milliseconds: 350);

  /// How long the pair stays side by side before the next question.
  final Duration pairHold = const Duration(milliseconds: 1300);

  /// Gap before a new question's word, so an instruction can finish.
  final Duration questionCue = const Duration(milliseconds: 400);

  // Colouring (experience audit 2026-09-13, п. 24).
  /// The last stubborn contour bits melting away at completion.
  final Duration coloringMelt = const Duration(milliseconds: 550);

  /// Idle bar ↔ done bar.
  final Duration coloringBarSwap = const Duration(milliseconds: 250);

  /// One pass of the ghost finger that shows what to do — once per profile,
  /// and any real touch cuts it short.
  final Duration coloringHandTrace = const Duration(milliseconds: 2400);

  /// …and how long it takes to disappear when it does.
  final Duration coloringHandFade = const Duration(milliseconds: 260);

  // Bubbles (docs/design/bubble_pop_redesign.md §3, §5). The pop is the
  // L2 base; `BubbleTuning` stretches it ×1.2 for L1 and ×0.9 for L3+,
  // and derives the card's `minHold` from the same token.
  /// One bubble pop: squash, burst, the card's hold, its fade.
  final Duration bubblePop = const Duration(milliseconds: 1000);

  /// Ripple of a tap into empty sky (20 → 72 dp).
  final Duration bubbleRipple = const Duration(milliseconds: 320);

  /// A bubble being born: scale 0.6 → 1.08 → 1.0 with a fade, so a
  /// one-year-old sees where it came from instead of finding it there.
  final Duration bubbleSpawn = const Duration(milliseconds: 420);

  /// How long a revealed card waits for its queued word before it gives
  /// up and finishes silently (§3: the picture waits for *its* word).
  final Duration bubbleWordWait = const Duration(milliseconds: 1200);

  /// Gap between two pops of the closing cascade (§6).
  final Duration bubbleCascade = const Duration(milliseconds: 70);

  /// A tap on Bloom blows at most one bubble out of the wand per this
  /// (§2) — the same beat as his giggle, so the two never disagree.
  final Duration bubbleWand = const Duration(milliseconds: 1500);

  /// Between two idle hints inside one round (§2: repeat every 8 s).
  final Duration bubbleHintRepeat = const Duration(seconds: 8);

  /// The window a run of misses has to happen in before Bloom notices it
  /// (§5: 2 / 3 / 3 misses in four seconds → `curious` + a wiggling hint).
  /// A rule, not an animation: a miss four seconds after the last one is
  /// a new try, not a struggle.
  final Duration bubbleMissWindow = const Duration(seconds: 4);

  /// The sign over Bloom's head turning over to the next thing to find
  /// (§5, «Знайди бульбашку»).
  final Duration bubbleSignFlip = const Duration(milliseconds: 220);

  /// How long the round's spoken instruction is given before the first
  /// target is named, so the two voices never talk over each other.
  final Duration bubbleFindIntro = const Duration(milliseconds: 1600);

  // Quest map (ux-gap-audit G13). Bloom walks the trail from the stop he
  // has just finished to the next one; the paw prints in the header fill
  // on the same beat so the two read as one event.
  /// Bloom's walk from one stop to the next.
  final Duration journeyStep = const Duration(milliseconds: 900);

  /// The breath of the one stop that can be pressed (1.0 → 1.06). The
  /// map's whole "press here" signal for a child who cannot read a check
  /// mark: on a map where nothing else moves, the thing that moves is the
  /// thing to touch.
  final Duration questBreath = const Duration(milliseconds: 900);

  /// One outward pass of the sparks around the chest once the five stops
  /// are done. Two rings ride it half a cycle apart, so the felt rhythm is
  /// twice as often as this.
  final Duration questFireworks = const Duration(milliseconds: 1400);

  // Idle loops (`AmbientLoop` periods). One half-cycle rest → peak; the
  // loop reverses, so the felt period is double.

  /// The home hero's invite breath (1.0 → 1.02): the whole card, so slow
  /// enough that the screen does not seem to breathe with it.
  final Duration ambientBreath = const Duration(milliseconds: 1600);

  /// The active step / stone (1.0 → 1.04): one element at a time.
  final Duration ambientPulse = const Duration(milliseconds: 1200);

  /// The home hero's arrival fade, and the sweep of its progress bar when
  /// a task lands — long enough that a parent sees the bar move, short
  /// enough that a child is not waiting on it.
  final Duration heroArrive = const Duration(milliseconds: 480);
  final Duration heroProgress = const Duration(milliseconds: 650);

  /// The hop of the hero's play button, and how long it hops for before
  /// it settles: an invitation, not a permanent animation.
  final Duration heroHop = const Duration(milliseconds: 1400);
  final Duration heroHopSettle = const Duration(milliseconds: 4200);

  // Curves
  final Curve standard = Curves.easeOutCubic;
  final Curve emphasized = Curves.easeOutBack;
  final Curve playful = Curves.elasticOut;
  final Curve exit = Curves.easeIn;
}

/// Size scale. Reached as `DT.size.tapMin`, `DT.size.mascotMd`.
class DTSize {
  const DTSize._();

  /// Minimum edge of anything a child taps (CLAUDE.md rule 1).
  final double tapMin = 72;

  /// Back / close control in the kid zone — same size, named separately so
  /// `KidScreen` (F6) can pin it without implying every target is a button.
  final double tapBack = 72;

  final double iconSm = 24;
  final double iconMd = 32;
  final double iconLg = 48;

  /// Bloom sizes: a corner presence, a hero companion, a celebration lead.
  final double mascotSm = 64;
  final double mascotMd = 96;
  final double mascotLg = 140;

  /// Bloom **S**, the companion (docs/design/bloom_character.md §4.1):
  /// 56 on a phone, 72 on a tablet, 48 when the screen is under 600 dp tall.
  /// Whatever the drawing, the hit zone is [tapMin].
  final double mascotCompanion = 56;
  final double mascotCompanionCompact = 48;
  final double mascotCompanionTablet = 72;

  /// The shelf Bloom sits on under the cards `PageView`: 64 phone / 80
  /// tablet / 56 on a short screen (§4.2).
  final double bloomShelf = 64;
  final double bloomShelfCompact = 56;
  final double bloomShelfTablet = 80;

  /// How much of Bloom shows above the home hero, as a share of his size.
  /// A fixed 28 dp read fine at 56 (eyes out) and as "ears stuck behind a
  /// box" at the tablet's 72. 0.6 keeps eyes and cheeks visible at any size.
  final double bloomPeekFraction = 0.6;

  /// The home hero (ux-gap G5): 150 dp tall, the illustration fills the
  /// left [heroArtFraction] of it up to [heroArtMax] dp, and the whole
  /// card stops growing at [heroMaxWidth] so a 1194 px tablet gets a
  /// centred card rather than a strip.
  final double heroHeight = 150;
  final double heroArtFraction = 0.45;
  final double heroArtMax = 220;
  final double heroMaxWidth = 640;
  double bloomPeekOf(double mascotSize) => mascotSize * bloomPeekFraction;

  /// Bloom S for [context]: tablet / compact / phone by the shortest and
  /// the vertical extent of the screen.
  double mascotCompanionOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide >= kLargeScreen) return mascotCompanionTablet;
    if (size.height < 600) return mascotCompanionCompact;
    return mascotCompanion;
  }

  /// The cards shelf height for [context] — see [mascotCompanionOf].
  double bloomShelfOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide >= kLargeScreen) return bloomShelfTablet;
    if (size.height < 600) return bloomShelfCompact;
    return bloomShelf;
  }
}

/// Colour roles derived from one pack accent.
///
/// Generalises `BoardTheme` from docs/design/memory_match_redesign.md — one
/// colour in, every surface role out — so a pack tile, its cards screen, and
/// a game board built from that pack all agree without 21 hand palettes.
/// `BoardTheme` itself adds HSL normalisation (seal/wash/mat); this is the
/// plain version for tiles, chips and headers.
@immutable
class PackPalette {
  const PackPalette._({
    required this.accent,
    required this.tint,
    required this.border,
    required this.onTint,
  });

  factory PackPalette.of(Color accent) => PackPalette._(
        accent: accent,
        tint: Color.lerp(accent, Colors.white, 0.82) ?? accent,
        border: accent.withValues(alpha: 0.35),
        onTint: DT.onTint(accent),
      );

  /// The pack's own colour — icons, progress, the pressed state.
  final Color accent;

  /// Background of the tile / card the accent lives on.
  final Color tint;

  /// Hairline around the tint so it reads on [DT.bgWarm].
  final Color border;

  /// Text drawn on [tint] — see [DT.onTint] for the contrast reasoning.
  final Color onTint;

  @override
  bool operator ==(Object other) =>
      other is PackPalette && other.accent == accent;

  @override
  int get hashCode => accent.hashCode;
}

/// Scale factor for responsive sizing — clamped to keep typography sane on
/// extreme small/large devices. Reference: 375dp (iPhone X width).
double screenScale(BuildContext context) =>
    (MediaQuery.of(context).size.width / 375).clamp(0.85, 1.3);

/// Convenience: scaled font size.
double responsiveFont(BuildContext context, double base) =>
    base * screenScale(context);

/// Breakpoints in logical pixels.
const double kSmallScreen = 360;
const double kMediumScreen = 500;
const double kLargeScreen = 768;
