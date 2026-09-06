import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/services/purchase_service.dart';

/// These tests cover the store response *shaping*, which is where the
/// paywall's promises come from. Nothing here touches a store: the input is
/// the product list, fed through the test seam.
ProductDetails _product(String id, double rawPrice, String price) =>
    ProductDetails(
      id: id,
      title: id,
      description: id,
      price: price,
      rawPrice: rawPrice,
      currencyCode: 'UAH',
    );

void main() {
  // The service reaches for InAppPurchase.instance on construction, which
  // registers the platform plugin: that needs a binding, and the Play
  // client would go looking for a real billing connection. StoreKit's
  // registration is inert in tests, so construct under iOS and switch to
  // Android only where the Play-specific branch is what's under test.
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final service = PurchaseService.instance;

  tearDown(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDownAll(() => debugDefaultTargetPlatformOverride = null);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.debugIndexProducts([]);
  });

  group('offer indexing', () {
    test('Play\'s per-offer duplicates collapse to one plan per SKU', () async {
      // Google Play returns one entry per offer: the base plan, plus the
      // 3-day trial whose first pricing phase is free.
      service.debugIndexProducts([
        _product('yearly_premium', 0, 'Безкоштовно'),
        _product('yearly_premium', 649, '649,00 ₴'),
        _product('monthly_premium', 149, '149,00 ₴'),
      ]);

      expect(service.products.map((p) => p.id),
          ['yearly_premium', 'monthly_premium']);
      // The tile must quote what the parent will be charged, never the
      // trial's zero.
      expect(service.products.first.rawPrice, 649);
    });

    test('the checkout charges the free-phase offer, not the shown one', () {
      service.debugIndexProducts([
        _product('yearly_premium', 649, '649,00 ₴'),
        _product('yearly_premium', 0, 'Безкоштовно'),
      ]);

      // Play bills against the offer token of the entry handed to
      // buyNonConsumable — the trial is granted only via the free one.
      expect(service.debugOfferToBuy('yearly_premium')!.rawPrice, 0);
      expect(service.products.single.rawPrice, 649);
    });

    test('an unknown SKU from the store is ignored', () {
      service.debugIndexProducts([_product('gold_bars', 99, '99 ₴')]);
      expect(service.products, isEmpty);
    });
  });

  group('trial availability', () {
    test('promised while the store has not answered', () {
      expect(service.trialDaysFor('yearly_premium'), PurchaseService.kTrialDays);
    });

    test('never promised for the one-time lifetime unlock', () {
      expect(service.trialDaysFor('lifetime_premium'), isNull);
    });

    test('withheld once this device has held an entitlement', () async {
      // The subscription group grants its introductory offer once, so a
      // parent who already took the 3 days meets the full price on the
      // native sheet — the paywall must not promise otherwise.
      SharedPreferences.setMockInitialValues({
        'pro_validated_at': DateTime.now().millisecondsSinceEpoch,
      });

      await service.refreshTrialAvailability();

      expect(service.trialDaysFor('yearly_premium'), isNull);
      expect(service.trialDaysFor('monthly_premium'), isNull);
    });

    test('a free-phase offer from Play means the trial is live', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      service.debugIndexProducts([
        _product('yearly_premium', 0, 'Безкоштовно'),
        _product('yearly_premium', 649, '649,00 ₴'),
      ]);

      await service.refreshTrialAvailability();

      expect(service.trialDaysFor('yearly_premium'), PurchaseService.kTrialDays);
    });

    test('Play returning only a paid offer means the trial is spent',
        () async {
      // Play filters offers by eligibility, so no free phase coming back
      // for a loaded SKU is the store saying "not for this account".
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      service.debugIndexProducts([_product('yearly_premium', 649, '649,00 ₴')]);

      await service.refreshTrialAvailability();

      expect(service.trialDaysFor('yearly_premium'), isNull);
    });
  });
}
