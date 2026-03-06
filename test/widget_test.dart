import 'package:flutter_test/flutter_test.dart';

import 'package:smartapp/main.dart';

void main() {
  testWidgets('App renders home screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartApp());
    expect(find.textContaining('Розмовлялки'), findsOneWidget);
  });
}
