import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/services/audio_service.dart';

/// Pins the real shipped content manifests so a locale refactor can never
/// silently change what uk/en users see: pack ids, order, card counts, lock
/// flags and the category ids injected in the multilingual refactor.
void main() {
  List<PackModel> load(String lang) {
    final raw = File('assets/data/${lang}_cards.json').readAsStringSync();
    return (json.decode(raw) as List<dynamic>)
        .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  group('uk_cards.json', () {
    final packs = load('uk');

    test('pack ids, order and categories are pinned', () {
      expect(
        [for (final p in packs) '${p.id}:${p.category}'],
        [
          'rozmovlyalky:speech',
          'animals:world',
          'home:world',
          'emotions:world',
          'transport:world',
          'food:world',
          'colors:world',
          'body:world',
          'phrases:speech',
          'actions:speech',
          'opposites:speech',
          'sound_r:sounds',
          'sound_l:sounds',
          'sound_sh:sounds',
          'sound_s:sounds',
          'sound_z:sounds',
          'sound_zh:sounds',
          'sound_ch:sounds',
          'sound_shch:sounds',
          'sound_ts:sounds',
          'adjectives:speech',
          'poems:speech',
        ],
      );
    });

    test('card counts and lock flags are pinned', () {
      expect(
        {for (final p in packs) p.id: (p.cards.length, p.isLocked)},
        {
          'rozmovlyalky': (25, false),
          'animals': (29, false),
          'home': (30, true),
          'emotions': (30, true),
          'transport': (30, true),
          'food': (30, true),
          'colors': (30, true),
          'body': (30, true),
          'phrases': (25, true),
          'actions': (25, true),
          'opposites': (30, true),
          'sound_r': (17, false),
          'sound_l': (18, true),
          'sound_sh': (16, true),
          'sound_s': (16, true),
          'sound_z': (16, true),
          'sound_zh': (13, true),
          'sound_ch': (15, true),
          'sound_shch': (11, true),
          'sound_ts': (12, true),
          'adjectives': (23, true),
          'poems': (28, true),
        },
      );
    });
  });

  group('en_cards.json', () {
    final packs = load('en');

    test('pack ids, order and categories are pinned', () {
      expect(
        [for (final p in packs) '${p.id}:${p.category}'],
        [
          'en_animals:world',
          'en_home:world',
          'en_emotions:world',
          'en_transport:world',
          'en_food:world',
          'en_colors:world',
          'en_body:world',
          'en_actions:speech',
          'en_opposites:speech',
          'en_phrases:speech',
          'en_adjectives:speech',
          'en_sound_r:sounds',
          'en_sound_l:sounds',
          'en_sound_s:sounds',
          'en_sound_z:sounds',
          'en_sound_sh:sounds',
          'en_sound_zh:sounds',
          'en_sound_ch:sounds',
          'en_sound_th:sounds',
          'en_sound_w:sounds',
          'en_sound_bl:sounds',
        ],
      );
    });

    test('card counts and lock flags are pinned', () {
      expect(
        {for (final p in packs) p.id: (p.cards.length, p.isLocked)},
        {
          'en_animals': (29, false),
          'en_home': (30, true),
          'en_emotions': (12, true),
          'en_transport': (25, true),
          'en_food': (30, true),
          'en_colors': (30, true),
          'en_body': (30, true),
          'en_actions': (25, false),
          'en_opposites': (30, true),
          'en_phrases': (25, true),
          'en_adjectives': (13, true),
          'en_sound_r': (16, false),
          'en_sound_l': (16, true),
          'en_sound_s': (16, true),
          'en_sound_z': (13, true),
          'en_sound_sh': (15, true),
          'en_sound_zh': (6, true),
          'en_sound_ch': (15, true),
          'en_sound_th': (16, true),
          'en_sound_w': (14, true),
          'en_sound_bl': (18, true),
        },
      );
    });
  });

  group('game-pool filter equivalence', () {
    // The games tab used a uk-only branch `audioKey != null && image != null`
    // vs the en branch `image != null && hasSound(audioKey)`. Unifying on the
    // en form is byte-identical ONLY while both facts below hold — this test
    // pins them against the shipped manifests + _audioMap.
    for (final lang in ['uk', 'en']) {
      test('$lang: hasSound(audioKey) == (audioKey != null) for every card',
          () {
        for (final pack in load(lang)) {
          for (final card in pack.cards) {
            expect(
              AudioService.instance.hasSound(card.audioKey),
              card.audioKey != null,
              reason: '${pack.id}/${card.id}: audioKey=${card.audioKey} is '
                  'not resolvable by AudioService',
            );
          }
        }
      });

      test('$lang: every pack has at least one illustrated card', () {
        for (final pack in load(lang)) {
          expect(pack.cards.any((c) => c.image != null), isTrue,
              reason: '${pack.id} has no card with an image — the unified '
                  'odd-one-out pool filter would drop it');
        }
      });
    }
  });
}
