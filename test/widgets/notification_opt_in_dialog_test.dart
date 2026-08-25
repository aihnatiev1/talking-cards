import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/services/notification_service.dart';
import 'package:talking_cards/widgets/notification_opt_in_dialog.dart';

/// The pre-prompt replaced an OS permission dialog that used to be awaited
/// during splash init. It must ask at most once, and must never ask parents
/// who already answered in an older build.
void main() {
  Widget host() => ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => maybeAskNotificationOptIn(context, ref),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      );

  Future<void> tapAsk(WidgetTester tester) async {
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
  }

  testWidgets('"not now" is remembered and never asks again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host());

    await tapAsk(tester);
    expect(find.text('Нагадувати про заняття?'), findsOneWidget);

    await tester.tap(find.text('Не зараз'));
    await tester.pumpAndSettle();

    expect(await NotificationService.instance.isEnabled, isFalse);
    expect(await NotificationService.instance.permissionAsked, isTrue);

    await tapAsk(tester);
    expect(find.text('Нагадувати про заняття?'), findsNothing);
  });

  testWidgets('upgraders who already have the flag are not re-asked',
      (tester) async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': true});
    await tester.pumpWidget(host());

    await tapAsk(tester);

    expect(find.text('Нагадувати про заняття?'), findsNothing);
  });
}
