import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// The illustration slot of an articulation exercise.
///
/// The twelve drawings (one per exercise — where the tongue goes, what the
/// lips do) are being produced separately and will land in
/// `assets/images/articulation/<id>.webp`. Until then this widget draws a
/// mouth, not an emoji: a parent looking for «Грибок» needs to see a
/// tongue against a palate, and 🍄 tells them nothing.
///
/// Three properties, in the order they matter:
///
/// * **Absence never throws.** A missing asset reaches [errorBuilder] and
///   becomes the painted stand-in. That is not cosmetic: `main.dart` hands
///   `FlutterError.onError` to `recordFlutterFatalError`, so an `Image`
///   without an `errorBuilder` over a file that is not there yet is a
///   fatal crash report (the same rule `CardImage` exists to enforce for
///   card art — see `test/architecture/asset_access_test.dart`).
/// * **Arrival needs no code change.** The path is derived from the
///   exercise id; drop `spatula.webp` into the folder and the spatula tile
///   shows it on the next build.
/// * **No flash of emptiness.** [frameBuilder] keeps the stand-in on
///   screen until the first decoded frame, so the slot is never a blank
///   box while the file is being read.
///
/// Card art deliberately does *not* come through here: that content can
/// live in a Play asset pack and must go through `AssetPackService` /
/// `CardImage`. These twelve drawings are bundled unconditionally, which
/// is what makes a literal path safe.
class ArticulationArt extends StatelessWidget {
  /// Exercise id — the file name, no extension.
  final String id;

  /// Inset applied to the picture *and* the stand-in, so the swap does not
  /// move the artwork.
  final EdgeInsets padding;

  const ArticulationArt({
    super.key,
    required this.id,
    this.padding = const EdgeInsets.all(DT.sp8),
  });

  static String assetPath(String id) => 'assets/images/articulation/$id.webp';

  @override
  Widget build(BuildContext context) {
    final stand = ArticulationArtPlaceholder(padding: padding);
    return Image.asset(
      assetPath(id),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      // Not a card: no ResizeImage key to agree on with a precache site,
      // and twelve drawings never all live in memory at once.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return Padding(padding: padding, child: child);
        }
        return stand;
      },
      errorBuilder: (context, error, stack) => stand,
    );
  }
}

/// Drawn wherever an exercise illustration is not (yet) on the device.
///
/// A quiet mouth in the [AppIconPainter] idiom — one silhouette, a lit
/// interior, a 2 dp ink outline, all from `DT` — at low contrast, because
/// it is a placeholder and must not compete with the real drawing that
/// will replace it.
class ArticulationArtPlaceholder extends StatelessWidget {
  final EdgeInsets padding;

  const ArticulationArtPlaceholder({
    super.key,
    this.padding = const EdgeInsets.all(DT.sp8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _MouthPainter()),
        ),
      ),
    );
  }
}

class _MouthPainter extends CustomPainter {
  const _MouthPainter();

  /// Side of the design space, as in `AppIconPainter`.
  static const double grid = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        (size.width < size.height ? size.width : size.height) / grid;
    canvas.save();
    canvas.translate(
      (size.width - grid * scale) / 2,
      (size.height - grid * scale) / 2,
    );
    canvas.scale(scale);

    final lips = Path()
      ..moveTo(5, 24)
      ..cubicTo(10, 22, 15, 15, 24, 15)
      ..cubicTo(33, 15, 38, 22, 43, 24)
      ..cubicTo(38, 34, 33, 39, 24, 39)
      ..cubicTo(15, 39, 10, 34, 5, 24)
      ..close();

    final cavity = Path()
      ..moveTo(10, 24)
      ..cubicTo(15, 21, 18, 19, 24, 19)
      ..cubicTo(30, 19, 33, 21, 38, 24)
      ..cubicTo(33, 31, 30, 34, 24, 34)
      ..cubicTo(18, 34, 15, 31, 10, 24)
      ..close();

    canvas.drawPath(lips, Paint()..color = DT.coralTint);
    canvas.drawPath(
      cavity,
      Paint()..color = DT.onTint(DT.coral).withValues(alpha: 0.45),
    );

    canvas.save();
    canvas.clipPath(cavity);
    // Upper teeth: a white band across the top of the cavity.
    canvas.drawRect(
      const Rect.fromLTWH(8, 17, 32, 5.5),
      Paint()..color = DT.surfaceWhite.withValues(alpha: 0.85),
    );
    // The tongue, resting low — the thing every one of these exercises is
    // actually about.
    canvas.drawPath(
      Path()
        ..moveTo(13, 35)
        ..cubicTo(14, 26, 34, 26, 35, 35)
        ..close(),
      Paint()..color = DT.bloomEarInside,
    );
    canvas.restore();

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = DT.textPrimary.withValues(alpha: 0.35);
    canvas.drawPath(lips, ink);
    canvas.drawPath(cavity, ink..strokeWidth = 1.5);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) => false;
}
