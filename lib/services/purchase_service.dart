import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'notification_service.dart';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const _prefKey = 'is_pro';
  static const _installedKey = 'installed';
  static const _validatedAtKey = 'pro_validated_at';
  static const _yearlyId = 'yearly_premium';
  static const _monthlyId = 'monthly_premium';
  // One-time unlock; queried alongside the subscriptions and simply absent
  // until the SKU is created in the store consoles.
  static const _lifetimeId = 'lifetime_premium';
  static const _productIds = {_yearlyId, _monthlyId, _lifetimeId};

  // Silent restore is a local query on both platforms (StoreKit 2
  // currentEntitlements / Play Billing queryPurchases), so an expired
  // subscription simply stops being delivered. Re-check at most daily and
  // keep a grace window so a transient store hiccup or a long-offline
  // device never locks a paying family out.
  static const _revalidateAfter = Duration(hours: 24);
  static const _graceWindow = Duration(days: 3);

  final ValueNotifier<bool> isPro = ValueNotifier(false);
  bool _initialized = false;
  bool _entitlementSeen = false;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = [];

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_prefKey) ?? false;
    AnalyticsService.instance.setProProperty(isPro.value);
    isPro.addListener(() {
      AnalyticsService.instance.setProProperty(isPro.value);
    });

    final available = await _iap.isAvailable();
    if (!available) {
      _initialized = true;
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
    );

    final response = await _iap.queryProductDetails(_productIds);
    products = response.productDetails;

    // Sort: yearly → monthly → lifetime
    const order = [_yearlyId, _monthlyId, _lifetimeId];
    products.sort((a, b) {
      final ai = order.indexOf(a.id);
      final bi = order.indexOf(b.id);
      return ai.compareTo(bi);
    });

    _initialized = true;

    // Fresh install: silently restore purchases from store
    final isReinstall = !prefs.containsKey(_installedKey);
    await prefs.setBool(_installedKey, true);
    if (isReinstall && !isPro.value) {
      _iap.restorePurchases();
    } else if (isPro.value) {
      unawaited(_revalidateEntitlement(prefs));
    }
  }

  /// Re-checks that a locally persisted Pro flag is still backed by an
  /// active subscription. Without this a cancelled trial stays Pro forever.
  Future<void> _revalidateEntitlement(SharedPreferences prefs) async {
    final validatedAtMs = prefs.getInt(_validatedAtKey);
    final now = DateTime.now();
    if (validatedAtMs == null) {
      // Existing Pro user updating to the first build with revalidation:
      // start the clock instead of risking an instant revoke.
      await prefs.setInt(_validatedAtKey, now.millisecondsSinceEpoch);
      return;
    }
    final validatedAt = DateTime.fromMillisecondsSinceEpoch(validatedAtMs);
    if (now.difference(validatedAt) < _revalidateAfter) return;

    _entitlementSeen = false;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      return; // Store unreachable — keep current state until next launch.
    }
    // Entitlements arrive via purchaseStream; give them a moment.
    await Future<void>.delayed(const Duration(seconds: 10));
    if (_entitlementSeen) return;
    if (now.difference(validatedAt) > _graceWindow) {
      isPro.value = false;
      await _persist();
    }
  }

  Future<bool> purchase({int planIndex = 0}) async {
    if (products.isEmpty) return false;

    final product = products[planIndex.clamp(0, products.length - 1)];
    return _buy(product);
  }

  /// Purchase by product ID directly (used by the paywall tile selection).
  Future<bool> purchaseByProductId(String productId) async {
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      // Products never loaded (store unreachable at launch) — the paywall
      // still renders its fallback prices, so this is invisible without an
      // event of its own.
      AnalyticsService.instance
          .logPurchaseError(productId, 'product_unavailable');
      return false;
    }
    return _buy(product);
  }

  Future<bool> _buy(ProductDetails product) async {
    _beginPurchase(product.id);
    final param = PurchaseParam(productDetails: product);
    bool started;
    try {
      started = await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _resolvePurchase(product.id, () => AnalyticsService.instance
          .logPurchaseError(product.id, 'buy_threw: $e'));
      rethrow;
    }
    if (!started) {
      _resolvePurchase(product.id, () => AnalyticsService.instance
          .logPurchaseError(product.id, 'buy_refused'));
    }
    return started;
  }

  // --- Purchase outcome tracking ---
  //
  // Terminal events used to be logged by the paywall widget, behind a
  // `mounted` check. In the week of 2026-08-20 that produced 5 purchase_start
  // events and exactly one terminal event: the system sheet backgrounds the
  // app, the screen goes away, and the outcome was never recorded. The store
  // stream outlives any widget, so the funnel closes here instead.

  /// Product the user is actively buying — lets the stream tell a real
  /// checkout apart from a silent restore at launch.
  String? _pendingPurchaseId;
  Timer? _pendingTimer;

  /// Face ID, a password or an Ask-to-Buy approval can take minutes; this is
  /// only a backstop so an outcome that never arrives is still visible.
  static const _pendingBudget = Duration(minutes: 3);

  void _beginPurchase(String productId) {
    _pendingTimer?.cancel();
    _pendingPurchaseId = productId;
    _pendingTimer = Timer(_pendingBudget, () {
      if (_pendingPurchaseId != productId) return;
      _pendingPurchaseId = null;
      AnalyticsService.instance
          .logPurchaseError(productId, 'no_outcome_in_3min');
    });
  }

  void _resolvePurchase(String productId, void Function() log) {
    if (_pendingPurchaseId != productId) return;
    _pendingPurchaseId = null;
    _pendingTimer?.cancel();
    log();
  }

  Future<bool> restore() async {
    await _iap.restorePurchases();
    // Wait for purchaseStream to deliver result, timeout after 10s
    if (!isPro.value) {
      final completer = Completer<void>();
      void listener() {
        if (isPro.value && !completer.isCompleted) {
          completer.complete();
        }
      }
      isPro.addListener(listener);
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      isPro.removeListener(listener);
    }
    return isPro.value;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndDeliver(purchase);
      }
      _logOutcome(purchase);
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Closes the funnel for a checkout this session started. A `restored`
  /// entitlement arriving from the silent launch restore has no pending id
  /// and is deliberately not reported as a sale.
  void _logOutcome(PurchaseDetails purchase) {
    final id = purchase.productID;
    if (id != _pendingPurchaseId) return;
    final analytics = AnalyticsService.instance;
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return; // Ask to Buy / SCA — still in flight.
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _resolvePurchase(id, () => analytics.logPurchaseSuccess(id));
      case PurchaseStatus.canceled:
        _resolvePurchase(id, () => analytics.logPurchaseCancel(id));
      case PurchaseStatus.error:
        final err = purchase.error;
        _resolvePurchase(
            id,
            () => analytics.logPurchaseError(
                id, err == null ? 'unknown' : '${err.code}: ${err.message}'));
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    if (_productIds.contains(purchase.productID)) {
      _entitlementSeen = true;
      isPro.value = true;
      await _persist();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _validatedAtKey, DateTime.now().millisecondsSinceEpoch);
      // No reason to nag a paying user with the day-3 trial reminder.
      await NotificationService.instance.cancelPaywallReminder();
    }
  }

  Future<void> resetPurchase() async {
    if (!kDebugMode) return;
    isPro.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isPro.value);
  }

  void dispose() {
    _sub?.cancel();
  }
}
