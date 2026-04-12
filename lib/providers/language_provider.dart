import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_provider.dart';

/// Returns the active profile's learning language ('uk' or 'en').
///
/// Derives directly from [profileProvider] — no separate persistence.
/// When the profile switches or its language changes, this automatically
/// emits the new value and [packsProvider] reloads.
final languageProvider = Provider<String>((ref) {
  final profile = ref.watch(profileProvider);
  return profile.active?.language ?? 'uk';
});
