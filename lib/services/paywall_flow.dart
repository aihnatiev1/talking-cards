import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/packs_provider.dart';
import '../screens/paywall_screen.dart';
import '../widgets/parental_gate.dart';

/// Runs the full unlock flow: parental gate → paywall.
/// Returns true if purchase was successful.
Future<bool> runPaywallFlow(BuildContext context, WidgetRef ref) async {
  final passed = await ParentalGate.show(context);
  if (!passed || !context.mounted) return false;

  final purchased = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );

  if (purchased == true && context.mounted) {
    ref.read(isProProvider.notifier).state = true;
    return true;
  }
  return false;
}
