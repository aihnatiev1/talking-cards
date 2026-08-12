import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guardrails for the multilingual refactor: every UI string must go
/// through AppS so that a third locale can resolve it from a translation
/// table keyed by the English literal.
///
/// Runs against the repo sources (lib/ relative to this test file).
void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  setUpAll(() {
    expect(libDir.existsSync(), isTrue,
        reason: 'source_scan_test must run from the package root '
            '(flutter test does this by default)');
  });

  test('no unescaped \$-interpolation inside s(...) single-quoted literals',
      () {
    // Matches `s('...` / `s.p('...` (also ps/sErr/loc/ts receivers) where the
    // first single-quoted literal contains an unescaped `$`. Interpolated UI
    // strings must use s.p with {placeholder} templates instead, so the
    // literal doubles as a stable translation key.
    final callStart = RegExp(r"\b(?:s|ps|sErr|loc|ts)(?:\.p)?\(\s*'");
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final src = file.readAsStringSync();
      for (final m in callStart.allMatches(src)) {
        // Scan the single-quoted literal that starts at the match end.
        var i = m.end;
        var interpolated = false;
        while (i < src.length) {
          final ch = src[i];
          if (ch == r'\') {
            i += 2; // escaped char (incl. \$ and \') — fine
            continue;
          }
          if (ch == "'") break;
          if (ch == r'$') {
            interpolated = true;
            break;
          }
          i++;
        }
        if (interpolated) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Interpolated s() literals found — convert to s.p() with '
            '{placeholder} templates:\n${offenders.join('\n')}');
  });

  test('no isEn identifier anywhere in lib/', () {
    // Phases 3–5 replaced every `bool isEn` param/local with `String lang`
    // (behavioral branches use `lang == 'en'` inline). The allowlist is
    // intentionally EMPTY — a new isEn is always a regression. The pattern
    // also catches the private/suffixed variants that used to exist
    // (_isEn, _isEnLang, isEnMode, isEnNow) without tripping on unrelated
    // identifiers like isEnabled.
    const allowlist = <String>{};
    final pattern = RegExp(r'\b_?isEn(?:Lang|Mode|Now)?\b');
    final offenders = <String>[];

    for (final file in dartFiles()) {
      if (allowlist.contains(file.path)) continue;
      final src = file.readAsStringSync();
      for (final m in pattern.allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(offenders, isEmpty,
        reason: 'isEn found — pass the locale string (lang) instead:\n'
            '${offenders.join('\n')}');
  });

  test("no AppS(...) call fed by an == 'en' comparison", () {
    final pattern = RegExp(r"AppS\([^)]*==\s*'en'");
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final src = file.readAsStringSync();
      for (final m in pattern.allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(offenders, isEmpty,
        reason: "AppS must receive the locale string, never a bool from "
            "== 'en':\n${offenders.join('\n')}");
  });
}
