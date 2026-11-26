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
  /// than that is simply not offered without it. The one exception is the
  /// lesson's friend (its first picture): the lesson is how a child earns
  /// that friend, voice and all, so it is lent from the whole pack.
  List<CardModel> cards(List<PackModel> packs) {
    final mine = packs.where((p) => packIds.contains(p.id));
    final available = mine.expand(
      (p) => p.isLocked ? p.cards.take(p.effectiveFreePreviewCount) : p.cards,
    );
    final everything = mine.expand((p) => p.cards);
    final result = <CardModel>[];
    for (final (i, image) in images.indexed) {
      final card = (i == 0 ? everything : available)
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
      ['ph_pig', 'ph_hen', 'ph_rooster'],
      packIds: _sounds,
      withSounds: true,
    ),
    PlayTopic('pond_friends', 'Біля води', 'By the pond', [
      'duck',
      'frog',
      'fish',
    ]),
    // The rooster is this lesson's friend: the dog is on the farm already.
    PlayTopic('yard_friends', 'На подвір’ї', 'In the yard', [
      'rooster',
      'dog',
      'bee',
    ]),
    PlayTopic(
      'sound_pond',
      'Ква-ква, жабка!',
      'Ribbit, little frog!',
      // The frog with two free voices, so the lesson can always be played.
      ['ph_frog', 'ph_cow', 'ph_horse'],
      packIds: _sounds,
      withSounds: true,
    ),
    // One lesson for every farm animal that is not free, so a sleeping one
    // on the farm can always be woken by playing.
    PlayTopic('coop_friends', 'Курочка в гостях', 'Visiting the hen', [
      'chicken',
      'cat',
      'bee',
    ]),
    PlayTopic('meadow_friends', 'На лузі', 'In the meadow', [
      'dog',
      'butterfly',
      'snail',
    ]),
    PlayTopic('sky_friends', 'Хто літає?', 'Who can fly?', [
      'bird',
      'butterfly',
      'bee',
    ]),
    PlayTopic(
      'bee_voices',
      'Дзз, бджілка!',
      'Buzz, little bee!',
      ['ph_bee', 'ph_pig', 'ph_cow'],
      packIds: _sounds,
      withSounds: true,
    ),
  ];

  /// The lesson that brings the friend [key] (a farm animal), if one can be
  /// played with these [packs].
  static PlayTopic? bringing(String key, List<PackModel> packs) => all
      .where(
        (t) => friendKey(t.images.first) == key && t.cards(packs).length == 3,
      )
      .firstOrNull;

  /// The clay friend a picture stands for: `ph_cat` → `cat`, the bunny is
  /// Bloom's `rabbit`, the hen is the `chicken`.
  static String friendKey(String image) {
    final name = image.startsWith('ph_') ? image.substring(3) : image;
    return switch (name) {
      'bunny' => 'rabbit',
      'hen' => 'chicken',
      _ => name,
    };
  }
}
