import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/app_theme.dart';
import 'package:talking_cards/utils/motion.dart';

/// Freezes ambient motion for every test in the enclosing `main` / `group`.
///
/// Sets [MotionPolicy.debugOverride] to [MotionMode.test] in `setUp` and
/// clears it in `tearDown`, so an `AmbientLoop` renders its rest pose and a
/// `dur()`-gated transition sits at its end state. Golden tests need this —
/// a breathing hero caught mid-breath is a different PNG every run — and
/// `pumpAndSettle` needs it to terminate on screens that idle-animate.
///
/// Scoped on purpose: a few widget tests assert that a loop *is* running,
/// which is why `flutter_test_config.dart` does not set the override for
/// the whole suite.
void useTestMotion() {
  setUp(() => MotionPolicy.debugOverride = MotionMode.test);
  tearDown(() => MotionPolicy.debugOverride = null);
}

/// Key of the `RepaintBoundary` that [goldenHost] draws around its child —
/// pass `find.byKey(goldenKey)` to `matchesGoldenFile` so the PNG is exactly
/// the host surface and nothing else.
const goldenKey = ValueKey('golden-host');

/// The one tree every golden is rendered in: the real app theme
/// (`buildAppTheme`, or the parent-zone dark theme when [dark]), a
/// `MediaQuery` pinned to [size] at `devicePixelRatio: 1`, and a `Scaffold`.
///
/// Pair with [setGoldenSurface] so the tester's window matches [size];
/// otherwise the Scaffold lays out against the default 800×600 surface and
/// the PNG has an unrelated frame around the widget.
Widget goldenHost(
  Widget child, {
  Size size = const Size(390, 844),
  bool dark = false,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, devicePixelRatio: 1),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? buildAppDarkTheme() : buildAppTheme(),
      home: RepaintBoundary(
        key: goldenKey,
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Sizes the tester's window to [size] logical pixels at ratio 1 and
/// restores it after the test.
void setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [setGoldenSurface] + [goldenHost] + `pumpWidget` + `pumpAndSettle`.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  bool dark = false,
  Widget Function(Widget host)? wrap,
}) async {
  setGoldenSurface(tester, size);
  final host = goldenHost(child, size: size, dark: dark);
  await tester.pumpWidget(wrap == null ? host : wrap(host));
  await tester.pumpAndSettle();
}
