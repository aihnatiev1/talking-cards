import 'dart:math';

import '../models/card_model.dart';
import '../models/pack_model.dart';

/// Pack id → category name (Ukrainian).
const packCategoriesUk = <String, String>{
  'rozmovlyalky': 'Мовлення',
  'phrases': 'Мовлення',
  'actions': 'Мовлення',
  'opposites': 'Мовлення',
  'adjectives': 'Мовлення',
  'sound_r': 'Звуки',
  'sound_l': 'Звуки',
  'sound_sh': 'Звуки',
  'sound_s': 'Звуки',
  'sound_z': 'Звуки',
  'sound_zh': 'Звуки',
  'sound_ch': 'Звуки',
  'sound_shch': 'Звуки',
  'sound_ts': 'Звуки',
  'animals': 'Світ',
  'transport': 'Світ',
  'home': 'Світ',
  'food': 'Світ',
  'body': 'Світ',
  'emotions': 'Світ',
  'colors': 'Світ',
};

/// Pack id → category name (English).
const packCategoriesEn = <String, String>{
  'en_phrases': 'Speaking',
  'en_actions': 'Speaking',
  'en_opposites': 'Speaking',
  'en_adjectives': 'Speaking',
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
  'en_animals': 'World',
  'en_transport': 'World',
  'en_home': 'World',
  'en_food': 'World',
  'en_body': 'World',
  'en_emotions': 'World',
  'en_colors': 'World',
};

const allCategoriesUk = ['Мовлення', 'Звуки', 'Світ'];
const allCategoriesEn = ['Speaking', 'Sounds', 'World'];

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
