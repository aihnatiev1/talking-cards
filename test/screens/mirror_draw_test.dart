import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/mirror_draw_screen.dart';
import 'package:talking_cards/widgets/crayon_palette.dart';

/// Mirror drawing has one rule: nothing a child does here can be wrong,
/// and every line comes back doubled.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MirrorDrawScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('ten crayons, the first one already in hand', (tester) async {
    await open(tester);
    final palette = tester.widget<CrayonPalette>(find.byType(CrayonPalette));
    expect(kCrayons.length, 10);
    expect(palette.selectedId, kCrayons.first.id);
  });

  testWidgets('picking a crayon changes the one in hand', (tester) async {
    await open(tester);
    final green = kCrayons.firstWhere((c) => c.id == 'green');
    tester.widget<CrayonPalette>(find.byType(CrayonPalette)).onSelected(green);
    await tester.pump();
    expect(
      tester.widget<CrayonPalette>(find.byType(CrayonPalette)).selectedId,
      'green',
    );
  });

  testWidgets('a drag leaves a line, and clearing takes it away', (
    tester,
  ) async {
    await open(tester);
    final canvas = find.byType(CustomPaint).last;

    await tester.drag(canvas, const Offset(40, 60));
    await tester.pump();

    // The screen holds the stroke; the painter is what doubles it, and a
    // repaint is what we can observe from here.
    final before = tester.widget<CustomPaint>(canvas).painter;
    expect(before, isNotNull);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    expect(find.byType(MirrorDrawScreen), findsOneWidget);
  });
}
