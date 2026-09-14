import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../services/profile_service.dart';
import 'curriculum_provider.dart';

/// How many times each Core 60 word has been put in front of the child in
/// «Повтори за мною».
///
/// Deliberately a count of *offers*, not of successes. The app cannot
/// judge how a word was said and does not try; what it can do honestly is
/// make sure the sixty words come round in order instead of the same four
/// arriving by chance out of a library of 471. Success lives in
/// `wordEvidenceProvider`, where a human put it.
final curriculumProgressProvider =
    StateNotifierProvider<CurriculumProgressNotifier, Map<String, int>>(
      (ref) => CurriculumProgressNotifier(),
    );

class CurriculumProgressNotifier extends StateNotifier<Map<String, int>> {
  CurriculumProgressNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'curriculum_offers';

  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      state = decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      // A store we cannot read is a store we start over: this is a
      // practice counter, not something worth failing a launch for.
      state = const {};
    }
  }

  Future<void> record(String cardId) async {
    state = {...state, cardId: (state[cardId] ?? 0) + 1};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefixedKey, json.encode(state));
  }

  /// Tests and a fresh profile.
  Future<void> reset() async {
    state = const {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefixedKey);
  }
}

/// The next set of words to practise: the least-practised first, ties
/// broken by plan order.
///
/// So a child who has never opened the game starts at unit one word one,
/// and a child who finished a pass round the sixty starts the second pass
/// at the beginning rather than wherever chance lands. Empty when there is
/// no curriculum for this language — the caller falls back to the library.
final speakSetProvider = Provider<List<CardModel>>((ref) {
  final units = ref.watch(curriculumUnitsProvider).valueOrNull;
  if (units == null || units.isEmpty) return const [];
  final offers = ref.watch(curriculumProgressProvider);

  final ordered = [
    for (final unit in units)
      for (final card in unit.cards) card,
  ];
  // A stable sort keeps plan order inside each count bucket.
  final indexed = [
    for (var i = 0; i < ordered.length; i++) (card: ordered[i], order: i),
  ]..sort((a, b) {
      final byCount = (offers[a.card.id] ?? 0).compareTo(
        offers[b.card.id] ?? 0,
      );
      return byCount != 0 ? byCount : a.order.compareTo(b.order);
    });
  return [for (final e in indexed) e.card];
});
