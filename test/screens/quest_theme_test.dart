import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/quest_theme.dart';
import 'package:talking_cards/models/semantic_group.dart';

/// The theme of the day (experience audit 2026-09-13, п. 25).
///
/// The route used to open a random pack at every card stop, so the walk was
/// five unrelated screens. A theme is the fix — but only if it is the *same*
/// theme all day and at every stop: a subject that changes when the app is
/// killed mid-route, or that stop 4 does not share with stop 2, is no
/// subject at all.
void main() {
  const bg = Color(0xFFFFF8F0);
  const accent = Color(0xFF6FBEA7);
  CardModel card(String id, String image) => CardModel(
        id: id,
        sound: id,
        text: id,
        emoji: '🐾',
        colorBg: bg,
        colorAccent: accent,
        image: image,
        audioKey: id,
      );

  /// Enough material for two honest themes: animals and things that go.
  final cards = <CardModel>[
    for (final image in ['cat', 'dog', 'cow', 'horse', 'pig', 'duck'])
      card('uk_$image', image),
    for (final image in ['avtomobil', 'avtobus', 'poizd', 'litak', 'korabel'])
      card('uk_$image', image),
    // Picture-less and group-less cards must not reach a theme.
    const CardModel(
      id: 'uk_ba',
      sound: 'ба',
      text: 'ба',
      emoji: '👶',
      colorBg: bg,
      colorAccent: accent,
      audioKey: 'ba',
    ),
    card('uk_zima', 'zima'),
  ];

  final monday = DateTime(2026, 9, 14);
  final tuesday = DateTime(2026, 9, 15);

  QuestTheme? build(
    DateTime day, {
    String profile = 'p1_',
    CardModel? preferred,
    List<CardModel>? deck,
  }) =>
      QuestThemes.of(
        deck ?? cards,
        day: day,
        profile: profile,
        preferred: preferred,
      );

  test('the same day and profile give the same theme twice running', () {
    final first = build(monday)!;
    final second = build(monday)!;
    expect(second.group, first.group);
    expect(second.hero.id, first.hero.id);
    expect(
      second.cards.map((c) => c.id).toList(),
      first.cards.map((c) => c.id).toList(),
      reason: 'a restart must not reshuffle the day',
    );
  });

  test('another day is another theme; another profile is another day', () {
    // Over a fortnight the subject must actually move — a "theme of the
    // day" that is always animals is a pack, not a day.
    final byDay = {
      for (var i = 0; i < 14; i++)
        build(monday.add(Duration(days: i)))!.group,
    };
    expect(byDay.length, greaterThan(1));

    final sameDayOtherChild = {
      for (final profile in ['p1_', 'p2_', 'p3_', 'p4_'])
        build(monday, profile: profile)!.hero.id,
    };
    expect(sameDayOtherChild.length, greaterThan(1));
  });

  test('all five stops work with one theme', () {
    final theme = build(monday)!;
    final deck =
        theme.asPack(title: theme.title(false), color: accent).cards;

    // Stop 1 listens to the hero; stops 2 and 4 open the deck; stop 5
    // opens it again; stop 3 plays a four-tile round out of the same list.
    expect(deck.first.id, theme.hero.id);
    expect(deck.length, greaterThanOrEqualTo(QuestThemes.minCards));
    expect(theme.cards.length, greaterThanOrEqualTo(4));
    for (final c in theme.cards) {
      expect(
        SemanticGroups.of(c),
        theme.group,
        reason: 'every card the route shows belongs to the day’s subject',
      );
    }
    // The deck is a virtual pack: it may never overwrite a real pack's
    // progress or resume index.
    expect(QuestTheme.virtualPackId.startsWith('_'), isTrue);
  });

  test('the card of the day leads the route when it can', () {
    final cat = cards.firstWhere((c) => c.image == 'cat');
    final theme = build(monday, preferred: cat)!;
    expect(theme.group, SemanticGroup.animals);
    expect(theme.hero.id, cat.id);
    expect(theme.cards.first.id, cat.id);

    // A card outside every curated set cannot lead — the day falls back to
    // its own pick instead of building a theme of one picture.
    final winter = cards.firstWhere((c) => c.image == 'zima');
    final fallback = build(monday, preferred: winter)!;
    expect(fallback.hero.id, isNot(winter.id));
    expect(fallback.group, build(monday)!.group);
  });

  test('too little material means no theme at all, not a fake one', () {
    expect(build(monday, deck: [card('uk_cat', 'cat')]), isNull);
    expect(build(monday, deck: const []), isNull);
    // Three animals are still not a round of four.
    expect(
      build(
        monday,
        deck: [for (final i in ['cat', 'dog', 'cow']) card('uk_$i', i)],
      ),
      isNull,
    );
  });

  test('the theme deck is a pack the card screens can open', () {
    final theme = build(tuesday)!;
    final pack = theme.asPack(title: theme.title(false), color: accent);
    expect(pack, isA<PackModel>());
    expect(pack.id, QuestTheme.virtualPackId);
    expect(pack.isLocked, isFalse);
    expect(pack.cards, theme.cards);
  });
}
