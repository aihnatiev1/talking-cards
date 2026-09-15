import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/coloring_sheets_provider.dart';
import 'package:talking_cards/screens/coloring_hub_screen.dart';
import 'package:talking_cards/screens/mirror_draw_screen.dart';

/// «Малюємо» is a shelf of ways to draw now, the way the cards tab is a
/// shelf of packs — so it must behave like a tab, and it must only offer
/// what it can actually open.
void main() {
  Future<void> open(WidgetTester tester, {List<String> sheets = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        // The real index is read from the bundle, which a widget test's
        // fake-async zone will not let finish; what matters here is what
        // the shelf does with the answer.
        overrides: [
          coloringSheetsProvider.overrideWith((ref) async => sheets),
        ],
        child: const MaterialApp(home: ColoringHubScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the shelf has no close button — it is a tab', (tester) async {
    await open(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Close',
      ),
      findsNothing,
      reason: 'closing a tab pops the home shell and blacks the screen',
    );
  });

  testWidgets('with drawings, every way of drawing is on the shelf', (
    tester,
  ) async {
    await open(tester, sheets: const ['lion']);
    for (final title in [
      'Чарівна вода',
      'Розфарбуй',
      'Слухай і фарбуй',
      'Наліпки',
      'Дзеркальце',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('with no drawings the filling modes are not offered', (
    tester,
  ) async {
    await open(tester);
    // A tile that opens an empty screen is worse than no tile.
    expect(find.text('Розфарбуй'), findsNothing);
    expect(find.text('Слухай і фарбуй'), findsNothing);
    // The modes that need no artwork are still there.
    expect(find.text('Чарівна вода'), findsOneWidget);
    expect(find.text('Наліпки'), findsOneWidget);
    expect(find.text('Дзеркальце'), findsOneWidget);
  });

  testWidgets('a tile opens its screen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Дзеркальце'));
    await tester.pumpAndSettle();
    expect(find.byType(MirrorDrawScreen), findsOneWidget);
  });
}
