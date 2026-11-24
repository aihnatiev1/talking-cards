import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../utils/design_tokens.dart';
import 'kid_tap.dart';
import 'profile_avatar.dart';

/// Tappable avatar chip shown in the HomeScreen top bar.
/// Displays active profile emoji + name; opens profile selector on tap.
class ProfileAvatarChip extends ConsumerWidget {
  const ProfileAvatarChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final active = profileState.active;
    if (active == null) return const SizedBox.shrink();

    return KidTap(
      onTap: () => showProfileSelector(context),
      // The selector sheet slides in with its own sound; a tock here would
      // double it. The squeeze and the haptic still answer the finger.
      sound: null,
      // A chip is shorter than 72 dp by design (it rides the home top bar
      // beside the streak), so the hit zone is padded out to the rule-1
      // minimum instead of the drawing.
      child: KidHitBox(
        // The same round avatar button as on the Play home: the child's
        // painted head, nothing else to read.
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            shape: BoxShape.circle,
            border: Border.all(color: DT.outline, width: 2),
          ),
          child: ProfileAvatar(active.avatarEmoji, size: 44),
        ),
      ),
    );
  }
}
