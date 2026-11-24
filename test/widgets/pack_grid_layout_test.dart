import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/widgets/pack_grid_card.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  for (final width in [280.0, 390.0, 834.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('catalog fits $width at text scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        AssetPackService.instance.debugConfigure(
          padAssets: const {},
          bundled: true,
        );
        final packs = [
          for (var i = 0; i < 3; i++)
            PackModel(
              id: 'pack-$i',
              title: [
                'Протилежності',
                'Тварини та їхні маленькі дитинчата',
                'Actions and everyday activities',
              ][i],
              icon: '',
              color: Colors.teal,
              isLocked: false,
              isFree: true,
              cards: const [],
            ),
        ];
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) => SliverGrid(
                            gridDelegate: PackGridCard.gridDelegate(
                              context,
                              constraints.crossAxisExtent,
                              packs.map((p) => p.title),
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => PackGridCard(
                                key: ValueKey(packs[index].id),
                                pack: packs[index],
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
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final pack in packs) {
          await tester.ensureVisible(find.byKey(ValueKey(pack.id)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final tile = tester.getRect(find.byKey(ValueKey(pack.id)));
          final title = tester.getRect(find.text(pack.title));
          expect(title.left, greaterThanOrEqualTo(tile.left));
          expect(title.right, lessThanOrEqualTo(tile.right));
          expect(title.bottom, lessThanOrEqualTo(tile.bottom));
        }
      });
    }
  }
}
