import 'dart:math';
import 'dart:ui' show Color;

import 'card_model.dart';
import 'pack_model.dart';
import 'semantic_group.dart';

/// The theme of the day — one set of pictures every stop of the quest map
/// works with (experience audit 2026-09-13, п. 25).
///
/// The map used to open a *random* unlocked pack at the "find 3 cards" stop
/// and another random one at "repeat after me", so the route was five
/// unrelated screens with a chest at the end. A two-year-old cannot hold a
/// story together out of that. A theme gives the walk one subject: today we
/// visit the cat — we listen to him, we find him among his friends, we say
/// his name, and the chest is the end of *that* visit.
///
/// The set is picked deterministically from the date and the active profile
/// (the same trick as `cardOfTheDay`), so closing the app mid-route and
/// coming back does not swap the animals for vegetables; and two children
/// on one device get their own day.
final class QuestTheme {
  const QuestTheme({
    required this.group,
    required this.hero,
    required this.cards,
  });

  /// The curated set the day is drawn from.
  final SemanticGroup group;

  /// The face of the day — the picture the child recognises the route by.
  /// Always the first entry of [cards].
  final CardModel hero;

  /// Every card of the theme, hero first. At least [QuestThemes.minCards]
  /// of them, all with artwork, all from unlocked packs.
  final List<CardModel> cards;

  /// The picture that stands for the day. Non-null: a theme is only built
  /// out of cards [SemanticGroups] bucketed, and it buckets by image.
  String get image => hero.image!;

  /// A parent- and screen-reader-facing name. The child is never asked to
  /// read it — she recognises the day by [image] (CLAUDE.md rule 4).
  String title(bool isEn) => switch (group) {
        SemanticGroup.animals => isEn ? 'Animals' : 'Тварини',
        SemanticGroup.food => isEn ? 'Tasty things' : 'Смаколики',
        SemanticGroup.transport => isEn ? 'Things that go' : 'Транспорт',
        SemanticGroup.toys => isEn ? 'Toys' : 'Іграшки',
        SemanticGroup.people => isEn ? 'Family' : 'Рідні',
        SemanticGroup.body => isEn ? 'Our body' : 'Наше тіло',
        SemanticGroup.shapes => isEn ? 'Shapes' : 'Фігури',
        SemanticGroup.colors => isEn ? 'Colours' : 'Кольори',
      };

  /// «Тема дня: тварини, котик» — what assistive tech reads on the map.
  String semanticLabel(bool isEn) =>
      '${isEn ? 'Today' : 'Тема дня'}: ${title(isEn)}, ${hero.sound}';

  /// The deck the card stops open: a virtual pack, like `_favorites` and
  /// `_review`. The leading underscore is the contract every counter in
  /// the app already reads — progress, stats and the resume index all skip
  /// ids that start with it, so a themed walk never overwrites where the
  /// child is inside a real pack.
  PackModel asPack({required String title, required Color color}) => PackModel(
        id: virtualPackId,
        title: title,
        icon: '🗺️',
        color: color,
        isLocked: false,
        isFree: true,
        cards: cards,
      );

  static const virtualPackId = '_theme';
}

/// Builds the [QuestTheme] of a given day.
final class QuestThemes {
  const QuestThemes._();

  /// A theme needs enough pictures to fill a card stop and a four-tile
  /// guess round out of itself; below that the route would repeat two
  /// pictures five times.
  static const minCards = 4;

  /// Date + profile → the seed. Same shape as `cardOfTheDay`, with the
  /// profile folded in by hand: `String.hashCode` is not promised to be
  /// stable across runs, and "the theme must survive a restart" is the
  /// whole point.
  static int seedOf(DateTime day, String profile) {
    var h = day.year * 10000 + day.month * 100 + day.day;
    for (final unit in profile.codeUnits) {
      h = 0x1fffffff & (h * 31 + unit);
    }
    return h;
  }

  /// The theme for [day], or null when [cards] cannot make an honest one
  /// (too little unlocked material — the caller then keeps its old
  /// behaviour rather than pretending the route has a subject).
  ///
  /// [preferred] — the card of the day. When its picture is in a group with
  /// enough material, that group *is* the theme and the card is its hero,
  /// so the tile on the home screen and the route on the map are one story
  /// instead of two.
  static QuestTheme? of(
    Iterable<CardModel> cards, {
    required DateTime day,
    required String profile,
    CardModel? preferred,
  }) {
    final byGroup = SemanticGroups.bucket(cards);
    final groups = [
      for (final e in byGroup.entries)
        if (e.value.length >= minCards) e.key,
    ]..sort((a, b) => a.index.compareTo(b.index));
    if (groups.isEmpty) return null;

    final rng = Random(seedOf(day, profile));

    SemanticGroup? group;
    CardModel? hero;
    if (preferred != null) {
      final preferredGroup = SemanticGroups.of(preferred);
      if (preferredGroup != null && groups.contains(preferredGroup)) {
        // `bucket` keeps one card per picture, and it may have kept another
        // pack's copy of this one — the hero must be the card that is
        // actually in the deck.
        final inDeck = byGroup[preferredGroup]!
            .where((c) => c.image == preferred.image)
            .firstOrNull;
        if (inDeck != null) {
          group = preferredGroup;
          hero = inDeck;
        }
      }
    }
    group ??= groups[rng.nextInt(groups.length)];

    // Sort before shuffling: the bucket's order follows the pack list, and
    // a stable start makes the shuffle a function of the seed alone.
    final pool = List<CardModel>.from(byGroup[group]!)
      ..sort((a, b) => a.id.compareTo(b.id))
      ..shuffle(rng);
    final lead = hero ?? pool.first;
    return QuestTheme(
      group: group,
      hero: lead,
      cards: [lead, ...pool.where((c) => c.id != lead.id)],
    );
  }
}
