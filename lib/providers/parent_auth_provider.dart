import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the parental PIN.
///
/// [state] = true means the parent has authenticated this app session.
/// Authentication resets to false when the app is restarted (in-memory only).
///
/// The PIN itself is persisted in SharedPreferences at a global (non-profile)
/// key — one PIN protects all profiles on this device.
final parentAuthProvider =
    StateNotifierProvider<ParentAuthNotifier, bool>(
  (ref) => ParentAuthNotifier(),
);

class ParentAuthNotifier extends StateNotifier<bool> {
  ParentAuthNotifier() : super(false);

  static const _pinKey = 'parent_pin';

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  /// Returns true and authenticates the session if [pin] is correct.
  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == pin) {
      state = true;
      return true;
    }
    return false;
  }

  /// Save a new PIN. Authenticates the session automatically.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    state = true;
  }

  /// Wipe the PIN and lock out of parent area.
  Future<void> resetPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    state = false;
  }

  void lock() => state = false;
}
