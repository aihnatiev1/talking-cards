import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/confetti_overlay_mixin.dart';
import 'package:talking_cards/widgets/confetti_burst.dart';

class _ConfettiHost extends ConsumerStatefulWidget {
  const _ConfettiHost();
  @override
  ConsumerState<_ConfettiHost> createState() => _ConfettiHostState();
}

class _ConfettiHostState extends ConsumerState<_ConfettiHost>
    with ConfettiOverlayMixin {
  @override
  void dispose() {
    disposeConfetti();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showConfetti(),
          child: const Text('Burst'),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: _ConfettiHost())),
  );
}

void main() {
  group('ConfettiOverlayMixin', () {
    testWidgets('showConfetti inserts a ConfettiBurst into the overlay',
        (tester) async {
      await _pump(tester);
      expect(find.byType(ConfettiBurst), findsNothing);

      await tester.tap(find.text('Burst'));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsOneWidget);
      // Wrapped in IgnorePointer by default — find one that contains the burst
      expect(
        find.ancestor(
          of: find.byType(ConfettiBurst),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('overlay is removed after default linger (1500ms)',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Burst'));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      // settle any pending frames the burst may have queued
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('a second showConfetti replaces the first entry',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Burst'));
      await tester.pump();
      await tester.tap(find.text('Burst'));
      await tester.pump();
      // Should still be exactly one
      expect(find.byType(ConfettiBurst), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('disposeConfetti called on widget removal cleans overlay',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Burst'));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsOneWidget);

      // Replace the host — triggers dispose()
      await tester.pumpWidget(
        const ProviderScope(
            child: MaterialApp(home: Scaffold(body: SizedBox()))),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(ConfettiBurst), findsNothing);
    });
  });
}
