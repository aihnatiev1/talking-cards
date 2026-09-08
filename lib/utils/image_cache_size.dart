import 'dart:math';

import 'package:flutter/widgets.dart';

/// Card illustrations ship at 640px wide (tools/compress_assets.py resizes
/// to this; keep the two in sync). Decoding wider than the render box
/// wastes memory (a 640×858 RGBA decode is ~2.2MB per image) — cap the
/// decode width at what the layout can actually display on this device.
/// Keep precacheImage callers in sync with the display sites: mismatched
/// widths create a second cache entry and double the decode.
const int kCardSourceWidth = 640;

/// Full-screen card image (FlashCard swiper, card reveal).
int cardCacheWidth(BuildContext context) {
  final mq = MediaQuery.of(context);
  return min(
      kCardSourceWidth, (mq.size.width * mq.devicePixelRatio).round());
}

/// Grid tile / quiz option thumbnails (roughly half the screen wide).
int tileCacheWidth(BuildContext context) {
  final mq = MediaQuery.of(context);
  return min(
      kCardSourceWidth, (mq.size.width * mq.devicePixelRatio / 2).round());
}
