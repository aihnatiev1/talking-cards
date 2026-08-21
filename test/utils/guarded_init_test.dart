import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/guarded_init.dart';

void main() {
  group('runGuarded', () {
    test('returns true and awaits a healthy init', () async {
      var ran = false;
      final ok = await runGuarded('healthy', () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        ran = true;
      }, budget: const Duration(seconds: 1));

      expect(ok, isTrue);
      expect(ran, isTrue);
    });

    test('swallows a throwing init without reporting a timeout', () async {
      final timedOut = <String>[];
      final ok = await runGuarded(
        'broken',
        () async => throw StateError('no platform channel'),
        budget: const Duration(seconds: 1),
        onTimeout: timedOut.add,
      );

      expect(ok, isFalse);
      expect(timedOut, isEmpty);
    });

    test('abandons a hanging init and names it', () async {
      final timedOut = <String>[];
      // Never completes — the exact shape of a StoreKit/Remote Config hang
      // that used to strand the splash on its spinner.
      final ok = await runGuarded(
        'hanging',
        () => Completer<void>().future,
        budget: const Duration(milliseconds: 40),
        onTimeout: timedOut.add,
      );

      expect(ok, isFalse);
      expect(timedOut, ['hanging']);
    });

    test('without a budget it waits (widget-test mode)', () async {
      var ran = false;
      final ok = await runGuarded('no-budget', () async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        ran = true;
      });

      expect(ok, isTrue);
      expect(ran, isTrue);
    });
  });
}
