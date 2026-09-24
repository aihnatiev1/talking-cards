import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/cards_screen.dart';
import 'package:talking_cards/screens/coloring_hub_screen.dart';
import 'package:talking_cards/screens/fill_coloring_screen.dart';
import 'package:talking_cards/screens/guess_screen.dart';
import 'package:talking_cards/screens/home_screen.dart';
import 'package:talking_cards/screens/quest_map_screen.dart';
import 'package:talking_cards/utils/motion.dart';

/// Real app screenshots for all seven store slots, one locale per run.
/// Unlike the exploratory audit, a failed capture fails the run.
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/visual_refresh_test.dart \
///   --dart-define=AUDIT_LANG=en -d SIMULATOR_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const lang = String.fromEnvironment('AUDIT_LANG', defaultValue: 'uk');

  Future<void> frames(WidgetTester tester, [int count = 15]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('capture current $lang store journey', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    addTearDown(() => MotionPolicy.debugOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'welcome_shown': true,
      'swipe_hint_shown': true,
      'today_plan_intro_seen_v1': true,
      'installed': true,
      'notifications_permission_asked': true,
      'whats_new_seen_v2_0': true,
      'active_profile_id': 'store_preview',
      'app_profiles': [
        jsonEncode({
          'id': 'store_preview',
          'name': lang == 'en' ? 'Emma' : 'Соломійка',
          'avatar': '👧',
          'createdAt': DateTime.now().toIso8601String(),
          'lang': lang,
          'level': 2,
        }),
      ],
    });
    app.keepTestErrorHandlers = true;
    app.main();
    // Startup includes asynchronous plugin initialization with timeouts.
    for (var i = 0; i < 90 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    await frames(tester);
    await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await frames(tester, 5);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'A prompt must not cover a store screenshot',
      );
      await binding.takeScreenshot('refresh-$name-$lang');
    }

    await shot('home');
    final sounds = find.text(lang == 'en' ? 'Sounds' : 'Звуки');
    expect(sounds, findsWidgets);
    await tester.tap(sounds.first);
    await frames(tester);
    await shot('sounds');

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    final packs = await container.read(packsProvider.future);
    final animals = packs.firstWhere(
      (p) => p.id == (lang == 'en' ? 'en_animals' : 'animals'),
    );

    Future<void> screen(
      String name,
      Widget screen, {
      Future<void> Function()? prepare,
    }) async {
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));
      await frames(tester, 20);
      if (prepare != null) await prepare();
      await shot(name);
      nav.pop();
      await frames(tester, 8);
    }

    await screen('cards', CardsScreen(pack: animals));
    await screen('game', GuessScreen(cards: animals.cards));
    await screen('draw', const ColoringHubScreen());
    await screen(
      'fill',
      const FillColoringScreen(sheetId: 'bear_heart'),
      prepare: () async {
        final picture = tester.getRect(find.byType(CustomPaint).last);
        for (final point in [
          picture.center,
          Offset(picture.center.dx, picture.top + picture.height * .18),
        ]) {
          await tester.tapAt(point);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 400)),
          );
          await frames(tester, 4);
        }
      },
    );
    await screen(
      'quest',
      QuestMapScreen(
        cardOfDay: animals.cards.first,
        cardOfDayLocked: false,
        onCardOfDayTap: () {},
      ),
    );
  });
}
