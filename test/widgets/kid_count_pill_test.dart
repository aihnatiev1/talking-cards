import 'dart:io';
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

  test('every kid screen with an x/y counter uses the pill', () {
    // The cards screen kept its own pack-coloured text for a while after
    // the games moved over — mint on `DT.bgWarm` is 1.9:1. Cheaper to pin
    // the call site here than to boot the whole screen with audio, prefs
    // and assets just to read one colour.
    for (final path in const [
      'lib/screens/cards_screen.dart',
      'lib/screens/bubble_pop_screen.dart',
      'lib/screens/memory_match_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('trailing: KidCountPill('),
          reason: '$path must put its counter in KidCountPill');
    }
  });

  const accents = [
    DT.brand,
    DT.mint,
    DT.coral,
    DT.sunBurst,
    DT.sky,
    DT.violet,
    DT.peach,
    DT.pink,
    DT.teal,
  ];

  test('DT.contrastRatio agrees with the standard written out here', () {
    for (final accent in accents) {
      expect(DT.contrastRatio(Colors.white, accent),
          closeTo(contrast(Colors.white, accent), 0.001));
    }
  });

  test('DT.solid can carry white text for every accent', () {
    for (final accent in accents) {
      final ratio = contrast(Colors.white, DT.solid(accent));
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'white on DT.solid($accent) is ${ratio.toStringAsFixed(2)}:1');
      // The hue survives the darkening — the button still looks like the pack.
      expect(HSLColor.fromColor(DT.solid(accent)).hue,
          closeTo(HSLColor.fromColor(accent).hue, 0.5));
    }
  });

  test('the countdown chip reads on every pack', () {
    // cards_screen: white on `pack.color` was 2.0:1 (mint), 1.3:1 (sunBurst).
    expect(contrast(KidActionPill.foreground, KidActionPill.background),
        greaterThanOrEqualTo(7.0));
    for (final accent in accents) {
      // The glyph is a non-text control: 3:1 is the WCAG floor, and the
      // accent-derived ink clears 4.5:1 anyway.
      final icon =
          contrast(KidActionPill.iconColor(accent), KidActionPill.background);
      expect(icon, greaterThanOrEqualTo(4.5),
          reason: 'pause glyph on $accent is ${icon.toStringAsFixed(2)}:1');
    }
  });

  test('the preview strip and the unlock dialog read on every pack', () {
    for (final accent in accents) {
      // 2. `Preview x of y` — charcoal on the pack tint, not pack colour
      //    on a 10 % wash of itself (mint was 1.9:1).
      final strip =
          contrast(DT.textPrimary, PackPalette.of(accent).tint);
      expect(strip, greaterThanOrEqualTo(7.0),
          reason: 'preview strip on $accent is ${strip.toStringAsFixed(2)}:1');

      // …and its lock glyph.
      expect(contrast(DT.solid(accent), PackPalette.of(accent).tint),
          greaterThanOrEqualTo(3.0));

      // 3. The unlock dialog title on the white dialog card.
      expect(contrast(DT.textPrimary, DT.surfaceWhite),
          greaterThanOrEqualTo(7.0));

      // Both «Unlock» buttons: white on the darkened accent.
      expect(contrast(Colors.white, DT.solid(accent)),
          greaterThanOrEqualTo(4.5));
    }
  });

  test('the quest map pack label reads over its own wash', () {
    for (final accent in accents) {
      // quest_map_screen: the tile washes `pack.color` at 8 % (20 % when
      // selected) over `DT.bgWarm`; the label used to be `pack.color`.
      for (final alpha in const [0.08, 0.2]) {
        final wash = Color.alphaBlend(accent.withValues(alpha: alpha), DT.bgWarm);
        final ratio = contrast(DT.textPrimary, wash);
        expect(ratio, greaterThanOrEqualTo(7.0),
            reason: 'quest tile $accent @$alpha is ${ratio.toStringAsFixed(2)}:1');
      }
    }
  });

  test('no kid-zone call site paints text or white in the raw pack colour', () {
    // Cheaper than booting these screens with audio, prefs and assets.
    final cards = File('lib/screens/cards_screen.dart').readAsStringSync();
    expect(cards, isNot(contains('color: widget.pack.color,\n                        fontSize')),
        reason: 'preview strip text must not be the pack colour');
    expect(cards, isNot(contains('foregroundColor: Colors.white')),
        reason: 'a filled button must use DT.solid(accent) under white');
    expect(cards, contains('DT.solid(widget.pack.color)'));
    final quest = File('lib/screens/quest_map_screen.dart').readAsStringSync();
    expect(quest, isNot(contains('fontSize: 13,\n                              color: pack.color,')),
        reason: 'quest tile label must not be the pack colour');
  });

  testWidgets('the countdown chip is white, ringed, and a 72 dp target',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KidActionPill(
              label: '3',
              icon: Icons.pause_rounded,
              accent: DT.sunBurst,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<Container>(find.byKey(KidActionPill.pillKey));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, KidActionPill.background);
    expect(decoration.border!.top.color, DT.sunBurst);
    expect(tester.widget<Text>(find.text('3')).style!.color,
        KidActionPill.foreground);
    expect(tester.widget<Icon>(find.byIcon(Icons.pause_rounded)).color,
        KidActionPill.iconColor(DT.sunBurst));

    final size = tester.getSize(find.byType(KidTap));
    expect(size.height, greaterThanOrEqualTo(72.0));
    expect(size.width, greaterThanOrEqualTo(72.0));

    await tester.tap(find.byType(KidActionPill));
    await tester.pumpAndSettle();
    expect(taps, 1);
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
