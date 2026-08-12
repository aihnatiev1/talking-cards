import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/profile_service.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(),
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _load();
  }

  static const _key = 'favorite_cards';
  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefixedKey) ?? [];
    state = list.toSet();
  }

  Future<void> toggle(String cardId) async {
    final updated = {...state};
    final added = !updated.contains(cardId);
    if (added) {
      updated.add(cardId);
    } else {
      updated.remove(cardId);
    }
    AnalyticsService.instance.logFavoriteToggle(cardId, added);
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefixedKey, state.toList());
  }

  bool isFavorite(String cardId) => state.contains(cardId);
}
