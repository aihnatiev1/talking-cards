import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/play_session.dart';
import 'package:talking_cards/models/play_topic.dart';
import 'package:talking_cards/screens/play_lesson_screen.dart';
import 'package:talking_cards/utils/design_tokens.dart';

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

    test('everything earned: it rests on the last one played', () {
      var j = const PlayJournal();
      for (final t in all) {
        j = j.put(session(t, 7));
      }
      expect(PlayTopic.pick(all, j), all.last);
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
