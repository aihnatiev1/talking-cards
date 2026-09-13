import 'package:shared_preferences/shared_preferences.dart';

import 'profile_service.dart';

/// The biggest «Знайди пару» board this child last played *calmly*
/// (docs/design/memory_match_redesign.md §6, wave 2.6).
///
/// The ladder itself lives inside one session: a child who spent five
/// rounds growing from two pairs to four used to open the next morning at
/// two again and climb the same stairs. One integer per profile fixes
/// that — the session opens on the board that was comfortable and the
/// ladder carries on from there.
///
/// Nothing here is shown, spoken or reset by the child: the only visible
/// consequence is the size of the first deal. The value is clamped by the
/// level's start and ceiling when it is read ([MemoryTiers.openingFor]),
/// so an older sibling's profile can never hand a toddler eight cards.
class MemoryComfortService {
  MemoryComfortService._();

  static final instance = MemoryComfortService._();

  static const _key = 'memory_comfort_tier';

  String get _prefsKey => '${ProfileService.prefix}$_key';

  /// Test seam: an in-memory value that skips the plugin entirely.
  static int? debugValue;

  Future<int?> read() async {
    if (debugValue != null) return debugValue;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey);
  }

  /// Remembers [pairs] when it is bigger than what is stored. A hard round
  /// never lowers it: the board the child *managed* is the honest memory,
  /// and the session's own ladder already steps back when today is a bad
  /// day.
  Future<void> remember(int pairs) async {
    if (debugValue != null) {
      if (pairs > debugValue!) debugValue = pairs;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefsKey) ?? 0;
    if (pairs <= current) return;
    await prefs.setInt(_prefsKey, pairs);
  }
}
