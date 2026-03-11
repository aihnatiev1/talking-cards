import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/parental_gate.dart';

void main() {
  group('ParentalGate widget', () {
    testWidgets('shows math question', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ParentalGate.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show title
      expect(find.text('Перевірка для батьків'), findsOneWidget);
      // Should show lock emoji
      expect(find.text('🔒'), findsOneWidget);
      // Should show a math question with "Скільки буде"
      expect(find.textContaining('Скільки буде'), findsOneWidget);
      // Should show 4 option buttons + the "Open" button = 5
      expect(find.byType(ElevatedButton), findsNWidgets(5));
      // Should show cancel button
      expect(find.text('Скасувати'), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await ParentalGate.show(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Скасувати'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('correct answer returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await ParentalGate.show(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Extract the math question
      final questionFinder = find.textContaining('Скільки буде');
      final questionText = (tester.widget(questionFinder) as Text).data!;
      // Parse "Скільки буде A + B?"
      final match = RegExp(r'(\d+) \+ (\d+)').firstMatch(questionText);
      final a = int.parse(match!.group(1)!);
      final b = int.parse(match.group(2)!);
      final correctAnswer = a + b;

      // Tap the correct answer
      await tester.tap(find.text('$correctAnswer'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('wrong answer shows error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ParentalGate.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Extract the correct answer
      final questionFinder = find.textContaining('Скільки буде');
      final questionText = (tester.widget(questionFinder) as Text).data!;
      final match = RegExp(r'(\d+) \+ (\d+)').firstMatch(questionText);
      final a = int.parse(match!.group(1)!);
      final b = int.parse(match.group(2)!);
      final correctAnswer = a + b;

      // Find a wrong answer button inside the dialog
      final dialogButtons = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(ElevatedButton),
      );
      final buttons = tester.widgetList<ElevatedButton>(dialogButtons);
      for (final button in buttons) {
        final child = button.child;
        if (child is Text && child.data != '$correctAnswer') {
          await tester.tap(find.widgetWithText(ElevatedButton, child.data!));
          break;
        }
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Попроси маму або тата'), findsOneWidget);
    });

    testWidgets('math options contain only positive numbers', (tester) async {
      // Run multiple times to check randomness
      for (int i = 0; i < 10; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => ParentalGate.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Check all button texts are positive integers
        final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
        for (final button in buttons) {
          final child = button.child;
          if (child is Text) {
            final value = int.tryParse(child.data ?? '');
            if (value != null) {
              expect(value, greaterThan(0),
                  reason: 'Option should be positive, got $value');
            }
          }
        }

        // Close dialog
        await tester.tap(find.text('Скасувати'));
        await tester.pumpAndSettle();
      }
    });
  });
}
