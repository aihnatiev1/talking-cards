import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/onboarding_screen.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/utils/app_theme.dart';
import 'package:talking_cards/widgets/kid_tap.dart';
import 'package:talking_cards/models/bloom_state.dart';
import 'package:talking_cards/providers/bloom_reactions_provider.dart';

/// Onboarding branches on the system locale: EN opens straight into the
/// magic moment (English installs churned on the keyboard page before ever
/// hearing a card), UA keeps name → age → magic.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOnboarding(WidgetTester tester, Locale locale) async {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    // The magic moment reads its starter cards from the asset bundle — real
    // I/O, so it needs runAsync. pumpAndSettle is out (mascot + spinner
    // animate forever), hence the hand-stepped frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('EN starts on the magic moment, without the name page', (
    tester,
  ) async {
    await pumpOnboarding(tester, const Locale('en'));

    expect(find.text('Tap the card to hear the word!'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Two steps only: magic moment + age.
    expect(find.text("Child's name (optional)"), findsNothing);

    // bloom_character §3.6: a second of nothing and Bloom points at the
    // card the child is meant to tap — the hint that replaced the looping
    // bounce. Checked here rather than in a test of its own: the magic
    // moment mounts once per test process (a second mount never leaves
    // its spinner — pre-existing, and not this screen's doing).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingScreen)),
    );
    expect(
      container.read(bloomReactionsProvider).emotion,
      isNot(BloomEmotion.point),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    final bloom = container.read(bloomReactionsProvider);
    expect(bloom.emotion, BloomEmotion.point);
    expect(bloom.hintDirection, Alignment.bottomCenter);
    // The re-armed hint timer is pending; unmount before the binding
    // counts timers.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('UA starts on the name page', (tester) async {
    await pumpOnboarding(tester, const Locale('uk'));

    expect(find.text('Знайомство'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Далі →'), findsOneWidget);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'age picker fits $size with text $scale and keeps selection',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.localeTestValue = const Locale('uk');
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);
          MotionPolicy.debugOverride = MotionMode.test;
          addTearDown(() => MotionPolicy.debugOverride = null);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: buildAppTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const OnboardingScreen(),
              ),
            ),
          );
          await tester.pump();
          final avatar = find.widgetWithText(KidTap, '👧');
          expect(tester.getSize(avatar).width, greaterThanOrEqualTo(72));
          expect(tester.getSize(avatar).height, greaterThanOrEqualTo(72));
          await tester.tap(find.text('Далі →'), warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('4–5'));
          await tester.tap(find.text('4–5'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final selected = tester.widget<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '4–5 років',
            ),
          );
          expect(selected.properties.selected, isTrue);
        },
      );
    }
  }
}
