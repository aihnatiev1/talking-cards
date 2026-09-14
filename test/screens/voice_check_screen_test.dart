import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/screens/voice_check_screen.dart';
import 'package:talking_cards/services/listen_service.dart';

void main() {
  testWidgets('the HUD borrows the microphone and gives it back', (
    tester,
  ) async {
    final listen = ListenService.instance;
    listen.debugSilentMode = true;
    listen.enabled.value = false;
    addTearDown(() {
      listen.debugSilentMode = false;
      listen.enabled.value = false;
      listen.debugReset();
    });

    await tester.pumpWidget(
      const MaterialApp(home: VoiceCheckScreen(isEn: false)),
    );
    expect(listen.enabled.value, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(listen.enabled.value, isFalse);
  });

  testWidgets('without permission it says so instead of pretending', (
    tester,
  ) async {
    final listen = ListenService.instance;
    // debugSilentMode reports no permission, which is the branch a parent
    // hits before granting it in iOS Settings.
    listen.debugSilentMode = true;
    addTearDown(() {
      listen.debugSilentMode = false;
      listen.enabled.value = false;
      listen.debugReset();
    });

    await tester.pumpWidget(
      const MaterialApp(home: VoiceCheckScreen(isEn: true)),
    );
    await tester.tap(find.text('Listen'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No microphone permission'), findsOneWidget);
  });
}
