import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// A frosted pill behind a game's one line of cue text, so the line stays
/// readable over a painted backdrop (rainbow, forest, nursery wall).
class CuePill extends StatelessWidget {
  const CuePill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DT.surfaceWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(DT.rLg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: child,
      ),
    );
  }
}

/// What Bloom says, drawn as his speech bubble: solid white, rounded, with
/// a tail pointing at him — so the one line of text reads as *his* words,
/// not as a system toast lying on the grass.
class CueBubble extends StatelessWidget {
  const CueBubble({super.key, required this.child, this.tailRight = true});

  final Widget child;

  /// Bloom stands to the right of the bubble (true) or to its left.
  final bool tailRight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(tailRight: tailRight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tailRight ? 18 : 30,
          12,
          tailRight ? 30 : 18,
          12,
        ),
        child: child,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.tailRight});

  final bool tailRight;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 12.0;
    final body = tailRight
        ? Rect.fromLTRB(0, 0, size.width - tail, size.height)
        : Rect.fromLTRB(tail, 0, size.width, size.height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(22)));
    final y = size.height * 0.62;
    if (tailRight) {
      path
        ..moveTo(body.right - 2, y - 10)
        ..quadraticBezierTo(body.right + 4, y + 2, size.width, y + 8)
        ..quadraticBezierTo(body.right + 2, y + 10, body.right - 2, y + 8)
        ..close();
    } else {
      path
        ..moveTo(body.left + 2, y - 10)
        ..quadraticBezierTo(body.left - 4, y + 2, 0, y + 8)
        ..quadraticBezierTo(body.left - 2, y + 10, body.left + 2, y + 8)
        ..close();
    }
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 6, false);
    canvas.drawPath(path, Paint()..color = DT.surfaceWhite);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.tailRight != tailRight;
}
