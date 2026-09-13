import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/kid_screen.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

/// The header counter, pinned by arithmetic rather than by eye.
///
/// Rule 5 of CLAUDE.md asks for WCAG AAA where it is reachable. The pill
/// used to be white on the accent: `DT.brand` measured 4.3:1 and a mint
/// pack 2.0:1 — the second is below AA. Dark text on white makes the
/// figure independent of the pack: 11.7:1 for every one of them.
void main() {
  /// WCAG 2.x relative luminance, written out instead of leaning on
  /// `Color.computeLuminance`, so the number this test defends is the
  /// number in the standard.
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('the pill clears AAA on every pack accent', () {
    final ratio = contrast(KidCountPill.foreground, KidCountPill.background);
    expect(ratio, greaterThanOrEqualTo(7.0),
        reason: 'counter pill is ${ratio.toStringAsFixed(2)}:1');

    // The ring carries the pack colour and is never asked to carry text,
    // so no accent can drag the pair down.
    for (final accent in const [
      DT.brand,
      DT.mint,
      DT.coral,
      DT.sunBurst,
      DT.sky,
      DT.violet,
      DT.peach,
      DT.pink,
      DT.teal,
    ]) {
      expect(contrast(KidCountPill.foreground, KidCountPill.background),
          greaterThanOrEqualTo(7.0),
          reason: 'accent $accent must not change the text pair');
    }
  });

  test('the old white-on-accent pill is what we moved away from', () {
    // Kept as the record of why: both are under AAA, mint is under AA.
    expect(contrast(Colors.white, DT.brand), lessThan(7.0));
    expect(contrast(Colors.white, DT.mint), lessThan(4.5));
  });

  testWidgets('the pill paints white, rings the accent, reserves 72 dp',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: KidCountPill(label: '3/8', accent: DT.mint)),
        ),
      ),
    );

    final box = tester.widget<Container>(
      find.byKey(KidCountPill.pillKey),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, KidCountPill.background);
    expect(decoration.border!.top.color, DT.mint);
    expect(decoration.border!.top.width, KidCountPill.ringWidth);

    final text = tester.widget<Text>(find.text('3/8'));
    expect(text.style!.color, KidCountPill.foreground);

    // It lives in the trailing slot, which must stay a control's width so
    // the title in the middle does not shift as the count changes.
    expect(tester.getSize(find.byType(KidCountPill)).width,
        greaterThanOrEqualTo(72.0));
  });

  testWidgets('a game header gives back/close the full 72 dp hit zone',
      (tester) async {
    for (final screen in <Widget>[
      const KidScreen(body: SizedBox.shrink(), accent: DT.mint),
      const KidScreen.game(body: SizedBox.shrink(), accent: DT.mint),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      final size = tester.getSize(find.byType(KidTap).first);
      expect(size.width, greaterThanOrEqualTo(72.0));
      expect(size.height, greaterThanOrEqualTo(72.0));
    }
  });
}
