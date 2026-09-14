import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/semantic_group.dart';
import 'package:talking_cards/screens/odd_one_out_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/answer_feedback.dart';

import '../helpers/motion.dart';

/// «Зайвий» after experience audit 2026-09-13, п. 22.
///
/// The round used to be "three cards from one pack, one from another", and a
/// pack is a catalogue fact: «Вдома» holds a mum, a ball and a porridge, so
/// the right answer was right only to whoever wrote the JSON. A round is now
/// built from curated semantic groups — things that look like they belong
/// together — and the answer is followed by a short wordless demonstration
/// that must not delay the next question.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CardModel card(String image) => CardModel(
        id: image,
        sound: image,
        text: image,
        emoji: '🐶',
        colorBg: const Color(0xFFFFFFFF),
        colorAccent: const Color(0xFF000000),
        image: image,
        audioKey: image,
      );

  PackModel pack(String id, List<String> images) => PackModel(
        id: id,
        title: id,
        icon: '📦',
        color: const Color(0xFF6C63FF),
        isLocked: false,
        isFree: true,
        cards: [for (final i in images) card(i)],
      );

  group('semantic groups', () {
    test('are pairwise disjoint — a picture belongs to one group only', () {
      final seen = <String, SemanticGroup>{};
      for (final group in SemanticGroup.values) {
        for (final image in group.images) {
          expect(
            seen[image],
            isNull,
            reason: '$image is in both ${seen[image]} and $group',
          );
          seen[image] = group;
        }
      }
      expect(seen, isNotEmpty);
    });

    test('name real card images, not typos', () {
      // Every membership was read off the shipped catalogue; a typo would
      // silently shrink a group until rounds stopped being buildable.
      expect(SemanticGroups.of(card('cat')), SemanticGroup.animals);
      expect(SemanticGroups.of(card('apple')), SemanticGroup.food);
      expect(SemanticGroups.of(card('avtobus')), SemanticGroup.transport);
      expect(SemanticGroups.of(card('mommy')), SemanticGroup.people);
      // A syllable card ("БІ-БІ-БІ") sorts into nothing — as it should.
      expect(SemanticGroups.of(card('syl_bi')), isNull);
      expect(SemanticGroups.of(card('cat').copyless()), SemanticGroup.animals);
    });

    test('a toy car is not traffic, and a harnessed horse is not transport',
        () {
      // The two traps that made "right by pack id" indefensible.
      expect(SemanticGroups.of(card('toy_car')), SemanticGroup.toys);
      expect(SemanticGroups.of(card('konik')), isNull);
    });

    test('groups that cannot be told apart by picture never meet', () {
      expect(
        SemanticGroups.contrast(SemanticGroup.shapes, SemanticGroup.colors),
        isFalse,
      );
      expect(
        SemanticGroups.contrast(SemanticGroup.toys, SemanticGroup.shapes),
        isFalse,
        reason: 'a ball among circles is a defensible answer either way',
      );
      expect(
        SemanticGroups.contrast(SemanticGroup.animals, SemanticGroup.transport),
        isTrue,
      );
    });
  });

  group('SemanticGroups.task', () {
    final catalogue = [
      ...pack('animals', ['cat', 'dog', 'cow', 'bear']).cards,
      ...pack('transport', ['avtobus', 'poizd', 'litak']).cards,
      ...pack('rozmovlyalky', ['syl_bi', 'syl_ah', 'syl_la']).cards,
    ];

    test('the three that stay together really are one group, and the odd '
        'one really is another', () {
      final rng = Random(11);
      for (var i = 0; i < 200; i++) {
        final task = SemanticGroups.task(catalogue, rng);
        expect(task, isNotNull);

        expect(task!.majority, hasLength(SemanticGroups.majoritySize));
        for (final c in task.majority) {
          expect(SemanticGroups.of(c), task.majorityGroup);
        }
        expect(SemanticGroups.of(task.odd), task.oddGroup);
        expect(task.oddGroup, isNot(task.majorityGroup));
        expect(
          SemanticGroups.contrast(task.majorityGroup, task.oddGroup),
          isTrue,
        );
        // …and the board holds four different pictures.
        final images = {...task.majority.map((c) => c.image), task.odd.image};
        expect(images, hasLength(4));
      }
    });

    test('the same picture twice in the catalogue is one card on the board',
        () {
      // «яблуко» is in both «Їжа» and «Вдома»; two of it is not a question.
      final task = SemanticGroups.task([
        ...pack('food', ['apple', 'banana', 'grapes']).cards,
        ...pack('home', ['apple']).cards,
        ...pack('transport', ['avtobus']).cards,
      ], Random(3));
      final images = {...task!.majority.map((c) => c.image), task.odd.image};
      expect(images, hasLength(4));
    });

    test('material that cannot make an honest question returns null', () {
      // Only sound packs open: nothing sorts, so the screen falls back
      // rather than inventing a rule the child cannot see.
      expect(
        SemanticGroups.task(
          pack('rozmovlyalky', ['syl_bi', 'syl_ah', 'syl_la', 'syl_or']).cards,
          Random(1),
        ),
        isNull,
      );
      // One group and nothing to contrast it with is equally unbuildable.
      expect(
        SemanticGroups.task(
          pack('animals', ['cat', 'dog', 'cow', 'bear']).cards,
          Random(1),
        ),
        isNull,
      );
    });
  });

  group('the screen', () {
    useTestMotion();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AssetPackService.instance
          .debugConfigure(padAssets: const {}, bundled: true);
      FeedbackService.debugMute = true;
    });

    tearDown(() => FeedbackService.debugMute = false);

    final packs = [
      pack('animals', ['cat', 'dog', 'cow', 'bear', 'frog']),
      pack('transport', ['avtobus', 'poizd', 'litak']),
      pack('food', ['apple', 'banana', 'grapes', 'kavun']),
    ];

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: OddOneOutScreen(packs: packs)),
        ),
      );
      await tester.pump();
    }

    Finder tiles() => find.byType(AnswerFrame);

    /// The four card words on the board. A card whose webp is absent in the
    /// test bundle draws its fallback emoji through `CardImage`, so the
    /// glyphs are filtered out — only the labels are words.
    List<String> boardWords(WidgetTester tester) {
      final known = {for (final p in packs) for (final c in p.cards) c.sound};
      return tester
          .widgetList<Text>(find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .whereType<String>()
          .where(known.contains)
          .toList();
    }

    testWidgets('deals a board whose odd card is odd by picture', (
      tester,
    ) async {
      await open(tester);
      expect(tiles(), findsNWidgets(4));

      final words = boardWords(tester);
      expect(words, hasLength(4));

      final groups = <SemanticGroup, int>{};
      for (final word in words) {
        final group = SemanticGroups.of(card(word));
        expect(group, isNotNull, reason: '$word sorts into no group');
        groups[group!] = (groups[group] ?? 0) + 1;
      }
      // Three of one, one of another — that is the whole question.
      expect(groups.values.toList()..sort(), [1, 3]);
    });

    testWidgets('the demonstration plays after the answer and the next '
        'question still arrives on time', (tester) async {
      await open(tester);

      // Find the odd tile: the minority group on the board.
      final words = boardWords(tester);
      final counts = <SemanticGroup, List<String>>{};
      for (final word in words) {
        counts.putIfAbsent(SemanticGroups.of(card(word))!, () => []).add(word);
      }
      final odd = counts.values.firstWhere((w) => w.length == 1).single;

      await tester.tap(find.text(odd));
      await tester.pump();

      // Straight after the answer the board is explaining itself: the odd
      // card has left its slot, the group has closed in.
      final demos = tester.widgetList<AnimatedSlide>(
        find.byType(AnimatedSlide),
      );
      expect(demos, isNotEmpty);

      // …and it is over inside the round gap: a new board is dealt, and it
      // is tappable again (the demo is not a modal wait).
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(4));
      expect(
        tester
            .widgetList<AnswerFrame>(tiles())
            .where((f) => f.mark == AnswerMark.correct),
        isEmpty,
        reason: 'the new question starts unanswered',
      );
    });
  });
}

extension on CardModel {
  /// The same card as it arrives from a different pack — same picture,
  /// different id. Grouping is keyed on the picture, so this must sort the
  /// same way.
  CardModel copyless() => CardModel(
        id: '${id}_2',
        sound: sound,
        text: text,
        emoji: emoji,
        colorBg: colorBg,
        colorAccent: colorAccent,
        image: image,
        audioKey: audioKey,
      );
}
