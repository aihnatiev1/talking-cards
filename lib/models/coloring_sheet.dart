import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// One eye, found in the line art by `tools/gen_region_map.py`.
///
/// Eyes are drawn solid, so they are part of the outline and never an
/// area anyone can fill. They are here because a blink is the cheapest
/// thing that makes a finished drawing look alive, and it needs to know
/// where to close a lid — and in what colour, which is whatever the child
/// painted the face.
class ColoringEye {
  final double cx, cy, rx, ry;

  /// The area the eye sits in, so the lid is the colour of the face.
  final int hostArea;

  const ColoringEye({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.hostArea,
  });
}

/// A line drawing with every fillable area already worked out.
///
/// The areas come from the build-time map rather than a flood fill under
/// the finger: a live fill leaks through an anti-aliased outline and one
/// tap paints half the picture.
class ColoringSheet {
  final String id;
  final ui.Image lineArt;
  final int width, height;

  /// Area id per pixel, row-major; 0 is outline and background.
  final Uint16List areaAt;

  /// Pixel indices per area, so filling one is a write over its own
  /// pixels rather than a pass over the picture.
  final Map<int, Uint32List> pixelsOf;

  final List<ColoringEye> eyes;

  /// The card id of the word this picture says when it is finished, or
  /// null for a drawing that has no word yet.
  ///
  /// This is the line between a colouring app and a speech app: the
  /// reward for finishing a lion is hearing «лев», in the same voice the
  /// cards use, at the moment the child is proudest of it.
  final String? word;

  /// The paper around the figure. Fillable like anything else, but it
  /// never counts towards "finished": on a face drawing it is most of the
  /// pixels, and painting it alone used to end the picture with the whole
  /// animal still white.
  final int? backgroundArea;

  ColoringSheet({
    required this.id,
    required this.lineArt,
    required this.width,
    required this.height,
    required this.areaAt,
    required this.pixelsOf,
    required this.eyes,
    this.word,
    this.backgroundArea,
  });

  int get areaCount => pixelsOf.length;

  /// The area under a point, or 0. A finger that lands on the outline
  /// itself is looking for the area beside it, so search outward a little
  /// before giving up — at this age the tap is never where it was aimed.
  int areaNear(int x, int y, {int radius = 14}) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    final direct = areaAt[y * width + x];
    if (direct != 0) return direct;
    for (var r = 2; r <= radius; r += 2) {
      for (var dy = -r; dy <= r; dy += 2) {
        for (var dx = -r; dx <= r; dx += 2) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final id = areaAt[ny * width + nx];
          if (id != 0) return id;
        }
      }
    }
    return 0;
  }

  static Future<ColoringSheet> load(String id) async {
    final base = 'assets/images/coloring/$id';
    final meta =
        json.decode(await rootBundle.loadString('$base.json'))
            as Map<String, dynamic>;
    // The outline on transparency, not the delivered file: artwork
    // arrives on solid white, and white drawn over the child's colours
    // hides every one of them. tools/gen_region_map.py knocks the paper
    // out; this is that file.
    final lineArt = await _decode('$base.ink.png');
    final map = await _decode('$base.map.png');
    final raw = await map.toByteData(format: ui.ImageByteFormat.rawRgba);
    map.dispose();

    final w = meta['width'] as int;
    final h = meta['height'] as int;
    final bytes = raw!.buffer.asUint8List();
    final areaAt = Uint16List(w * h);
    final counts = <int, int>{};
    for (var i = 0; i < w * h; i++) {
      // The generator encodes the id as (R << 8 | G).
      final id = (bytes[i * 4] << 8) | bytes[i * 4 + 1];
      areaAt[i] = id;
      if (id != 0) counts[id] = (counts[id] ?? 0) + 1;
    }
    final pixelsOf = {
      for (final e in counts.entries) e.key: Uint32List(e.value),
    };
    final cursor = <int, int>{};
    for (var i = 0; i < w * h; i++) {
      final id = areaAt[i];
      if (id == 0) continue;
      final at = cursor[id] ?? 0;
      pixelsOf[id]![at] = i;
      cursor[id] = at + 1;
    }

    final sheet = ColoringSheet(
      id: id,
      lineArt: lineArt,
      width: w,
      height: h,
      areaAt: areaAt,
      pixelsOf: pixelsOf,
      eyes: const [],
    );

    final eyes = <ColoringEye>[];
    for (final e in (meta['eyes'] as List<dynamic>)) {
      final m = e as Map<String, dynamic>;
      final cx = (m['cx'] as num).toDouble();
      final cy = (m['cy'] as num).toDouble();
      final ry = (m['ry'] as num).toDouble();
      // Just above the eye is the face it sits in.
      final host = sheet.areaNear(
        cx.round(),
        (cy - ry * 2).round().clamp(0, h - 1),
        radius: 30,
      );
      eyes.add(ColoringEye(
        cx: cx,
        cy: cy,
        rx: (m['rx'] as num).toDouble(),
        ry: ry,
        hostArea: host,
      ));
    }

    return ColoringSheet(
      id: id,
      lineArt: lineArt,
      width: w,
      height: h,
      areaAt: areaAt,
      pixelsOf: pixelsOf,
      eyes: eyes,
      word: meta['word'] as String?,
      backgroundArea: meta['background'] as int?,
    );
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    return (await codec.getNextFrame()).image;
  }
}
