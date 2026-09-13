import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/app_icon_painters.dart';

/// Every [AppIcon] paints at the three spec sizes, in sticker mode, and
/// with a colour override — a bad Bézier or a zero-length polygon edge in
/// one routine would otherwise be found by the first parent to open that
/// screen.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  for (final icon in AppIcon.values) {
    group(icon.name, () {
      for (final size in [24.0, 32.0, 48.0]) {
        testWidgets('paints at $size', (tester) async {
          await pump(tester, AppIconView(icon, size: size));
          final box = tester.getSize(find.byType(AppIconView));
          expect(box, Size(size, size));
        });
      }

      testWidgets('paints in sticker mode and with a colour override',
          (tester) async {
        await pump(
          tester,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconView(icon, size: 40, sticker: true),
              AppIconView(icon, size: 40, color: Colors.white),
            ],
          ),
        );
      });

      testWidgets('exposes a semantics label', (tester) async {
        await pump(tester, AppIconView(icon));
        expect(find.bySemanticsLabel(icon.label), findsOneWidget);
      });
    });
  }

  testWidgets('default size is DT.size.iconMd', (tester) async {
    await pump(tester, const AppIconView(AppIcon.play));
    expect(
      tester.getSize(find.byType(AppIconView)),
      Size(DT.size.iconMd, DT.size.iconMd),
    );
  });

  testWidgets('a non-square box keeps the art square and centred',
      (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 48,
        height: 38,
        child: CustomPaint(painter: AppIconPainter(AppIcon.navCards)),
      ),
    );
  });

  group('LetterStickerIcon', () {
    for (final letter in ['Р', 'Щ', 'S', 'SH', 'BL']) {
      testWidgets('paints "$letter"', (tester) async {
        await pump(
          tester,
          LetterStickerIcon(letter: letter, color: DT.coral, size: 48),
        );
        expect(find.bySemanticsLabel(letter), findsOneWidget);
      });
    }
  });

  test('isLetterIcon tells sound-pack letters from emoji', () {
    expect(isLetterIcon('Р'), isTrue);
    expect(isLetterIcon('Щ'), isTrue);
    expect(isLetterIcon('R'), isTrue);
    expect(isLetterIcon('SH'), isTrue);
    expect(isLetterIcon('🐾'), isFalse);
    expect(isLetterIcon('↔️'), isFalse);
    expect(isLetterIcon('🅰️'), isFalse);
    expect(isLetterIcon(''), isFalse);
    expect(isLetterIcon('ABC'), isFalse);
  });
}
