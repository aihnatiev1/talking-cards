import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/widgets/app_logo_mark.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';
import 'package:talking_cards/widgets/notification_opt_in_dialog.dart';
import 'package:talking_cards/widgets/parental_gate.dart';
import 'package:talking_cards/widgets/paywall_hero_art.dart';

import '../helpers/motion.dart';

/// The parent zone belongs to the same universe as the child's half
/// (ux-gap-audit 2026-09-13 G15): where a grown-up is asked for money,
/// trust or a permission, the art is the app's own — Bloom and the drawn
/// [AppIcon] set — not a system emoji or a Material glyph.
///
/// What stays deliberately *un*-childish is the parental gate: it is the
/// door out of the kid zone (CLAUDE.md rule 7), so it gets bigger keys for
/// an adult thumb and nothing else.
void main() {
  useTestMotion();

  group('paywall hero art', () {
    testWidgets('is Bloom plus a fan of three cards, not an emoji',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PaywallHeroArt(semanticsLabel: 'Bloom and the cards'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BloomMascot), findsOneWidget);
      // One glyph per card: a picture, its sound, the star of what's new.
      expect(find.byType(AppIconView), findsNWidgets(3));
      expect(find.byKey(const ValueKey('fan-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('fan-mid')), findsOneWidget);
      expect(find.byKey(const ValueKey('fan-right')), findsOneWidget);
    });

    testWidgets('fits the paywall banner width without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          // The narrowest banner the paywall can build: a 320 dp phone
          // minus the screen's 28 dp padding and the banner's own 20 dp.
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Center(
              child: PaywallHeroArt(semanticsLabel: 'Bloom and the cards'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('about mark', () {
    testWidgets('introduces the app with Bloom', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: AppLogoMark(semanticsLabel: 'FirstWords Cards')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BloomMascot), findsOneWidget);
      expect(tester.getSize(find.byType(AppLogoMark)), const Size(64, 64));
    });
  });

  group('notification opt-in', () {
    testWidgets('asks with Bloom and a drawn bell, not 🔔', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => maybeAskNotificationOptIn(context, ref),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.text('Нагадувати про заняття?'), findsOneWidget);
      expect(find.text('🔔'), findsNothing);
      expect(find.byType(BloomMascot), findsOneWidget);
      expect(find.byType(AppIconView), findsOneWidget);
    });
  });

  group('parental gate', () {
    Future<void> openGate(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showParentalGate(context, isEn: false),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('keys are 72×64 for an adult thumb', (tester) async {
      await openGate(tester);

      for (final digit in ['0', '5', '9']) {
        expect(
          tester.getSize(find.widgetWithText(TextButton, digit)),
          const Size(72, 64),
          reason: 'A missed key burns one of the three tries.',
        );
      }
    });

    testWidgets('stays neutral: no mascot in the doorway', (tester) async {
      await openGate(tester);

      expect(find.byType(BloomMascot), findsNothing);
      expect(find.byType(AppIconView), findsNothing);
      // Still a gate: the question is spelled in words a reader can parse
      // and a pre-reader cannot.
      expect(find.textContaining('плюс'), findsOneWidget);
    });
  });
}
