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

  test('finishing hands the picture over and frees the canvas', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final working = c.read(filledSheetsProvider.notifier);
    final finished = c.read(finishedSheetsProvider.notifier);

    await working.record('bear_cub', 3, 'brown');
    await working.record('bear_cub', 4, 'yellow');

    // What the screen does when the last part is painted.
    await finished.putAll('bear_cub', working.of('bear_cub'));
    await working.clear('bear_cub');

    // The meadow keeps it; the canvas opens blank next time. Before this
    // split, every picture after the first one opened already coloured.
    expect(finished.of('bear_cub'), {3: 'brown', 4: 'yellow'});
    expect(working.of('bear_cub'), isEmpty);
  });

  test('the two stores do not see each other', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(filledSheetsProvider.notifier).record('cat_face', 1, 'red');
    expect(c.read(finishedSheetsProvider.notifier).of('cat_face'), isEmpty);
  });
}
