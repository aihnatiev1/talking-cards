import 'card_model.dart';
import 'pack_model.dart';
import 'play_session.dart';

/// Curated image identities are shared by UA/EN; audio stays with each card.
///
/// The first picture of a topic is the friend it brings to «Мій світ».
class PlayTopic {
  const PlayTopic(
    this.id,
    this.titleUk,
    this.titleEn,
    this.images, {
    this.packIds = const {'animals', 'en_animals'},
    this.withSounds = false,
  });
  final String id;
  final String titleUk;
  final String titleEn;
  final List<String> images;

  /// Where the pictures come from.
  final Set<String> packIds;

  /// The animal-sound cards: a photo and the narrator's word followed by
  /// the animal's real voice. Meeting them plays the whole recording.
  final bool withSounds;

  String title(bool isEn) => isEn ? titleEn : titleUk;

  /// A locked pack lends only its free preview; a lesson that needs more
  /// than that is simply not offered without it.
  List<CardModel> cards(List<PackModel> packs) {
    final available = packs
        .where((p) => packIds.contains(p.id))
        .expand(
          (p) =>
              p.isLocked ? p.cards.take(p.effectiveFreePreviewCount) : p.cards,
        );
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
  /// one not yet earned. When every friend has been met, the lessons come
  /// round again in order — the next after the last one played — so «play»
  /// is always a lesson to play and never the same one twice in a row.
  static PlayTopic? pick(List<PlayTopic> available, PlayJournal? journal) {
    final last = available.where((t) => t.id == journal?.lastTopic).firstOrNull;
    final session = last == null ? null : journal?.sessions[last.id];
    if (last != null && session != null && !session.complete) return last;
    final earned = journal?.rewards ?? const <String>{};
    final next = available.where((t) => !earned.contains(t.id)).firstOrNull;
    if (next != null) return next;
    if (last == null) return available.firstOrNull;
    return available[(available.indexOf(last) + 1) % available.length];
  }

  static const _sounds = {'animal_sounds', 'en_animal_sounds'};

  static const all = [
    PlayTopic('animal_friends', 'Привіт, тваринки!', 'Hello, animal friends!', [
      'cow',
      'cat',
      'dog',
    ]),
    PlayTopic(
      'sound_home',
      'Хто як каже?',
      'Who says what?',
      ['ph_cat', 'ph_dog', 'ph_cow'],
      packIds: _sounds,
      withSounds: true,
    ),
    PlayTopic('farm_friends', 'Хто на фермі?', 'Who lives on the farm?', [
      'horse',
      'pig',
      'chicken',
    ]),
    // The owl, not the bunny, is this lesson's friend: the bunny is Bloom.
    PlayTopic('forest_friends', 'У лісі', 'In the forest', [
      'owl',
      'bunny',
      'bear',
    ]),
    PlayTopic(
      'sound_farm',
      'Голоси ферми',
      'Farm voices',
      ['ph_pig', 'ph_hen', 'ph_sheep'],
      packIds: _sounds,
      withSounds: true,
    ),
    PlayTopic('pond_friends', 'Біля води', 'By the pond', [
      'duck',
      'frog',
      'fish',
    ]),
    PlayTopic('yard_friends', 'На подвір’ї', 'In the yard', [
      'dog',
      'rooster',
      'bee',
    ]),
    PlayTopic(
      'sound_pond',
      'Голоси біля ставка',
      'Voices by the pond',
      ['ph_frog', 'ph_duck', 'ph_bird'],
      packIds: _sounds,
      withSounds: true,
    ),
  ];
}
