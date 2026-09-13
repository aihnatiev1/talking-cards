import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/widgets/quest_journey_map.dart';

void main() {
  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(844, 390),
    Size(834, 1194),
    Size(1194, 834),
    Size(280, 600),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('route fits $size, text $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SafeArea(
                  child: QuestJourneyMap(
                    quest: const DailyQuestState(date: 'test'),
                    isEn: false,
                    onStopTap: (_) {},
                    onClaimTreasure: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        final rects = [
          for (var i = 0; i < 6; i++)
            tester.getRect(find.byKey(ValueKey('journey-stop-$i'))),
        ];
        for (var i = 0; i < 6; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(0));
          expect(rects[i].right, lessThanOrEqualTo(size.width));
          for (var j = i + 1; j < 6; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('journey-stop-5')),
        );
        await tester.pump();
        final treasure = tester.getRect(
          find.byKey(const ValueKey('journey-stop-5')),
        );
        expect(treasure.bottom, lessThanOrEqualTo(size.height + 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('stop actions, reward gating, reduced motion and preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
    await tester.runAsync(() => loader.load());
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(() => icons.load());
    QuestTask? tapped;
    var claims = 0;
    Future<void> show(Set<QuestTask> completed) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('preview'),
              child: Scaffold(
                backgroundColor: const Color(0xFFEAF7F1),
                appBar: AppBar(
                  backgroundColor: const Color(0xFFEAF7F1),
                  title: const Text('Пригода дня'),
                  centerTitle: true,
                ),
                body: QuestJourneyMap(
                  quest: DailyQuestState(date: 'test', completed: completed),
                  isEn: false,
                  onStopTap: (t) => tapped = t,
                  onClaimTreasure: () => claims++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show({});
    await tester.tap(find.byKey(const ValueKey('journey-stop-0')));
    expect(tapped, QuestTask.listenCardOfDay);
    await tester.ensureVisible(find.byKey(const ValueKey('journey-stop-5')));
    await tester.tap(find.byKey(const ValueKey('journey-stop-5')));
    expect(claims, 0);
    await show(QuestTask.values.take(5).toSet());
    await tester.ensureVisible(find.byKey(const ValueKey('journey-stop-5')));
    await tester.tap(find.byKey(const ValueKey('journey-stop-5')));
    expect(claims, 1);
    await show({QuestTask.listenCardOfDay});
    await tester.drag(
      find.byKey(const ValueKey('journey-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('QUEST_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/quest-journey-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}
