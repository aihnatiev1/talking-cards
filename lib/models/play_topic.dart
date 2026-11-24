import 'card_model.dart';
import 'pack_model.dart';
import 'play_session.dart';

/// Curated image identities are shared by UA/EN; audio stays with each card.
class PlayTopic {
  const PlayTopic(this.id, this.titleUk, this.titleEn, this.images);
  final String id;
  final String titleUk;
  final String titleEn;
  final List<String> images;
  String title(bool isEn) => isEn ? titleEn : titleUk;

  List<CardModel> cards(List<PackModel> packs) {
    final available = packs
        .where(
          (p) => !p.isLocked && (p.id == 'animals' || p.id == 'en_animals'),
        )
        .expand((p) => p.cards);
    final result = <CardModel>[];
    for (final image in images) {
      final card = available
          .where((c) => c.image == image && c.audioKey != null)
          .firstOrNull;
      if (card == null) return const [];
      result.add(card);
    }
    return result;
  }

  /// The lesson the Play shelf offers: the one in progress, else the next
  /// one not yet earned; only when every topic is done does it rest on the
  /// last one played (the shelf then says «My world» / play again).
  static PlayTopic? pick(List<PlayTopic> available, PlayJournal? journal) {
    final last = available.where((t) => t.id == journal?.lastTopic).firstOrNull;
    final session = last == null ? null : journal?.sessions[last.id];
    if (last != null && session != null && !session.complete) return last;
    final earned = journal?.rewards ?? const <String>{};
    return available.where((t) => !earned.contains(t.id)).firstOrNull ??
        last ??
        available.firstOrNull;
  }

  static const all = [
    PlayTopic('animal_friends', 'Привіт, тваринки!', 'Hello, animal friends!', [
      'cow',
      'cat',
      'dog',
    ]),
    PlayTopic('farm_friends', 'Хто на фермі?', 'Who lives on the farm?', [
      'horse',
      'pig',
      'chicken',
    ]),
    PlayTopic('pond_friends', 'Біля води', 'By the pond', [
      'duck',
      'frog',
      'fish',
    ]),
  ];
}
