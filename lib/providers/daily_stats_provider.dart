import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dailyStatsProvider =
    StateNotifierProvider<DailyStatsNotifier, Map<String, int>>(
  (ref) => DailyStatsNotifier(),
);

class DailyStatsNotifier extends StateNotifier<Map<String, int>> {
  DailyStatsNotifier() : super({}) {
    _load();
  }

  static const _prefix = 'daily_views_';

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final map = <String, int>{};
    for (final k in keys) {
      map[k.substring(_prefix.length)] = prefs.getInt(k) ?? 0;
    }
    state = map;
  }

  Future<void> recordView() async {
    final key = _todayKey;
    final current = state[key] ?? 0;
    state = {...state, key: current + 1};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$key', current + 1);
  }

  /// Returns view counts for the last 7 days (oldest first).
  List<MapEntry<String, int>> last7Days() {
    final now = DateTime.now();
    final result = <MapEntry<String, int>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result.add(MapEntry(key, state[key] ?? 0));
    }
    return result;
  }

  int get totalViews => state.values.fold(0, (sum, v) => sum + v);
}
