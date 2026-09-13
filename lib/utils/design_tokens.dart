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
  /// Formerly `kAccent` in constants.dart; those names are now aliases.
  static const brand = Color(0xFF6C63FF);
  static const teal = Color(0xFF4ECDC4); // formerly kTeal
  static const soundRed = Color(0xFFD63031); // formerly kSoundRed
  static const streakOrange = Color(0xFFE17055); // formerly kStreakOrange

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
  static const warning = Color(0xFFE17055);
  static const error = Color(0xFFE53935);

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

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.35,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textMuted,
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
  const DTMotion._();

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
