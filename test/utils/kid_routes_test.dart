import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/kid_routes.dart';
import 'package:talking_cards/utils/motion.dart';

/// A host with a real Navigator. [reduceMotion] is applied *above* the
/// Navigator (via `MaterialApp.builder`) because that is where a route
/// looks — `navigator.context` — for the OS flag.
Widget _host({bool reduceMotion = false}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('home')),
    );

typedef _Factory = PageRoute<Object?> Function(Widget page);

const Map<String, _Factory> _factories = {
  'content': KidRoutes.content,
  'game': KidRoutes.game,
  'sheet': KidRoutes.sheet,
  'overlay': KidRoutes.overlay,
  'replace': KidRoutes.replace,
};

void main() {
  tearDown(() => MotionPolicy.debugOverride = null);

  for (final entry in _factories.entries) {
    testWidgets('${entry.key} pushes, shows the page and pops', (tester) async {
      await tester.pumpWidget(_host());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      navigator.push(entry.value(const Scaffold(body: Text('pushed'))));
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('routes return their result', (tester) async {
    await tester.pumpWidget(_host());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    final result = navigator.push<bool>(
      KidRoutes.sheet<bool>(const Scaffold(body: Text('paywall'))),
    );
    await tester.pumpAndSettle();
    navigator.pop(true);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('overlay and sheet are non-opaque, the rest are opaque',
      (tester) async {
    await tester.pumpWidget(_host());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    final overlay = KidRoutes.overlay(const SizedBox());
    final sheet = KidRoutes.sheet(const SizedBox());
    expect(overlay.opaque, isFalse);
    expect(sheet.opaque, isFalse);
    expect(KidRoutes.content(const SizedBox()).opaque, isTrue);
    expect(KidRoutes.game(const SizedBox()).opaque, isTrue);
    expect(KidRoutes.replace(const SizedBox()).opaque, isTrue);

    // The screen underneath stays in the tree while an overlay is up.
    navigator.push(overlay);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(overlay.barrierColor, KidRoutes.overlayBarrier);
    expect(sheet.barrierColor, KidRoutes.sheetBarrier);
  });

  testWidgets('full motion keeps the specified durations', (tester) async {
    await tester.pumpWidget(_host());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    final route = KidRoutes.content(const SizedBox());
    navigator.push(route);
    await tester.pump();
    expect(route.transitionDuration, KidRoutes.contentIn);
    expect(route.reverseTransitionDuration, KidRoutes.contentOut);
    // Mid-flight after one frame: the page is still animating in.
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation?.isCompleted, isFalse);
    await tester.pumpAndSettle();
    expect(route.animation?.isCompleted, isTrue);
  });

  testWidgets('reduced motion collapses every route to zero duration',
      (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    for (final entry in _factories.entries) {
      final route = entry.value(Scaffold(body: Text(entry.key)));
      navigator.push(route);
      // One frame, no clock advance: with a zero duration the route is
      // already fully in.
      await tester.pump();
      expect(route.transitionDuration, Duration.zero, reason: entry.key);
      expect(route.reverseTransitionDuration, Duration.zero,
          reason: entry.key);
      expect(route.animation?.isCompleted, isTrue, reason: entry.key);
      expect(find.text(entry.key), findsOneWidget);
      navigator.pop();
      await tester.pump();
    }
  });

  testWidgets('MotionPolicy.debugOverride also quiets routes', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    await tester.pumpWidget(_host());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    final route = KidRoutes.game(const SizedBox());
    navigator.push(route);
    await tester.pump();
    expect(route.transitionDuration, Duration.zero);
  });

  testWidgets('KidPageTransitionsBuilder wraps MaterialPageRoute pages',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: KidPageTransitionsBuilder(),
            TargetPlatform.iOS: KidPageTransitionsBuilder(),
          }),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              // The one place outside kid_routes.dart a MaterialPageRoute
              // is spelled out: this test proves the theme fallback.
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('themed')),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Our builder renders fade + scale; the platform defaults do not use
    // ScaleTransition for a page on iOS.
    expect(find.byType(ScaleTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('themed'), findsOneWidget);
    expect(const KidPageTransitionsBuilder().transitionDuration,
        KidRoutes.contentIn);
  });
}
