import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/sticker_scene_screen.dart';

/// The youngest drawing mode: nothing can be wrong, and every sticker is
/// a word said out loud.
void main() {
  testWidgets('with no packs it asks for one instead of showing an empty '
      'meadow', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: StickerSceneScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Відкрий хоча б один пак'), findsOneWidget);
  });
}
