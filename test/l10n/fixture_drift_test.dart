import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the canonical extractor in --check mode as part of the suite so
/// fixture drift (a changed/removed uk-en pair, or new s() strings not yet
/// committed to test/fixtures/l10n_strings.json) fails CI, not just manual
/// runs. Cheap: one python3 process over lib/ sources.
void main() {
  test('l10n string fixture matches lib/ sources (extractor --check)',
      () async {
    ProcessResult version;
    try {
      version = await Process.run('python3', ['--version']);
    } on ProcessException {
      markTestSkipped('python3 not available on this machine — run '
          'tools/extract_l10n_strings.py --check manually');
      return;
    }
    expect(version.exitCode, 0);

    final result = await Process.run(
      'python3',
      ['tools/extract_l10n_strings.py', '--check'],
    );
    expect(
      result.exitCode,
      0,
      reason: 'l10n fixture drift detected — if the change is intentional, '
          'regenerate with `python3 tools/extract_l10n_strings.py`.\n'
          '${result.stdout}\n${result.stderr}',
    );
  });
}
