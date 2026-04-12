import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/srs_card_state.dart';
import '../services/profile_service.dart';
import '../services/sm2_service.dart';

// ─────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────

class SrsState {
  /// All tracked cards (cardId → state).
  final Map<String, SrsCardState> cards;

  /// IDs of cards due for review today (pre-computed on load).
  final List<String> dueIds;

  const SrsState({required this.cards, required this.dueIds});

  int get dueCount => dueIds.length;
}

// ─────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────

class SrsNotifier extends StateNotifier<SrsState> {
  SrsNotifier()
      : super(const SrsState(cards: {}, dueIds: [])) {
    _load();
  }

  static const _key = 'srs_v1';
  String get _prefixedKey => '${ProfileService.prefix}$_key';

  // ── Persistence ─────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final cards = map.map(
        (k, v) => MapEntry(
            k, SrsCardState.fromJson(v as Map<String, dynamic>)),
      );
      state = SrsState(cards: cards, dueIds: _due(cards));
    } catch (_) {
      // Corrupt data — start fresh
    }
  }

  Future<void> _save(Map<String, SrsCardState> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        json.encode(cards.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefixedKey, encoded);
  }

  // ── Public API ──────────────────────────────

  /// Record a quiz answer for [cardId] and update its SM-2 state.
  ///
  /// [quality] uses the standard SM-2 scale (0–5).
  /// Recommended values for this app:
  ///   5 = correct on first try in quiz
  ///   4 = card viewed (passive)
  ///   2 = wrong answer in quiz
  Future<void> recordAnswer(String cardId, int quality) async {
    final current =
        state.cards[cardId] ?? SrsCardState.initial(cardId);
    final updated = Sm2Service.update(current, quality);
    final newCards = Map<String, SrsCardState>.from(state.cards)
      ..[cardId] = updated;
    state = SrsState(cards: newCards, dueIds: _due(newCards));
    await _save(newCards);
  }

  /// Mark a card as reviewed without changing its SRS state
  /// (e.g., after completing the review session).
  Future<void> markReviewed(String cardId) =>
      recordAnswer(cardId, 4);

  // ── Helpers ─────────────────────────────────

  static List<String> _due(Map<String, SrsCardState> cards) =>
      cards.values
          .where((s) => s.isDueToday)
          .map((s) => s.cardId)
          .toList();
}

// ─────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────

final srsProvider =
    StateNotifierProvider<SrsNotifier, SrsState>(
  (ref) => SrsNotifier(),
);
