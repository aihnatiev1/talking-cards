import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/bubble_pop_screen.dart';

void main() {
  for (final body in [
    const Size(280, 160),
    const Size(390, 700),
    const Size(844, 192),
    const Size(834, 1000),
  ]) {
    test('card stays inside $body throughout its spring and lift', () {
      for (final diameter in [88.0, 176.0, 238.0]) {
        for (final origin in [
          Offset.zero,
          Offset(body.width, 0),
          Offset(0, body.height),
          Offset(body.width, body.height),
          body.center(Offset.zero),
        ]) {
          final placement = BubbleStage.revealPlacement(
            body: body,
            bubbleSize: diameter,
            origin: origin,
          );
          expect(placement.scale, inInclusiveRange(0, 1));
          for (var frame = 0; frame <= 100; frame++) {
            final t = frame / 100;
            final spring = 1 + .25 * Curves.elasticOut.transform(t);
            final width = diameter * .95 * spring * placement.scale;
            final height = width * 4 / 3;
            final centre =
                origin +
                placement.shift +
                Offset(0, -8 * math.sin(t * math.pi));
            final rect = Rect.fromCenter(
              center: centre,
              width: width,
              height: height,
            );
            expect(rect.left, greaterThanOrEqualTo(7.99));
            expect(rect.top, greaterThanOrEqualTo(7.99));
            expect(rect.right, lessThanOrEqualTo(body.width - 7.99));
            expect(rect.bottom, lessThanOrEqualTo(body.height - 7.99));
          }
        }
      }
    });
  }
  test('ordinary phone portrait preserves the full reveal size', () {
    final placement = BubbleStage.revealPlacement(
      body: const Size(390, 700),
      bubbleSize: 160,
      origin: const Offset(195, 350),
    );
    expect(placement.scale, 1);
    expect(placement.shift, Offset.zero);
  });
}
