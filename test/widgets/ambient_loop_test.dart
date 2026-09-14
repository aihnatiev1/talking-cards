import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/ambient_loop.dart';

/// AmbientLoop is the one owner of `repeat()`; these tests pin the contract
/// every migrated loop now relies on (architecture audit 2026-09-13 §2 F2).
void main() {
  tearDown(() => MotionPolicy.debugOverride = null);

  /// Records every `t` the builder saw so a test can tell "moved" from
  /// "sat at rest" without reaching into the controller.
  Widget host(
    List<double> seen, {
    bool reduce = false,
    bool enabled = true,
    bool reverse = true,
    Duration? settleAfter,
    Duration period = const Duration(milliseconds: 400),
    bool tickers = true,
  }) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TickerMode(
            enabled: tickers,
            child: AmbientLoop(
              period: period,
              reverse: reverse,
              enabled: enabled,
              settleAfter: settleAfter,
              builder: (_, t, child) {
                seen.add(t);
                return Transform.scale(scale: 1 + t, child: child);
              },
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

  group('MotionPolicy', () {
    testWidgets('mirrors the OS flag and the override wins', (tester) async {
      late MotionPolicy seen;
      Widget probe(bool reduce) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Builder(builder: (context) {
              seen = MotionPolicy.of(context);
              return const SizedBox();
            }),
          );

      await tester.pumpWidget(probe(false));
      expect(seen.mode, MotionMode.full);
      expect(seen.reduce, isFalse);
      expect(seen.ambient, isTrue);
      expect(seen.dur(const Duration(seconds: 1)), const Duration(seconds: 1));

      await tester.pumpWidget(probe(true));
      expect(seen.mode, MotionMode.reduced);
      expect(seen.reduce, isTrue);
      expect(seen.ambient, isFalse);
      expect(seen.dur(const Duration(seconds: 1)), Duration.zero);

      MotionPolicy.debugOverride = MotionMode.test;
      await tester.pumpWidget(probe(false));
      expect(seen.mode, MotionMode.test);
      expect(seen.reduce, isTrue);
      expect(seen.ambient, isFalse);
      expect(reduceMotionOf(tester.element(find.byType(SizedBox))), isTrue);
    });
  });

  group('AmbientLoop', () {
    testWidgets('loops under full motion', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(host(seen));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
      expect(seen.any((t) => t > 0.5), isTrue, reason: 'reached the peak');
      // Still going a few periods later — it is a loop, not a one-shot.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('is static under reduced motion', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(host(seen, reduce: true));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen, everyElement(0.0));
      // The thing pumpAndSettle-based tests actually need.
      await tester.pumpAndSettle();
    });

    testWidgets('is static under MotionMode.test', (tester) async {
      MotionPolicy.debugOverride = MotionMode.test;
      final seen = <double>[];
      await tester.pumpWidget(host(seen));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen, everyElement(0.0));
      await tester.pumpAndSettle();
    });

    testWidgets('renders the child', (tester) async {
      await tester.pumpWidget(host(<double>[], reduce: true));
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('stops at rest after settleAfter', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(
        host(seen, settleAfter: const Duration(seconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);

      // Wall clock passes the settle point; the loop then plays its current
      // pass back to rest (at most one period) and goes quiet.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen.last, 0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('a wrapping loop also settles at rest', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(host(
        seen,
        reverse: false,
        settleAfter: const Duration(seconds: 1),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen.last, 0.0);
    });

    testWidgets('respects TickerMode(enabled: false)', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(host(seen, tickers: false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen, everyElement(0.0));

      // Un-hiding the subtree (an IndexedStack tab coming back) resumes.
      await tester.pumpWidget(host(seen, tickers: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('enabled toggles the loop cleanly', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(host(seen, enabled: false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen, everyElement(0.0));

      await tester.pumpWidget(host(seen, enabled: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
      expect(seen.last, greaterThan(0.0));

      await tester.pumpWidget(host(seen, enabled: false));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen.last, 0.0, reason: 'disabled means rest pose, not a freeze');
    });

    testWidgets('re-enabling restarts the settle window', (tester) async {
      final seen = <double>[];
      Widget build(bool enabled) => host(
            seen,
            enabled: enabled,
            settleAfter: const Duration(milliseconds: 500),
          );
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: 'settled once');

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue, reason: 'fresh accent');
    });

    testWidgets('disposes without leaking a ticker', (tester) async {
      await tester.pumpWidget(host(<double>[]));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
