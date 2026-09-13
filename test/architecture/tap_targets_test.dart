import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/kid_screen.dart';
import 'package:talking_cards/widgets/kid_tap.dart';
import 'package:talking_cards/widgets/profile_avatar_chip.dart';
import 'package:talking_cards/widgets/quiz_option.dart';
import 'package:talking_cards/widgets/speaker_button.dart';
import 'package:talking_cards/widgets/streak_chip.dart';
import 'package:talking_cards/widgets/treasure_card.dart';

import '../helpers/motion.dart';

/// Rule 1 of CLAUDE.md, pinned: nothing a 1–4-year-old is asked to hit is
/// smaller than [DTSize.tapMin] (72 dp) in either direction.
///
/// The measurement is the **hit zone**, not the drawing: a close control may
/// stay a small grey glyph as long as the finger has 72 dp to land in, which
/// is why the assert reads the size of the `KidTap` (or of the widget under
/// test when it owns its own detector) rather than of the icon inside it.
///
/// [_exceptions] is the agreed list of targets that are deliberately under
/// the minimum. It is **shrink-only**: an entry leaves when the widget grows
/// to 72, and a new one is a design decision, not a test edit.
void main() {
  useTestMotion();

  /// name → smallest allowed edge. Empty on purpose: every widget covered
  /// below reaches the full 72 dp today. When a case has to sit lower
  /// (a deliberately discouraged exit, say), it is named here with a
  /// reason and a number, never silently shrunk in the widget.
  const Map<String, double> exceptions = {};

  const card = CardModel(
    id: 'cat',
    sound: 'Кіт',
    text: 'Це кіт',
    emoji: '🐱',
    colorBg: Color(0xFFFFF4E0),
    colorAccent: Color(0xFF6C63FF),
  );

  final cases = <String, Widget>{
    'KidBackButton': const KidBackButton(accent: DT.brand),
    'KidCloseButton': const KidCloseButton(accent: DT.brand),
    'SpeakerButton': const SpeakerButton(),
    'StreakChip': StreakChip(streak: 3, onTap: () {}),
    'TreasureCard': TreasureCard(done: 2, total: 5, onTap: () {}),
    'QuizOption': SizedBox(
      width: 160,
      height: 160,
      child: QuizOption(card: card, onTap: () {}),
    ),
    'ProfileAvatarChip': const ProfileAvatarChip(),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} gives the finger at least 72 dp', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Center(child: entry.value)),
          ),
        ),
      );
      await tester.pump();

      final taps = find.byType(KidTap);
      expect(
        taps,
        findsWidgets,
        reason: '${entry.key} must answer a tap through KidTap',
      );
      final min = exceptions[entry.key] ?? DT.size.tapMin;
      for (var i = 0; i < taps.evaluate().length; i++) {
        final size = tester.getSize(taps.at(i));
        expect(
          size.width,
          greaterThanOrEqualTo(min),
          reason: '${entry.key} hit zone is ${size.width} dp wide',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(min),
          reason: '${entry.key} hit zone is ${size.height} dp tall',
        );
      }
    });
  }
}
