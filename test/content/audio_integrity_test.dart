import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/services/audio_service.dart';

/// Content/audio integrity, resolved EXACTLY the way the app does:
/// [CardModel.audioKey] is `audio ?? image` — a card without an explicit
/// `audio` field falls back to its image name, which may have no recording.
///
/// Invariants pinned here:
///  * every EXPLICIT `audio` key resolves (via _audioMap ∪ identity) to an
///    mp3 that is actually bundled, and is playable ([hasSound] == true);
///  * image-fallback keys are playable IFF their mp3 exists — in particular
///    the 11 silent seasonal cards must stay hasSound == false even after
///    registerKeys, because AudioService gates runtime registration on the
///    real asset manifest. Reverting that guard turns this suite red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Production path: the same AssetManifest load precache() performs.
    await AudioService.instance.ensureAudioManifestLoaded();
  });

  List<(String pack, Map<String, dynamic> json, CardModel card)> cards(
      String path) {
    final packs = json.decode(File(path).readAsStringSync()) as List<dynamic>;
    return [
      for (final p in packs)
        for (final c in (p as Map<String, dynamic>)['cards'] as List<dynamic>)
          (
            p['id'] as String,
            c as Map<String, dynamic>,
            CardModel.fromJson(c),
          ),
    ];
  }

  bool bundled(String key) => File(
        'assets/audio_mp3/${AudioService.resolveFileForTesting(key)}.mp3',
      ).existsSync();

  for (final manifest in [
    'assets/data/uk_cards.json',
    'assets/data/en_cards.json',
    'assets/data/seasonal_packs.json',
  ]) {
    test('$manifest: audio keys resolve exactly as the app resolves them',
        () {
      final all = cards(manifest);
      // Register everything, like packsProvider/seasonal provider do —
      // the manifest gate inside registerKeys must keep silent keys out.
      AudioService.instance.registerKeys(
          [for (final (_, _, c) in all) if (c.audioKey != null) c.audioKey!]);

      final problems = <String>[];
      for (final (pack, raw, card) in all) {
        final key = card.audioKey;
        final explicit =
            (raw['audio'] as String?)?.trim().isNotEmpty ?? false;
        if (key == null) {
          if (AudioService.instance.hasSound(key)) {
            problems.add('$pack/${card.id}: null key reported playable');
          }
          continue;
        }
        if (explicit) {
          // Declared audio must be bundled AND playable.
          if (!bundled(key)) {
            problems.add('$pack/${card.id}: declared audio "$key" has no '
                'bundled mp3');
          }
          if (!AudioService.instance.hasSound(key)) {
            problems.add('$pack/${card.id}: declared audio "$key" not '
                'playable (hasSound == false)');
          }
        } else {
          // Image-fallback key: playable IFF the mp3 exists in the bundle.
          final expected = bundled(key);
          final actual = AudioService.instance.hasSound(key);
          if (actual != expected) {
            problems.add('$pack/${card.id}: fallback key "$key" — '
                'hasSound=$actual but bundled mp3 exists=$expected');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  test('the 11 silent seasonal image-fallback cards are NOT playable', () {
    const silentKeys = [
      'podarunok', 'dzvinochok', 'mandaryn', 'hirlyanda', 'kazka',
      'krab', 'lystya', 'hryby', 'doshch', 'zholud', 'horobets',
    ];
    // Even after an explicit registration attempt (what the seasonal
    // provider effectively does), the manifest gate must reject them.
    AudioService.instance.registerKeys(silentKeys);
    for (final key in silentKeys) {
      expect(AudioService.instance.hasSound(key), isFalse,
          reason: '"$key" has no assets/audio_mp3/$key.mp3 — reporting it '
              'playable stalls auto-play on that card');
    }
  });
}
