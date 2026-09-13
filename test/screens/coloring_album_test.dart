import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/coloring_album_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/coloring_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';

import '../helpers/motion.dart';

/// The colouring tab after experience audit 2026-09-13, п. 24.
///
/// Three promises: a picture a child finishes joins an album that is theirs
/// and survives the app being closed; the picture they left half-revealed is
/// waiting next time; and the finger demonstration runs once per profile, not
/// every visit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CardModel card(String id, String image) => CardModel(
        id: id,
        sound: id,
        text: id,
        emoji: '🐶',
        colorBg: const Color(0xFFFFFFFF),
        colorAccent: const Color(0xFF000000),
        image: image,
        audioKey: id,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: true);
    FeedbackService.debugMute = true;
  });

  tearDown(() => FeedbackService.debugMute = false);

  group('the album', () {
    test('a finished picture joins it, newest first', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final album = container.read(coloringAlbumProvider.notifier);
      await album.ready;

      await album.record(card('cat', 'cat'));
      await album.record(card('dog', 'dog'));

      final entries = container.read(coloringAlbumProvider).entries;
      expect(entries.map((e) => e.image), ['dog', 'cat']);
      expect(entries.first.revealedAt.isAfter(DateTime(2020)), isTrue);
    });

    test('survives a restart', () async {
      final first = ProviderContainer();
      final album = first.read(coloringAlbumProvider.notifier);
      await album.ready;
      await album.record(card('cat', 'cat'));
      first.dispose();

      // A new container over the same (mock) prefs is what a cold start is.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(coloringAlbumProvider.notifier).ready;

      expect(
        second.read(coloringAlbumProvider).entries.map((e) => e.image),
        ['cat'],
      );
      expect(second.read(coloringAlbumProvider).loaded, isTrue);
    });

    test('the same picture twice is one keepsake, moved to the front',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final album = container.read(coloringAlbumProvider.notifier);
      await album.ready;

      await album.record(card('cat', 'cat'));
      await album.record(card('dog', 'dog'));
      await album.record(card('cat', 'cat'));

      expect(
        container.read(coloringAlbumProvider).entries.map((e) => e.image),
        ['cat', 'dog'],
      );
    });

    test('an unfinished picture is remembered, and finishing it clears that',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final album = container.read(coloringAlbumProvider.notifier);
      await album.ready;

      await album.setUnfinished('cat');
      expect(container.read(coloringAlbumProvider).unfinishedCardId, 'cat');

      await album.record(card('cat', 'cat'));
      expect(container.read(coloringAlbumProvider).unfinishedCardId, isNull);
    });

    test('a corrupt line is skipped, not thrown over', () async {
      SharedPreferences.setMockInitialValues({
        'coloring_album': ['broken', 'cat|cat|2026-09-13T10:00:00.000'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(coloringAlbumProvider.notifier).ready;

      expect(
        container.read(coloringAlbumProvider).entries.map((e) => e.image),
        ['cat'],
      );
    });
  });

  group('the colouring tab', () {
    // Freezes Bloom's idle loops so `pumpAndSettle` terminates; the ghost
    // finger itself is a one-shot and still runs (see `showHand`).
    useTestMotion();

    final packs = [
      PackModel(
        id: 'animals',
        title: 'animals',
        icon: '🐶',
        color: const Color(0xFF6C63FF),
        isLocked: false,
        isFree: true,
        cards: [card('cat', 'cat'), card('dog', 'dog')],
      ),
    ];

    Future<ProviderContainer> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        packsProvider.overrideWith((ref) async => packs),
        // Keeps `PurchaseService` (and a billing channel that does not
        // exist in a test) out of the free-allowance check.
        isProProvider.overrideWith((ref) => false),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ColoringScreen()),
        ),
      );
      // The canvas decodes a real webp into a `ui.Image`; that needs the
      // real event loop, which in a widget test means `runAsync`.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('shows once per profile and never again', (tester) async {
      final container = await open(tester);
      addTearDown(container.dispose);

      // First visit: the ghost finger is on the canvas…
      expect(find.byKey(const ValueKey('ghost-finger')), findsOneWidget);

      // …it finishes on its own and the profile remembers that.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(container.read(coloringAlbumProvider).handHintSeen, isTrue);
      expect(find.byKey(const ValueKey('ghost-finger')), findsNothing);

      // Second visit, same profile, same prefs: no demonstration.
      await tester.pumpWidget(const SizedBox.shrink());
      final again = await open(tester);
      addTearDown(again.dispose);
      expect(find.byKey(const ValueKey('ghost-finger')), findsNothing);
    });

    testWidgets('a real finger interrupts it', (tester) async {
      final container = await open(tester);
      addTearDown(container.dispose);
      expect(find.byKey(const ValueKey('ghost-finger')), findsOneWidget);

      final canvas = find.byType(CustomPaint).first;
      final centre = tester.getCenter(canvas);
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const ValueKey('ghost-finger')), findsNothing);
      expect(container.read(coloringAlbumProvider).handHintSeen, isTrue);
    });

    testWidgets('a picture revealed to the end joins the album', (
      tester,
    ) async {
      final container = await open(tester);
      addTearDown(container.dispose);
      expect(container.read(coloringAlbumProvider).entries, isEmpty);

      // Sweep the whole canvas the way a child eventually does — the screen
      // calls a picture finished at 85 % of its cells. The canvas is the
      // biggest painted box that is not the screen-wide background.
      final screen = tester.getRect(find.byType(MaterialApp));
      final canvas = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => tester.getRect(find.byWidget(w)))
          .where((r) => r != screen)
          .reduce((a, b) => a.width * a.height >= b.width * b.height ? a : b);
      for (var i = 0; i <= 16; i++) {
        final y = canvas.top + canvas.height * (i / 16);
        final gesture = await tester.startGesture(Offset(canvas.left + 4, y));
        for (var x = 0.0; x <= canvas.width; x += 12) {
          await gesture.moveTo(Offset(canvas.left + x, y));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
      }

      // Recorded under this profile — the album is now invisible storage
      // (it remembers what was finished), not a shelf the child must visit.
      final album = container.read(coloringAlbumProvider);
      expect(album.entries, hasLength(1));
      expect(['cat', 'dog'], contains(album.entries.single.image));
      expect(album.unfinishedCardId, isNull);
      await tester.pump();
      // One control, centred, with its word on it — no icon-only twin.
      expect(find.text('Нова картинка'), findsOneWidget);
      expect(find.textContaining('Мої картинки'), findsNothing);
      // Let the celebration's confetti timer run out before the tree goes.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the picture left unfinished is the one waiting next time', (
      tester,
    ) async {
      final container = await open(tester);
      addTearDown(container.dispose);
      await tester.pumpAndSettle();

      final left = container.read(coloringAlbumProvider).unfinishedCardId;
      expect(left, isNotNull, reason: 'the current picture is remembered');

      await tester.pumpWidget(const SizedBox.shrink());
      final again = await open(tester);
      addTearDown(again.dispose);
      await tester.pumpAndSettle();

      expect(again.read(coloringAlbumProvider).unfinishedCardId, left);
    });
  });
}
