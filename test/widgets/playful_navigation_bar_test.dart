import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/playful_navigation_bar.dart';

void main() {
  for (final width in [280.0, 390.0, 844.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('navigation fits width $width and text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 600),
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(bottom: 34),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  bottomNavigationBar: PlayfulNavigationBar(
                    selectedIndex: selected,
                    onSelected: (i) => setState(() => selected = i),
                    isEn: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          final target = find.byKey(ValueKey('main-tab-$i'));
          final rect = tester.getRect(target);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.bottom, lessThanOrEqualTo(566));
          expect(rect.height, greaterThanOrEqualTo(72));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected, i);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('preview all selected states', (tester) async {
    tester.view.physicalSize = const Size(390, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
    await tester.runAsync(font.load);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('preview'),
          child: Scaffold(
            backgroundColor: const Color(0xFFF1ECE5),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 3; i++)
                  PlayfulNavigationBar(
                    selectedIndex: i,
                    onSelected: (_) {},
                    isEn: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('NAV_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/playful-navigation-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
