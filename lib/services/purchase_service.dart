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
  static const _yearlyId = 'yearly_premium';
  static const _monthlyId = 'monthly_premium';
  static const _productIds = {_yearlyId, _monthlyId};

  final ValueNotifier<bool> isPro = ValueNotifier(false);
  bool _initialized = false;

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

    // Sort: yearly → monthly
    const order = [_yearlyId, _monthlyId];
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
    }
  }

  Future<bool> purchase({int planIndex = 0}) async {
    if (products.isEmpty) return false;

    final product = products[planIndex.clamp(0, products.length - 1)];
    final param = PurchaseParam(productDetails: product);

    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Purchase by product ID directly (used by the paywall tile selection).
  Future<bool> purchaseByProductId(String productId) async {
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return false;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
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
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    if (_productIds.contains(purchase.productID)) {
      isPro.value = true;
      await _persist();
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
