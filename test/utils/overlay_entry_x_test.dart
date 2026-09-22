import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/overlay_entry_x.dart';

void main() {
  testWidgets('a second removal is a no-op, not a crash', (tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(MaterialApp(
      home: Overlay(initialEntries: [
        OverlayEntry(builder: (context) {
          overlay = Overlay.of(context);
          return const SizedBox.shrink();
        }),
      ]),
    ));

    final entry = OverlayEntry(builder: (_) => const Text('burst'));
    overlay.insert(entry);
    await tester.pump();
    expect(find.text('burst'), findsOneWidget);

    entry.removeIfMounted();
    await tester.pump();
    expect(find.text('burst'), findsNothing);

    // The timer that was going to remove it fires after dispose already did.
    entry.removeIfMounted();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove() itself throws the second time — the reason this exists',
      (tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(MaterialApp(
      home: Overlay(initialEntries: [
        OverlayEntry(builder: (context) {
          overlay = Overlay.of(context);
          return const SizedBox.shrink();
        }),
      ]),
    ));

    final entry = OverlayEntry(builder: (_) => const SizedBox.shrink());
    overlay.insert(entry);
    await tester.pump();
    entry.remove();
    expect(entry.remove, throwsA(anything));
  });
}
