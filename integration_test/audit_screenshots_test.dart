import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/main.dart' as app;
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/screens/articulation_screen.dart';
import 'package:talking_cards/screens/bubble_pop_screen.dart';
import 'package:talking_cards/screens/card_reveal_screen.dart';
import 'package:talking_cards/screens/cards_screen.dart';
import 'package:talking_cards/screens/coloring_hub_screen.dart';
import 'package:talking_cards/screens/coloring_screen.dart';
import 'package:talking_cards/screens/fill_coloring_screen.dart';
import 'package:talking_cards/screens/guess_screen.dart';
import 'package:talking_cards/screens/kid_word_wall_screen.dart';
import 'package:talking_cards/screens/memory_match_screen.dart';
import 'package:talking_cards/screens/mirror_draw_screen.dart';
import 'package:talking_cards/screens/my_meadow_screen.dart';
import 'package:talking_cards/screens/odd_one_out_screen.dart';
import 'package:talking_cards/screens/opposite_game_screen.dart';
import 'package:talking_cards/screens/paywall_screen.dart';
import 'package:talking_cards/screens/quest_map_screen.dart';
import 'package:talking_cards/screens/repeat_game_screen.dart';
import 'package:talking_cards/screens/rewards_screen.dart';
import 'package:talking_cards/screens/stats_screen.dart';
import 'package:talking_cards/screens/sticker_scene_screen.dart';
import 'package:talking_cards/services/audio_service.dart';

/// Design-audit rig: walks every kid-facing and parent-facing screen and
/// dumps raw PNGs so the visual quality can be judged from real renders,
/// not from code. Not a store asset pipeline.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/audit_screenshots_test.dart -d `<sim udid>`
/// Which language the walk runs in. The store needs the same screens in
/// both, and the rig only ever spoke Ukrainian:
///
///   flutter drive ... --dart-define=AUDIT_LANG=en
const _lang = String.fromEnvironment('AUDIT_LANG', defaultValue: 'uk');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String today(int daysAgo) {
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, Object> livedIn() {
    final profiles = [
      {
        'id': 'p1',
        'name': _lang == 'en' ? 'Emma' : 'Соломійка',
        'avatar': '👧',
        'createdAt':
            DateTime.now().subtract(const Duration(days: 40)).toIso8601String(),
        'lang': _lang,
        'level': 2,
      },
    ];
    return {
      'onboarding_done': true,
      'welcome_shown': true,
      'swipe_hint_shown': true,
      'today_plan_intro_seen_v1': true,
      'installed': true,
      // The what's-new sheet covers the home screen, which is the one
      // shot the store listing is built from. A seeded profile has
      // already "seen" it.
      'whats_new_seen_v2_0': true,
      'is_pro': true,
      'active_profile_id': 'p1',
      'app_profiles': [for (final p in profiles) json.encode(p)],
      'p1_streak_current': 6,
      'p1_streak_last_date': today(0),
      'p1_completed_packs': ['animals', 'home', 'colors'],
      'p1_pack_progress_animals': 29,
      'p1_pack_progress_home': 30,
      'p1_pack_progress_colors': 30,
      'p1_pack_progress_body': 14,
      for (final e in {0: 14, 1: 12, 2: 19, 3: 9, 4: 16, 5: 21}.entries)
        'p1_daily_views_${today(e.key)}': e.value,
    };
  }

  /// Infinite loops (mascot breathing, confetti) make pumpAndSettle hang,
  /// so we pump a fixed amount of wall-clock instead.
  Future<void> settle(WidgetTester tester, [int ms = 1400]) async {
    final steps = ms ~/ 100;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    try {
      await binding.takeScreenshot(_lang == 'en' ? '$name-en' : name);
      debugPrint('AUDIT_SHOT ok $name');
    } catch (e) {
      debugPrint('AUDIT_SHOT fail $name: $e');
    }
  }

  Future<void> pushAndShot(
    WidgetTester tester,
    NavigatorState nav,
    String name,
    Widget Function() build, {
    int wait = 1600,
    Future<void> Function(WidgetTester)? interact,
  }) async {
    try {
      nav.push(MaterialPageRoute(builder: (_) => build()));
      await settle(tester, wait);
      // Anything a screen reads from SharedPreferences or an asset needs
      // the real event loop; pumping a fake clock lets the screen build
      // with the store still empty. The drawing shelf showed five tiles
      // instead of six that way.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await settle(tester, 400);
      await shot(tester, name);
      if (interact != null) {
        await interact(tester);
      }
    } catch (e, st) {
      debugPrint('AUDIT_SHOT error in $name: $e\n$st');
    }
    try {
      // Pop back to the home stack whatever the screen did.
      while (nav.canPop()) {
        nav.pop();
        await settle(tester, 400);
      }
    } catch (e) {
      debugPrint('AUDIT_SHOT pop error after $name: $e');
    }
  }

  testWidgets('fresh install: splash + onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    app.keepTestErrorHandlers = true;
    app.main();
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 200));
    await shot(tester, 'a00-splash');
    await settle(tester, 4500);
    await shot(tester, 'a01-onboarding-1');
    // Advance through onboarding pages where a forward button exists.
    for (var i = 2; i <= 4; i++) {
      final next = find.byWidgetPredicate((w) =>
          w is FilledButton || w is ElevatedButton || w is TextButton);
      if (next.evaluate().isEmpty) break;
      await tester.tap(next.last, warnIfMissed: false);
      await settle(tester, 1200);
      await shot(tester, 'a0$i-onboarding-$i');
    }
  });

  testWidgets('lived-in profile: every screen', (tester) async {
    SharedPreferences.setMockInitialValues(livedIn());
    app.main();
    await settle(tester, 5500);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester, 600);

    await shot(tester, 'b00-home-cards');

    // Tabs via the bottom navigation labels.
    for (final (label, name) in [('Ігри', 'b01-home-games'), ('Малюємо', 'b02-home-coloring')]) {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await settle(tester, 1500);
        await shot(tester, name);
      } else {
        debugPrint('AUDIT_SHOT tab not found: $label');
      }
    }
    final back = find.text('Картки');
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first, warnIfMissed: false);
      await settle(tester, 800);
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
    final packs = await container.read(packsProvider.future);
    debugPrint('AUDIT_SHOT packs=${packs.map((p) => p.id).join(',')}');
    final unlocked = packs.where((p) => p.cards.isNotEmpty).toList();
    final pack = unlocked.firstWhere((p) => p.id == 'animals',
        orElse: () => unlocked.first);
    final allCards = [for (final p in unlocked) ...p.cards];
    final playable = allCards
        .where((c) => c.audioKey != null && c.image != null &&
            AudioService.instance.hasSound(c.audioKey))
        .toList();
    final playablePacks = unlocked
        .where((p) => p.cards.where((c) => c.image != null).length >= 3)
        .toList();
    PackModel oppPack = unlocked.firstWhere(
        (p) => p.id.contains('oppos') || p.id.contains('protyl'),
        orElse: () => pack);
    final CardModel card = pack.cards.first;

    await pushAndShot(tester, nav, 'c00-cards-screen', () => CardsScreen(pack: pack),
        interact: (t) async {
      // Tap the card to hear it and show the listening state.
      await t.tapAt(t.getCenter(find.byType(Scaffold).last));
      await settle(t, 500);
      await shot(t, 'c01-cards-screen-tapped');
      // Swipe to the next card.
      await t.fling(find.byType(Scaffold).last, const Offset(-400, 0), 1200);
      await settle(t, 900);
      await shot(t, 'c02-cards-screen-next');
    });

    await pushAndShot(tester, nav, 'd00-guess', () => GuessScreen(cards: playable),
        wait: 2600, interact: (t) async {
      final opts = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'QuizOption');
      if (opts.evaluate().isNotEmpty) {
        await t.tap(opts.first, warnIfMissed: false);
        await settle(t, 700);
        await shot(t, 'd01-guess-after-tap');
        await settle(t, 1800);
        await shot(t, 'd02-guess-next');
      }
    });

    await pushAndShot(
        tester,
        nav,
        'e00-memory-match',
        () => MemoryMatchScreen(
            pack: pack,
            cards: pack.cards.where((c) => c.image != null).toList(),
            pairCount: 3),
        wait: 2200,
        interact: (t) async {
      final tiles = find.byType(GestureDetector);
      if (tiles.evaluate().length > 2) {
        await t.tap(tiles.at(1), warnIfMissed: false);
        await settle(t, 700);
        await shot(t, 'e01-memory-match-flipped');
      }
    });

    await pushAndShot(tester, nav, 'f00-bubble-pop', () => const BubblePopScreen(),
        wait: 2500, interact: (t) async {
      await settle(t, 2000);
      await shot(t, 'f01-bubble-pop-later');
    });

    await pushAndShot(tester, nav, 'g00-odd-one-out',
        () => OddOneOutScreen(packs: playablePacks), wait: 2400);

    await pushAndShot(tester, nav, 'h00-repeat-game',
        () => RepeatGameScreen(cards: playable), wait: 2400);

    await pushAndShot(tester, nav, 'i00-articulation',
        () => const ArticulationScreen(), wait: 1800);

    await pushAndShot(tester, nav, 'j00-opposites',
        () => OppositeGameScreen(pack: oppPack), wait: 2200);

    await pushAndShot(tester, nav, 'k00-coloring', () => const ColoringScreen(),
        wait: 2000);

    // The drawing shelf and everything on it. Five ways to draw landed at
    // once and none of them was in the audit set, so nothing outside the
    // app had ever seen them.
    await pushAndShot(tester, nav, 'k01-draw-shelf',
        () => const ColoringHubScreen(), wait: 2000);

    await pushAndShot(tester, nav, 'k02-fill-coloring',
        () => const FillColoringScreen(sheetId: 'bear_heart'),
        wait: 3000, interact: (t) async {
      // Paint a few parts so the shot shows the point of the screen rather
      // than an empty outline. The spots are taken from the drawing's own
      // rect — hard-coded offsets missed it entirely the first time, and
      // the result looked like a broken feature rather than a bad tap.
      final picture = t.getRect(find.byType(CustomPaint).last);
      for (final at in [
        picture.center,
        Offset(picture.center.dx, picture.top + picture.height * 0.18),
        Offset(picture.center.dx, picture.bottom - picture.height * 0.2),
      ]) {
        await t.tapAt(at);
        // The painted layer is built by ui.decodeImageFromPixels, whose
        // callback needs the real event loop — pumping a fake clock lets
        // the fill be recorded but never drawn, which is why the first
        // run of this shot came back as an empty outline.
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await settle(t, 600);
      }
      await settle(t, 600);
      await shot(t, 'k03-fill-coloring-painted');
    });

    await pushAndShot(tester, nav, 'k04-fill-by-ear',
        () => const FillColoringScreen(
              sheetId: 'bear_heart',
              byEar: true,
            ),
        wait: 2600);

    await pushAndShot(tester, nav, 'k05-stickers',
        () => const StickerSceneScreen(), wait: 2200);

    await pushAndShot(tester, nav, 'k06-mirror-draw',
        () => const MirrorDrawScreen(), wait: 1800);

    await pushAndShot(tester, nav, 'k07-my-meadow',
        () => const MyMeadowScreen(), wait: 2200);

    await pushAndShot(tester, nav, 'l00-rewards', () => const RewardsScreen(),
        wait: 2000);

    await pushAndShot(
        tester,
        nav,
        'm00-quest-map',
        () => QuestMapScreen(
            cardOfDay: card, cardOfDayLocked: false, onCardOfDayTap: () {}),
        wait: 2600);

    await pushAndShot(
        tester,
        nav,
        'n00-card-reveal',
        () => CardRevealScreen(card: card, pack: pack, newTotal: 12),
        wait: 900,
        interact: (t) async {
      await settle(t, 1600);
      await shot(t, 'n01-card-reveal-settled');
    });

    await pushAndShot(tester, nav, 'o00-paywall',
        () => const PaywallScreen(source: 'audit'), wait: 2200);

    await pushAndShot(tester, nav, 'p00-stats', () => const StatsScreen(),
        wait: 1800);

    await pushAndShot(tester, nav, 'q00-word-wall',
        () => const KidWordWallScreen(), wait: 2000);

    // Profile selector sheet + parent dashboard behind the gate.
    final chip = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ProfileAvatarChip');
    if (chip.evaluate().isNotEmpty) {
      await tester.tap(chip.first, warnIfMissed: false);
      await settle(tester, 1200);
      await shot(tester, 'r00-profile-selector');
      await tester.tapAt(const Offset(200, 80));
      await settle(tester, 800);
    }
    final info = find.byIcon(Icons.info_outline_rounded);
    if (info.evaluate().isNotEmpty) {
      await tester.longPress(info.first, warnIfMissed: false);
      await settle(tester, 1200);
      await shot(tester, 's00-parental-gate');
    }
  });
}
