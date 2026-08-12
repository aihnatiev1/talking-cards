import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/paywall_screen.dart';

/// Widget tests for the current paywall. Firebase isn't initialized in the
/// test environment — RemoteConfigService falls back to its baked-in
/// defaults, so RC-driven strings assert the default copy.
void main() {
  Widget createPaywallApp() {
    return ProviderScope(
      child: MaterialApp(
        home: const PaywallScreen(),
      ),
    );
  }

  /// Pumps the paywall and advances past its 3-second close-button delay
  /// so no timer is left pending at teardown.
  Future<void> pumpPaywall(WidgetTester tester) async {
    await tester.pumpWidget(createPaywallApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  group('PaywallScreen', () {
    testWidgets('renders headline and benefits', (tester) async {
      await pumpPaywall(tester);

      // RC-default headline (no child profile in tests → non-personalized)
      expect(find.text('Розблокуй всі картки!'), findsOneWidget);
      expect(find.textContaining('19 розділів'), findsOneWidget);
      expect(find.textContaining('400+ яскравих карток'), findsOneWidget);
      expect(find.textContaining('Нові розділи'), findsOneWidget);
    });

    testWidgets('shows two fallback plan options', (tester) async {
      await pumpPaywall(tester);

      // Fallback plans when store products are not loaded
      expect(find.text('Річна'), findsOneWidget);
      expect(find.text('Місячна'), findsOneWidget);
    });

    testWidgets('shows yearly badge "Найвигідніше"', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Найвигідніше'), findsOneWidget);
    });

    testWidgets('shows trial CTA and cancel-anytime note', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Спробувати 3 дні безкоштовно'), findsOneWidget);
      expect(find.textContaining('Скасувати будь-коли'), findsAtLeast(1));
    });

    testWidgets('shows restore purchases button', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Відновити покупки'), findsOneWidget);
    });

    testWidgets('shows Terms of Use link', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Умови використання'), findsOneWidget);
    });

    testWidgets('shows Privacy Policy link', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Конфіденційність'), findsOneWidget);
    });

    testWidgets('honest social proof: no fabricated 4.9 rating',
        (tester) async {
      await pumpPaywall(tester);

      expect(find.textContaining('4.9'), findsNothing);
    });

    testWidgets('close button appears after the 3s read delay',
        (tester) async {
      await pumpPaywall(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button pops screen', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                    popped = result == false || result == null;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Fire the 3s close-button timer scheduled in initState.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Invoke the close IconButton directly — its top-right position can
      // fall outside the tappable area in the small test viewport.
      final closeButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(IconButton),
        ),
      );
      closeButton.onPressed!();
      await tester.pumpAndSettle();

      expect(popped, true);
    });

    testWidgets('can select monthly plan', (tester) async {
      await pumpPaywall(tester);

      await tester.tap(find.text('Місячна'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/місяць'), findsAtLeast(1));
    });
  });
}
