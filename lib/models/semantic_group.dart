import 'dart:math';

import 'card_model.dart';

/// Curated "these belong together" sets, keyed by the card's [CardModel.image]
/// (experience audit 2026-09-13, п. 22).
///
/// «Зайвий» used to build a round out of two *packs*: three cards from one,
/// one from another. Catalogue membership is not a picture a two-year-old
/// can read — the «Вдома» pack holds a mum, a ball and a porridge, so the
/// "right" answer was right only by pack id. A group here is a thing a child
/// can see: animals, food, things that drive, toys, people, body parts,
/// shapes, colours.
///
/// Keyed by image name on purpose — the same illustration is shared by the
/// Ukrainian and English catalogues while ids and words differ (same reason
/// as [CardModel.calmingExcludedImages]). Every membership below was read off
/// `assets/data/*_cards.json`; the sets are pairwise disjoint, and
/// `test/screens/odd_one_out_semantics_test.dart` holds them to it.
enum SemanticGroup {
  animals,
  food,
  transport,
  toys,
  people,
  body,
  shapes,
  colors;

  /// Images that belong to this group.
  Set<String> get images => switch (this) {
        SemanticGroup.animals => _animals,
        SemanticGroup.food => _food,
        SemanticGroup.transport => _transport,
        SemanticGroup.toys => _toys,
        SemanticGroup.people => _people,
        SemanticGroup.body => _body,
        SemanticGroup.shapes => _shapes,
        SemanticGroup.colors => _colors,
      };
}

const _animals = {
  'cat', 'dog', 'cow', 'horse', 'pig', 'chicken', 'rooster', 'duck', 'frog',
  'fish', 'bird', 'butterfly', 'bee', 'snail', 'bunny', 'bear', 'lisichka',
  'wolf', 'deer', 'hedgehog', 'owl', 'pingvin', 'slon', 'lev', 'mavpochka',
  'krokodil', 'cherepaha', 'delfin', 'bilochka',
};

const _food = {
  'apple', 'banana', 'grapes', 'apelsin', 'polunicia', 'kavun', 'grusha',
  'vishnia', 'persik', 'limon', 'hlib', 'moloko', 'sir', 'kasha', 'porridge',
  'sup', 'pirijok', 'pechivo', 'tort', 'morozivo', 'varenik', 'morkva',
  'ogirok', 'pomidor', 'kartoplia', 'kukurudza', 'garbuz', 'med', 'yaice',
  'cukerka', 'en_pancake', 'en_juice',
};

/// Things that drive, fly and sail. `toy_car` is deliberately absent — it is
/// a toy in the picture, and a toy car among real cars is exactly the kind of
/// "right by catalogue" trap this file exists to remove. So are `metro` and
/// `kanatna_doroga` (a tunnel mouth and a cable line read as scenery), and
/// `konik` — a horse in harness is an animal to a child.
const _transport = {
  'avtomobil', 'avtobus', 'poizd', 'litak', 'korabel', 'velosiped', 'motocikl',
  'gelicopter', 'tramvai', 'taxi', 'pojejna', 'shvidka', 'policia',
  'vantajivka', 'tractor', 'samokat', 'raketa', 'chovnik', 'yahta', 'sanki',
  'skateboard', 'ekskavator', 'pidvodnii_choven', 'aeroplan', 'electrichka',
  'kareta', 'povitriana_kulia',
};

const _toys = {'ball', 'doll', 'toy_car', 'blocks'};

const _people = {'mommy', 'dad', 'grandma', 'grandpa', 'baby', 'family'};

/// Parts a child can point to on themselves. Organs (`lungs`, `hart_t`) and
/// abstractions (`skin`, `body`, `smile`) stay out: they do not sort.
const _body = {
  'head', 'eyes', 'ears', 'nose', 'mouse', 'teeth', 'tonge', 'hair', 'neck',
  'sholdes', 'hands', 'fingers', 'stomack', 'back', 'legs', 'knees', 'foots',
  'elbow', 'palms', 'eyebrows', 'cheeks', 'forehead', 'chin',
};

const _shapes = {
  'circle', 'square', 'triangle', 'star', 'oval', 'diamond', 'hart_k',
};

const _colors = {
  'red', 'blue', 'yellow', 'green', 'white', 'black', 'orange', 'pink',
  'purple', 'brown', 'gray', 'sky-blue', 'gold',
};

/// Pairs that must never meet in one round, even though they are different
/// groups: the contrast would not be visible, only nameable.
///
/// A ball among circles, a yellow square among colours, a hand among
/// grandmas — an adult can defend each of those answers and a two-year-old
/// cannot see it.
const _confusable = <Set<SemanticGroup>>[
  {SemanticGroup.shapes, SemanticGroup.colors},
  {SemanticGroup.shapes, SemanticGroup.toys},
  {SemanticGroup.colors, SemanticGroup.food},
  {SemanticGroup.people, SemanticGroup.body},
  {SemanticGroup.people, SemanticGroup.animals},
  {SemanticGroup.toys, SemanticGroup.transport},
];

/// One «Зайвий» question: [majority] all belong to [majorityGroup], [odd]
/// belongs to [oddGroup] and to nothing else on the board.
final class OddOneOutTask {
  const OddOneOutTask({
    required this.majorityGroup,
    required this.majority,
    required this.oddGroup,
    required this.odd,
  });

  final SemanticGroup majorityGroup;
  final List<CardModel> majority;
  final SemanticGroup oddGroup;
  final CardModel odd;
}

/// Reading and using [SemanticGroup] over a live card list.
final class SemanticGroups {
  const SemanticGroups._();

  /// How many cards of one group make a majority on the 2×2 board.
  static const majoritySize = 3;

  /// The group [card] is drawn in, or null when its picture is not in any
  /// curated set (syllables, verses, adjectives, moods…).
  static SemanticGroup? of(CardModel card) {
    final image = card.image;
    if (image == null) return null;
    for (final group in SemanticGroup.values) {
      if (group.images.contains(image)) return group;
    }
    return null;
  }

  /// Whether two groups may face each other in one round.
  static bool contrast(SemanticGroup a, SemanticGroup b) =>
      a != b && !_confusable.any((pair) => pair.contains(a) && pair.contains(b));

  /// [cards] bucketed by group, one card per picture (the same illustration
  /// appears in several packs — «яблуко» is in both «Їжа» and «Вдома» — and
  /// two copies of it on one board is not a question).
  static Map<SemanticGroup, List<CardModel>> bucket(Iterable<CardModel> cards) {
    final byGroup = <SemanticGroup, List<CardModel>>{};
    final seen = <String>{};
    for (final card in cards) {
      final group = of(card);
      if (group == null) continue;
      if (!seen.add(card.image!)) continue; // `of` proved image is non-null
      byGroup.putIfAbsent(group, () => []).add(card);
    }
    return byGroup;
  }

  /// Builds a question out of [cards], or returns null when the available
  /// material cannot make an honest one (too few groups, too small a group).
  /// Callers fall back to their previous behaviour rather than showing a
  /// round nobody can reason about.
  static OddOneOutTask? task(Iterable<CardModel> cards, Random rng) {
    final byGroup = bucket(cards);
    final majorityGroups = [
      for (final entry in byGroup.entries)
        if (entry.value.length >= majoritySize) entry.key,
    ]..shuffle(rng);

    for (final majority in majorityGroups) {
      final oddGroups = [
        for (final entry in byGroup.entries)
          if (entry.value.isNotEmpty && contrast(majority, entry.key)) entry.key,
      ]..shuffle(rng);
      if (oddGroups.isEmpty) continue;

      final oddGroup = oddGroups.first;
      final pool = List<CardModel>.from(byGroup[majority]!)..shuffle(rng);
      final oddPool = List<CardModel>.from(byGroup[oddGroup]!)..shuffle(rng);

      return OddOneOutTask(
        majorityGroup: majority,
        majority: pool.take(majoritySize).toList(),
        oddGroup: oddGroup,
        odd: oddPool.first,
      );
    }
    return null;
  }
}
