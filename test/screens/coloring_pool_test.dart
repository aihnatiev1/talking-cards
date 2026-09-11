import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/screens/coloring_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';

CardModel _card(String id, {String? image}) => CardModel(
      id: id,
      sound: id,
      text: id,
      emoji: '🙂',
      colorBg: const Color(0xFFFFFFFF),
      colorAccent: const Color(0xFF000000),
      image: image,
    );

PackModel _pack(String id, List<CardModel> cards) => PackModel(
      id: id,
      title: id,
      icon: '📦',
      color: const Color(0xFF000000),
      isLocked: false,
      isFree: true,
      cards: cards,
    );

/// Colouring-book pool + picker (design audit 2026-09-08, #25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every other test in this file runs on a bundled build, where nothing
  // needs downloading — the same shape as iOS and debug.
  setUp(() => AssetPackService.instance
      .debugConfigure(padAssets: const {}, bundled: true));

  group('ColoringScreen.coloringPool', () {
    test('drops pictures still inside an undelivered Play asset pack', () {
      // The colouring book decodes bytes itself, so a picture that is not
      // on the device is not a blank canvas — it threw out of a
      // fire-and-forget load (Crashlytics 2026-09-08, fatal) and left the
      // screen spinning forever. Keep it out of the pool entirely.
      AssetPackService.instance.debugConfigure(
        padAssets: const {'assets/pad_content/images/webp/paid.webp'},
        bundled: false,
      );
      final packs = [
        _pack('mixed', [
          _card('free_one', image: 'free_one'),
          _card('paid_one', image: 'paid'),
        ]),
      ];

      final ids = ColoringScreen.coloringPool(packs).map((c) => c.id);
      expect(ids, ['free_one']);
    });

    test('drops negative-mood images, null images, virtual and verse packs',
        () {
      final verseId = PackModel.nonWordPackIds.first;
      final packs = [
        _pack('emotions', [
          _card('happy', image: 'happy'),
          _card('sad', image: 'sad'),
          _card('angry', image: 'angry'),
          _card('hurts', image: 'en_it_hurts'),
        ]),
        _pack('animals', [
          _card('cat', image: 'cat'),
          _card('no_image'),
        ]),
        _pack('_favorites', [_card('fav', image: 'fav')]),
        _pack(verseId, [_card('poem', image: 'poem')]),
      ];

      final ids = ColoringScreen.coloringPool(packs).map((c) => c.id);

      expect(ids, ['happy', 'cat']);
    });

    test('every excluded image name is a real card image', () {
      // Guards against typos in the constant silently excluding nothing.
      for (final name in CardModel.calmingExcludedImages) {
        expect(name, isNotEmpty);
        expect(name.trim(), name);
      }
      expect(CardModel.calmingExcludedImages, contains('sad'));
      expect(CardModel.calmingExcludedImages, contains('angry'));
      expect(CardModel.calmingExcludedImages, contains('afraid'));
    });
  });

  group('ColoringScreen.pickNext', () {
    final pool = [
      _card('a', image: 'a'),
      _card('b', image: 'b'),
      _card('c', image: 'c'),
    ];

    test('never repeats the current card when the pool has a choice', () {
      final rng = math.Random(42);
      var current = pool.first;
      for (var i = 0; i < 500; i++) {
        final next = ColoringScreen.pickNext(pool, current, rng);
        expect(next.id, isNot(current.id));
        current = next;
      }
    });

    test('reaches every other card, including the last slot', () {
      final rng = math.Random(7);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(ColoringScreen.pickNext(pool, pool[1], rng).id);
      }
      expect(seen, {'a', 'c'});
    });

    test('single-card pool returns that card even if it is current', () {
      final single = [pool.first];
      final next = ColoringScreen.pickNext(single, pool.first, math.Random(1));
      expect(next.id, 'a');
    });

    test('no current card draws from the whole pool', () {
      final rng = math.Random(3);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(ColoringScreen.pickNext(pool, null, rng).id);
      }
      expect(seen, {'a', 'b', 'c'});
    });

    test('current card not in pool (language switch) draws from all', () {
      final rng = math.Random(5);
      final stranger = _card('zzz', image: 'zzz');
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(ColoringScreen.pickNext(pool, stranger, rng).id);
      }
      expect(seen, {'a', 'b', 'c'});
    });
  });
}
