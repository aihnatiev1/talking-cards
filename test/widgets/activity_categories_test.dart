import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/widgets/activity_categories.dart';
import 'package:talking_cards/widgets/pack_grid_card.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  for (final width in [280.0, 390.0, 834.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('readable categories $width at text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? picked;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: ActivityCategories(
                  labels: const ['Speaking', 'Sounds', 'World'],
                  selected: 'Speaking',
                  onSelected: (label) => picked = label,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('World'));
        await tester.tap(find.text('World'));
        await tester.pumpAndSettle();
        expect(picked, 'World');
        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(find.text('World')).style?.fontSize, 14);
      });
    }
  }

  testWidgets('catalogue with actual Ukrainian artwork', (tester) async {
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    final packs = await tester.runAsync(() async {
      final data =
          jsonDecode(await rootBundle.loadString('assets/data/uk_cards.json'))
              as List;
      return data
          .map((item) => PackModel.fromJson(item as Map<String, dynamic>))
          .take(4)
          .toList();
    });
    await pumpGolden(
      tester,
      Column(
        children: [
          ActivityCategories(
            labels: const ['Мовлення', 'Звуки', 'Світ'],
            selected: 'Мовлення',
            onSelected: (_) {},
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid(
                      gridDelegate: PackGridCard.gridDelegate(
                        context,
                        constraints.crossAxisExtent,
                        packs!.map((p) => p.title),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => PackGridCard(
                          pack: packs[index],
                          progress: index == 0 ? 3 : 0,
                          onTap: () {},
                        ),
                        childCount: packs.length,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      wrap: (host) => ProviderScope(child: host),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('../goldens/images/catalogue_shelf.png'),
    );
  }, skip: !Platform.isMacOS);
}
