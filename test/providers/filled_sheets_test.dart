import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/filled_sheets_provider.dart';

/// A picture a child spent five minutes on must still be there after the
/// close button.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('what was painted is remembered per drawing', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(filledSheetsProvider.notifier);

    await notifier.record('lion', 3, 'yellow');
    await notifier.record('lion', 5, 'brown');
    await notifier.record('fish', 1, 'blue');

    expect(notifier.of('lion'), {3: 'yellow', 5: 'brown'});
    expect(notifier.of('fish'), {1: 'blue'});
    expect(notifier.of('house'), isEmpty);
  });

  test('painting the same area again replaces the colour', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(filledSheetsProvider.notifier);

    await notifier.record('lion', 3, 'yellow');
    await notifier.record('lion', 3, 'red');
    expect(notifier.of('lion'), {3: 'red'});
  });

  test('it survives a restart', () async {
    final first = ProviderContainer();
    await first.read(filledSheetsProvider.notifier).record('lion', 2, 'green');
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final notifier = second.read(filledSheetsProvider.notifier);
    for (var i = 0; i < 5 && notifier.of('lion').isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(notifier.of('lion'), {2: 'green'});
  });

  test('starting over forgets one drawing and leaves the rest', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(filledSheetsProvider.notifier);

    await notifier.record('lion', 1, 'red');
    await notifier.record('fish', 1, 'blue');
    await notifier.clear('lion');

    expect(notifier.of('lion'), isEmpty);
    expect(notifier.of('fish'), {1: 'blue'});
  });

  test('an unreadable store starts empty instead of failing a launch',
      () async {
    SharedPreferences.setMockInitialValues({'filled_sheets': 'not json'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(filledSheetsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state, isEmpty);
  });
}
