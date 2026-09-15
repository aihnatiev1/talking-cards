import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/filled_sheets_provider.dart';
import 'package:talking_cards/screens/my_meadow_screen.dart';

/// The meadow is a place, not a gallery: it fills up as the child
/// finishes things, and until then it says so rather than showing an
/// empty grid.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty, it promises rather than showing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyMeadowScreen())),
    );
    await tester.pump();
    expect(find.text('Тут стануть твої малюнки'), findsOneWidget);
  });

  testWidgets('a finished drawing gets a place on it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(filledSheetsProvider.notifier)
        .record('placeholder_lion', 1, 'yellow');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyMeadowScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Тут стануть твої малюнки'), findsNothing);
    expect(find.byKey(const ValueKey('sheet-placeholder_lion')), findsOneWidget);
  });
}
