import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';

/// Vector art for every [AppIcon] (ux-gap-audit 2026-09-13 §5.1).
///
/// One painter, one switch of drawing routines. Every icon is composed in
/// a 48×48 space (live zone 4…44) out of a few paper cut-outs:
///
///  * `shape` — a closed silhouette, filled with the accent and lit from
///    above by a `Color.lerp(base, white, .35)` band (the two tones of the
///    spec), outlined with 2.5 dp ink (`DT.textPrimary` α .70);
///  * `fat`   — an open stroke (arrow, check, arc) given the same fill +
///    outline treatment;
///  * `line`  — a thin inner line, 1.5 dp at α .35, or a coloured doodle;
///  * `dot`   — an unoutlined disc (eyes, highlights).
///
/// The painter scales the 48-space uniformly to whatever box it gets and
/// centres it, so the same art is pixel-sharp at 24, 32, 48 and any dpr.
/// The white sticker edge (`sticker: true`) is a fat white stroke under
/// every outlined piece, drawn before the fills — so the union silhouette
/// gets a 1.5 dp paper rim and interior joins stay clean.
///
/// Colours come only from `DT` (guarded by
/// `test/architecture/design_tokens_test.dart`).
class AppIconPainter extends CustomPainter {
  final AppIcon icon;
  final Color? color;
  final bool sticker;

  /// Flattens the whole sheet into one shape in this colour (G14: the
  /// album's unearned stickers). Fills and fat strokes stay, the ink
  /// outline, the highlight band and the doodles drop out.
  final Color? silhouette;

  const AppIconPainter(
    this.icon, {
    this.color,
    this.sticker = false,
    this.silhouette,
  });

  /// Side of the design space every routine draws in.
  static const double grid = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / grid;
    canvas.save();
    canvas.translate(
      (size.width - grid * scale) / 2,
      (size.height - grid * scale) / 2,
    );
    canvas.scale(scale);
    final sheet = _Sheet(color ?? defaultColorOf(icon));
    _compose(sheet, icon);
    sheet.render(canvas, sticker: sticker, silhouette: silhouette);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AppIconPainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.sticker != sticker ||
      old.silhouette != silhouette;
}

/// The semantic accent of each icon (spec §5.1 palette row).
Color defaultColorOf(AppIcon icon) => switch (icon) {
      AppIcon.back => DT.sky,
      AppIcon.close => DT.coral,
      AppIcon.sound => DT.mint,
      AppIcon.soundOff => DT.mint,
      AppIcon.play => DT.mint,
      AppIcon.replay => DT.sky,
      AppIcon.shuffle => DT.violet,
      AppIcon.home => DT.peach,
      AppIcon.check => DT.success,
      AppIcon.lock => DT.sunBurst,
      AppIcon.star => DT.sunBurst,
      AppIcon.parent => DT.violet,
      AppIcon.catSpeech => DT.violet,
      AppIcon.catSounds => DT.peach,
      AppIcon.catWorld => DT.mint,
      AppIcon.gameGuess => DT.sky,
      AppIcon.gameMatch => DT.mint,
      AppIcon.gameBubbles => DT.coral,
      AppIcon.gameRepeat => DT.peach,
      AppIcon.gameOdd => DT.violet,
      AppIcon.gameOpposites => DT.pink,
      AppIcon.gameArticulation => DT.pink,
      AppIcon.gameSort => DT.sky,
      AppIcon.gameSyllables => DT.coral,
      AppIcon.stepListen => DT.peach,
      AppIcon.stepCards => DT.violet,
      AppIcon.stepQuest => DT.mint,
      AppIcon.stopCardTree => DT.mint,
      AppIcon.stopBell => DT.sunBurst,
      AppIcon.stopMicFlower => DT.peach,
      AppIcon.pawStep => DT.peach,
      AppIcon.rewardChestClosed => DT.peach,
      AppIcon.rewardChestOpen => DT.peach,
      AppIcon.rewardGift => DT.peach,
      AppIcon.rewardTrophy => DT.sunBurst,
      AppIcon.streakFlame => DT.peach,
      AppIcon.hint => DT.sunBurst,
      AppIcon.stickerUnicorn => DT.pinkTint,
      AppIcon.stickerDragon => DT.mint,
      AppIcon.stickerRainbow => DT.sky,
      AppIcon.stickerButterfly => DT.violet,
      AppIcon.stickerAlbum => DT.coral,
      AppIcon.calendar => DT.sky,
      AppIcon.navCards => DT.violet,
      AppIcon.navGames => DT.peach,
      AppIcon.navColoring => DT.mint,
    };

/// True when a pack's JSON `icon` is a bare letter (or a two-letter sound
/// such as `SH`) rather than an emoji — the case [LetterStickerIcon] draws.
bool isLetterIcon(String icon) =>
    icon.length <= 2 &&
    icon.isNotEmpty &&
    RegExp(r'^[A-Za-zА-ЯІЇЄҐа-яіїєґ]+$').hasMatch(icon);

/// A sound pack's letter as a paper sticker: chubby plate in the pack
/// colour, white sticker edge, Nunito 900 letter in `DT.onTint`, and a
/// small smile doodle so «Р» sits among drawings instead of reading as a
/// font glyph (spec §5.1 list).
class LetterStickerIcon extends StatelessWidget {
  final String letter;
  final Color color;
  final double? size;

  const LetterStickerIcon({
    super.key,
    required this.letter,
    required this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final side = size ?? DT.size.iconLg;
    return Semantics(
      label: letter,
      image: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: side,
          child: CustomPaint(
            isComplex: true,
            painter: LetterStickerPainter(letter: letter, color: color),
          ),
        ),
      ),
    );
  }
}

/// Painter behind [LetterStickerIcon]; exposed so a tile can size it to a
/// non-square pane.
class LetterStickerPainter extends CustomPainter {
  final String letter;
  final Color color;

  const LetterStickerPainter({required this.letter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const grid = AppIconPainter.grid;
    final scale = math.min(size.width, size.height) / grid;
    canvas.save();
    canvas.translate(
      (size.width - grid * scale) / 2,
      (size.height - grid * scale) / 2,
    );
    canvas.scale(scale);

    final sheet = _Sheet(color)
      ..shape(_rr(4, 4, 40, 40, 12))
      ..line(_arc(24, 36.5, 3.5, 0.35, math.pi - 0.7), width: 1.8, color: _ink70)
      ..dot(19.5, 34.5, 1.3, _ink70)
      ..dot(28.5, 34.5, 1.3, _ink70);
    sheet.render(canvas, sticker: true);

    final text = letter.toUpperCase();
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: DT.kidFont,
          fontVariations: DT.kidWeight(900),
          fontWeight: FontWeight.w900,
          fontSize: text.length > 1 ? 17 : 24,
          height: 1,
          color: DT.onTint(color),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(24 - painter.width / 2, 21 - painter.height / 2),
    );
    painter.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LetterStickerPainter old) =>
      old.letter != letter || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────
//  Toolkit
// ─────────────────────────────────────────────────────────────────────────

const double _strokeW = 2.5;
const double _innerW = 1.5;
const double _stickerW = 1.5;
final Color _ink70 = DT.textPrimary.withValues(alpha: 0.70);
final Color _ink35 = DT.textPrimary.withValues(alpha: 0.35);

Color _lit(Color base) => Color.lerp(base, Colors.white, 0.35) ?? base;

sealed class _Op {
  const _Op();
}

final class _Shape extends _Op {
  final Path path;
  final Color base;
  final bool outline;
  final bool twoTone;
  const _Shape(this.path, this.base, {this.outline = true, this.twoTone = true});
}

final class _Fat extends _Op {
  final Path path;
  final Color base;
  final double width;
  const _Fat(this.path, this.base, this.width);
}

final class _Line extends _Op {
  final Path path;
  final Color color;
  final double width;
  const _Line(this.path, this.color, this.width);
}

final class _Dot extends _Op {
  final Offset c;
  final double r;
  final Color color;
  const _Dot(this.c, this.r, this.color);
}

/// Ordered list of paper pieces for one icon, plus the accent they share.
class _Sheet {
  final Color accent;
  final List<_Op> ops = [];
  _Sheet(this.accent);

  void shape(Path p, {Color? color, bool outline = true, bool twoTone = true}) =>
      ops.add(_Shape(p, color ?? accent, outline: outline, twoTone: twoTone));

  void fat(Path p, double width, {Color? color}) =>
      ops.add(_Fat(p, color ?? accent, width));

  void line(Path p, {Color? color, double width = _innerW}) =>
      ops.add(_Line(p, color ?? _ink35, width));

  void dot(double x, double y, double r, [Color? color]) =>
      ops.add(_Dot(Offset(x, y), r, color ?? Colors.white));

  void render(Canvas canvas, {required bool sticker, Color? silhouette}) {
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (silhouette != null) {
      // One flat paper cut-out: the same union of shapes and fat strokes,
      // in one colour. Thin lines and dots are detail, not silhouette.
      paint.color = silhouette;
      for (final op in ops) {
        switch (op) {
          case _Shape(:final path):
            paint.style = PaintingStyle.fill;
            canvas.drawPath(path, paint);
          case _Fat(:final path, :final width):
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = width + _strokeW;
            canvas.drawPath(path, paint);
          case _Line() || _Dot():
            break;
        }
      }
      return;
    }

    if (sticker) {
      paint
        ..style = PaintingStyle.stroke
        ..color = Colors.white;
      for (final op in ops) {
        switch (op) {
          case _Shape(:final path, :final outline):
            if (!outline) continue;
            paint.strokeWidth = _strokeW + 2 * _stickerW;
            canvas.drawPath(path, paint);
          case _Fat(:final path, :final width):
            paint.strokeWidth = width + _strokeW + 2 * _stickerW;
            canvas.drawPath(path, paint);
          case _Line() || _Dot():
            break;
        }
      }
    }

    for (final op in ops) {
      switch (op) {
        case _Shape(:final path, :final base, :final outline, :final twoTone):
          paint
            ..style = PaintingStyle.fill
            ..color = base;
          canvas.drawPath(path, paint);
          if (twoTone) {
            final b = path.getBounds();
            canvas.save();
            canvas.clipPath(path);
            paint.color = _lit(base);
            canvas.drawRect(
              Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.42),
              paint,
            );
            canvas.restore();
          }
          if (outline) {
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = _strokeW
              ..color = _ink70;
            canvas.drawPath(path, paint);
          }
        case _Fat(:final path, :final base, :final width):
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + _strokeW
            ..color = _ink70;
          canvas.drawPath(path, paint);
          paint
            ..strokeWidth = width
            ..color = base;
          canvas.drawPath(path, paint);
        case _Line(:final path, :final color, :final width):
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = color;
          canvas.drawPath(path, paint);
        case _Dot(:final c, :final r, :final color):
          paint
            ..style = PaintingStyle.fill
            ..color = color;
          canvas.drawCircle(c, r, paint);
      }
    }
  }
}

Path _rr(double l, double t, double w, double h, double r) => Path()
  ..addRRect(RRect.fromRectAndRadius(
    Rect.fromLTWH(l, t, w, h),
    Radius.circular(r),
  ));

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path _oval(double l, double t, double w, double h) =>
    Path()..addOval(Rect.fromLTWH(l, t, w, h));

Path _arc(double cx, double cy, double r, double start, double sweep) =>
    Path()
      ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep);

Path _poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  return p;
}

/// Closed polygon with every corner rounded by [r] — the "no sharp
/// corners" rule of the spec without hand-placing Bézier handles.
Path _roundPoly(List<Offset> pts, double r) {
  final n = pts.length;
  final path = Path();
  for (var i = 0; i < n; i++) {
    final prev = pts[(i - 1 + n) % n];
    final cur = pts[i];
    final next = pts[(i + 1) % n];
    final toPrev = prev - cur;
    final toNext = next - cur;
    final rad = math.min(r, math.min(toPrev.distance, toNext.distance) / 2);
    final a = cur + toPrev / toPrev.distance * rad;
    final b = cur + toNext / toNext.distance * rad;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  return path..close();
}

Path _star(double cx, double cy, double outer, double inner, double r) {
  final pts = <Offset>[];
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 5;
    pts.add(Offset(cx + rad * math.cos(a), cy + rad * math.sin(a)));
  }
  return _roundPoly(pts, r);
}

Path _placed(Path p, double dx, double dy, [double rotate = 0]) {
  final m = Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..rotateZ(rotate);
  return p.transform(m.storage);
}

Path _speaker() => Path()
  ..addPath(_rr(9, 18, 9, 12, 3), Offset.zero)
  ..addPath(
    _roundPoly(const [
      Offset(16, 19),
      Offset(27, 11),
      Offset(27, 37),
      Offset(16, 29),
    ], 3),
    Offset.zero,
  );

// ─────────────────────────────────────────────────────────────────────────
//  Icons
// ─────────────────────────────────────────────────────────────────────────

void _compose(_Sheet s, AppIcon icon) {
  switch (icon) {
    // ── Controls ──
    case AppIcon.back:
      s.fat(
        _poly(const [Offset(29, 11), Offset(16, 24), Offset(29, 37)]),
        6.5,
      );
      s.fat(_poly(const [Offset(16, 24), Offset(38, 24)]), 6.5);

    case AppIcon.close:
      s.fat(_poly(const [Offset(14, 14), Offset(34, 34)]), 6.5);
      s.fat(_poly(const [Offset(34, 14), Offset(14, 34)]), 6.5);

    case AppIcon.sound:
      s.shape(_speaker());
      s.line(_arc(28, 24, 7, -0.9, 1.8), width: 2.5, color: _ink70);
      s.line(_arc(28, 24, 12.5, -0.9, 1.8), width: 2.5, color: _ink70);

    case AppIcon.soundOff:
      s.shape(_speaker());
      s.fat(_poly(const [Offset(30, 19), Offset(40, 29)]), 3.5,
          color: DT.coral);
      s.fat(_poly(const [Offset(40, 19), Offset(30, 29)]), 3.5,
          color: DT.coral);

    case AppIcon.play:
      s.shape(_roundPoly(const [
        Offset(15, 9),
        Offset(40, 24),
        Offset(15, 39),
      ], 4.5));

    case AppIcon.replay:
      const cx = 24.0, cy = 25.0, r = 12.0;
      s.fat(_arc(cx, cy, r, -math.pi / 3, math.pi * 5 / 3), 5.5);
      // Arrowhead at the arc's end (240°), pointing along its travel.
      const end = Offset(cx + r * -0.5, cy + r * -0.866);
      const dir = Offset(0.866, -0.5);
      const perp = Offset(0.5, 0.866);
      s.shape(
        _roundPoly([
          end + dir * 9,
          end + perp * 7,
          end - perp * 7,
        ], 2.5),
        twoTone: false,
      );

    case AppIcon.shuffle:
      s.fat(
        _poly(const [
          Offset(9, 15),
          Offset(18, 15),
          Offset(30, 33),
          Offset(38, 33),
        ]),
        5,
      );
      s.fat(
        _poly(const [
          Offset(9, 33),
          Offset(18, 33),
          Offset(30, 15),
          Offset(38, 15),
        ]),
        5,
        color: _lit(s.accent),
      );
      s.shape(
        _roundPoly(const [Offset(36, 9), Offset(43, 15), Offset(36, 21)], 2),
        twoTone: false,
      );
      s.shape(
        _roundPoly(const [Offset(36, 27), Offset(43, 33), Offset(36, 39)], 2),
        twoTone: false,
      );

    case AppIcon.home:
      s.shape(_rr(11, 20, 26, 20, 4));
      s.shape(_roundPoly(const [
        Offset(24, 6),
        Offset(43, 23),
        Offset(5, 23),
      ], 3.5));
      s.shape(_rr(20, 28, 8, 12, 3), color: DT.sunBurst);

    case AppIcon.check:
      s.fat(
        _poly(const [Offset(11, 25), Offset(20, 34), Offset(37, 14)]),
        7,
      );

    case AppIcon.lock:
      s.fat(_arc(24, 18, 8, math.pi, math.pi), 4.5, color: _lit(s.accent));
      s.shape(_rr(10, 19, 28, 22, 7.5));
      s.dot(19, 27.5, 1.7, _ink70);
      s.dot(29, 27.5, 1.7, _ink70);
      s.line(_arc(24, 29.5, 5, 0.35, math.pi - 0.7), width: 2, color: _ink70);

    case AppIcon.star:
      s.shape(_star(24, 25, 19, 9, 2.5));

    case AppIcon.parent:
      s.shape(_rr(8, 22, 18, 20, 8));
      s.shape(_circle(17, 13, 6.5));
      s.shape(_rr(25, 27, 14, 15, 6.5));
      s.shape(_circle(32, 20, 4.8));

    // ── Categories ──
    case AppIcon.catSpeech:
      s.shape(
        _roundPoly(const [Offset(13, 30), Offset(11, 41), Offset(24, 32)], 2),
        twoTone: false,
      );
      s.shape(_rr(6, 8, 36, 25, 11));
      s.dot(16, 20.5, 2.3);
      s.dot(24, 20.5, 2.3);
      s.dot(32, 20.5, 2.3);

    case AppIcon.catSounds:
      s.shape(
        _roundPoly(const [
          Offset(30, 8),
          Offset(41, 14),
          Offset(41, 22),
          Offset(30, 16),
        ], 2.5),
        twoTone: false,
      );
      s.fat(_poly(const [Offset(30, 10), Offset(30, 31)]), 3.5);
      s.shape(_placed(_oval(-9, -6, 18, 12), 24, 33, -0.3));

    case AppIcon.catWorld:
      s.shape(_circle(24, 24, 18.5));
      s.shape(_oval(11, 13, 12, 9), color: _lit(_lit(s.accent)), outline: false, twoTone: false);
      s.shape(_oval(23, 24, 13, 11), color: _lit(_lit(s.accent)), outline: false, twoTone: false);

    // ── Games ──
    case AppIcon.gameGuess:
      s.fat(_arc(24, 27, 15, math.pi, math.pi), 4.5, color: _lit(s.accent));
      s.shape(_rr(5, 24, 11, 15, 4.5));
      s.shape(_rr(32, 24, 11, 15, 4.5));

    case AppIcon.gameMatch:
      s.shape(_placed(_rr(-8, -11, 16, 22, 4), 15, 22, -0.14));
      s.shape(_placed(_rr(-8, -11, 16, 22, 4), 33, 26, 0.14));
      s.dot(15, 22, 3.2);
      s.dot(33, 26, 3.2);

    case AppIcon.gameBubbles:
      s.shape(_circle(18, 28, 12.5));
      s.shape(_circle(34, 15, 8));
      s.shape(_circle(37, 34, 5), twoTone: false);
      s.dot(13, 22, 2.6);
      s.dot(31, 11.5, 1.7);

    case AppIcon.gameRepeat:
      // «Повтори за мною» is two people and one word between them.
      // It used to be a microphone on a stand — a promise that something
      // is listening to the child's pronunciation and grading it. Nothing
      // in this app listens (experience audit 2026-09-13 §21), so the
      // badge shows the truth: a grown-up and a child, saying it together.
      s.shape(_rr(13, 3, 22, 12, 5.5), color: _lit(s.accent));
      s.line(_poly(const [Offset(18, 9), Offset(30, 9)]));
      s.shape(
        _roundPoly(
          const [Offset(20, 14), Offset(27, 14), Offset(20.5, 20.5)],
          1.5,
        ),
        color: _lit(s.accent),
      );
      s.shape(_rr(3, 38, 20, 10, 5));
      s.shape(_rr(25, 36, 20, 12, 6));
      s.shape(_circle(13, 30, 6.5));
      s.shape(_circle(35, 27, 7.5));
      s.dot(11, 29, 1.6);
      s.dot(33, 26, 1.8);

    case AppIcon.gameOdd:
      s.fat(_poly(const [Offset(30, 30), Offset(41, 41)]), 6);
      s.shape(_circle(20, 20, 13.5));
      s.shape(
        _circle(20, 20, 8),
        color: Color.lerp(s.accent, Colors.white, 0.7) ?? s.accent,
        outline: false,
        twoTone: false,
      );
      s.dot(16, 15.5, 2);

    case AppIcon.gameOpposites:
      s.shape(_roundPoly(const [
        Offset(4, 24),
        Offset(16, 12),
        Offset(16, 18.5),
        Offset(32, 18.5),
        Offset(32, 12),
        Offset(44, 24),
        Offset(32, 36),
        Offset(32, 29.5),
        Offset(16, 29.5),
        Offset(16, 36),
      ], 2.5));

    case AppIcon.gameArticulation:
      s.shape(_rr(7, 15, 34, 18, 9));
      s.shape(
        _rr(13, 21.5, 22, 7.5, 3.75),
        color: DT.onTint(s.accent),
        outline: false,
        twoTone: false,
      );
      s.shape(_oval(17, 24, 14, 14), color: DT.coral);
      s.line(_poly(const [Offset(24, 28), Offset(24, 36)]));

    case AppIcon.gameSort:
      // «По купках»: two paper trays, a round and a square piece above
      // them — the game is "this one goes there".
      s.shape(_circle(13, 13, 7), color: DT.sunBurst);
      s.shape(_placed(_rr(-6, -6, 12, 12, 3.5), 34, 13, 0.2),
          color: DT.coral);
      s.shape(_rr(4, 26, 18, 15, 5.5));
      s.shape(_rr(26, 26, 18, 15, 5.5));
      s.line(_poly(const [Offset(7, 31.5), Offset(19, 31.5)]));
      s.line(_poly(const [Offset(29, 31.5), Offset(41, 31.5)]));

    case AppIcon.gameSyllables:
      // «Рахуй склади»: a drum and two sticks — one beat per syllable.
      s.fat(_poly(const [Offset(7, 9), Offset(17, 20)]), 3,
          color: DT.peach);
      s.fat(_poly(const [Offset(41, 9), Offset(31, 20)]), 3,
          color: DT.peach);
      s.shape(_rr(8, 20, 32, 20, 8));
      s.shape(_oval(8, 16, 32, 11), color: _lit(s.accent), twoTone: false);
      s.line(_poly(const [Offset(13, 26), Offset(20, 35)]));
      s.line(_poly(const [Offset(20, 26), Offset(13, 35)]));
      s.line(_poly(const [Offset(28, 26), Offset(35, 35)]));
      s.line(_poly(const [Offset(35, 26), Offset(28, 35)]));

    // ── Daily steps ──
    case AppIcon.stepListen:
      s.shape(Path()
        ..moveTo(16, 17)
        ..cubicTo(16, 5, 36, 5, 36, 18)
        ..cubicTo(36, 25, 30, 27, 29, 33)
        ..cubicTo(28, 41, 16, 43, 15, 34)
        ..cubicTo(14.5, 30, 19, 29, 19, 25)
        ..cubicTo(19, 21, 16, 21, 16, 17)
        ..close());
      s.line(Path()
        ..moveTo(21, 16)
        ..cubicTo(26, 11, 32, 15, 29, 22)
        ..cubicTo(27, 26, 24, 24, 24, 27));

    case AppIcon.stepCards:
      s.shape(_placed(_rr(-8, -12, 16, 23, 4), 17, 26, -0.26));
      s.shape(_placed(_rr(-8, -12, 16, 23, 4), 29, 24, 0.16));
      s.dot(29, 20, 3.2, DT.sunBurst);

    case AppIcon.stepQuest:
      s.shape(_roundPoly(const [
        Offset(5, 12),
        Offset(17.5, 7.5),
        Offset(30.5, 12),
        Offset(43, 7.5),
        Offset(43, 36),
        Offset(30.5, 40.5),
        Offset(17.5, 36),
        Offset(5, 40.5),
      ], 3));
      s.line(_poly(const [Offset(17.5, 9), Offset(17.5, 35)]));
      s.line(_poly(const [Offset(30.5, 13), Offset(30.5, 39)]));
      s.line(_poly(const [Offset(33, 19), Offset(39, 25)]),
          color: DT.coral, width: 2.5);
      s.line(_poly(const [Offset(39, 19), Offset(33, 25)]),
          color: DT.coral, width: 2.5);

    // ── Quest-map landmarks (G13) ──
    case AppIcon.stopCardTree:
      // A little tree with two cards hanging in its crown — the stop
      // where the child goes and looks at pictures.
      s.shape(_rr(21, 28, 6, 16, 3), color: DT.peach);
      s.shape(_circle(14, 17, 11));
      s.shape(_circle(34, 16, 10));
      s.shape(_circle(24, 20, 11));
      s.shape(_placed(_rr(-4.5, -5.5, 9, 11, 2.5), 13, 28, -0.22),
          color: DT.violet);
      s.shape(_placed(_rr(-4.5, -5.5, 9, 11, 2.5), 34, 27, 0.18),
          color: DT.sunBurst);

    case AppIcon.stopBell:
      // The "listen and guess" stop: a bell with a clapper.
      s.fat(_arc(24, 12, 4, math.pi, math.pi), 3, color: _lit(s.accent));
      s.shape(Path()
        ..moveTo(24, 9)
        ..cubicTo(33, 9, 35, 19, 35, 31)
        ..lineTo(13, 31)
        ..cubicTo(13, 19, 15, 9, 24, 9)
        ..close());
      s.shape(_rr(9, 29, 30, 7, 3.5));
      s.shape(_circle(24, 40, 3.6), color: DT.coral, twoTone: false);

    case AppIcon.stopMicFlower:
      // A microphone growing like a flower: petals, stem, one leaf.
      s.fat(_poly(const [Offset(24, 30), Offset(24, 43)]), 3.5,
          color: DT.mint);
      s.shape(_placed(_oval(-6.5, -4, 13, 8), 14, 38, -0.4), color: DT.mint);
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        s.shape(_circle(24 + 9 * math.cos(a), 20 + 9 * math.sin(a), 6));
      }
      s.shape(_rr(18.5, 11, 11, 19, 5.5), color: DT.violet);
      s.line(_poly(const [Offset(21, 17), Offset(27, 17)]),
          color: Colors.white, width: 1.5);
      s.line(_poly(const [Offset(21, 22), Offset(27, 22)]),
          color: Colors.white, width: 1.5);

    case AppIcon.pawStep:
      // One paw print: pad plus four toes.
      s.shape(_oval(13, 21, 22, 18));
      s.shape(_placed(_oval(-4, -5.5, 8, 11), 12, 15, -0.35));
      s.shape(_placed(_oval(-4, -5.5, 8, 11), 20, 10, -0.12));
      s.shape(_placed(_oval(-4, -5.5, 8, 11), 29, 10, 0.12));
      s.shape(_placed(_oval(-4, -5.5, 8, 11), 37, 15, 0.35));

    // ── Rewards ──
    // A pirate chest, not a box with a stripe: a domed lid, gold bands
    // down both corners, a gold clasp straddling the seam and a keyhole.
    // The old one was two rounded rectangles — at 46 dp it read as a
    // suitcase, and a treasure a two-year-old cannot recognise is not a
    // reason to finish five tasks.
    case AppIcon.rewardChestClosed:
      // Body.
      s.shape(_rr(7, 24, 34, 16, 3.5));
      // Domed lid.
      s.shape(Path()
        ..moveTo(7, 24)
        ..cubicTo(7, 9, 41, 9, 41, 24)
        ..close());
      // Gold: the seam band, two corner straps, the clasp.
      s.shape(_rr(7, 22.5, 34, 4, 2), color: DT.sunBurst);
      s.shape(_rr(9.5, 26.5, 4, 13.5, 1.5), color: DT.sunBurst);
      s.shape(_rr(34.5, 26.5, 4, 13.5, 1.5), color: DT.sunBurst);
      s.shape(_rr(20, 19, 8, 11, 2.5), color: DT.sunBurst);
      s.dot(24, 24.5, 1.8, _ink70);
      // One sparkle, so the closed chest still promises something.
      s.shape(_star(40, 12, 4.2, 1.9, 1),
          color: DT.sunBurst, twoTone: false, outline: false);

    case AppIcon.rewardChestOpen:
      // Lid thrown back, treasure heaped over the rim, sparkles above.
      // The lid hinges off the back of the box, not floating above it.
      s.shape(_placed(_rr(-16, -9, 32, 10, 4), 23, 18, -0.30));
      // Coins heaped over the rim: three, so it reads as loose treasure
      // and not one lump.
      s.shape(_circle(17, 25, 5), color: DT.sunBurst);
      s.shape(_circle(31, 25, 5), color: DT.sunBurst);
      s.shape(_circle(24, 22, 6), color: DT.sunBurst);
      s.shape(_rr(7, 26, 34, 14, 3.5));
      s.shape(_rr(7, 25, 34, 4, 2), color: DT.sunBurst);
      s.shape(_rr(9.5, 29, 4, 11, 1.5), color: DT.sunBurst);
      s.shape(_rr(34.5, 29, 4, 11, 1.5), color: DT.sunBurst);
      s.shape(_star(40, 10, 4.6, 2.1, 1),
          color: DT.sunBurst, twoTone: false, outline: false);
      s.shape(_star(9, 13, 3.4, 1.5, 1),
          color: DT.sunBurst, twoTone: false, outline: false);

    case AppIcon.rewardGift:
      s.shape(_rr(8, 21, 32, 20, 5));
      s.shape(_rr(6, 14, 36, 10, 4.5));
      s.shape(_rr(20, 14, 8, 27, 2.5), color: DT.sunBurst, twoTone: false);
      s.shape(_placed(_oval(-7, -4.5, 14, 9), 16, 9, -0.35), color: DT.sunBurst);
      s.shape(_placed(_oval(-7, -4.5, 14, 9), 32, 9, 0.35), color: DT.sunBurst);
      s.shape(_circle(24, 11, 3.2), color: DT.sunBurst, twoTone: false);

    case AppIcon.rewardTrophy:
      s.fat(_arc(12, 14, 5, math.pi / 2, math.pi), 3);
      s.fat(_arc(36, 14, 5, -math.pi / 2, math.pi), 3);
      s.shape(_rr(14, 34, 20, 7, 3));
      s.shape(_rr(21, 27, 6, 8, 2));
      s.shape(Path()
        ..moveTo(12, 7)
        ..lineTo(36, 7)
        ..cubicTo(36, 21, 32, 28, 24, 29)
        ..cubicTo(16, 28, 12, 21, 12, 7)
        ..close());
      s.shape(_star(24, 16, 4.5, 2, 1), color: Colors.white, outline: false, twoTone: false);

    case AppIcon.streakFlame:
      s.shape(Path()
        ..moveTo(24, 4)
        ..cubicTo(30, 12, 40, 18, 38, 30)
        ..cubicTo(37, 38, 31, 43.5, 24, 43.5)
        ..cubicTo(17, 43.5, 11, 38, 10, 30)
        ..cubicTo(9, 22, 15, 17, 16, 12)
        ..cubicTo(18, 17, 21, 19, 22, 16)
        ..cubicTo(23, 12, 22, 8, 24, 4)
        ..close());
      s.shape(
        Path()
          ..moveTo(24, 22)
          ..cubicTo(28, 26, 32, 30, 31, 35)
          ..cubicTo(30, 40, 27, 42, 24, 42)
          ..cubicTo(21, 42, 18, 40, 17, 35)
          ..cubicTo(16, 30, 20, 26, 24, 22)
          ..close(),
        color: DT.sunBurst,
        outline: false,
      );
      s.dot(21, 32.5, 1.6, _ink70);
      s.dot(27, 32.5, 1.6, _ink70);
      s.line(_arc(24, 34, 3.5, 0.35, math.pi - 0.7), width: 1.6, color: _ink70);

    case AppIcon.hint:
      s.line(_poly(const [Offset(7, 9), Offset(11, 12.5)]),
          color: _ink70, width: 2.5);
      s.line(_poly(const [Offset(41, 9), Offset(37, 12.5)]),
          color: _ink70, width: 2.5);
      s.shape(_rr(19, 35, 10, 6, 3), color: _lit(s.accent), twoTone: false);
      s.shape(_rr(18, 28, 12, 8, 3.5), twoTone: false);
      s.shape(_circle(24, 19, 13.5));

    // ── Album stickers (G14) ──
    case AppIcon.stickerUnicorn:
      // Head in profile: rainbow mane behind, golden horn, a soft muzzle
      // with one eye, a nostril and a smile.
      s.shape(_circle(34, 14, 7.5), color: DT.violet);
      s.shape(_circle(38, 24, 6.5), color: DT.sky);
      s.shape(_circle(34, 33, 5.5), color: DT.pink);
      s.shape(
        _roundPoly(const [Offset(22, 2), Offset(28, 15), Offset(16, 15)], 2),
        color: DT.sunBurst,
      );
      s.shape(
        _placed(
          _roundPoly(const [
            Offset(-4, -7),
            Offset(4, -3),
            Offset(-1, 4),
          ], 2),
          31,
          13,
          0.25,
        ),
      );
      s.shape(_oval(8, 12, 25, 26));
      s.shape(_oval(4, 24, 17, 14), color: _lit(s.accent), twoTone: false);
      s.dot(20, 23, 2.2, _ink70);
      s.dot(8, 29, 1.5, _ink70);
      s.line(_arc(13, 31, 4, 0.3, math.pi - 0.8), width: 1.6, color: _ink70);

    case AppIcon.stickerDragon:
      // A friendly dragon head: a violet crest along the top, a snout to
      // the left and one small puff of flame leaving it.
      for (var i = 0; i < 3; i++) {
        s.shape(
          _roundPoly([
            Offset(26 + i * 6.0, 14),
            Offset(29 + i * 6.0, 5 + i * 1.0),
            Offset(33 + i * 6.0, 14),
          ], 1.5),
          color: DT.violet,
        );
      }
      s.shape(_rr(13, 11, 30, 24, 11));
      s.shape(_rr(5, 21, 18, 14, 7), color: _lit(s.accent), twoTone: false);
      s.dot(26, 21, 2.4, _ink70);
      s.dot(37, 21, 2.4, _ink70);
      s.line(_arc(28, 27, 5, 0.2, math.pi - 0.6), width: 1.6, color: _ink70);
      s.dot(9, 25, 1.4, _ink70);
      s.shape(_circle(6, 33, 4.5), color: DT.coral);
      s.shape(_circle(11, 39, 3), color: DT.sunBurst, twoTone: false);

    case AppIcon.stickerRainbow:
      // Three fat arcs rising out of two cloud puffs.
      s.fat(_arc(24, 33, 17, math.pi, math.pi), 5, color: DT.coral);
      s.fat(_arc(24, 33, 12, math.pi, math.pi), 5, color: DT.sunBurst);
      s.fat(_arc(24, 33, 7, math.pi, math.pi), 5, color: DT.mint);
      s.shape(_circle(9, 34, 7), color: Colors.white, twoTone: false);
      s.shape(_circle(15, 36, 5.5), color: Colors.white, twoTone: false);
      s.shape(_circle(39, 34, 7), color: Colors.white, twoTone: false);
      s.shape(_circle(33, 36, 5.5), color: Colors.white, twoTone: false);
      s.dot(15, 11, 1.8, DT.sunBurst);
      s.dot(35, 9, 2.2, DT.sunBurst);

    case AppIcon.stickerButterfly:
      // Four wings, a chubby body, two antennae with dots.
      s.shape(_placed(_oval(-11, -8, 22, 16), 13, 17, -0.25));
      s.shape(_placed(_oval(-11, -8, 22, 16), 35, 17, 0.25));
      s.shape(_placed(_oval(-8, -6, 16, 12), 15, 32, 0.25), color: DT.pink);
      s.shape(_placed(_oval(-8, -6, 16, 12), 33, 32, -0.25), color: DT.pink);
      s.shape(_rr(21, 10, 6, 30, 3), color: DT.peach);
      s.line(_poly(const [Offset(23, 11), Offset(18, 4)]),
          color: _ink70, width: 2);
      s.line(_poly(const [Offset(25, 11), Offset(30, 4)]),
          color: _ink70, width: 2);
      s.dot(17, 4, 2, DT.sunBurst);
      s.dot(31, 4, 2, DT.sunBurst);
      s.dot(14, 17, 2.6, Colors.white);
      s.dot(34, 17, 2.6, Colors.white);

    case AppIcon.stickerAlbum:
      // The album itself: a chubby book with a paper label and a star
      // sticker already stuck on the cover.
      s.shape(_rr(8, 6, 32, 36, 6));
      s.shape(_rr(8, 6, 8, 36, 5), color: _lit(s.accent), twoTone: false);
      s.line(_poly(const [Offset(16, 8), Offset(16, 40)]));
      s.shape(_rr(20, 12, 15, 12, 3),
          color: Colors.white, twoTone: false);
      s.shape(_star(27, 32, 7, 3.2, 1.2), color: DT.sunBurst);

    // ── Parent zone (G15) ──
    case AppIcon.calendar:
      // A wall calendar: two rings, a torn-off header and marked days.
      // The dashboard's "active days" counter, in the app's own hand.
      s.fat(_poly(const [Offset(16, 5), Offset(16, 13)]), 3.5,
          color: _lit(s.accent));
      s.fat(_poly(const [Offset(32, 5), Offset(32, 13)]), 3.5,
          color: _lit(s.accent));
      s.shape(_rr(6, 10, 36, 32, 8));
      s.line(_poly(const [Offset(7, 21), Offset(41, 21)]));
      s.dot(16, 28, 2.4);
      s.dot(24, 28, 2.4);
      s.dot(32, 28, 2.4);
      s.dot(16, 35.5, 2.4);
      s.dot(24, 35.5, 2.4);
      s.dot(32, 35.5, 3.2, DT.coral);

    // ── Navigation (redraws of the former `_ToyIcon` art in DT tones) ──
    case AppIcon.navCards:
      // Two fanned cards: a sunBurst back card and a violet front card
      // showing a little landscape.
      s.shape(_placed(_rr(0, 0, 25, 29, 6), 7, 11, -0.19), color: DT.sunBurst);
      s.shape(_placed(_rr(0, 0, 24, 29, 6), 19, 8, 0.12));
      s.shape(_placed(_rr(3, 3, 18, 22, 4), 19, 8, 0.12),
          color: Colors.white, outline: false, twoTone: false);
      s.shape(
        _placed(
          _roundPoly(const [
            Offset(5, 22),
            Offset(10, 13),
            Offset(14, 18),
            Offset(18, 14),
            Offset(20, 22),
          ], 1.5),
          19,
          8,
          0.12,
        ),
        color: DT.mint,
        outline: false,
        twoTone: false,
      );
      s.shape(_placed(_circle(15, 9, 3), 19, 8, 0.12),
          color: DT.sunBurst, outline: false, twoTone: false);

    case AppIcon.navGames:
      // A peach game pad: d-pad on the left, two buttons on the right.
      s.shape(_rr(3, 12, 42, 25, 11));
      s.shape(_rr(11, 19, 5, 13, 1.8), color: DT.onTint(s.accent),
          outline: false, twoTone: false);
      s.shape(_rr(7, 23, 13, 5, 1.8), color: DT.onTint(s.accent),
          outline: false, twoTone: false);
      s.dot(33, 22, 3.4);
      s.dot(38, 28, 3.4, DT.violet);

    case AppIcon.navColoring:
      // A mint palette with five paint dabs and a brush resting on it.
      s.shape(_oval(4, 8, 37, 32));
      s.dot(13, 20, 4, DT.coral);
      s.dot(23, 15, 4, DT.sunBurst);
      s.dot(33, 20, 4, DT.violet);
      s.dot(13, 31, 4, DT.sky);
      s.dot(25, 30, 4);
      s.shape(_placed(_rr(-2, -3, 4, 16, 2), 36, 33, 0.55),
          color: DT.peach, twoTone: false);
      s.shape(_placed(_rr(-3, -6, 6, 7, 2), 36, 33, 0.55),
          color: DT.sunBurst, twoTone: false);
      s.shape(
        _placed(
          Path()
            ..moveTo(-3, -6)
            ..quadraticBezierTo(-5, -12, 1, -15)
            ..quadraticBezierTo(5, -10, 3, -6)
            ..close(),
          36,
          33,
          0.55,
        ),
        color: DT.sky,
        twoTone: false,
      );
  }
}
