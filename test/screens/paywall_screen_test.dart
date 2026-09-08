import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/pack_model.dart';
import 'package:talking_cards/models/profile_model.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/providers/profile_provider.dart';
import 'package:talking_cards/screens/paywall_screen.dart';
import 'package:talking_cards/services/profile_service.dart';
import 'package:talking_cards/services/purchase_service.dart';

/// Widget tests for the current paywall. Firebase isn't initialized in the
/// test environment — RemoteConfigService falls back to its baked-in
/// defaults, so RC-driven strings assert the default copy.
void main() {
  Widget createPaywallApp({
    List<Override> overrides = const [],
    bool isOnboarding = false,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: PaywallScreen(isOnboarding: isOnboarding),
      ),
    );
  }

  /// A catalogue of [n] packs, so the copy's number is under the test's
  /// control rather than whatever the bundled JSON happens to hold today.
  Override packsOf(int n) => packsProvider.overrideWith(
        (ref) async => List.generate(
          n,
          (i) => PackModel(
            id: 'p$i',
            title: 'Pack $i',
            icon: '🐶',
            color: const Color(0xFF000000),
            isLocked: true,
            isFree: false,
            cards: const [],
          ),
        ),
      );

  /// An active profile as onboarding would have saved it; [language] also
  /// drives [languageProvider], so 'en' renders the English paywall.
  Override profileNamed(String name, {String language = 'uk'}) =>
      profileProvider.overrideWith(
        (ref) => ProfileNotifier(ref, [
          ProfileModel(
            id: ProfileService.activeId,
            name: name,
            avatarEmoji: '👶',
            createdAt: DateTime(2026),
            language: language,
          ),
        ]),
      );

  /// Pumps the paywall and advances past its 3-second close-button delay
  /// so no timer is left pending at teardown.
  Future<void> pumpPaywall(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool isOnboarding = false,
  }) async {
    await tester.pumpWidget(
        createPaywallApp(overrides: overrides, isOnboarding: isOnboarding));
    await tester.pump(const Duration(seconds: 3));
    // Let the catalogue load give up: there is no billing client here, and
    // the CTA spins until the store answers or the budget runs out.
    await tester.pump(PurchaseService.storeBudget);
    await tester.pumpAndSettle();
  }

  ProductDetails product(String id, double raw, String price) => ProductDetails(
        id: id,
        title: id,
        description: id,
        price: price,
        rawPrice: raw,
        currencyCode: 'UAH',
      );

  /// A store that has answered: the CTA can sell. Without this the test
  /// environment has no billing client, so the screen correctly shows its
  /// "store unavailable" state instead of a Buy button.
  void seedStore() {
    // Shaped like Google Play's answer for a family still entitled to the
    // trial: a free-phase offer next to each paid base plan.
    PurchaseService.instance.debugIndexProducts([
      product('yearly_premium', 649, '649 грн'),
      product('yearly_premium', 0, 'Безкоштовно'),
      product('monthly_premium', 149, '149 грн'),
      product('monthly_premium', 0, 'Безкоштовно'),
    ]);
  }

  // Without a mock store SharedPreferences.getInstance() never completes in
  // a widget test — and the paywall now waits on it before its first paint.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => PurchaseService.instance.debugIndexProducts([]));

  group('PaywallScreen', () {
    testWidgets('renders headline and benefits', (tester) async {
      await pumpPaywall(tester, overrides: [packsOf(3)]);

      // RC-default headline (no child profile in tests → non-personalized)
      expect(find.text('Розблокуй всі картки!'), findsOneWidget);
      expect(find.text('3 розділи для розвитку'), findsOneWidget);
      expect(find.textContaining('400+ яскравих карток'), findsOneWidget);
      expect(find.textContaining('Нові розділи'), findsOneWidget);
    });

    testWidgets('the pack count is the catalogue\'s, correctly declined',
        (tester) async {
      // Two literals on this screen used to disagree (19 vs 21) while the
      // app shipped neither. 21 is also the awkward Ukrainian case: a
      // numeral ending in 1 takes the singular.
      await pumpPaywall(tester, overrides: [packsOf(21)]);

      expect(find.text('21 розділ для розвитку'), findsOneWidget);
      expect(find.textContaining('19'), findsNothing);
    });

    testWidgets('no catalogue yet means no number, not a stale one',
        (tester) async {
      // A load that never settles: the first frame on a cold start, or an
      // asset failure. Either way the copy must not invent a count.
      await pumpPaywall(tester, overrides: [
        packsProvider
            .overrideWith((ref) => Completer<List<PackModel>>().future),
      ]);

      expect(find.text('Розділи на кожну тему'), findsOneWidget);
      expect(find.textContaining('розділів для розвитку'), findsNothing);
    });

    testWidgets('the EN placeholder name "Kid" is not personalised',
        (tester) async {
      // Onboarding saves 'Kid' when the EN parent skips the name field —
      // the same placeholder as «Малюк», and it used to open the paywall
      // with "Kid's learning plan (age 2–3)".
      await pumpPaywall(tester,
          overrides: [profileNamed('Kid', language: 'en'), packsOf(21)]);

      expect(find.text('Unlock full potential'), findsOneWidget);
      expect(find.textContaining("Kid's"), findsNothing);
    });

    testWidgets('a real EN name still personalises the headline',
        (tester) async {
      await pumpPaywall(tester,
          overrides: [profileNamed('Mia', language: 'en'), packsOf(21)]);

      // Prefix only: the age suffix is glued with an NBSP by design.
      expect(find.textContaining("Mia's learning plan"), findsOneWidget);
    });

    testWidgets('EN social proof names no storefront', (tester) async {
      // "5.0 on the Ukrainian App Store" made a US parent read the offer
      // as someone else's. The number and the review stay real.
      await pumpPaywall(tester,
          isOnboarding: true,
          overrides: [profileNamed('Kid', language: 'en'), packsOf(21)]);

      expect(find.text('Rated 5.0 by parents'), findsOneWidget);
      expect(find.textContaining('App Store review (translated)'),
          findsOneWidget);
      expect(find.textContaining('Ukrain'), findsNothing);
    });

    testWidgets('the onboarding skip link reads as a real choice',
        (tester) async {
      // 13sp grey under the CTA looked like fine print; with the X hidden
      // for 3s a parent saw no way out and killed the app.
      await pumpPaywall(tester, isOnboarding: true, overrides: [packsOf(21)]);

      final label = find.text('Продовжити з безкоштовними розділами');
      expect(label, findsOneWidget);
      final style = tester.widget<Text>(label).style;
      expect(style?.fontSize, greaterThanOrEqualTo(16));
      expect(style?.fontWeight, FontWeight.w700);

      final button =
          find.ancestor(of: label, matching: find.byType(TextButton));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(56));
      // Full width inside the CTA column's 28dp side padding (800dp surface).
      expect(size.width, greaterThanOrEqualTo(700));
    });

    testWidgets('shows two fallback plan options', (tester) async {
      await pumpPaywall(tester);

      // Fallback plans when store products are not loaded
      expect(find.text('Річна'), findsOneWidget);
      expect(find.text('Місячна'), findsOneWidget);
    });

    testWidgets('shows yearly savings badge', (tester) async {
      await pumpPaywall(tester);

      // Fallback prices: 649 vs 149×12 → −64%.
      expect(find.text('Вигідніше на 64%'), findsOneWidget);
    });

    testWidgets('shows trial CTA and cancel-anytime note', (tester) async {
      seedStore();
      await pumpPaywall(tester);

      expect(find.text('Спробувати 3 дні безкоштовно'), findsOneWidget);
      expect(find.textContaining('Скасувати будь-коли'), findsAtLeast(1));
    });

    testWidgets('shows restore purchases button', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Відновити покупки'), findsOneWidget);
    });

    testWidgets('shows Terms of Use link', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Умови використання'), findsOneWidget);
    });

    testWidgets('shows Privacy Policy link', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('Конфіденційність'), findsOneWidget);
    });

    testWidgets('honest social proof: no fabricated 4.9 rating',
        (tester) async {
      await pumpPaywall(tester);

      expect(find.textContaining('4.9'), findsNothing);
    });

    testWidgets('close button appears after the 3s read delay',
        (tester) async {
      await pumpPaywall(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button pops screen', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                    popped = result == false || result == null;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Fire the 3s close-button timer scheduled in initState.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Invoke the close IconButton directly — its top-right position can
      // fall outside the tappable area in the small test viewport.
      final closeButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(IconButton),
        ),
      );
      closeButton.onPressed!();
      await tester.pumpAndSettle();

      expect(popped, true);
    });

    testWidgets('a spent trial is not advertised', (tester) async {
      // Both stores grant the introductory offer once per subscription
      // group. This device has already held an entitlement, so the native
      // sheet will ask for the full price — the screen must say so rather
      // than promise days the store will refuse.
      SharedPreferences.setMockInitialValues({
        'pro_validated_at': DateTime.now().millisecondsSinceEpoch,
      });
      seedStore();

      await pumpPaywall(tester);

      expect(find.text('3 ДНІ БЕЗКОШТОВНО'), findsNothing);
      expect(find.text('Спробувати 3 дні безкоштовно'), findsNothing);
      expect(find.textContaining('3 дні безкоштовно, потім'), findsNothing);
      expect(find.text('ПОВНИЙ ДОСТУП'), findsOneWidget);
      expect(find.text('Оформити підписку'), findsOneWidget);
      // The offer itself still has to be sellable.
      expect(find.textContaining('Скасувати будь-коли'), findsAtLeast(1));
    });

    testWidgets('an unreachable store is said out loud, with a retry',
        (tester) async {
      // No billing client here, exactly like a tablet with no Wi-Fi. The
      // old screen kept its Buy button, which then did nothing at all.
      await pumpPaywall(tester);

      expect(find.text('Стор недоступний — спробувати ще'), findsOneWidget);
      expect(find.textContaining('Перевірте інтернет'), findsOneWidget);
      expect(find.text('Спробувати 3 дні безкоштовно'), findsNothing);
      // The button is live — it retries rather than buying.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a purchase waiting on Ask to Buy is shown as such',
        (tester) async {
      seedStore();
      addTearDown(
          () => PurchaseService.instance.awaitingApproval.value = false);
      await pumpPaywall(tester);

      PurchaseService.instance.awaitingApproval.value = true;
      await tester.pumpAndSettle();

      expect(find.textContaining('Ask to Buy'), findsOneWidget);
    });

    testWidgets('a late entitlement closes the paywall and unlocks Pro',
        (tester) async {
      // The store can grant Pro long after the purchase sheet closes (Ask to
      // Buy, a slow verification). The screen must still end successfully —
      // it used to give up after 10 seconds and leave a paying family here.
      addTearDown(() => PurchaseService.instance.isPro.value = false);

      bool? result;
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () async {
                        result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const PaywallScreen()),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(capturedRef.read(isProProvider), false);

      // Well past the old 10-second window.
      await tester.pump(const Duration(seconds: 30));
      PurchaseService.instance.isPro.value = true;
      await tester.pumpAndSettle();

      expect(result, true);
      expect(capturedRef.read(isProProvider), true);
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets('tapping a plan tile selects it', (tester) async {
      seedStore();
      // Disposed at the end of the body: the tester checks handles before
      // tearDowns run.
      final semantics = tester.ensureSemantics();
      await pumpPaywall(tester);

      // The tile can sit below the fold of the 800×600 test surface; a tap
      // that misses would still leave '/місяць' on screen, so assert the
      // selection itself.
      final monthly = find.text('Місячна');
      await tester.ensureVisible(monthly);
      await tester.tap(monthly);
      await tester.pumpAndSettle();

      SemanticsNode tileOf(Finder label) => tester.getSemantics(find
          .ancestor(of: label, matching: find.byType(Semantics))
          .first);
      expect(tileOf(monthly).hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(tileOf(find.text('Річна')).hasFlag(SemanticsFlag.isSelected),
          isFalse);
      // And the CTA sub-line now quotes the monthly price.
      expect(find.textContaining('149 грн/місяць'), findsOneWidget);
      semantics.dispose();
    });
  });
}
