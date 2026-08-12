import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/audio_service.dart';

/// Content integrity: every audio key referenced by any locale's cards JSON
/// (and the seasonal packs) must resolve — via the _audioMap alias table or
/// by identity — to an mp3 that is actually bundled in assets/audio_mp3/.
/// A missing file would fail silently at runtime (the card plays nothing).
void main() {
  Iterable<(String pack, String card, String key)> audioKeys(String path) sync* {
    final packs =
        json.decode(File(path).readAsStringSync()) as List<dynamic>;
    for (final p in packs) {
      final pack = p as Map<String, dynamic>;
      for (final c in pack['cards'] as List<dynamic>) {
        final card = c as Map<String, dynamic>;
        final key = card['audio'] as String?;
        if (key != null) {
          yield (pack['id'] as String, card['id'] as String, key);
        }
      }
    }
  }

  for (final manifest in [
    'assets/data/uk_cards.json',
    'assets/data/en_cards.json',
    'assets/data/seasonal_packs.json',
  ]) {
    test('$manifest: every audio key resolves to a bundled mp3', () {
      final missing = <String>[];
      for (final (pack, card, key) in audioKeys(manifest)) {
        final file = AudioService.resolveFileForTesting(key);
        if (!File('assets/audio_mp3/$file.mp3').existsSync()) {
          missing.add('$pack/$card: "$key" -> assets/audio_mp3/$file.mp3');
        }
      }
      expect(missing, isEmpty,
          reason: 'audio files missing from the bundle:\n${missing.join('\n')}');
    });
  }
}
