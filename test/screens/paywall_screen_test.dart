import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/paywall_screen.dart';

void main() {
  Widget createPaywallApp() {
    return ProviderScope(
      child: MaterialApp(
        home: const PaywallScreen(),
      ),
    );
  }

  group('PaywallScreen', () {
    testWidgets('renders title and benefits', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Розблокуй всі картки!'), findsOneWidget);
      expect(find.textContaining('6 розділів'), findsOneWidget);
      expect(find.textContaining('174 яскраві картки'), findsOneWidget);
      expect(find.textContaining('Нові розділи'), findsOneWidget);
      expect(find.textContaining('3 дні безкоштовно'), findsAtLeast(1));
    });

    testWidgets('shows two plan options', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      // Fallback plans when products not loaded
      expect(find.text('Річна'), findsOneWidget);
      expect(find.text('Місячна'), findsOneWidget);
    });

    testWidgets('shows yearly badge "Найвигідніше"', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Найвигідніше'), findsOneWidget);
    });

    testWidgets('shows purchase button', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Спробувати 3 дні безкоштовно'), findsOneWidget);
    });

    testWidgets('shows restore purchases button', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Відновити покупки'), findsOneWidget);
    });

    testWidgets('shows "Може пізніше" button', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Може пізніше'), findsOneWidget);
    });

    testWidgets('shows Terms of Use link', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Умови використання'), findsOneWidget);
    });

    testWidgets('shows Privacy Policy link', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('Політика конфіденційності'), findsOneWidget);
    });

    testWidgets('close button exists', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

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

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(popped, true);
    });

    testWidgets('can select monthly plan', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      // Tap on monthly plan
      await tester.tap(find.text('Місячна'));
      await tester.pumpAndSettle();

      // Price text below button should show monthly price
      expect(find.textContaining('/місяць'), findsAtLeast(1));
    });

    testWidgets('shows star emoji', (tester) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pumpAndSettle();

      expect(find.text('🌟'), findsOneWidget);
    });
  });
}
