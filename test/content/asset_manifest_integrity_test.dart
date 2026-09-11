import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/audio_service.dart';

/// Every illustration and clip a card names must exist somewhere in the
/// build — either bundled or inside `assets/pad_content/`.
///
/// This is the half of "content may be missing" that no runtime fallback
/// should be asked to cover. A typo in the JSON, a card added without its
/// webp, or a `tools/pad_split.py` run that moved a file and not its
/// sibling used to surface as a failed decode on a child's device (and,
/// because main.dart routes FlutterError into recordFlutterFatalError, as
/// a fatal crash). Here it is a red test instead.
void main() {
  /// Both roots are equivalent at runtime — [AssetPackService] resolves a
  /// name to whichever one holds it.
  bool exists(String kind, String name, String ext) =>
      File('assets/$kind/$name.$ext').existsSync() ||
      File('assets/pad_content/$kind/$name.$ext').existsSync();

  /// Every card in every pack of [file], as (packId, card) pairs.
  Iterable<(String, Map<String, dynamic>)> cardsOf(String file) sync* {
    final raw = File('assets/data/$file').readAsStringSync();
    for (final pack in jsonDecode(raw) as List) {
      final p = pack as Map<String, dynamic>;
      for (final card in (p['cards'] as List? ?? const [])) {
        yield (p['id'] as String, card as Map<String, dynamic>);
      }
    }
  }

  // Drafts are work in progress and deliberately not shipped.
  const shipped = ['uk_cards.json', 'en_cards.json', 'seasonal_packs.json'];

  for (final file in shipped) {
    group(file, () {
      test('every named illustration exists', () {
        final missing = <String>[];
        for (final (packId, card) in cardsOf(file)) {
          final image = card['image'] as String?;
          if (image != null && !exists('images/webp', image, 'webp')) {
            missing.add('$packId/${card['id']}: images/webp/$image.webp');
          }
        }
        expect(missing, isEmpty,
            reason: 'named in $file, absent from the build:\n'
                '${missing.join('\n')}');
      });

      test('every named clip is a known key and its file exists', () {
        // A card's `audio` is a key, not a filename: it may be a Cyrillic
        // alias the player maps to a Latin file. Both halves can break —
        // an unknown key is dropped silently, a known key can point at a
        // file nobody recorded. Silence is the worst failure this app has.
        final unknown = <String>[];
        final missing = <String>[];
        for (final (packId, card) in cardsOf(file)) {
          final audio = card['audio'] as String?;
          if (audio == null) continue;
          if (!AudioService.debugKnownKey(audio)) {
            unknown.add('$packId/${card['id']}: "$audio"');
            continue;
          }
          final clip = AudioService.debugAudioFile(audio);
          if (!exists('audio_mp3', clip, 'mp3')) {
            missing.add('$packId/${card['id']}: audio_mp3/$clip.mp3');
          }
        }
        expect(unknown, isEmpty,
            reason: 'not in the audio map, so never played:\n'
                '${unknown.join('\n')}');
        expect(missing, isEmpty,
            reason: 'named in $file, absent from the build:\n'
                '${missing.join('\n')}');
      });
    });
  }
}
