import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/play_topic.dart';
import 'package:talking_cards/providers/language_provider.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/providers/card_of_day_provider.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/play_session_provider.dart';
import 'package:talking_cards/screens/home_screen.dart';
import 'package:talking_cards/tabs/packs_tab.dart';
import 'package:talking_cards/screens/cards_screen.dart';
import 'package:talking_cards/screens/quest_map_screen.dart';
import 'package:talking_cards/screens/play_lesson_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/app_startup.dart';
import 'package:talking_cards/utils/app_theme.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/play_components.dart';
import 'package:talking_cards/widgets/pack_preview_dialog.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('PLAY_PREVIEW')) return;
  await settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('/tmp/firstword-redesign').create(recursive: true);
    await File(
      '/tmp/firstword-redesign/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> host(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  String lang = 'uk',
  double safeTop = 0,
  bool omitAnimalLessons = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'welcome_shown': true,
    'whats_new_seen_v2_0': true,
  });
  AppStartup.readyLogged = true;
  AppStartup.viaOnboarding = true;
  FeedbackService.debugMute = true;
  addTearDown(() => FeedbackService.debugMute = false);
  AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
  final font = FontLoader(DT.kidFont)
    ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await tester.runAsync(() async {
    await font.load();
    await icons.load();
  });
  final catalogue = await tester.runAsync(
    () async =>
        (jsonDecode(
                  await rootBundle.loadString('assets/data/${lang}_cards.json'),
                )
                as List)
            .map((item) => PackModel.fromJson(item as Map<String, dynamic>))
            .toList(),
  );
  final container = ProviderContainer(
    overrides: [
      cardOfDaySelectorProvider.overrideWithValue(
        (packs) => packs.isEmpty
            ? null
            : (packs.first.cards.first, packs.first.isLocked),
      ),
      packsProvider.overrideWith(
        (ref) async => omitAnimalLessons
            ? catalogue!.where((p) => !p.id.endsWith('animals')).toList()
            : catalogue!,
      ),
      languageProvider.overrideWithValue(lang),
    ],
  );
  addTearDown(container.dispose);
  await container.read(playSessionProvider.notifier).ready;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
            padding: EdgeInsets.only(top: safeTop),
          ),
          child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  await settle(tester);
  return container;
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(PlayAction, label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets('daily tasks open from home without scrolling', (tester) async {
    await host(tester, height: 700, safeTop: 62);
    await tester.tap(find.byKey(const ValueKey('home-daily-quest')));
    await settle(tester);
    expect(find.byType(QuestMapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview dialog fits large text and returns without unlocking', (
    tester,
  ) async {
    final container = await host(tester, width: 320, height: 568, scale: 2);
    final pack = container.read(packsProvider).requireValue.first;
    var unlocks = 0;
    showDialog<void>(
      context: tester.element(find.byType(HomeScreen)),
      builder: (_) => PackPreviewDialog(
        pack: pack,
        waiting: pack.cards.take(4).toList(),
        remaining: 4,
        isEn: false,
        onUnlock: () => unlocks++,
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tapText(tester, 'До карток');
    expect(find.byType(PackPreviewDialog), findsNothing);
    expect(unlocks, 0);
  });

  testWidgets('the lesson comes first; the catalogue is one scroll away', (
    tester,
  ) async {
    await host(tester, height: 700, safeTop: 62);
    await screenshot(tester, '07-compact-home-safe-area');
    // One big action sits above the fold; the shelf follows it.
    expect(find.text('Привіт, тваринки!').hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(PlayAction, 'Грати').hitTestable(),
      findsOneWidget,
    );
    final entry = find.byKey(const ValueKey('home-all-packs'));
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(entry);
    await tester.pump();
    expect(entry.hitTestable(), findsOneWidget);
    await tester.tap(entry);
    await settle(tester);
    expect(find.byType(PacksTab).hitTestable(), findsOneWidget);
    expect(find.byType(PlayLessonScreen), findsNothing);
    expect(find.text('Привіт, тваринки!').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home pack opens its actual cards', (tester) async {
    await host(tester, height: 700, safeTop: 62);
    await tester.scrollUntilVisible(
      find.text('Тваринки'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Тваринки'));
    await tester.pump();
    await tester.tap(find.text('Тваринки'));
    await settle(tester);
    expect(find.byType(CardsScreen), findsOneWidget);
    expect(
      tester.widget<CardsScreen>(find.byType(CardsScreen)).pack.id,
      'animals',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'old lesson cannot advance another profile and resumes its own step',
    (tester) async {
      final container = await host(tester);
      final original = container.read(profileProvider);
      final topic = PlayTopic.all.first;
      final cards = topic.cards(container.read(packsProvider).requireValue);
      await tapText(tester, 'Грати');
      await tester.tap(find.text(cards.first.sound));
      await settle(tester);
      await tapText(tester, 'Далі');
      await tester.tap(find.text(cards[1].sound));
      await settle(tester);
      final staleNext = tester
          .widget<PlayAction>(
            find.byWidgetPredicate((w) => w is PlayAction && w.label == 'Далі'),
          )
          .onPressed!;
      // Simulate a profile change while this route is still mounted.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      container.read(profileProvider.notifier).state = original.copyWith(
        activeId: 'second-child',
      );
      final second = container.read(playSessionProvider.notifier);
      await second.start(topic.id, cards.map((c) => c.id).toList());
      staleNext();
      await settle(tester);
      expect(
        container
            .read(playSessionProvider)
            .requireValue
            .sessions[topic.id]!
            .step,
        0,
      );
      expect(find.text('Відкриймо інше заняття'), findsOneWidget);
      Navigator.of(tester.element(find.byType(PlayLessonScreen))).pop();
      await settle(tester);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      container.read(profileProvider.notifier).state = original;
      await container.read(playSessionProvider.notifier).ready;
      await settle(tester);
      expect(
        container
            .read(playSessionProvider)
            .requireValue
            .sessions[topic.id]!
            .step,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home to lesson, help, reward, world and replay', (tester) async {
    final container = await host(tester);
    await screenshot(tester, '01-home');
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('../goldens/images/play_home.png'),
    );
    expect(find.text('Привіт, тваринки!'), findsOneWidget);
    await tapText(tester, 'Грати');
    await screenshot(tester, '02-listen');
    final cards = PlayTopic.all.first.cards(
      container.read(packsProvider).requireValue,
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(cards[i].sound));
      await settle(tester);
      await tapText(tester, 'Далі');
    }
    await screenshot(tester, '03-find');
    for (var i = 0; i < 3; i++) {
      if (i == 0) {
        await tester.ensureVisible(find.text('Покажи мені'));
        await tester.tap(find.text('Покажи мені'));
        await settle(tester);
        await screenshot(tester, '04-help');
      }
      final option = find.byKey(ValueKey('lesson-option-${cards[i].id}'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await settle(tester);
      await tapText(tester, 'Далі');
    }
    await tapText(tester, 'Завершити');
    expect(container.read(playSessionProvider).requireValue.rewards, {
      'animal_friends',
    });
    expect(
      container.read(playSessionProvider).requireValue.current!.assisted,
      contains(3),
    );
    await screenshot(tester, '05-complete');
    await tapText(tester, 'До мого світу');
    await screenshot(tester, '06-world');
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('../goldens/images/play_world.png'),
    );
    expect(find.text('Торкнись друга й послухай'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final layout in [
    (320.0, 568.0, 2.0, 'uk'),
    (390.0, 844.0, 1.0, 'en'),
    (834.0, 1194.0, 2.0, 'uk'),
  ]) {
    testWidgets('home and lesson fit $layout', (tester) async {
      await host(
        tester,
        width: layout.$1,
        height: layout.$2,
        scale: layout.$3,
        lang: layout.$4,
      );
      await tapText(tester, layout.$4 == 'en' ? 'Play' : 'Грати');
      expect(find.byType(PlayLessonScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
