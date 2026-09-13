import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/practice_suggestion_provider.dart';
import 'package:talking_cards/providers/word_evidence_provider.dart';
import 'package:talking_cards/screens/parent_dashboard_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';

/// A parent reads the dashboard as evidence about their child. So the three
/// things the app can actually observe must stay three things:
///
///   seen       — the card was on screen
///   recognized — the child picked it correctly in a game
///   marked     — a grown-up said it came out
///
/// Collapsing them into one number called "learned" is the lie this test
/// exists to prevent (audit §28).
CardModel _card(String id) => CardModel.fromJson({
  'id': id,
  'sound': id.toUpperCase(),
  'text': '',
  'image': '$id.webp',
  'audio': id,
  'emoji': '🐱',
  'colorBg': '#FFFFFF',
  'colorAccent': '#000000',
});

PackModel _pack(List<CardModel> cards) => PackModel(
  id: 'animals',
  title: 'Тваринки',
  icon: '🐱',
  color: Colors.orange,
  isLocked: false,
  isFree: true,
  cards: cards,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
  });

  group('word evidence keeps the three signals apart', () {
    test('a game answer and a grown-up mark land in different buckets', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(wordEvidenceProvider.notifier);

      await notifier.recordRecognized('cat');
      await notifier.recordParentMark('water');

      final state = container.read(wordEvidenceProvider);
      expect(state.recognizedIds, {'cat'});
      expect(state.parentMarkedIds, {'water'});
      expect(state.evidencedIds, {'cat', 'water'});
    });

    test('seeing a card is not evidence at all', () async {
      // pack_progress is how views are stored; the evidence map must stay
      // empty no matter how many cards scrolled past.
      SharedPreferences.setMockInitialValues({'pack_progress_animals': 40});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(packProgressProvider.notifier).updateProgress(
        'animals',
        39,
      );

      expect(container.read(packProgressProvider)['animals'], 40);
      expect(container.read(wordEvidenceProvider).evidencedIds, isEmpty);
    });

    test('the same word can carry both signals without double counting', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(wordEvidenceProvider.notifier);

      await notifier.recordRecognized('cat');
      await notifier.recordRecognized('cat');
      await notifier.recordParentMark('cat');

      final state = container.read(wordEvidenceProvider);
      expect(state['cat']!.recognized, 2);
      expect(state['cat']!.parentMarked, 1);
      expect(state.evidencedIds.length, 1);
    });

    test('the week window counts only the last seven days', () {
      final now = DateTime(2026, 9, 13);
      final state = <String, WordEvidence>{
        'fresh': WordEvidence(
          recognized: 1,
          recognizedDay: dayIndex(now.subtract(const Duration(days: 6))),
        ),
        'stale': WordEvidence(
          recognized: 1,
          recognizedDay: dayIndex(now.subtract(const Duration(days: 8))),
        ),
        'marked': WordEvidence(
          parentMarked: 1,
          parentMarkedDay: dayIndex(now),
        ),
      };

      expect(state.recognizedSince(7, now: now), 1);
      expect(state.parentMarkedSince(7, now: now), 1);
    });

    test('survives a restart', () async {
      final first = ProviderContainer();
      await first.read(wordEvidenceProvider.notifier).recordRecognized('cat');
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      // The notifier loads asynchronously on construction.
      second.read(wordEvidenceProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(wordEvidenceProvider).recognizedIds, {'cat'});
    });
  });

  group('practice suggestion', () {
    final cards = [_card('cat'), _card('water'), _card('ball'), _card('dog')];

    test('puts the most-missed words first', () {
      final picked = practiceSuggestion(
        mistakes: const {'ball': 1, 'cat': 5, 'water': 3},
        dueIds: const [],
        allCards: cards,
      );
      expect([for (final c in picked) c.id], ['cat', 'water', 'ball']);
    });

    test('fills up from cards due for review, without repeating', () {
      final picked = practiceSuggestion(
        mistakes: const {'cat': 2},
        dueIds: const ['cat', 'dog'],
        allCards: cards,
      );
      expect([for (final c in picked) c.id], ['cat', 'dog']);
    });

    test('stays empty rather than inventing a task', () {
      expect(
        practiceSuggestion(mistakes: const {}, dueIds: const [], allCards: cards),
        isEmpty,
      );
    });
  });

  testWidgets('the overview names all three signals separately', (
    tester,
  ) async {
    final cards = [_card('cat'), _card('water'), _card('ball')];
    SharedPreferences.setMockInitialValues({
      'pack_progress_animals': 3,
      'word_evidence_v1': jsonEncode({
        'cat': [2, 0, dayIndex(DateTime.now()), -1],
        'water': [0, 1, -1, dayIndex(DateTime.now())],
      }),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packsProvider.overrideWith((ref) async => [_pack(cards)]),
        ],
        child: const MaterialApp(home: ParentDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Переглянули'), findsOneWidget);
    expect(find.text('Впізнали у грі'), findsOneWidget);
    expect(find.text('Позначили ви'), findsOneWidget);

    // Three cards seen, one word recognized, one word marked — the numbers
    // must not agree with each other.
    expect(find.text('3 карток'), findsOneWidget);
    expect(find.text('1 слів'), findsNWidgets(2));

    // Nothing on this screen calls a viewed card "вивчене".
    expect(find.textContaining('вивчен'), findsNothing);

    expect(find.byKey(const ValueKey('weekly_summary_card')), findsOneWidget);

    // One concrete thing to do together, further down the same list.
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('practice_suggestion_card')),
      findsOneWidget,
    );
  });
}
