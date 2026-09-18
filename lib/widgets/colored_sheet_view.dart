import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/coloring_sheet.dart';
import 'crayon_palette.dart';

/// A finished drawing, painted the way the child left it.
///
/// Loads the contour and replays the stored colours; used by the meadow,
/// where a dozen of these stand together. Nothing here is interactive —
/// the picture is the thing, and the tap belongs to whoever placed it.
class ColoredSheetView extends StatefulWidget {
  final String sheetId;

  /// Area id → crayon id, as the child left it.
  final Map<int, String> fills;

  const ColoredSheetView({
    super.key,
    required this.sheetId,
    required this.fills,
  });

  @override
  State<ColoredSheetView> createState() => _ColoredSheetViewState();
}

class _ColoredSheetViewState extends State<ColoredSheetView> {
  ColoringSheet? _sheet;
  ui.Image? _paint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sheet = await ColoringSheet.load(widget.sheetId);
    if (!mounted) {
      sheet.lineArt.dispose();
      return;
    }
    final buffer = Uint32List(sheet.width * sheet.height);
    for (final entry in widget.fills.entries) {
      final pixels = sheet.pixelsOf[entry.key];
      final crayon = kCrayons.where((c) => c.id == entry.value).firstOrNull;
      if (pixels == null || crayon == null) continue;
      final c = crayon.color;
      final packed = (0xFF << 24) |
          ((c.b * 255).round() << 16) |
          ((c.g * 255).round() << 8) |
          (c.r * 255).round();
      for (final i in pixels) {
        buffer[i] = packed;
      }
    }
    final image = await _decode(buffer, sheet.width, sheet.height);
    if (!mounted) {
      sheet.lineArt.dispose();
      image.dispose();
      return;
    }
    setState(() {
      _sheet = sheet;
      _paint = image;
    });
  }

  static Future<ui.Image> _decode(Uint32List buffer, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      buffer.buffer.asUint8List(),
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  void dispose() {
    _sheet?.lineArt.dispose();
    _paint?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _FlatSheetPainter(
        lineArt: sheet.lineArt,
        layer: _paint,
        source: Rect.fromLTWH(
          0,
          0,
          sheet.width.toDouble(),
          sheet.height.toDouble(),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FlatSheetPainter extends CustomPainter {
  final ui.Image lineArt;
  final ui.Image? layer;
  final Rect source;

  const _FlatSheetPainter({
    required this.lineArt,
    required this.layer,
    required this.source,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final brush = Paint()..filterQuality = FilterQuality.medium;
    if (layer != null) canvas.drawImageRect(layer!, source, dst, brush);
    canvas.drawImageRect(lineArt, source, dst, brush);
  }

  @override
  bool shouldRepaint(_FlatSheetPainter old) =>
      old.layer != layer || old.lineArt != lineArt;
}
