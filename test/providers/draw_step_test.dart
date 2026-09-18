import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';

/// Drawing is part of the day, but not one of the five steps: the promise
/// is five steps and about five minutes, and the adventure map is drawn
/// with exactly five stops and a chest.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<DailyQuestNotifier> quest(ProviderContainer c) async {
    final n = c.read(dailyQuestProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return n;
  }

  test('one drawing is enough to count, and it counts only once', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = await quest(c);

    await n.recordDrawing();
    await n.recordDrawing();

    expect(
      c.read(dailyQuestProvider).completed.contains(QuestTask.drawPicture),
      isTrue,
      reason: 'the step is "you drew today", not "you finished a drawing"',
    );
  });

  test('drawing never changes the five, nor blocks the treasure', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = await quest(c);

    expect(c.read(dailyQuestProvider).totalCount, 5);

    await n.recordDrawing();
    expect(c.read(dailyQuestProvider).doneCount, 0,
        reason: 'a bonus task is not one of the five');

    for (final task in [
      QuestTask.listenCardOfDay,
      QuestTask.viewCards3,
      QuestTask.playQuiz,
      QuestTask.viewCards5,
      QuestTask.reviewOldCard,
    ]) {
      await n.completeTask(task);
    }
    expect(c.read(dailyQuestProvider).allDone, isTrue);
  });
}
