import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the image-cache ceiling (perf pass 2026-09-13, sprint 5).
///
/// Flutter's default is 100 MB / 1000 entries. On the 2016 tablet a family
/// hands the child (rule 10) that ceiling is bigger than the headroom the
/// whole app gets, and the cache fills with card art nobody is looking at
/// until the OS kills the process — a "it just closes by itself" bug with
/// no stack trace to file. `main.dart` sets a real cap before the first
/// frame; this test keeps it there, because the default comes back the
/// moment the line is deleted and nothing else in the tree would notice.
void main() {
  test('main.dart caps the image cache before the first frame', () {
    final src = File('lib/main.dart').readAsStringSync();

    expect(
      src.contains('imageCache'),
      isTrue,
      reason: 'lib/main.dart must bound PaintingBinding.instance.imageCache',
    );
    expect(
      RegExp(r'maximumSizeBytes\s*=').hasMatch(src),
      isTrue,
      reason: 'the byte ceiling is the one that actually bounds card art',
    );
    expect(
      RegExp(r'maximumSize\s*=').hasMatch(src),
      isTrue,
      reason: 'entry count too, so thumbnails cannot fill the cache',
    );

    // The cap has to run before any image can be decoded — i.e. inside
    // main(), right after the binding exists.
    final binding = src.indexOf('ensureInitialized()');
    final cap = src.indexOf('_capImageCache()');
    final runApp = src.indexOf('runApp(');
    expect(binding, greaterThan(-1));
    expect(cap, greaterThan(binding));
    expect(cap, lessThan(runApp));
  });
}
