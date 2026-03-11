import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/color_utils.dart';

void main() {
  group('colorFromHex', () {
    test('parses 6-digit hex with hash', () {
      expect(colorFromHex('#FF5733'), const Color(0xFFFF5733));
    });

    test('parses 6-digit hex without hash', () {
      expect(colorFromHex('FF5733'), const Color(0xFFFF5733));
    });

    test('parses black', () {
      expect(colorFromHex('#000000'), const Color(0xFF000000));
    });

    test('parses white', () {
      expect(colorFromHex('#FFFFFF'), const Color(0xFFFFFFFF));
    });

    test('adds FF alpha to 6-digit hex', () {
      final color = colorFromHex('4CAF50');
      expect(color.a, 1.0); // fully opaque
    });

    test('parses lowercase hex', () {
      expect(colorFromHex('#ff5733'), const Color(0xFFFF5733));
    });

    test('parses 8-digit hex (with alpha)', () {
      // 8-digit hex should be passed through as-is
      expect(colorFromHex('80FF5733'), const Color(0x80FF5733));
    });
  });
}
