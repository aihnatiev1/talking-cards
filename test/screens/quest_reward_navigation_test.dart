import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/bonus_cards_provider.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/providers/language_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/card_reveal_screen.dart';
import 'package:talking_cards/screens/quest_map_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/utils/kid_routes.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  const card = CardModel(
    id: 'cat',
    sound: 'КОТИК',
    text: '',
    emoji: 'cat',
    colorBg: Colors.white,
    colorAccent: Colors.teal,
  );
  const pack = PackModel(
    id: 'reward-pack',
    title: 'Тваринки',
    icon: '',
    color: Colors.teal,
    isLocked: true,
    isFree: false,
    freePreviewCountOverride: 0,
    cards: [card],
  );

  testWidgets('one grant, one reveal, one exit returns home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    final container = ProviderContainer(
      overrides: [
        packsProvider.overrideWith((ref) async => [pack]),
        languageProvider.overrideWithValue('uk'),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(bonusCardsProvider);
      container.read(dailyQuestProvider);
      await Future<void>.delayed(Duration.zero);
      for (final task in QuestTask.values.take(5)) {
        await container.read(dailyQuestProvider.notifier).completeTask(task);
      }
      await container.read(packsProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  KidRoutes.content(
                    QuestMapScreen(
                      cardOfDay: card,
                      cardOfDayLocked: true,
                      onCardOfDayTap: () {},
                    ),
                  ),
                ),
                child: const Text('HOME'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journey-next-5')));
    await tester.pumpAndSettle();
    final choice = find.text('Тваринки');
    await tester.tap(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(container.read(bonusCardsProvider)[pack.id], 1);
    expect(container.read(dailyQuestProvider).rewardClaimed, isTrue);
    expect(find.byType(CardRevealScreen), findsOneWidget);
    await tester.ensureVisible(find.text('На головну'));
    await tester.tap(find.text('На головну'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(CardRevealScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
