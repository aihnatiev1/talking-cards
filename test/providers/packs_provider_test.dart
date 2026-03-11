import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/packs_provider.dart';

void main() {
  group('CompletedPacksNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () async {
      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.debugState, isEmpty);
    });

    test('markCompleted adds pack id', () async {
      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markCompleted('animals');

      expect(notifier.debugState, contains('animals'));
    });

    test('markCompleted ignores virtual packs (starting with _)', () async {
      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markCompleted('_favorites');

      expect(notifier.debugState, isEmpty);
    });

    test('markCompleted persists to SharedPreferences', () async {
      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markCompleted('animals');
      await notifier.markCompleted('transport');

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('completed_packs');
      expect(saved!.toSet(), {'animals', 'transport'});
    });

    test('loads existing data', () async {
      SharedPreferences.setMockInitialValues({
        'completed_packs': ['pack_1', 'pack_2'],
      });

      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState, {'pack_1', 'pack_2'});
    });

    test('cleans virtual packs from saved data on load', () async {
      SharedPreferences.setMockInitialValues({
        'completed_packs': ['pack_1', '_favorites', '_review'],
      });

      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState, {'pack_1'});

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('completed_packs');
      expect(saved, ['pack_1']);
    });

    test('duplicate markCompleted does not add twice', () async {
      final notifier = CompletedPacksNotifier();
      await Future.delayed(Duration.zero);

      await notifier.markCompleted('animals');
      await notifier.markCompleted('animals');

      expect(notifier.debugState.length, 1);
    });
  });

  group('PackProgressNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () async {
      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.debugState, isEmpty);
    });

    test('updateProgress records max index', () async {
      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      await notifier.updateProgress('pack_1', 3);

      expect(notifier.debugState['pack_1'], 4); // cardIndex + 1
    });

    test('updateProgress only updates if new index is higher', () async {
      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      await notifier.updateProgress('pack_1', 5);
      await notifier.updateProgress('pack_1', 3); // lower — should not update

      expect(notifier.debugState['pack_1'], 6); // 5 + 1 = 6
    });

    test('updateProgress ignores virtual packs', () async {
      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      await notifier.updateProgress('_favorites', 5);

      expect(notifier.debugState, isEmpty);
    });

    test('persists progress', () async {
      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      await notifier.updateProgress('animals', 9);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('pack_progress_animals'), 10);
    });

    test('loads existing progress', () async {
      SharedPreferences.setMockInitialValues({
        'pack_progress_animals': 5,
        'pack_progress_transport': 12,
      });

      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState['animals'], 5);
      expect(notifier.debugState['transport'], 12);
    });

    test('cleans virtual pack progress on load', () async {
      SharedPreferences.setMockInitialValues({
        'pack_progress_animals': 5,
        'pack_progress__favorites': 10,
      });

      final notifier = PackProgressNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState.containsKey('_favorites'), false);
      expect(notifier.debugState['animals'], 5);
    });
  });
}
