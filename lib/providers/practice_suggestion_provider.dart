import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import 'packs_provider.dart';
import 'srs_provider.dart';
import 'weak_words_provider.dart';

/// Words to offer a grown-up for one short practice together.
///
/// Order of preference, strongest reason first:
///  1. words missed in a game (most misses first);
///  2. words due for review today;
///  3. nothing — an empty list, so the UI can stay quiet instead of
///     inventing a task.
List<CardModel> practiceSuggestion({
  required Map<String, int> mistakes,
  required List<String> dueIds,
  required List<CardModel> allCards,
  int limit = 3,
}) {
  final byId = {for (final c in allCards) c.id: c};
  final picked = <String, CardModel>{};

  final ranked = mistakes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in ranked) {
    if (picked.length >= limit) break;
    final card = byId[entry.key];
    if (card != null) picked[card.id] = card;
  }
  for (final id in dueIds) {
    if (picked.length >= limit) break;
    final card = byId[id];
    if (card != null) picked[card.id] = card;
  }
  return picked.values.toList();
}

/// Assembled from live state; empty while packs are still loading.
final practiceSuggestionProvider = Provider<List<CardModel>>((ref) {
  final packs = ref.watch(packsProvider).valueOrNull;
  if (packs == null) return const [];
  return practiceSuggestion(
    mistakes: ref.watch(weakWordsProvider),
    dueIds: ref.watch(srsProvider).dueIds,
    allCards: [
      for (final pack in packs)
        if (!pack.id.startsWith('_')) ...pack.cards,
    ],
  );
});
