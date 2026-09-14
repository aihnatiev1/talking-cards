import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/listen_enabled_provider.dart';
import 'package:talking_cards/services/listen_service.dart';

/// The microphone's contract in «Повтори за мною»: off unless a grown-up
/// turned it on, and a turn that hears nothing is not a failure.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ListenService.instance.debugSilentMode = true;
    ListenService.instance.debugInterval = const Duration(milliseconds: 1);
  });

  tearDown(() {
    ListenService.instance.debugSilentMode = false;
    ListenService.instance.debugInterval = null;
    ListenService.instance.enabled.value = false;
    ListenService.instance.debugReset();
  });

  test('the setting starts off and drives the service', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(listenEnabledProvider), isFalse);
    expect(ListenService.instance.enabled.value, isFalse);

    await container.read(listenEnabledProvider.notifier).set(true);
    expect(container.read(listenEnabledProvider), isTrue);
    expect(ListenService.instance.enabled.value, isTrue);

    await container.read(listenEnabledProvider.notifier).set(false);
    expect(ListenService.instance.enabled.value, isFalse);
  });

  test('the setting survives a restart, per profile', () async {
    final first = ProviderContainer();
    await first.read(listenEnabledProvider.notifier).set(true);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // The notifier loads from SharedPreferences, so give the platform
    // channel a turn before reading it back.
    for (var i = 0; i < 5 && !second.read(listenEnabledProvider); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(second.read(listenEnabledProvider), isTrue);
  });

  test('a silent turn ends quiet, and the mic is released', () async {
    ListenService.instance.enabled.value = true;
    final outcome = await ListenService.instance.listenOnce();
    expect(outcome.name, 'quiet');
    expect(ListenService.instance.isListening, isFalse);
    expect(ListenService.instance.level.value, 0);
  });
}
