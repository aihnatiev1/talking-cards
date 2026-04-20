import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Tracks how many times each card was answered incorrectly in the quiz.
/// Data is per-profile and persisted across sessions.
final weakWordsProvider =
    StateNotifierProvider<WeakWordsNotifier, Map<String, int>>(
  (ref) => WeakWordsNotifier(),
);

class WeakWordsNotifier extends StateNotifier<Map<String, int>> {
  WeakWordsNotifier() : super({}) {
    _load();
  }

  static const _prefix = 'weak_words_';
  String get _fullPrefix => '${ProfileService.prefix}$_prefix';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final fp = _fullPrefix;
    final map = <String, int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(fp)) {
        final cardId = key.substring(fp.length);
        map[cardId] = prefs.getInt(key) ?? 0;
      }
    }
    state = map;
  }

  /// Call when a quiz answer is wrong for [cardId].
  Future<void> recordMistake(String cardId) async {
    final next = (state[cardId] ?? 0) + 1;
    state = {...state, cardId: next};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_fullPrefix$cardId', next);
  }

  /// Returns up to [limit] cards sorted by mistake count descending.
  List<MapEntry<String, int>> topMistakes([int limit = 10]) {
    final sorted = state.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }
}
