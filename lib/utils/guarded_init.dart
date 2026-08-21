import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs a startup step behind both an error net and a time budget.
///
/// Startup used to be all-or-nothing: `SplashScreen` awaited every service
/// with a bare try/catch, so a service that *threw* was survivable but a
/// service that *hung* left the user on a spinner forever. Analytics showed
/// installs that fired `session_start` and never a single card view, which is
/// exactly what an infinite splash looks like from the outside.
///
/// A skipped init is always recoverable — Remote Config falls back to
/// defaults, purchases re-query on the paywall, notifications reschedule on
/// the next launch. A blank screen is not.
///
/// Returns true when [body] finished on its own, false when it was abandoned
/// (threw or ran out of budget).
Future<bool> runGuarded(
  String name,
  Future<void> Function() body, {
  Duration? budget,
  void Function(String name)? onTimeout,
}) async {
  try {
    await (budget == null ? body() : body().timeout(budget));
    return true;
  } on TimeoutException {
    debugPrint('startup: $name timed out after ${budget?.inSeconds}s');
    onTimeout?.call(name);
    return false;
  } catch (e, st) {
    debugPrint('startup: $name failed: $e\n$st');
    return false;
  }
}
