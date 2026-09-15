import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/filled_sheets_provider.dart';
import 'package:talking_cards/screens/fill_coloring_screen.dart';

/// Does a tap on the picture actually fill anything?
///
/// A widget test cannot answer it — the sheet and its region map are real
/// assets, and the fake-async zone a widget test runs in never lets that
/// load finish. On a device it loads, so this is where the question
/// belongs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a part of the drawing paints it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: FillColoringScreen(sheetId: 'bear_cub'),
        ),
      ),
    );
    // The sheet decodes two images and builds its index; give it time.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final picture = find.byType(CustomPaint).last;
    expect(picture, findsOneWidget);
    final box = tester.getRect(picture);
    debugPrint('FILL_TEST picture rect: $box');

    // The middle of the drawing: on this lion that is the muzzle/head.
    await tester.tapAt(box.center);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final saved = container
        .read(filledSheetsProvider.notifier)
        .of('bear_cub');
    debugPrint('FILL_TEST filled areas: $saved');
    expect(saved, isNotEmpty, reason: 'a tap in the middle painted nothing');
  });
}
