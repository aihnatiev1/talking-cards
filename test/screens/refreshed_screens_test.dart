import 'dart:io';
import 'dart:convert';
import 'package:talking_cards/models/pack_model.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/parent_dashboard_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/tabs/games_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
  });
  for (final screen in ['games', 'parent']) {
    for (final width in [320.0, 390.0, 834.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$screen $width text $scale', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final font = FontLoader('Nunito')
            ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
          await tester.runAsync(font.load);
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await tester.runAsync(icons.load);
          final catalogue = await tester.runAsync(() async {
            final json = jsonDecode(await rootBundle.loadString('assets/data/uk_cards.json')) as List;
            return json.map((item) => PackModel.fromJson(item as Map<String, dynamic>)).toList();
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                packsProvider.overrideWith((ref) async => catalogue!),
              ],
              child: MaterialApp(
                theme: ThemeData(fontFamily: 'Nunito'),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: screen == 'games'
                        ? const GamesTab()
                        : const ParentDashboardScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('SCREEN_PREVIEW') &&
              width == 390 &&
              scale == 1) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/refreshed-$screen.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
