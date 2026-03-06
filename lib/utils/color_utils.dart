import 'dart:ui';

Color colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) buffer.write('FF');
  buffer.write(hex);
  return Color(int.parse(buffer.toString(), radix: 16));
}
