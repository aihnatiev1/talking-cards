import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(),
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _load();
  }

  static const _key = 'favorite_cards';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = list.toSet();
  }

  Future<void> toggle(String cardId) async {
    final updated = {...state};
    if (updated.contains(cardId)) {
      updated.remove(cardId);
    } else {
      updated.add(cardId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  bool isFavorite(String cardId) => state.contains(cardId);
}
