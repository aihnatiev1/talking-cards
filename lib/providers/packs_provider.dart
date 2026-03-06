import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pack_model.dart';
import '../services/purchase_service.dart';

final isProProvider = StateProvider<bool>(
  (ref) => PurchaseService.instance.isPro.value,
);

final packsProvider = FutureProvider<List<PackModel>>((ref) async {
  final isPro = ref.watch(isProProvider);
  final jsonString = await rootBundle.loadString('assets/data/uk_cards.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
  final packs = jsonList
      .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
      .toList();

  if (!isPro) return packs;

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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    // Filter out virtual packs that may have been saved by mistake
    final cleaned = list.where((id) => !id.startsWith('_')).toSet();
    if (cleaned.length != list.length) {
      await prefs.setStringList(_key, cleaned.toList());
    }
    state = cleaned;
  }

  Future<void> markCompleted(String packId) async {
    // Ignore virtual packs
    if (packId.startsWith('_')) return;
    state = {...state, packId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${_key}_'));
    final map = <String, int>{};
    for (final k in keys) {
      final packId = k.substring('${_key}_'.length);
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
      await prefs.setInt('${_key}_$packId', cardIndex + 1);
    }
  }
}
