import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/widgets/daily_hero_card.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  for (final width in [280.0, 390.0, 700.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('hero fits $width at text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        AssetPackService.instance.debugConfigure(
          padAssets: const {},
          bundled: true,
        );
        var taps = 0;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1100),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DailyHeroCard(
                        title: 'Протилежності та знайомі слова',
                        accent: Colors.purple,
                        onHeroTap: () => taps++,
                        isEn: false,
                        progress: .2,
                        mascot: const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(Icons.face, size: 60),
                        ),
                        tasks: [
                          DailyTask(
                            icon: AppIcon.stepCards,
                            label: 'Послухай картку дня',
                            isDone: true,
                            isActive: false,
                            onTap: () {},
                          ),
                          DailyTask(
                            icon: AppIcon.stepQuest,
                            label: 'Продовжити пригоду',
                            isDone: false,
                            isActive: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final a = tester.getRect(find.byKey(const ValueKey('daily_task_0')));
        final b = tester.getRect(find.byKey(const ValueKey('daily_task_1')));
        expect(a.overlaps(b), isFalse);
        expect(a.left, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(width));
        await tester.tap(find.text('Протилежності та знайомі слова'));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    }
  }

  // Found on an iPhone 16e at iOS XXL (2026-09-29): three columns at ×1.3
  // split «Adventure» into «Adventur / e». No word of a label may break.
  for (final scale in [1.0, 1.3]) {
    testWidgets('no step label breaks inside a word at 390 × $scale',
        (tester) async {
      const width = 390.0;
      tester.view.physicalSize = const Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
      DailyTask task(String label, AppIcon icon) => DailyTask(
            icon: icon,
            label: label,
            isDone: false,
            isActive: false,
            onTap: () {},
          );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(width, 1100),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DailyHeroCard(
                      title: 'BRUSH',
                      accent: Colors.purple,
                      onHeroTap: () {},
                      isEn: true,
                      progress: 0,
                      mascot: const SizedBox(width: 72, height: 72),
                      tasks: [
                        task("Today's Pack", AppIcon.stepCards),
                        task('Adventure', AppIcon.stepQuest),
                        task('Draw', AppIcon.stepCards),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final word in ["Today's", 'Pack', 'Adventure', 'Draw']) {
        final text = find.textContaining(word == "Today's" || word == 'Pack'
            ? "Today's Pack"
            : word);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final label = paragraph.text.toPlainText();
        final start = label.indexOf(word);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
        );
        final lines = boxes.map((b) => b.top.round()).toSet();
        expect(lines, hasLength(1),
            reason: '«$word» breaks across lines at ×$scale');
      }
    });
  }
}
