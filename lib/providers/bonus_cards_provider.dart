import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Tracks how many bonus cards the user unlocked per pack via daily quests.
/// These cards extend the free preview beyond PackModel.freePreviewCount.
final bonusCardsProvider =
    StateNotifierProvider<BonusCardsNotifier, Map<String, int>>(
  (ref) => BonusCardsNotifier(),
);

class BonusCardsNotifier extends StateNotifier<Map<String, int>> {
  BonusCardsNotifier() : super({}) {
    _load();
  }

  static const _prefix = 'bonus_cards_';
  String get _fullPrefix => '${ProfileService.prefix}$_prefix';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final fp = _fullPrefix;
    final map = <String, int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(fp)) {
        final packId = key.substring(fp.length);
        map[packId] = prefs.getInt(key) ?? 0;
      }
    }
    state = map;
  }

  int bonusFor(String packId) => state[packId] ?? 0;

  /// Unlocks one additional card in the given pack. Returns the new total.
  Future<int> unlockOne(String packId) async {
    final current = state[packId] ?? 0;
    final next = current + 1;
    state = {...state, packId: next};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_fullPrefix$packId', next);
    return next;
  }
}
