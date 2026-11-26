import 'package:flutter/material.dart';

import '../models/play_topic.dart';
import '../utils/design_tokens.dart';

/// Scene companions, not replacements for the actual vocabulary card art.
/// Bundled character atlases, keyed by shared UA/EN image identity.
class AnimalFriendArt extends StatelessWidget {
  const AnimalFriendArt({super.key, required this.animal});
  final String animal;

  /// The clay friend for a card's picture name: a photo card (`ph_cat`)
  /// and a drawn card (`cat`) are the same friend; the drawn pack calls the
  /// rabbit `bunny` and the sound pack calls the hen `hen`.
  static String friendOf(String image) => PlayTopic.friendKey(image);

  /// The friends painted in clay (`assets/images/friends/<key>.webp`, the
  /// same puffy style as Bloom). Anything else falls back to the old flat
  /// atlas or the drawn painter — which must never reach a child's screen
  /// for a friend: a test holds every lesson's friend to this set.
  static const clay = {
    'cow',
    'cat',
    'dog',
    'rabbit',
    'horse',
    'pig',
    'chicken',
    'duck',
    'frog',
    'fish',
    'sheep',
    'rooster',
    'bird',
    'owl',
    'bee',
  };

  @override
  Widget build(BuildContext context) {
    final animal = friendOf(this.animal);
    final sprite = switch (animal) {
      'cow' => ('animal-friends-atlas-v1.png', 2.0, Alignment.topLeft),
      'cat' => ('animal-friends-atlas-v1.png', 2.0, Alignment.topRight),
      'dog' => ('animal-friends-atlas-v1.png', 2.0, Alignment.bottomLeft),
      'rabbit' => ('animal-friends-atlas-v1.png', 2.0, Alignment.bottomRight),
      'horse' => ('farm-pond-atlas-v1.png', 3.0, Alignment.topLeft),
      'pig' => ('farm-pond-atlas-v1.png', 3.0, Alignment.topCenter),
      'chicken' => ('farm-pond-atlas-v1.png', 3.0, Alignment.topRight),
      'duck' => ('farm-pond-atlas-v1.png', 3.0, Alignment.bottomLeft),
      'frog' => ('farm-pond-atlas-v1.png', 3.0, Alignment.bottomCenter),
      'fish' => ('farm-pond-atlas-v1.png', 3.0, Alignment.bottomRight),
      _ => null,
    };
    // The clay friends (Firefly, same puffy style as Bloom). The flat atlas
    // and the drawn painter remain the fallback for anything missing.
    if (clay.contains(animal)) {
      return ExcludeSemantics(
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              'assets/images/friends/$animal.webp',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: sprite == null
            ? CustomPaint(
                painter: _AnimalPainter(animal),
                size: const Size(160, 160),
              )
            : AspectRatio(
                aspectRatio: 1,
                child: ClipRect(
                  child: FractionallySizedBox(
                    widthFactor: sprite.$2,
                    heightFactor: 2,
                    alignment: sprite.$3,
                    child: Image.asset(
                      'assets/images/${sprite.$1}',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AnimalPainter extends CustomPainter {
  const _AnimalPainter(this.animal);
  final String animal;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width < size.height ? size.width : size.height) / 160;
    canvas.save();
    canvas.translate(
      (size.width - 160 * scale) / 2,
      (size.height - 160 * scale) / 2,
    );
    canvas.scale(scale);
    void oval(Rect rect, Color color, {bool outline = true}) {
      canvas.drawOval(rect, Paint()..color = color);
      if (outline) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = DT.friendInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }

    void circle(
      double x,
      double y,
      double radius,
      Color color, {
      bool outline = true,
    }) => oval(
      Rect.fromCircle(center: Offset(x, y), radius: radius),
      color,
      outline: outline,
    );
    void path(List<Offset> points, Color color) {
      final p = Path()..addPolygon(points, true);
      canvas.drawPath(p, Paint()..color = color);
      canvas.drawPath(
        p,
        Paint()
          ..color = DT.friendInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    void line(
      Offset a,
      Offset b, {
      double width = 2.5,
      Color color = DT.friendInk,
    }) => canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    void eyes(double y, {double left = 64, double right = 99}) {
      for (final x in [left, right]) {
        oval(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 11),
          DT.friendInk,
          outline: false,
        );
        circle(x - 1, y - 2, 1.8, DT.surfaceWhite, outline: false);
      }
    }

    void smile(double x, double y) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 7, y)
          ..quadraticBezierTo(x, y + 7, x + 7, y),
        Paint()
          ..color = DT.friendInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    oval(
      const Rect.fromLTWH(30, 136, 105, 12),
      DT.sceneGrassShade,
      outline: false,
    );
    if (animal == 'duck' || animal == 'chicken') {
      final fill = animal == 'duck' ? DT.friendGold : DT.friendCream;
      line(
        const Offset(70, 126),
        const Offset(65, 141),
        width: 6,
        color: DT.friendOrange,
      );
      line(
        const Offset(96, 126),
        const Offset(103, 141),
        width: 6,
        color: DT.friendOrange,
      );
      path(const [
        Offset(44, 99),
        Offset(23, 83),
        Offset(32, 117),
        Offset(56, 121),
      ], fill);
      oval(const Rect.fromLTWH(35, 77, 96, 58), fill);
      circle(98, 64, 31, fill);
      if (animal == 'chicken') {
        circle(87, 33, 8, DT.coral);
        circle(101, 29, 9, DT.coral);
        circle(113, 36, 7, DT.coral);
      }
      oval(
        const Rect.fromLTWH(50, 93, 48, 24),
        animal == 'duck' ? DT.friendOrange : DT.paper,
      );
      path(const [
        Offset(120, 64),
        Offset(145, 73),
        Offset(121, 81),
      ], DT.friendOrange);
      eyes(58, left: 94, right: 112);
      circle(108, 78, 6, DT.friendPink, outline: false);
    } else if (animal == 'frog') {
      oval(const Rect.fromLTWH(26, 110, 42, 28), DT.friendGreen);
      oval(const Rect.fromLTWH(96, 110, 42, 28), DT.friendGreen);
      oval(const Rect.fromLTWH(43, 77, 75, 62), DT.friendGreen);
      oval(const Rect.fromLTWH(58, 99, 45, 36), DT.mintTint, outline: false);
      oval(const Rect.fromLTWH(28, 49, 108, 62), DT.friendGreen);
      circle(55, 49, 21, DT.friendGreen);
      circle(108, 49, 21, DT.friendGreen);
      circle(55, 47, 13, DT.friendCream, outline: false);
      circle(108, 47, 13, DT.friendCream, outline: false);
      eyes(47, left: 55, right: 108);
      smile(82, 85);
      circle(46, 82, 7, DT.friendPink, outline: false);
      circle(118, 82, 7, DT.friendPink, outline: false);
    } else if (animal == 'fish') {
      path(const [
        Offset(111, 78),
        Offset(145, 49),
        Offset(145, 115),
        Offset(111, 98),
      ], DT.friendBlue);
      path(const [
        Offset(65, 61),
        Offset(75, 37),
        Offset(94, 64),
      ], DT.friendBlue);
      oval(const Rect.fromLTWH(23, 60, 102, 64), DT.friendBlue);
      oval(const Rect.fromLTWH(75, 79, 24, 28), DT.skyTint);
      eyes(80, left: 45, right: 61);
      smile(47, 101);
      circle(27, 47, 6, DT.skyTint);
      circle(18, 28, 4, DT.skyTint);
    } else {
      final fill = switch (animal) {
        'cat' => DT.friendGold,
        'dog' || 'horse' => DT.friendBrown,
        'pig' => DT.friendPink,
        _ => DT.friendCream,
      };
      // Feet and a compact body keep every friend readable at 72 dp.
      for (final x in [49.0, 96.0]) {
        oval(Rect.fromLTWH(x, 112, 21, 30), fill);
      }
      oval(const Rect.fromLTWH(38, 74, 85, 61), fill);
      if (animal == 'cow') {
        oval(const Rect.fromLTWH(46, 90, 25, 19), DT.friendInk, outline: false);
        oval(
          const Rect.fromLTWH(93, 103, 24, 22),
          DT.friendInk,
          outline: false,
        );
        line(const Offset(121, 101), const Offset(139, 88));
        oval(const Rect.fromLTWH(133, 79, 12, 18), DT.friendInk);
        path(const [
          Offset(55, 40),
          Offset(53, 20),
          Offset(68, 38),
        ], DT.friendGold);
        path(const [
          Offset(98, 38),
          Offset(114, 21),
          Offset(110, 44),
        ], DT.friendGold);
        oval(const Rect.fromLTWH(25, 44, 36, 20), fill);
        oval(const Rect.fromLTWH(109, 44, 32, 20), fill);
      } else if (animal == 'cat' || animal == 'pig') {
        path(const [Offset(48, 53), Offset(43, 23), Offset(72, 43)], fill);
        path(const [Offset(92, 43), Offset(119, 23), Offset(116, 58)], fill);
      } else if (animal == 'horse') {
        oval(const Rect.fromLTWH(50, 21, 16, 38), fill);
        oval(const Rect.fromLTWH(99, 21, 16, 38), fill);
      } else {
        oval(const Rect.fromLTWH(27, 45, 29, 51), DT.friendBrownDark);
        oval(const Rect.fromLTWH(109, 45, 29, 51), DT.friendBrownDark);
      }
      oval(Rect.fromLTWH(40, 36, 83, animal == 'horse' ? 79 : 67), fill);
      if (animal == 'cow') {
        oval(const Rect.fromLTWH(45, 39, 29, 25), DT.friendInk, outline: false);
      }
      if (animal == 'horse') {
        path(const [
          Offset(67, 37),
          Offset(71, 22),
          Offset(94, 26),
          Offset(100, 45),
          Offset(84, 39),
        ], DT.friendBrownDark);
      }
      eyes(animal == 'horse' ? 64 : 62);
      if (animal == 'cow' || animal == 'pig' || animal == 'horse') {
        oval(
          Rect.fromLTWH(51, 77, 62, animal == 'horse' ? 36 : 31),
          animal == 'horse' ? DT.friendCream : DT.friendPink,
        );
        circle(68, 88, 2.5, DT.friendInk, outline: false);
        circle(96, 88, 2.5, DT.friendInk, outline: false);
        smile(82, 96);
      } else {
        oval(
          const Rect.fromLTWH(60, 74, 43, 27),
          DT.friendCream,
          outline: false,
        );
        path(const [
          Offset(74, 77),
          Offset(89, 77),
          Offset(82, 84),
        ], DT.friendInk);
        smile(82, 88);
      }
      if (animal == 'cat') {
        line(const Offset(39, 79), const Offset(57, 82));
        line(const Offset(39, 90), const Offset(57, 87));
        line(const Offset(109, 82), const Offset(130, 79));
        line(const Offset(109, 87), const Offset(130, 90));
        for (final x in [73.0, 83.0, 93.0]) {
          line(Offset(x, 38), Offset(x, 48), color: DT.friendOrange, width: 4);
        }
      }
      if (animal == 'dog') {
        path(const [
          Offset(54, 106),
          Offset(111, 106),
          Offset(81, 124),
        ], DT.sky);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnimalPainter oldDelegate) =>
      oldDelegate.animal != animal;
}
