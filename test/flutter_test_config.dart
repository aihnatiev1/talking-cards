import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs once per test isolate before any test in `test/` (flutter_test picks
/// this file up by name).
///
/// Its only job is fonts. The test binding renders every glyph with the
/// built-in `FlutterTest` face — a filled square — so a golden of a Nunito
/// headline would otherwise be a row of boxes, and `MaterialIcons` would be
/// boxes too. Loading here, once, means golden tests do not each carry a
/// `FontLoader` and widget tests that measure text (`TextPainter` in
/// `PlayfulNavigationBar`, `QuestJourneyMap`) measure the real face.
///
/// Nunito is registered three times:
///  * as `Nunito` — `DT.kidFont`, the kid-zone headings and tile titles;
///  * as `Roboto` — the theme's body/label family (`buildAppTheme`), which
///    the tester has no copy of; borrowing Nunito keeps `DT.body` and
///    `DT.caption` legible in goldens instead of squares;
///  * `MaterialIcons` from the engine's own bundle, for `Icon(...)`.
///
/// Deliberately *not* here: `MotionPolicy.debugOverride`. Several widget
/// tests assert that a loop is running; freezing motion globally would break
/// them. Golden tests opt in with `useTestMotion()` from
/// `test/helpers/motion.dart`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  await testMain();
}

Future<void> _loadFonts() async {
  final nunito = rootBundle.load('assets/fonts/Nunito-Variable.ttf');
  for (final family in const ['Nunito', 'Roboto']) {
    final loader = FontLoader(family)..addFont(nunito);
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
