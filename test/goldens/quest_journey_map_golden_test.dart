import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/widgets/quest_journey_map.dart';

import '../helpers/motion.dart';

/// The daily-quest route at phone size in three moments: nothing done,
/// two stops done (the third one active and glowing), everything done with
/// the treasure open. `QuestJourneyMap` takes a plain `DailyQuestState`,
/// so no provider or clock is involved; the active stop's hop is an
/// `AmbientLoop` and rests under `useTestMotion()`.
void main() {
  useTestMotion();

  const size = Size(390, 844);

  Widget map(DailyQuestState quest) => SafeArea(
        child: QuestJourneyMap(
          quest: quest,
          isEn: false,
          onStopTap: (_) {},
          onClaimTreasure: () {},
        ),
      );

  group('QuestJourneyMap', () {
    testWidgets('fresh day — first stop active', (tester) async {
      await pumpGolden(tester, map(const DailyQuestState(date: 'test')),
          size: size);
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/quest_journey_map_fresh.png'),
      );
    });

    testWidgets('two stops done — third active', (tester) async {
      await pumpGolden(
        tester,
        map(const DailyQuestState(
          date: 'test',
          completed: {QuestTask.listenCardOfDay, QuestTask.viewCards3},
        )),
        size: size,
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/quest_journey_map_midway.png'),
      );
    });

    testWidgets('all done — treasure ready to open', (tester) async {
      await pumpGolden(
        tester,
        map(DailyQuestState(
          date: 'test',
          completed: QuestTask.values.take(5).toSet(),
        )),
        size: size,
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/quest_journey_map_done.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}
