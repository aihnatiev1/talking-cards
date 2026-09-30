import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration tests that capture store screenshots.
/// PNGs land in marketing/public/screenshots/auto/ (marketing/ is
/// gitignored — the rendered store slots are what gets versioned).
/// SHOTS_DIR moves them elsewhere, so an iPad run does not overwrite the
/// iPhone frames the store slots are rendered from.
Future<void> main() async {
  final dir = Platform.environment['SHOTS_DIR'] ??
      'marketing/public/screenshots/auto';
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('$dir/$name.png')
        ..createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
