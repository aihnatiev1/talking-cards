import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/widgets/animal_friend_art.dart';
import '../screens/play_experience_test.dart' show screenshot;

void main() {
  testWidgets('all lesson companions render as separate atlas cells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFE9F6EE),
          body: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ColoredBox(
              color: const Color(0xFFE9F6EE),
              child: Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final animal in [
                      'cow',
                      'cat',
                      'dog',
                      'horse',
                      'pig',
                      'chicken',
                      'duck',
                      'frog',
                      'fish',
                    ])
                      SizedBox(
                        width: 170,
                        height: 210,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: AnimalFriendArt(animal: animal),
                            ),
                            Text(animal),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await screenshot(tester, '09-all-animal-companions');
    expect(find.byType(Image), findsNWidgets(9));
    expect(tester.takeException(), isNull);
  });
}
