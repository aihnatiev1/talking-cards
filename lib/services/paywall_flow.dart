import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/packs_provider.dart';
import '../screens/paywall_screen.dart';

/// Shows the paywall. Returns true if purchase was successful.
///
/// Apple's IAP confirmation (Touch ID / Face ID / password) is the parental
/// safeguard at the actual purchase moment, so no in-app math gate is needed
/// before showing the offer. The gate stays on share / external links only.
///
/// Set [isOnboarding] when invoked right after onboarding to render the
/// welcome variant (extra social proof + explicit "continue free" button).
///
/// [source] names the door the parent came through — 'locked_tile',
/// 'preview_end', 'games_lock', 'coloring_gate', 'reminder' — and lands in
/// `paywall_view.source`, so the funnel can say which entry point converts
/// and which only collects cancels.
Future<bool> runPaywallFlow(
  BuildContext context,
  WidgetRef ref, {
  bool isOnboarding = false,
  String source = 'paywall_screen',
}) async {
  final purchased = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PaywallScreen(
        isOnboarding: isOnboarding,
        source: isOnboarding ? 'paywall_onboarding' : source,
      ),
    ),
  );

  if (purchased == true && context.mounted) {
    ref.read(isProProvider.notifier).state = true;
    return true;
  }
  return false;
}
