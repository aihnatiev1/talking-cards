import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration tests that capture store screenshots.
/// PNGs land in marketing/public/screenshots/auto/ (marketing/ is
/// gitignored — the rendered store slots are what gets versioned).
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('marketing/public/screenshots/auto/$name.png')
        ..createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
