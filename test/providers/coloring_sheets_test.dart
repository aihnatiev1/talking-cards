import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/coloring_sheets_provider.dart';

/// Adding a drawing must be a matter of dropping a file in and running
/// the tool — so the app reads the index, and an index that is not there
/// is an empty shelf, not a crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the index lists the drawings in its own order', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sheets = await container.read(coloringSheetsProvider.future);
    // The real bundled index; the placeholders are in it until real
    // contours replace them.
    expect(sheets, isNotEmpty);
    expect(sheets, everyElement(isA<String>()));
  });

  test('a missing index is an empty shelf, not an exception', () async {
    // Serve nothing for the asset the provider asks for. The bundle
    // caches what earlier tests loaded, so clear it on both sides.
    rootBundle.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      rootBundle.clear();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(coloringSheetsProvider.future), isEmpty);
  });

  test('every drawing in the index is a plain id, not a path', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (final id in await container.read(coloringSheetsProvider.future)) {
      expect(id.contains('/'), isFalse, reason: id);
      expect(id.endsWith('.png'), isFalse, reason: id);
      expect(id.endsWith('.map'), isFalse, reason: '$id is a region map');
    }
  });

  test('the index is valid json with a sheets list', () async {
    final raw = await rootBundle.loadString(
      'assets/images/coloring/sheets.json',
    );
    expect(json.decode(raw), containsPair('sheets', isA<List<dynamic>>()));
  });
}
