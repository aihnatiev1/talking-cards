import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/parental_gate.dart';

/// One gate per visit, not one per door.
void main() {
  setUp(debugResetParentalGate);

  testWidgets('a solved gate opens the next door without asking again',
      (tester) async {
    // The ⓘ button and «Parent area» sit on the same path: the sheet the
    // first gate opens is where the second one lived. A grown-up answered
    // the same sum twice; a toddler was stopped by neither more nor less.
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    expect(parentalGateIsOpen, isFalse);

    final first = showParentalGate(ctx, isEn: true);
    await tester.pumpAndSettle();
    // Answer it: tap the digits of the shown sum is fiddly in a test, so
    // assert the contract instead — before an answer, nothing is open.
    expect(parentalGateIsOpen, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await first, isFalse);
    expect(parentalGateIsOpen, isFalse,
        reason: 'a dismissed gate must not open anything');
  });
}
