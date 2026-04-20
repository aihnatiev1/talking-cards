import 'dart:math';

import '../models/card_model.dart';
import '../models/pack_model.dart';

/// Pack id → category name (Ukrainian).
const packCategoriesUk = <String, String>{
  'rozmovlyalky': 'Мовлення',
  'animals': 'Світ навколо',
  'transport': 'Світ навколо',
  'home': 'Побут',
  'food': 'Побут',
  'emotions': 'Розвиток',
  'colors': 'Розвиток',
  'body': 'Розвиток',
  'phrases': 'Мовлення',
  'actions': 'Розвиток',
  'opposites': 'Розвиток',
  'adjectives': 'Розвиток',
  'sound_r': 'Звуки',
  'sound_l': 'Звуки',
  'sound_sh': 'Звуки',
  'sound_s': 'Звуки',
  'sound_z': 'Звуки',
  'sound_zh': 'Звуки',
  'sound_ch': 'Звуки',
  'sound_shch': 'Звуки',
  'sound_ts': 'Звуки',
};

/// Pack id → category name (English).
const packCategoriesEn = <String, String>{
  'en_animals': 'Nature',
  'en_home': 'Home',
  'en_emotions': 'Feelings',
  'en_transport': 'Transport',
  'en_food': 'Food',
  'en_colors': 'Learning',
  'en_body': 'Learning',
  'en_actions': 'Learning',
  'en_opposites': 'Learning',
  'en_phrases': 'Speaking',
  'en_adjectives': 'Learning',
  'en_sound_r': 'Sounds',
  'en_sound_l': 'Sounds',
  'en_sound_s': 'Sounds',
  'en_sound_z': 'Sounds',
  'en_sound_sh': 'Sounds',
  'en_sound_zh': 'Sounds',
  'en_sound_ch': 'Sounds',
  'en_sound_th': 'Sounds',
  'en_sound_w': 'Sounds',
  'en_sound_bl': 'Sounds',
};

const allCategoriesUk = ['Все', 'Мовлення', 'Світ навколо', 'Побут', 'Розвиток', 'Звуки'];
const allCategoriesEn = ['All', 'Nature', 'Home', 'Feelings', 'Transport', 'Food', 'Learning', 'Speaking', 'Sounds'];

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
