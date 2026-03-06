import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final reviewProvider =
    StateNotifierProvider<CardLastSeenNotifier, Map<String, String>>(
  (ref) => CardLastSeenNotifier(),
);

class CardLastSeenNotifier extends StateNotifier<Map<String, String>> {
  CardLastSeenNotifier() : super({}) {
    _load();
  }

  static const _prefix = 'card_last_seen_';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final map = <String, String>{};
    for (final k in keys) {
      map[k.substring(_prefix.length)] = prefs.getString(k) ?? '';
    }
    state = map;
  }

  Future<void> markSeen(String cardId) async {
    final today = _todayKey();
    state = {...state, cardId: today};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$cardId', today);
  }

  /// Returns card IDs not seen for 3+ days
  Set<String> get reviewCardIds {
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(days: 3));
    final result = <String>{};
    for (final entry in state.entries) {
      final parts = entry.value.split('-');
      if (parts.length == 3) {
        final date = DateTime.tryParse(entry.value);
        if (date != null && date.isBefore(threshold)) {
          result.add(entry.key);
        }
      }
    }
    return result;
  }
}
