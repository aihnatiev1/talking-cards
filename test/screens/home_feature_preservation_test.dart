import 'package:talking_cards/widgets/play_components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/tabs/games_tab.dart';
import 'package:talking_cards/screens/quest_map_screen.dart';
import 'package:talking_cards/widgets/quest_journey_map.dart';
import 'package:talking_cards/screens/coloring_hub_screen.dart';
import 'package:talking_cards/screens/kid_word_wall_screen.dart';
import 'package:talking_cards/screens/cards_screen.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/providers/home_tab_provider.dart';
import 'package:talking_cards/providers/last_pack_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/favorites_provider.dart';
import 'package:talking_cards/providers/review_provider.dart';
import 'package:talking_cards/providers/streak_provider.dart';
import 'package:talking_cards/providers/card_of_day_provider.dart';
import 'play_experience_test.dart' show host, settle, tapText;

void main() {
  testWidgets(
    'packs and shortcuts survive when lesson topics are unavailable',
    (tester) async {
      await host(tester, omitAnimalLessons: true);
      expect(
        find.byKey(const ValueKey('home-games')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Розмовлялки'));
      await settle(tester);
      expect(
        tester.widget<CardsScreen>(find.byType(CardsScreen)).pack.id,
        'rozmovlyalky',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new streak milestone is celebrated once on the home screen', (
    tester,
  ) async {
    final container = await host(tester);
    container.read(streakProvider.notifier).state = const StreakState(
      currentStreak: 3,
      unlockedRewards: {'🦄'},
    );
    await settle(tester);
    expect(find.text('Серія 3 дні!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final done = find.text('Так тримати!');
    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
    await settle(tester);
    expect(container.read(streakProvider).celebratedRewards, contains('🦄'));
    expect(find.text('Серія 3 дні!'), findsNothing);
    await settle(tester);
    expect(find.text('Серія 3 дні!'), findsNothing);
  });

  for (final destination in ['game', 'cards']) {
    testWidgets('streak celebration waits until returning from $destination', (
      tester,
    ) async {
      final container = await host(tester);
      if (destination == 'game') {
        await tester.tap(find.byKey(const ValueKey('home-games')));
      } else {
        container.read(homeDestinationProvider.notifier).state =
            HomeDestination.cards;
      }
      await settle(tester);
      container.read(streakProvider.notifier).state = const StreakState(
        currentStreak: 3,
        unlockedRewards: {'🦄'},
      );
      await settle(tester);
      expect(find.text('Серія 3 дні!'), findsNothing);
      expect(container.read(streakProvider).celebratedRewards, isEmpty);
      if (destination == 'game') {
        Navigator.of(tester.element(find.byType(GamesTab))).pop();
      } else {
        container.read(homeDestinationProvider.notifier).state =
            HomeDestination.play;
      }
      await settle(tester);
      await settle(tester);
      expect(find.text('Серія 3 дні!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Так тримати!'));
      await settle(tester);
      expect(container.read(streakProvider).celebratedRewards, contains('🦄'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'daily repeat returns to the map, celebrates the stop and ignores double taps',
    (tester) async {
      final container = await host(tester);
      for (final task in [
        QuestTask.listenCardOfDay,
        QuestTask.viewCards3,
        QuestTask.playQuiz,
        QuestTask.viewCards5,
      ]) {
        await container.read(dailyQuestProvider.notifier).completeTask(task);
      }
      await tester.tap(find.byKey(const ValueKey('home-daily-quest')));
      await settle(tester);
      final next = find.byKey(const ValueKey('journey-next-4'));
      await tester.tap(next);
      await tester.tap(next);
      await settle(tester);
      expect(find.byType(CardsScreen, skipOffstage: false), findsOneWidget);
      Navigator.of(tester.element(find.byType(CardsScreen))).pop();
      await settle(tester);
      expect(find.byType(QuestMapScreen), findsOneWidget);
      expect(container.read(dailyQuestProvider).allDone, isTrue);
      expect(
        tester
            .widget<QuestJourneyMap>(find.byType(QuestJourneyMap))
            .justCompleted,
        QuestTask.reviewOldCard,
      );
      expect(find.byKey(const ValueKey('journey-next-5')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Draw and Treasures moved to «My world» (the Play tab now keeps the lesson,
  // the card of the day, Games and the card packs); Games stays one tap away.
  for (final entry in [('games', GamesTab)]) {
    testWidgets('${entry.$1} opens directly from home and returns', (
      tester,
    ) async {
      await host(tester);
      final button = find.byKey(ValueKey('home-${entry.$1}'));
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await settle(tester);
      expect(find.byType(entry.$2), findsOneWidget);
      Navigator.of(tester.element(find.byType(entry.$2))).pop();
      await settle(tester);
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in [
    ('Малювати', ColoringHubScreen),
    ('Мої скарби', KidWordWallScreen),
  ]) {
    testWidgets('${entry.$1} opens from My world and returns', (tester) async {
      await host(tester);
      await tester.tap(find.text('Мій світ'));
      await settle(tester);
      final button = find.text(entry.$1);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await settle(tester);
      expect(find.byType(entry.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'profile selector opens directly, without going through settings',
    (tester) async {
      await host(tester);
      await tester.tap(find.byKey(const ValueKey('home-profiles')));
      await settle(tester);
      expect(find.text('Профілі').hitTestable(), findsWidgets);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily card completes listening and retains its favorite action',
    (tester) async {
      final container = await host(tester);
      final card = container
          .read(cardOfDaySelectorProvider)(
            container.read(packsProvider).requireValue,
          )!
          .$1;
      await tester.tap(find.byKey(const ValueKey('home-card-of-day')));
      await settle(tester);
      expect(
        container.read(dailyQuestProvider).completed,
        contains(QuestTask.listenCardOfDay),
      );
      await tester.longPress(find.byKey(const ValueKey('home-card-of-day')));
      await settle(tester);
      await tapText(tester, 'Додати в улюблені');
      expect(container.read(favoritesProvider), contains(card.id));
    },
  );

  testWidgets('continue opens the saved pack without resetting progress', (
    tester,
  ) async {
    final container = await host(tester);
    await container
        .read(packProgressProvider.notifier)
        .updateProgress('animals', 3);
    await container.read(lastOpenedPackProvider.notifier).record('animals');
    await settle(tester);
    final button = find.byKey(const ValueKey('home-continue-pack'));
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester);
    expect(
      tester.widget<CardsScreen>(find.byType(CardsScreen)).pack.id,
      'animals',
    );
    expect(
      container.read(packProgressProvider)['animals'],
      greaterThanOrEqualTo(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'favorites, review and streak collections remain direct entries',
    (tester) async {
      final container = await host(tester);
      final cards = container
          .read(packsProvider)
          .requireValue
          .first
          .cards
          .take(6)
          .toList();
      await container.read(favoritesProvider.notifier).toggle(cards.first.id);
      container.read(streakProvider.notifier).state = const StreakState(
        currentStreak: 3,
      );
      await settle(tester);
      // One slot: cards due for review take it, else the favorites do.
      for (final id in ['favorites', 'review']) {
        // Existing review data, as restored for a returning profile.
        container.read(reviewProvider.notifier).state = id == 'review'
            ? {for (final c in cards) c.id: '2020-01-01'}
            : <String, String>{};
        await settle(tester);
        final button = find.byKey(ValueKey('home-$id'));
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await settle(tester);
        if (id == 'stickers') {
          expect(
            tester
                .widget<KidWordWallScreen>(find.byType(KidWordWallScreen))
                .initialTab,
            TreasureTab.stickers,
          );
          Navigator.of(tester.element(find.byType(KidWordWallScreen))).pop();
        } else {
          expect(
            tester.widget<CardsScreen>(find.byType(CardsScreen)).pack.id,
            '_$id',
          );
          Navigator.of(tester.element(find.byType(CardsScreen))).pop();
        }
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
