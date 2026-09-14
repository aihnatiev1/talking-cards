import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/board_theme.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/card_back_painter.dart';

/// The one rule the card back cannot break: **every back of a board is the
/// same picture**. A doodle seeded from the tile id would let a
/// three-year-old learn the cards by their backs after two rounds, and
/// «Знайди пару» would stop being a memory game.
///
/// This is the golden of the redesign (memory_match_redesign §1, wave 1
/// 1.2): the painter is rasterised twice per theme and the pixels are
/// compared byte for byte, so the check needs no committed .png and cannot
/// drift with a font or a device pixel ratio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(160, 178);

  Future<Uint8List> render(BoardTheme theme) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    CardBackPainter(theme).paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  final animals = BoardTheme.from(DT.teal);
  final mixed = BoardTheme.from(DT.mint);

  test('two backs of the same board are pixel-identical', () async {
    final a = await render(animals);
    final b = await render(animals);
    expect(a, equals(b));
  });

  test('a second board is a different picture', () async {
    final a = await render(animals);
    final b = await render(mixed);
    expect(a, isNot(equals(b)));
  });

  test('the painter repaints only when the theme changes', () {
    // Nothing per-tile can reach the painter: it takes one argument, and
    // two painters of the same board never repaint each other.
    expect(
      CardBackPainter(animals).shouldRepaint(CardBackPainter(animals)),
      isFalse,
    );
    expect(
      CardBackPainter(animals).shouldRepaint(CardBackPainter(mixed)),
      isTrue,
    );
  });

  group('BoardTheme', () {
    test('a pale pack darkens until a cream silhouette reads on it', () {
      final theme = BoardTheme.from(DT.sunBurst);
      final l = HSLColor.fromColor(theme.seal).lightness;
      expect(l, lessThanOrEqualTo(BoardTheme.maxLightness + 0.001));
      expect(l, greaterThanOrEqualTo(BoardTheme.minLightness - 0.001));
    });

    test('a near-black pack lightens so the wash keeps its hue', () {
      final theme = BoardTheme.from(const Color(0xFF004D40));
      final hsl = HSLColor.fromColor(theme.seal);
      expect(hsl.lightness, greaterThanOrEqualTo(BoardTheme.minLightness));
      expect(hsl.saturation, greaterThanOrEqualTo(BoardTheme.minSaturation));
    });
  });
}
