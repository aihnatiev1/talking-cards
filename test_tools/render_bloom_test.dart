import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';

/// Renders Bloom, straight from the app's painter, to transparent PNGs for
/// store art — so marketing never redraws the mascot by hand.
///
///   flutter test test_tools/render_bloom_test.dart
///
/// Output: `marketing/public/bloom/bloom-EMOTION-FACING.png` (1328 px).
/// Not part of `flutter test test/`: it writes files and asserts nothing
/// about the app.
void main() {
  const size = 300.0;
  const pixelRatio = 4.0;
  for (final emotion in [BloomEmotion.wave, BloomEmotion.happy, BloomEmotion.cheer]) {
    for (final facing in BloomFacing.values) {
      testWidgets('render ${emotion.name} ${facing.name}', (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.square(
                dimension: size + BloomMascot.hopClearance * 2,
                child: Center(
                  child: BloomMascot(
                    size: size,
                    facing: facing,
                    state: BloomState.still(emotion),
                  ),
                ),
              ),
            ),
          ),
        ));
        // Let the pose settle into the emotion.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: pixelRatio);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('marketing/public/bloom/bloom-${emotion.name}-${facing.name}.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
