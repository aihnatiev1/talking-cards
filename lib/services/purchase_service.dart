import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// The facade above hides the store-specific APIs, and one of them is not
// optional here: only StoreKit can say whether *this* Apple ID may still
// have the introductory offer.
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart'
    show InAppPurchasePlatform;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart'
    show InAppPurchaseStoreKitPlatform;
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

  /// Length of the free trial configured in both stores. Verified against
  /// the ASC and Play APIs on 2026-09-06: FREE_TRIAL, three days, one
  /// period, on `yearly_premium` and `monthly_premium` in 175 (Apple) and
  /// 173 (Google) territories. Changing the offer means changing this too.
  static const kTrialDays = 3;

  final ValueNotifier<bool> isPro = ValueNotifier(false);
  bool _initialized = false;
  bool _entitlementSeen = false;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// One entry per SKU, priced the way a parent will actually be charged —
  /// this is the list the paywall renders.
  List<ProductDetails> products = [];

  /// The offer each SKU is charged against. Separate from [products]; see
  /// [_indexProducts] for why the two can differ.
  final Map<String, ProductDetails> _offerToBuy = {};

  /// Store-reported trial eligibility per SKU. Absent means "not asked yet
  /// or the store would not say".
  final Map<String, bool> _trialAvailable = {};

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_prefKey) ?? false;
    AnalyticsService.instance.setProProperty(isPro.value);
    isPro.addListener(() {
      AnalyticsService.instance.setProProperty(isPro.value);
    });

    // Subscribe before anything can be bought or restored — and regardless
    // of whether the store answers right now: a purchase approved through
    // Ask to Buy, or finished while we were offline, is delivered on this
    // stream at the next launch and must not be missed.
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
    );

    _initialized = true;
    // A failed load is retried from the paywall, see [ensureProducts]; the
    // entitlement work below does not depend on it — restore and
    // revalidation are local queries on both platforms.
    await ensureProducts();

    // Fresh install: silently restore purchases from store
    final isReinstall = !prefs.containsKey(_installedKey);
    await prefs.setBool(_installedKey, true);
    if (isReinstall && !isPro.value) {
      unawaited(_iap.restorePurchases().catchError((_) {}));
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
      AnalyticsService.instance.logProRevoked('no_entitlement_after_grace');
      isPro.value = false;
      await _persist();
    }
  }

  Future<bool>? _productsInFlight;

  /// Loads the catalogue if it is not loaded yet; true when [products] is
  /// usable afterwards. Safe to call repeatedly and concurrently.
  ///
  /// `init` used to give up for the whole session the moment the store was
  /// unreachable at launch — one bad second of Wi-Fi on a child's tablet and
  /// every Buy tap that day quietly did nothing (`product_unavailable`,
  /// nothing on screen). Now the paywall retries on open and offers a retry
  /// button, and the unavailable state is one the parent can see.
  Future<bool> ensureProducts() {
    if (products.isNotEmpty) return Future.value(true);
    return _productsInFlight ??= _loadProducts().whenComplete(() {
      _productsInFlight = null;
    });
  }

  /// How long a catalogue load may take before the paywall calls the store
  /// unavailable. The billing client can sit in "connecting" indefinitely
  /// on a bad network, and a spinner with no end is the Buy-button-that-
  /// does-nothing in a different costume.
  static const storeBudget = Duration(seconds: 8);

  Future<bool> _loadProducts() async {
    try {
      final response = await () async {
        if (!await _iap.isAvailable()) return null;
        return _iap.queryProductDetails(_productIds);
      }()
          .timeout(storeBudget);
      if (response == null) return false;
      _indexProducts(response.productDetails);
    } catch (_) {
      return false; // Timed out, billing client not connected, no network.
    }
    if (products.isEmpty) return false;
    unawaited(refreshTrialAvailability());
    return true;
  }

  /// True while a checkout this session started is waiting on someone
  /// else — a parent approving an Ask to Buy request, or the bank's SCA.
  /// The paywall says so instead of going quiet.
  final ValueNotifier<bool> awaitingApproval = ValueNotifier(false);

  /// Test seam: the store stream is the only way outcomes reach this
  /// service, and no test has a store.
  @visibleForTesting
  void debugHandlePurchaseUpdate(List<PurchaseDetails> updates) =>
      _onPurchaseUpdate(updates);

  @visibleForTesting
  void debugBeginPurchase(String productId) => _beginPurchase(productId);

  /// Splits the store response into what the paywall shows and what we
  /// charge against.
  ///
  /// Google Play returns one [ProductDetails] per *offer*, not per product:
  /// with the 3-day trial live that is two entries sharing the id
  /// `yearly_premium`, and the trial's entry carries `rawPrice: 0` because
  /// its first pricing phase is the free one. Two things follow. Play bills
  /// against the offer token of whichever entry is handed to
  /// `buyNonConsumable`, so the trial is granted only when that entry is
  /// picked on purpose — picking "the first match" left it to an unstable
  /// sort. And the paywall has to render the *other* entry, or the same
  /// plan appears twice, once priced 0 ₴/рік. Apple returns a single
  /// product per id, so there both maps hold that one product.
  void _indexProducts(List<ProductDetails> found) {
    _offerToBuy.clear();
    // A fresh store response makes anything we knew about eligibility stale
    // — on Play the answer is derived from these very offers.
    _trialAvailable.clear();
    final display = <String, ProductDetails>{};
    for (final p in found) {
      if (!_productIds.contains(p.id)) continue;
      final leadsWithFreePhase = p.rawPrice == 0;
      final buying = _offerToBuy[p.id];
      if (buying == null || (leadsWithFreePhase && buying.rawPrice != 0)) {
        _offerToBuy[p.id] = p;
      }
      final showing = display[p.id];
      if (showing == null || (showing.rawPrice == 0 && !leadsWithFreePhase)) {
        display[p.id] = p;
      }
    }
    const order = [_yearlyId, _monthlyId, _lifetimeId];
    products = display.values.toList()
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
  }

  /// Test seams. A real store response is the one input [_indexProducts]
  /// has, and no test can obtain one.
  @visibleForTesting
  void debugIndexProducts(List<ProductDetails> found) => _indexProducts(found);

  /// The offer [productId] would be charged against right now.
  @visibleForTesting
  ProductDetails? debugOfferToBuy(String productId) => _offerToBuy[productId];

  /// Days of free trial the store will actually honour for [productId], or
  /// null when there is nothing free to promise.
  ///
  /// Both stores grant an introductory offer once per subscription group, so
  /// a parent who already used the three days meets the full price on the
  /// native sheet. A paywall that keeps shouting "3 ДНІ БЕЗКОШТОВНО" at them
  /// recreates the exact mismatch that produced ~40 purchase_start and zero
  /// sales in August, so the copy asks here first.
  ///
  /// An unknown answer keeps promising the trial: it really is configured in
  /// every territory, and hiding it from a parent who is entitled to it
  /// costs a sale.
  int? trialDaysFor(String productId) {
    if (productId == _lifetimeId) return null; // One-time purchase.
    return (_trialAvailable[productId] ?? true) ? kTrialDays : null;
  }

  /// What the paywall is telling this parent about the trial, as an
  /// analytics dimension: `offered`, `spent`, or `none` for the one-time
  /// unlock. Derived from the same map as [trialDaysFor] on purpose — the
  /// value has to be what the screen actually said, not what the store
  /// would answer on a second look.
  String trialStateFor(String productId) {
    if (productId == _lifetimeId) return 'none';
    return (_trialAvailable[productId] ?? true) ? 'offered' : 'spent';
  }

  /// Re-reads trial eligibility from the store. The paywall calls this on
  /// open, because eligibility flips the moment a trial is taken.
  Future<void> refreshTrialAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    // An entitlement this device has already seen means the subscription
    // group's one introductory offer is spent. Offline, free, and it covers
    // the common "took the trial, cancelled, came back" case even when the
    // store cannot be reached below.
    final spentOnThisDevice = prefs.getInt(_validatedAtKey) != null;

    for (final id in const [_yearlyId, _monthlyId]) {
      if (spentOnThisDevice) {
        _trialAvailable[id] = false;
        continue;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Play only returns the offers this user qualifies for, so a
        // free-phase offer coming back for the SKU *is* the answer.
        final offer = _offerToBuy[id];
        if (offer != null) _trialAvailable[id] = offer.rawPrice == 0;
        continue;
      }
      final platform = InAppPurchasePlatform.instance;
      if (platform is! InAppPurchaseStoreKitPlatform) continue;
      try {
        _trialAvailable[id] = await platform.isIntroductoryOfferEligible(id);
      } catch (_) {
        // StoreKit 1, no network, product never loaded — leave it unset and
        // fall back to promising the offer (see [trialDaysFor]).
      }
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

  Future<bool> _buy(ProductDetails shown) async {
    // On Play the entry the paywall displays is not the entry that carries
    // the trial's offer token — see [_indexProducts].
    final product = _offerToBuy[shown.id] ?? shown;
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
    awaitingApproval.value = false;
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
    awaitingApproval.value = false;
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
        // Ask to Buy / SCA: the sheet is gone but nothing is decided. The
        // three-minute backstop would have filed this as `no_outcome_in_3min`
        // — a purchase_error for a family that is simply waiting on a
        // parent. The approval, when it comes, arrives on this same stream,
        // possibly in a later session, and `_verifyAndDeliver` handles it
        // without a pending id.
        _pendingTimer?.cancel();
        awaitingApproval.value = true;
        analytics.logPurchasePending(id);
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _resolvePurchase(
            id, () => analytics.logPurchaseSuccess(id, trialStateFor(id)));
      case PurchaseStatus.canceled:
        _resolvePurchase(
            id, () => analytics.logPurchaseCancel(id, trialStateFor(id)));
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
