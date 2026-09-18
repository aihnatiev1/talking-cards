import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/coloring_sheet.dart';

/// The one rule that makes tap-to-fill usable at two: a tap that lands on
/// the outline, or just off the shape, still finds the part the child was
/// aiming at.
void main() {
  // A 10×10 sheet: a 4×4 block of area 1 at (1,1), everything else
  // outline (0).
  ColoringSheet sheet() {
    const w = 10, h = 10;
    final areaAt = Uint16List(w * h);
    final pixels = <int>[];
    for (var y = 1; y < 5; y++) {
      for (var x = 1; x < 5; x++) {
        areaAt[y * w + x] = 1;
        pixels.add(y * w + x);
      }
    }
    return ColoringSheet(
      id: 't',
      // The painter needs the image; nothing here touches it.
      lineArt: _nullImage,
      width: w,
      height: h,
      areaAt: areaAt,
      pixelsOf: {1: Uint32List.fromList(pixels)},
      eyes: const [],
    );
  }

  test('a tap inside a part finds it', () {
    expect(sheet().areaNear(2, 2), 1);
  });

  test('a tap on the outline finds the part beside it', () {
    // (0,2) is outline; the block starts one pixel to the right.
    expect(sheet().areaNear(0, 2), 1);
  });

  test('a tap far from anything fills nothing', () {
    // The default reach is 14 px, which is small on a 700 px drawing and
    // most of the way across this 10 px fixture — so the limit is what is
    // under test here, not the number.
    expect(sheet().areaNear(9, 9, radius: 2), 0);
  });

  test('a tap outside the picture fills nothing', () {
    expect(sheet().areaNear(-3, 4), 0);
    expect(sheet().areaNear(4, 40), 0);
  });

  test('the sheet knows how many parts are left to colour', () {
    expect(sheet().areaCount, 1);
  });
}

/// A stand-in: `areaNear` never reads the image, and decoding a real one
/// needs a binding this test does not want.
final _nullImage = _FakeImage();

class _FakeImage implements ui.Image {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
