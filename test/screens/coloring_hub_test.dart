import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/coloring_hub_screen.dart';
import 'package:talking_cards/screens/mirror_draw_screen.dart';

/// «Малюємо» is a shelf of ways to draw now, the way the cards tab is a
/// shelf of packs — so it must behave like a tab, and its tiles must open
/// something.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ColoringHubScreen()),
      ),
    );
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

  testWidgets('both ways of drawing are on the shelf', (tester) async {
    await open(tester);
    expect(find.text('Чарівна вода'), findsOneWidget);
    expect(find.text('Дзеркальце'), findsOneWidget);
  });

  testWidgets('a tile opens its screen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Дзеркальце'));
    await tester.pumpAndSettle();
    expect(find.byType(MirrorDrawScreen), findsOneWidget);
  });
}
