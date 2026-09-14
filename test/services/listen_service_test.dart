import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/listen_service.dart';
import 'package:talking_cards/services/voice_gate.dart';

/// The guards that make the microphone safe to ship, tested where they
/// live — not in a UI that could stop calling them.
void main() {
  final listen = ListenService.instance;

  setUp(() {
    listen.debugReset();
    listen.debugSilentMode = true;
    // Same thresholds, a faster clock.
    listen.debugInterval = const Duration(milliseconds: 1);
    listen.enabled.value = false;
    AudioService.instance.isSpeaking.value = false;
  });

  tearDown(() {
    listen.debugSilentMode = false;
    listen.debugInterval = null;
    listen.enabled.value = false;
  });

  test('off until a grown-up turns it on', () async {
    expect(await listen.listenOnce(), VoiceOutcome.quiet);
    expect(listen.isListening, isFalse);
  });

  test('never listens while the app is talking', () async {
    listen.enabled.value = true;
    AudioService.instance.isSpeaking.value = true;
    // Otherwise Bloom praises the child for Bloom's own voice.
    expect(await listen.listenOnce(), VoiceOutcome.quiet);
    expect(listen.isListening, isFalse);
  });

  test('a silent turn ends quietly, and ends', () async {
    listen.enabled.value = true;
    final outcome = await listen.listenOnce();
    expect(outcome, VoiceOutcome.quiet);
    expect(listen.isListening, isFalse);
    expect(listen.level.value, 0);
  });

  test('one turn at a time', () async {
    listen.enabled.value = true;
    final first = listen.listenOnce();
    expect(await listen.listenOnce(), VoiceOutcome.quiet);
    await first;
  });

  test('the audio session is borrowed for a turn and always given back', () async {
    // The first successful turn used to leave iOS in a record category:
    // from the next card on, the whole app was silent. The borrow is now
    // explicit, and this is the invariant — every true is followed by a
    // false, whichever way the turn ended.
    final listen = ListenService.instance;
    final events = <bool>[];
    listen.debugSessionHook = (listening) async => events.add(listening);
    addTearDown(() => listen.debugSessionHook = null);

    listen.debugSilentMode = true;
    listen.debugInterval = const Duration(milliseconds: 1);
    listen.enabled.value = true;
    addTearDown(() {
      listen.debugSilentMode = false;
      listen.debugInterval = null;
      listen.enabled.value = false;
      listen.debugReset();
    });

    await listen.listenOnce();
    expect(events, [true, false]);
  });
}
