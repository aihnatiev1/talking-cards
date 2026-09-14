import '../models/card_model.dart';

/// The teaching plan: sixty words, in seven units, that a child actually
/// uses at 1–3 — not the catalogue.
///
/// The catalogue is a library of 471 cards and it stays that way. This is
/// the curriculum laid over it: it owns no content, only an order, and
/// every entry is the id of a card that already exists. One card can be
/// in both — the library shelf it lives on does not know it was chosen.
///
/// Per language, like the catalogue itself (`assets/data/uk_curriculum.json`),
/// because a word list is only as good as the recording behind it.
class Curriculum {
  final int version;
  final String lang;
  final List<CurriculumUnit> units;

  const Curriculum({
    required this.version,
    required this.lang,
    required this.units,
  });

  factory Curriculum.fromJson(Map<String, dynamic> json) => Curriculum(
    version: json['version'] as int,
    lang: json['lang'] as String,
    units: (json['units'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CurriculumUnit.fromJson)
        .toList(),
  );

  /// Every card id in plan order.
  List<String> get cardIds => [for (final u in units) ...u.cardIds];
}

class CurriculumUnit {
  final String id;
  final String title;
  final String titleEn;
  final List<String> cardIds;

  const CurriculumUnit({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.cardIds,
  });

  factory CurriculumUnit.fromJson(Map<String, dynamic> json) => CurriculumUnit(
    id: json['id'] as String,
    title: json['title'] as String,
    titleEn: json['titleEn'] as String,
    cardIds: (json['cards'] as List<dynamic>).cast<String>(),
  );

  String localizedTitle(bool isEn) => isEn ? titleEn : title;
}

/// A unit with its cards already resolved against the catalogue.
class ResolvedUnit {
  final CurriculumUnit unit;
  final List<CardModel> cards;

  const ResolvedUnit({required this.unit, required this.cards});
}
