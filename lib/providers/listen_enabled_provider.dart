import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/listen_service.dart';
import '../services/profile_service.dart';

/// Whether a grown-up has turned the microphone on for this profile.
///
/// Off until someone deliberately turns it on, and per profile rather than
/// per app: a family where one child is working on speech and another is
/// not should not have to choose once for both. The switch lives behind
/// the parental gate, and this notifier is the one thing that moves
/// [ListenService.enabled] — no screen flips that flag on its own except
/// the parent-side microphone check, which borrows it and puts it back.
final listenEnabledProvider =
    StateNotifierProvider<ListenEnabledNotifier, bool>(
      (ref) => ListenEnabledNotifier(),
    );

class ListenEnabledNotifier extends StateNotifier<bool> {
  ListenEnabledNotifier() : super(false) {
    _load();
  }

  static const _key = 'listen_enabled';

  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_prefixedKey) ?? false;
    state = value;
    ListenService.instance.enabled.value = value;
  }

  Future<void> set(bool value) async {
    state = value;
    ListenService.instance.enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefixedKey, value);
  }
}
