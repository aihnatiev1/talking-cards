import 'package:flutter_test/flutter_test.dart';

import 'package:talking_cards/main.dart';

void main() {
  testWidgets('App renders home screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const TalkingCardsApp());
    expect(find.textContaining('Розмовлялки'), findsOneWidget);
  });
}
