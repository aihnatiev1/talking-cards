import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `ref` is dead inside `dispose`, and reaching for it there throws
/// `Cannot use "ref" after the widget was disposed` — which takes every
/// line below it down too.
///
/// That is not a theoretical risk. `cards_screen.dart` had
/// `_bloom.sceneLeft()` (a getter over `ref.read`) sitting above
/// `AudioService.stop()` in dispose, so leaving a pack mid-word threw
/// before the stop and the word followed the child onto the home screen.
/// Three separate attempts to fix that audio bug missed it, because the
/// exception is swallowed by the framework and the tests never opened a
/// real screen.
///
/// Resolve providers once (`late final x = ref.read(...)`) and dispose
/// touches only plain fields.
void main() {
  test('no dispose() reaches for ref', () {
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      var depth = 0;
      var inside = false;

      for (final line in lines) {
        if (!inside && RegExp(r'void dispose\(\)').hasMatch(line)) {
          inside = true;
          depth = 0;
        }
        if (!inside) continue;

        depth += '{'.allMatches(line).length;
        depth -= '}'.allMatches(line).length;

        // A comment mentioning ref is fine; a call is not.
        final code = line.split('//').first;
        if (RegExp(r'\bref\s*\.').hasMatch(code)) {
          offenders.add('${file.path}: ${line.trim()}');
        }
        if (depth <= 0 && line.contains('}')) inside = false;
      }
    }

    expect(offenders, isEmpty,
        reason: 'dispose() must not touch ref — resolve the provider once '
            'in a `late final` field instead:\n${offenders.join('\n')}');
  });
}
