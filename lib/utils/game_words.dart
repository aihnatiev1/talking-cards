import '../models/card_model.dart';
import '../models/pack_model.dart';

/// Whether [pack] may put its cards on a picture game's board — «Вгадай
/// звук», «Знайди пару», the bubbles. Not the phrase and verse packs (a
/// poem would play instead of a word) and not the photo packs (a photo of
/// a cat beside a drawn cat reads as two apps on one board).
bool isPictureGamePack(PackModel pack) =>
    !PackModel.nonWordPackIds.contains(pack.id) &&
    !PackModel.photoPackIds.contains(pack.id);

/// The words a game may use for a child of [level].
///
/// For a profile of 1–3 years ([level] ≤ 2) that is the teaching plan —
/// the sixty words a toddler actually uses («мама», «котик», «їсти») — when
/// at least [atLeast] of them are in [cards]. The whole library used to be
/// dealt at random, so a two-year-old was asked to find «підводний човен».
/// Older profiles, and languages without a plan, keep [cards].
///
/// One rule for every door into a game: the games hub and the daily quest
/// map both deal through here.
List<CardModel> wordsForAge(
  List<CardModel> cards, {
  required int level,
  required Iterable<CardModel> plan,
  required int atLeast,
}) {
  if (level > 2) return cards;
  final ids = {for (final c in plan) c.id};
  final early = cards.where((c) => ids.contains(c.id)).toList();
  return early.length >= atLeast ? early : cards;
}
