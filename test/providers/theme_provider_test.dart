import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/theme_provider.dart';

void main() {
  group('ThemeModeNotifier', () {
    test('default theme is light', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      // Before async load completes
      expect(notifier.debugState, ThemeMode.light);
    });

    test('loads dark mode from prefs', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState, ThemeMode.dark);
    });

    test('loads system mode from prefs', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState, ThemeMode.system);
    });

    test('unknown value stays light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'unknown'});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      expect(notifier.debugState, ThemeMode.light);
    });

    test('toggle from light to dark', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle();

      expect(notifier.debugState, ThemeMode.dark);
    });

    test('toggle from dark to light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle();

      expect(notifier.debugState, ThemeMode.light);
    });

    test('toggle persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('double toggle returns to original', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future.delayed(Duration.zero);

      await notifier.toggle();
      await notifier.toggle();

      expect(notifier.debugState, ThemeMode.light);
    });
  });
}
