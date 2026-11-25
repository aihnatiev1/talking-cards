import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/play_session.dart';
import 'package:talking_cards/models/play_topic.dart';
import 'package:talking_cards/screens/play_lesson_screen.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/animal_friend_art.dart';

void main() {
  const all = PlayTopic.all;
  PlaySession session(PlayTopic t, int step) =>
      PlaySession(topic: t.id, cardIds: ['a', 'b', 'c'], step: step);

  group('the Play shelf picks its lesson', () {
    test('no journal: the first', () {
      expect(PlayTopic.pick(all, null), all[0]);
    });

    test('a lesson in progress is continued', () {
      final j = const PlayJournal().put(session(all[0], 3));
      expect(PlayTopic.pick(all, j), all[0]);
    });

    test('a finished lesson hands over to the next, then the next', () {
      var j = const PlayJournal().put(session(all[0], 7));
      expect(PlayTopic.pick(all, j), all[1]);
      j = j.put(session(all[1], 7));
      expect(PlayTopic.pick(all, j), all[2]);
    });

    test('everything earned: the lessons come round again, never the same '
        'one twice in a row', () {
      var j = const PlayJournal();
      for (final t in all) {
        j = j.put(session(t, 7));
      }
      // The last one played was the last in the list: round to the first.
      expect(PlayTopic.pick(all, j), all.first);
      j = j.put(session(all.first, 7));
      expect(PlayTopic.pick(all, j), all[1]);
    });

    test('every topic brings a friend that has clay art', () {
      const clay = {
        'cow',
        'cat',
        'dog',
        'rabbit',
        'horse',
        'pig',
        'chicken',
        'duck',
        'frog',
        'fish',
        'owl',
        'sheep',
        'rooster',
        'bird',
      };
      for (final t in all) {
        expect(
          clay,
          contains(AnimalFriendArt.friendOf(t.images.first)),
          reason: t.id,
        );
      }
      // No friend twice in «Мій світ».
      expect({
        for (final t in all) AnimalFriendArt.friendOf(t.images.first),
      }, hasLength(all.length));
    });
  });

  test('the target walks across the three pictures', () {
    final slots = [
      for (final step in [3, 4, 5])
        threeOptions(['x', 'y', 'z'], step).indexOf(['x', 'y', 'z'][step - 3]),
    ];
    expect(slots.toSet(), {0, 1, 2});
    for (final step in [3, 4, 5]) {
      expect(threeOptions(['x', 'y', 'z'], step).toSet(), {'x', 'y', 'z'});
    }
  });

  test('brand as text and under white clears AA', () {
    const tint = Color(0xFFEAF4DE); // brand at 10 % over the page
    expect(DT.contrastRatio(DT.brandInk, DT.surfaceWhite), greaterThan(4.5));
    expect(DT.contrastRatio(DT.brandInk, tint), greaterThan(4.5));
    expect(
      DT.contrastRatio(DT.surfaceWhite, DT.solid(DT.brand)),
      greaterThan(4.5),
    );
  });
}
