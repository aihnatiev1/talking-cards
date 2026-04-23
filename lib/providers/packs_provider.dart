import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pack_model.dart';
import '../services/profile_service.dart';
import '../services/purchase_service.dart';
import 'language_provider.dart';

final isProProvider = StateProvider<bool>(
  (ref) => PurchaseService.instance.isPro.value,
);

final packsProvider = FutureProvider<List<PackModel>>((ref) async {
  final isPro = ref.watch(isProProvider);
  final lang = ref.watch(languageProvider);

  final assetPath = lang == 'en'
      ? 'assets/data/en_cards.json'
      : 'assets/data/uk_cards.json';

  final jsonString = await rootBundle.loadString(assetPath);
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
  final packs = jsonList
      .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
      .toList();

  // TEST MODE: unlock all packs regardless of Pro status.
  // TODO: revert — remove this unconditional unlock and restore the
  //       `if (!isPro) return packs;` gate before shipping.
  // ignore: dead_code
  if (false && !isPro) return packs;

  return packs
      .map((p) => p.isLocked ? p.copyWith(isLocked: false) : p)
      .toList();
});

/// Tracks completed pack IDs in SharedPreferences
final completedPacksProvider = StateNotifierProvider<CompletedPacksNotifier, Set<String>>(
  (ref) => CompletedPacksNotifier(),
);

class CompletedPacksNotifier extends StateNotifier<Set<String>> {
  CompletedPacksNotifier() : super({}) {
    _load();
  }

  static const _key = 'completed_packs';
  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefixedKey) ?? [];
    // Filter out virtual packs that may have been saved by mistake
    final cleaned = list.where((id) => !id.startsWith('_')).toSet();
    if (cleaned.length != list.length) {
      await prefs.setStringList(_prefixedKey, cleaned.toList());
    }
    state = cleaned;
  }

  Future<void> markCompleted(String packId) async {
    // Ignore virtual packs
    if (packId.startsWith('_')) return;
    state = {...state, packId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefixedKey, state.toList());
  }
}

/// Tracks max card index reached per pack
final packProgressProvider = StateNotifierProvider<PackProgressNotifier, Map<String, int>>(
  (ref) => PackProgressNotifier(),
);

class PackProgressNotifier extends StateNotifier<Map<String, int>> {
  PackProgressNotifier() : super({}) {
    _load();
  }

  static const _key = 'pack_progress';
  String get _fullPrefix => '${ProfileService.prefix}${_key}_';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final fp = _fullPrefix;
    final keys = prefs.getKeys().where((k) => k.startsWith(fp));
    final map = <String, int>{};
    for (final k in keys) {
      final packId = k.substring(fp.length);
      // Clean up virtual packs saved by mistake
      if (packId.startsWith('_')) {
        await prefs.remove(k);
        continue;
      }
      map[packId] = prefs.getInt(k) ?? 0;
    }
    state = map;
  }

  Future<void> updateProgress(String packId, int cardIndex) async {
    // Ignore virtual packs
    if (packId.startsWith('_')) return;
    final current = state[packId] ?? 0;
    if (cardIndex + 1 > current) {
      state = {...state, packId: cardIndex + 1};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_fullPrefix$packId', cardIndex + 1);
    }
  }
}
