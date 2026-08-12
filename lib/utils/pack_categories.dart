import 'dart:math';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import 'l10n.dart';

/// Category ids in display order for the home-grid filter chips. Each pack
/// carries its category in the cards JSON ("category": "speech" | "sounds" |
/// "world"), so new locales need no Dart-side pack→category maps.
const kPackCategoryIds = ['speech', 'sounds', 'world'];

/// Emoji shown before the chip label, keyed by category id.
const kPackCategoryIcons = <String, String>{
  'speech': '💬',
  'sounds': '🔤',
  'world': '🌍',
};

/// Localized label for a category id.
String packCategoryLabel(String categoryId, AppS s) => switch (categoryId) {
      'speech' => s('Мовлення', 'Speaking'),
      'sounds' => s('Звуки', 'Sounds'),
      'world' => s('Світ', 'World'),
      _ => categoryId,
    };

/// Deterministic daily card based on date seed.
/// Returns `(card, isFromLockedPack)` or null if no cards.
(CardModel, bool)? cardOfTheDay(List<PackModel> packs) {
  final allCards = packs.expand((p) => p.cards).toList();
  if (allCards.isEmpty) return null;
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  final card = allCards[Random(seed).nextInt(allCards.length)];
  final pack = packs.firstWhere((p) => p.cards.contains(card));
  return (card, pack.isLocked);
}
