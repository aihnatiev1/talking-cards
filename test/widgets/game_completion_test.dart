import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/kid_routes.dart';
import 'package:talking_cards/widgets/celebration.dart';
import 'package:talking_cards/widgets/game_celebration_overlay.dart';
import 'package:talking_cards/widgets/kid_screen.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugResetKidOverlayQueue();
    FeedbackService.debugMute = true;
  });
  tearDown(() => FeedbackService.debugMute = false);

  for (final action in ['continue', 'system back', 'again']) {
    testWidgets('$action leaves the finished game in a useful state', (
      tester,
    ) async {
      var repeats = 0;
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('ADVENTURE'),
                onPressed: () => Navigator.of(context).push(
                  KidRoutes.game(
                    Scaffold(
                      body: Builder(
                        builder: (gameContext) => TextButton(
                          child: const Text('FINISH'),
                          onPressed: () => showGameCelebration(
                            gameContext,
                            isEn: false,
                            returnToAdventure: true,
                            onAgain: () => repeats++,
                            onDone: () {
                              exits++;
                              Navigator.of(gameContext).pop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ADVENTURE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      expect(find.text('До пригоди'), findsOneWidget);
      if (action == 'system back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(
          find.text(action == 'continue' ? 'До пригоди' : 'Ще раз'),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(Celebration), findsNothing);
      if (action == 'again') {
        expect(repeats, 1);
        expect(exits, 0);
        expect(find.text('FINISH'), findsOneWidget);
      } else {
        expect(exits, 1);
        expect(repeats, 0);
        expect(find.text('ADVENTURE'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final tier in CelebrationTier.values) {
    testWidgets('$tier fits narrow screen with large text', (tester) async {
      tester.view.physicalSize = const Size(280, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Celebration(
              tier: tier,
              isEn: false,
              childName: 'Олександра',
              packTitle: 'Протилежності',
              onAgain: () {},
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final last = find.text(switch (tier) {
        CelebrationTier.round => 'Готово',
        CelebrationTier.pack => 'На головну',
        CelebrationTier.milestone => 'Так тримати!',
      }).last;
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('adventure completion visual preview', (tester) async {
    await pumpGolden(
      tester,
      Celebration(
        tier: CelebrationTier.round,
        isEn: false,
        childName: 'Соня',
        preferDone: true,
        doneLabel: 'До пригоди',
        subtitle: 'Гру завершено. Пригода триває!',
        onAgain: () {},
        onDone: () {},
      ),
    );
    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('../goldens/images/game_completion_adventure.png'),
    );
  }, skip: !Platform.isMacOS);
}
