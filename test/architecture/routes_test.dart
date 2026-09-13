import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one-transition-language rule (motion audit 2026-09-13 §5).
///
/// Every screen enters the way its *kind* enters — `KidRoutes.content`,
/// `.game`, `.sheet`, `.overlay`, `.replace` — and nothing else builds a
/// route. A `MaterialPageRoute` at a call site is a platform-default slide
/// on iOS and a zoom on Android; a bare `PageRouteBuilder` is one more
/// duration and curve to keep in step by hand. Both were how the app ended
/// up with seven ways to open a screen.
///
/// Like `asset_access_test.dart`, this is a source test because Dart has
/// no `internal` visibility and the project runs no custom lints.
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// The only file that may construct a route.
  const owner = 'lib/utils/kid_routes.dart';

  List<String> offenders(String token) => [
        for (final f in dart)
          if (f.path != owner && f.readAsStringSync().contains(token)) f.path,
      ];

  test('only KidRoutes builds a MaterialPageRoute', () {
    expect(
      offenders('MaterialPageRoute('),
      isEmpty,
      reason: 'Push with KidRoutes.content / game / sheet / overlay / '
          'replace instead. A new kind of transition belongs in '
          'kid_routes.dart, not at the call site.',
    );
  });

  test('only KidRoutes builds a PageRouteBuilder', () {
    expect(
      offenders('PageRouteBuilder('),
      isEmpty,
      reason: 'Same rule: one file owns durations, curves and barriers.',
    );
  });

  test('the old game route helper is gone', () {
    expect(
      offenders('_gameRoute('),
      isEmpty,
      reason: 'Use KidRoutes.game.',
    );
  });
}
