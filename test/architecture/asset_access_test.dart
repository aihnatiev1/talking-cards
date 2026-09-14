import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-owner rule for card content.
///
/// Dart cannot express "only this widget may resolve an asset" — there is
/// no `internal` visibility and this project deliberately runs no custom
/// lints. A source test is the honest substitute, and it is the difference
/// between fixing 17 call sites once and fixing the 18th after it ships.
///
/// The rule exists because every bypass has the same failure mode: a
/// widget builds an `ImageProvider` over content that is not on the device
/// yet, the decode throws, and `main.dart` routes `FlutterError.onError`
/// into `recordFlutterFatalError` — so a picture that is merely still
/// downloading is filed as a fatal crash.
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Files allowed to resolve content themselves, and why.
  const resolvers = {
    // Defines the contract.
    'lib/services/asset_pack_service.dart',
    // The single owner of card rendering.
    'lib/widgets/card_image.dart',
    // Warms the image cache; a precache is not a widget.
    'lib/screens/cards_screen.dart',
    // Needs a ui.Image for its CustomPainter, so it consumes bytes.
    'lib/screens/coloring_screen.dart',
    // The audio equivalent of CardImage.
    'lib/services/audio_service.dart',
  };

  List<String> offenders(
    bool Function(String source) hasProblem, {
    Set<String> alsoAllowed = const {},
  }) =>
      [
        for (final f in dart)
          if (!resolvers.contains(f.path) &&
              !alsoAllowed.contains(f.path) &&
              hasProblem(f.readAsStringSync()))
            f.path,
      ];

  test('only the declared owners resolve card content', () {
    expect(
      offenders((s) =>
          s.contains('cardArt(') ||
          s.contains('cardBytes(') ||
          s.contains('cardVoice(')),
      isEmpty,
      reason: 'Render card art with CardImage instead. If a new file really '
          'needs raw resolution, add it to `resolvers` above with a reason.',
    );
  });

  test('the throwing asset API is gone', () {
    // cardImage/cardImageBytes/audioSource handed back paths and providers
    // for content that may not exist. Nothing may reintroduce them.
    expect(
      offenders((s) =>
          s.contains('.cardImage(') ||
          s.contains('.cardImageBytes(') ||
          s.contains('.audioSource(')),
      isEmpty,
      reason: 'Use cardArt / cardBytes / cardVoice.',
    );
  });

  test('nobody hand-builds an asset path', () {
    // A literal path skips the pad_content indirection entirely, so the
    // same picture works in debug and is missing in the Play build.
    expect(
      offenders((s) =>
          s.contains("'assets/images/webp/") ||
          s.contains("'assets/audio_mp3/") ||
          s.contains("'assets/pad_content/"),
          // The splash image is painted before AssetPackService.init()
          // has run, so it cannot go through the service and is bundled
          // unconditionally — that is what makes it a safe literal.
          alsoAllowed: const {'lib/screens/splash_screen.dart'}),
      isEmpty,
      reason: 'Ask AssetPackService — it knows which root holds the file.',
    );
  });
}
