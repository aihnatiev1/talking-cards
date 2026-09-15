import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The line drawings available to the filling modes, in the order the
/// index lists them.
///
/// Read from `assets/images/coloring/sheets.json`, which
/// `tools/gen_region_map.py` rewrites every time it runs. Dropping a new
/// contour into the folder and running the tool is the whole of adding a
/// picture — no code, no list to keep in step, and nothing to forget.
///
/// Empty is a real answer, not a failure: a build with no contours yet
/// simply has no filling modes on the shelf.
final coloringSheetsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final raw = await rootBundle.loadString(
      'assets/images/coloring/sheets.json',
    );
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return (decoded['sheets'] as List<dynamic>).cast<String>();
  } catch (_) {
    return const [];
  }
});
