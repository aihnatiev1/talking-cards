import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/crayon_palette.dart';

/// The listening mode asks for a colour by name, so every crayon must
/// have a recording behind it — the words are cards in the `colors` pack,
/// keyed in English (red, blue…) with the Ukrainian voice on top.
void main() {
  // Keys present in assets/data/uk_cards.json, pack `colors`.
  const recorded = {
    'red', 'blue', 'yellow', 'green', 'white', 'black',
    'orange', 'pink', 'purple', 'brown', 'gray',
  };

  // And in assets/data/en_cards.json, pack `en_colors`.
  const recordedEn = {
    'en_red', 'en_blue', 'en_yellow', 'en_green', 'en_white', 'en_black',
    'en_orange_c', 'en_pink', 'en_purple', 'en_brown', 'en_gray',
  };

  test('every crayon has a colour word that is actually recorded', () {
    for (final crayon in kCrayons) {
      expect(
        recorded.contains(crayon.audio),
        isTrue,
        reason: 'no recording for «${crayon.name}» (key "${crayon.audio}") '
            '— the '
            'listening mode would ask for a colour it cannot say',
      );
    }
  });

  test('every crayon has an English take too', () {
    // The English app asked for its colours in Ukrainian: the crayons
    // carried one audio key, and it was the Ukrainian one. An English
    // child heard «жовтий» and was expected to find yellow.
    for (final crayon in kCrayons) {
      expect(
        recordedEn.contains(crayon.audioEn),
        isTrue,
        reason: 'no English recording for ${crayon.nameEn} '
            '(key "${crayon.audioEn}")',
      );
    }
  });

  test('crayon ids are unique, so an answer is unambiguous', () {
    expect(kCrayons.map((c) => c.id).toSet().length, kCrayons.length);
  });
}
