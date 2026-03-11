import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/favorites_provider.dart';

void main() {
  group('FavoritesNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () async {
      final notifier = FavoritesNotifier();
      // Allow async _load to complete
      await Future.delayed(Duration.zero);
      expect(notifier.debugState, isEmpty);
    });

    test('toggle adds card to favorites', () async {
      final notifier = FavoritesNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle('card_1');

      expect(notifier.debugState, contains('card_1'));
      expect(notifier.isFavorite('card_1'), true);
    });

    test('toggle removes card if already favorite', () async {
      final notifier = FavoritesNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle('card_1');
      expect(notifier.isFavorite('card_1'), true);

      await notifier.toggle('card_1');
      expect(notifier.isFavorite('card_1'), false);
    });

    test('multiple cards can be favorited', () async {
      final notifier = FavoritesNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle('card_1');
      await notifier.toggle('card_2');
      await notifier.toggle('card_3');

      expect(notifier.debugState.length, 3);
      expect(notifier.isFavorite('card_1'), true);
      expect(notifier.isFavorite('card_2'), true);
      expect(notifier.isFavorite('card_3'), true);
    });

    test('persists to SharedPreferences', () async {
      final notifier = FavoritesNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle('card_1');
      await notifier.toggle('card_2');

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('favorite_cards');
      expect(saved, isNotNull);
      expect(saved!.toSet(), {'card_1', 'card_2'});
    });

    test('loads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_cards': ['card_a', 'card_b'],
      });

      final notifier = FavoritesNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.isFavorite('card_a'), true);
      expect(notifier.isFavorite('card_b'), true);
      expect(notifier.debugState.length, 2);
    });
  });
}
