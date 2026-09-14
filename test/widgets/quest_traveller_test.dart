import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/quest_journey_map.dart';

import '../helpers/motion.dart';

/// Bloom is the traveller on the quest map (ux-gap-audit G13): he stands on
/// the stop the child is on, and walks the trail to the next one when it is
/// finished. The test asks the only question that matters at the layout
/// level — *which stop is he standing at* — by comparing his position with
/// the six stop rects, so the exact offset beside the plate stays free to
/// change.
void main() {
  useTestMotion();

  const size = Size(390, 844);

  Future<void> show(WidgetTester tester, Set<QuestTask> completed) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: Scaffold(
            body: SafeArea(
              child: QuestJourneyMap(
                quest: DailyQuestState(date: 'test', completed: completed),
                isEn: false,
                onStopTap: (_) {},
                onClaimTreasure: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Index of the stop whose plate Bloom is closest to.
  int stopUnderBloom(WidgetTester tester) {
    final bloom = tester.getRect(find.byType(BloomMascot)).center;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < 6; i++) {
      final stop = tester.getRect(find.byKey(ValueKey('journey-stop-$i')));
      // The plate is the top 80 dp of the stop box; the label below it
      // would drag the centre away from where Bloom stands.
      final plate = Offset(stop.center.dx, stop.top + 40);
      final d = (plate - bloom).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  testWidgets('stands on the first unfinished stop', (tester) async {
    await show(tester, {});
    expect(stopUnderBloom(tester), 0);

    await show(tester, {QuestTask.listenCardOfDay, QuestTask.viewCards3});
    expect(stopUnderBloom(tester), 2);
  });

  testWidgets('walks to the treasure once every stop is done',
      (tester) async {
    await show(tester, QuestTask.values.take(5).toSet());
    expect(stopUnderBloom(tester), 5);
  });

  testWidgets('a finished step moves him on, and settles', (tester) async {
    await show(tester, {});
    expect(stopUnderBloom(tester), 0);

    // Same tree, new quest state: the widget updates instead of remounting,
    // which is what triggers the walk.
    await show(tester, {QuestTask.listenCardOfDay});
    // pumpAndSettle inside `show` returned — under MotionMode.test the walk
    // collapses to nothing and Bloom simply appears at the next stop.
    expect(stopUnderBloom(tester), 1);
  });

  testWidgets('under full motion the walk takes DT.motion.journeyStep',
      (tester) async {
    MotionPolicy.debugOverride = MotionMode.full;
    addTearDown(() => MotionPolicy.debugOverride = MotionMode.test);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget map(Set<QuestTask> completed) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: size),
            child: Scaffold(
              body: SafeArea(
                child: QuestJourneyMap(
                  quest: DailyQuestState(date: 'test', completed: completed),
                  isEn: false,
                  onStopTap: (_) {},
                  onClaimTreasure: () {},
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(map({}));
    await tester.pump();
    expect(stopUnderBloom(tester), 0);

    await tester.pumpWidget(map({QuestTask.listenCardOfDay}));
    await tester.pump();
    // Mid-walk he is somewhere on the trail, not yet parked on stop 1…
    await tester.pump(const Duration(milliseconds: 100));
    // …and the walk finishes on its own. Pumped by hand, not settled: the
    // pressable stop breathes forever under full motion (that endless
    // pulse is the map's "press here"), so `pumpAndSettle` never returns.
    await tester.pump(DT.motion.journeyStep);
    await tester.pump(const Duration(milliseconds: 32));
    expect(stopUnderBloom(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
