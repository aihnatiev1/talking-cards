import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A drawing that names a card the catalogue does not have would finish
/// in silence, and nobody would notice until a child did. The word is
/// content, so it is checked against the content.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every drawing that has a word points at a real card', () async {
    final index = json.decode(
      await rootBundle.loadString('assets/images/coloring/sheets.json'),
    ) as Map<String, dynamic>;
    final sheets = (index['sheets'] as List<dynamic>).cast<String>();
    expect(sheets, isNotEmpty);

    final cards = json.decode(
      await rootBundle.loadString('assets/data/uk_cards.json'),
    );
    final packs = (cards is List ? cards : cards['packs']) as List<dynamic>;
    final ids = {
      for (final pack in packs.cast<Map<String, dynamic>>())
        for (final card in (pack['cards'] as List<dynamic>)
            .cast<Map<String, dynamic>>())
          card['id'] as String,
    };

    for (final sheet in sheets) {
      final meta = json.decode(
        await rootBundle.loadString('assets/images/coloring/$sheet.json'),
      ) as Map<String, dynamic>;
      final word = meta['word'] as String?;
      if (word == null) continue;
      expect(
        ids.contains(word),
        isTrue,
        reason: '$sheet names card "$word", which no pack has',
      );
    }
  });

  test('every drawing in the index has areas to fill', () async {
    final index = json.decode(
      await rootBundle.loadString('assets/images/coloring/sheets.json'),
    ) as Map<String, dynamic>;
    for (final sheet in (index['sheets'] as List<dynamic>).cast<String>()) {
      final meta = json.decode(
        await rootBundle.loadString('assets/images/coloring/$sheet.json'),
      ) as Map<String, dynamic>;
      expect(
        (meta['areas'] as List<dynamic>),
        isNotEmpty,
        reason: '$sheet has nothing a child could colour',
      );
    }
  });

  test('every drawing has an outline that lets the paint through', () async {
    // The delivered artwork is line art on solid white, and white drawn
    // over the child's colours hides all of them — the screen showed an
    // empty outline no matter how much was painted. The generator writes
    // a knocked-out copy; without it the feature is invisible.
    final index = json.decode(
      await rootBundle.loadString('assets/images/coloring/sheets.json'),
    ) as Map<String, dynamic>;
    for (final sheet in (index['sheets'] as List<dynamic>).cast<String>()) {
      final ink = await rootBundle.load(
        'assets/images/coloring/$sheet.ink.png',
      );
      expect(ink.lengthInBytes, greaterThan(0), reason: '$sheet has no ink layer');
    }
  });
}
