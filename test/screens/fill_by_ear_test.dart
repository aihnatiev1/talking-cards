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

  test('crayon ids are unique, so an answer is unambiguous', () {
    expect(kCrayons.map((c) => c.id).toSet().length, kCrayons.length);
  });
}
