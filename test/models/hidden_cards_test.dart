import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';

/// A card marked `"hidden": true` in the catalogue must not reach the app.
///
/// It is how a card whose illustration is wrong waits for a new one: the
/// text, the recording and the id stay in the JSON, and nothing — packs,
/// games, colouring, quest, SRS — ever sees it, because they all read the
/// same parsed packs.
void main() {
  Map<String, dynamic> card(String id) => {
        'id': id,
        'sound': id,
        'text': id,
        'emoji': '🐶',
        'colorBg': '#FFFFFF',
        'colorAccent': '#000000',
        'audio': id,
      };

  test('hidden cards never survive parsing', () {
    final pack = PackModel.fromJson({
      'id': 'p',
      'title': 't',
      'icon': '🐶',
      'color': '#FFFFFF',
      'cards': [
        card('shown'),
        {...card('gone'), 'hidden': true},
        {...card('also'), 'hidden': false},
      ],
    });

    expect(pack.cards.map((c) => c.id), ['shown', 'also']);
  });

  test('the six pulled pictures are out of both catalogues', () {
    // owl, car, pie, egg, sit, sea — pulled 2026-09-14 pending new art.
    const pulled = {
      'en': ['en_a21', 'en_sl16', 'en_ac14', 'en_fd16', 'en_fd28', 'en_t01',
          'en_ss13'],
      'uk': ['a21', 'sc04', 'act15', 'f16', 'f28', 'sts06', 't01', 'ss08'],
    };
    for (final entry in pulled.entries) {
      final raw = File('assets/data/${entry.key}_cards.json').readAsStringSync();
      final packs = (jsonDecode(raw) as List<dynamic>)
          .map((p) => PackModel.fromJson(p as Map<String, dynamic>))
          .toList();
      final live = {for (final p in packs) for (final c in p.cards) c.id};
      for (final id in entry.value) {
        expect(live, isNot(contains(id)), reason: '${entry.key}/$id is showing');
      }
    }
  });
}
