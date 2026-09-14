import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/home_tab_provider.dart';

/// The channel «Обрати гру» uses to leave the cards tab. The home screen
/// itself needs a fully booted app to pump, so the contract under test is
/// the request: raising it names the games tab, and whoever serves it is
/// expected to clear it.
void main() {
  test('games tab is index 1, matching the navigation bar', () {
    expect(kGamesTabIndex, 1);
  });

  testWidgets('a request is readable and clearable', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(homeTabRequestProvider), isNull);

    container.read(homeTabRequestProvider.notifier).state = kGamesTabIndex;
    expect(container.read(homeTabRequestProvider), kGamesTabIndex);

    container.read(homeTabRequestProvider.notifier).state = null;
    expect(container.read(homeTabRequestProvider), isNull);
  });
}
