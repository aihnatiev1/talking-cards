import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;

/// Store-screenshot rig: seeds a lived-in profile (streak, finished packs,
/// weekly activity), walks the real app and captures raw PNGs for the
/// Remotion store-slot renderer. Run on an iPhone Pro Max simulator:
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/store_screenshots_test.dart -d `<sim udid>`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ukWords = [
    '', 'один', 'два', 'три', 'чотири', 'п’ять', 'шість', 'сім',
    'вісім', 'дев’ять'
  ];
  const enWords = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'
  ];

  String today(int daysAgo) {
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, Object> seed(String lang) {
    final names = lang == 'en' ? ['Emma', 'Noah'] : ['Соломійка', 'Марко'];
    final profiles = [
      {
        'id': 'p1',
        'name': names[0],
        'avatar': '👧',
        'createdAt': DateTime.now()
            .subtract(const Duration(days: 40))
            .toIso8601String(),
        'lang': lang,
        'level': 2,
      },
      {
        'id': 'p2',
        'name': names[1],
        'avatar': '🦊',
        'createdAt': DateTime.now()
            .subtract(const Duration(days: 25))
            .toIso8601String(),
        'lang': lang,
        'level': 3,
      },
    ];
    return {
      'onboarding_done': true,
      'welcome_shown': true,
      'swipe_hint_shown': true,
      'today_plan_intro_seen_v1': true,
      'installed': true,
      'is_pro': true,
      'active_profile_id': 'p1',
      'app_profiles': [for (final p in profiles) json.encode(p)],
      // Lived-in progress for the active profile (prefix 'p1_').
      'p1_streak_current': 6,
      'p1_streak_last_date': today(0),
      'p1_completed_packs': [
        'animals', 'home', 'colors', 'food', 'emotions', 'transport'
      ],
      'p1_pack_progress_animals': 29,
      'p1_pack_progress_home': 30,
      'p1_pack_progress_colors': 30,
      'p1_pack_progress_food': 30,
      'p1_pack_progress_emotions': 30,
      'p1_pack_progress_transport': 30,
      'p1_pack_progress_body': 14,
      'p1_pack_progress_actions': 8,
      for (final e in {0: 14, 1: 12, 2: 19, 3: 9, 4: 16, 5: 21}.entries)
        'p1_daily_views_${today(e.key)}': e.value,
    };
  }

  Future<void> solveParentalGate(WidgetTester tester, List<String> words,
      {required String plusWord}) async {
    final questionFinder = find.textContaining(plusWord);
    expect(questionFinder, findsOneWidget);
    final question = (tester.widget<Text>(questionFinder).data ?? '');
    final parts = question.replaceAll('?', '').trim().split(' $plusWord ');
    final a = words.indexOf(parts[0].trim());
    final b = words.indexOf(parts[1].trim());
    expect(a > 0 && b > 0, true, reason: 'unparsed gate question: $question');
    for (final digit in '${a + b}'.split('')) {
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(TextButton, digit),
        ),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
  }

  Future<void> captureFlow(WidgetTester tester, String lang) async {
    SharedPreferences.setMockInitialValues(seed(lang));
    app.main();
    // Splash: services init + logo hold + fade.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    // 1. Home with live streak + progress.
    await binding.takeScreenshot('home-$lang-live');

    // 2. Profile selector sheet.
    final chip = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ProfileAvatarChip');
    expect(chip, findsOneWidget);
    await tester.tap(chip.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('profiles-$lang');
    // Dismiss the sheet.
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();

    // 3. Parent dashboard behind the gate.
    await tester.longPress(find.byIcon(Icons.info_outline_rounded),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    await solveParentalGate(
      tester,
      lang == 'en' ? enWords : ukWords,
      plusWord: lang == 'en' ? 'plus' : 'плюс',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await binding.takeScreenshot('dashboard-$lang-live');
  }

  testWidgets('capture uk store screenshots', (tester) async {
    await captureFlow(tester, 'uk');
  });
}
