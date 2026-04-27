import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Tracks the last opened pack id so the home screen can surface a
/// "Continue" tile (Lingokids-style). Entries older than 48h are ignored.
final lastOpenedPackProvider =
    StateNotifierProvider<LastOpenedPackNotifier, String?>(
  (ref) => LastOpenedPackNotifier(),
);

class LastOpenedPackNotifier extends StateNotifier<String?> {
  LastOpenedPackNotifier() : super(null) {
    _load();
  }

  static const _keyId = 'last_opened_pack';
  static const _keyAt = 'last_opened_pack_at';
  static const _staleMs = 48 * 60 * 60 * 1000;

  String get _prefixedId => '${ProfileService.prefix}$_keyId';
  String get _prefixedAt => '${ProfileService.prefix}$_keyAt';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefixedId);
    final at = prefs.getInt(_prefixedAt);
    if (id == null || at == null) {
      state = null;
      return;
    }
    final diff = DateTime.now().millisecondsSinceEpoch - at;
    if (diff > _staleMs) {
      state = null;
      return;
    }
    state = id;
  }

  Future<void> record(String packId) async {
    // Skip virtual (_favorites, _review) and seasonal packs — they are
    // ephemeral and shouldn't anchor the "Continue" hero.
    if (packId.startsWith('_') || packId.startsWith('seasonal_')) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_prefixedId, packId);
    await prefs.setInt(_prefixedAt, now);
    state = packId;
  }
}
