import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const _prefKey = 'is_pro';

  final ValueNotifier<bool> isPro = ValueNotifier(false);
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_prefKey) ?? false;
    _initialized = true;
  }

  /// Mock purchase — always succeeds.
  /// Replace this file with RevenueCat integration later.
  /// [planIndex] 0=weekly, 1=yearly, 2=monthly — reserved for RevenueCat.
  Future<bool> purchase({int planIndex = 1}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    isPro.value = true;
    await _persist();
    return true;
  }

  /// Mock restore — checks local storage.
  Future<bool> restore() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final restored = prefs.getBool(_prefKey) ?? false;
    isPro.value = restored;
    return restored;
  }

  /// Debug: reset purchase state
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
}
