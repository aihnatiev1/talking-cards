import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/cards_screen.dart';

/// Start-index rule for re-opening a pack (design audit 2026-09-08, #22):
/// resume on the first card not yet reached, never past the deck, never on
/// virtual packs.
void main() {
  group('CardsScreen.resumeIndex', () {
    test('never-opened pack starts at 0', () {
      expect(CardsScreen.resumeIndex(null, 10, 'phrases'), 0);
      expect(CardsScreen.resumeIndex(0, 10, 'phrases'), 0);
    });

    test('resumes on the first card not yet reached', () {
      // progress = highest index reached + 1 → that IS the next card.
      expect(CardsScreen.resumeIndex(1, 10, 'phrases'), 1);
      expect(CardsScreen.resumeIndex(4, 10, 'phrases'), 4);
      expect(CardsScreen.resumeIndex(9, 10, 'phrases'), 9);
    });

    test('fully seen pack starts over', () {
      expect(CardsScreen.resumeIndex(10, 10, 'phrases'), 0);
      // Stale progress from before a pack shrank (or a locked preview that
      // shows fewer cards than were once seen) must still clamp to 0.
      expect(CardsScreen.resumeIndex(25, 10, 'phrases'), 0);
    });

    test('virtual packs always start at 0', () {
      expect(CardsScreen.resumeIndex(3, 10, '_favorites'), 0);
      expect(CardsScreen.resumeIndex(3, 10, '_review'), 0);
    });

    test('empty deck is safe', () {
      expect(CardsScreen.resumeIndex(3, 0, 'phrases'), 0);
      expect(CardsScreen.resumeIndex(null, 0, 'phrases'), 0);
    });
  });
}
