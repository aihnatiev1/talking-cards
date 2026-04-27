import 'package:flutter/material.dart';

/// Shared design tokens for the kid-facing UI.
///
/// Distilled from competitor research (Khan Kids, Lingokids, Sago Mini, Toca
/// Boca) plus toddler UX heuristics: warm off-white backgrounds, saturated
/// pastel accents, soft shadows, rounded 20+ dp cards, and text large enough
/// for a non-reader's parent to scan at arm's length.
class DT {
  DT._();

  // ── Surfaces ─────────────────────────────────
  static const bgWarm = Color(0xFFFFFBF0); // primary screen background
  static const bgCard = Color(0xFFFFF4E0); // peach cream for cards
  static const surfaceWhite = Colors.white;

  // ── Text ────────────────────────────────────
  static const textPrimary = Color(0xFF3F3635); // warm charcoal, not black
  static const textSecondary = Color(0xFF6B605B);
  static const textMuted = Color(0xFF9E948E);

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

  // ── Shadows ─────────────────────────────────
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

  // ── Motion ──────────────────────────────────
  static const pressScale = 0.96;
  static const pressMs = Duration(milliseconds: 140);
  static const enterMs = Duration(milliseconds: 260);

  // ── Text styles (use these, not inline) ─────
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -0.3,
  );

  static const h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.15,
  );

  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.2,
  );

  static const tileTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
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
