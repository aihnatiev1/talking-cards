import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../utils/constants.dart';

/// Tappable avatar chip shown in the HomeScreen top bar.
/// Displays active profile emoji + name; opens profile selector on tap.
class ProfileAvatarChip extends ConsumerWidget {
  const ProfileAvatarChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final active = profileState.active;
    if (active == null) return const SizedBox.shrink();

    // Only show chip if more than one profile exists, or the default was renamed
    final showName = active.name != 'Малюк' || profileState.profiles.length > 1;
    final isEn = active.language == 'en';

    return GestureDetector(
      onTap: () => showProfileSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: kAccent.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(active.avatarEmoji,
                style: const TextStyle(fontSize: 16)),
            if (isEn) ...[
              const SizedBox(width: 2),
              const Text('🇬🇧', style: TextStyle(fontSize: 12)),
            ],
            if (showName) ...[
              const SizedBox(width: 5),
              Text(
                active.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
            ],
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: kAccent),
          ],
        ),
      ),
    );
  }
}
