import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talking_cards/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TalkingCardsApp()));
    await tester.pump();
    // App should at least render without crashing
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
