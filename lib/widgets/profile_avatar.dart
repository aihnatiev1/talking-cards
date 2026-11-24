import 'package:flutter/material.dart';

/// A child's avatar: the painted clay head for the emoji the profile stores,
/// and the emoji itself for any value that has no picture (old profiles,
/// parent avatars) — nothing already saved stops working.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.emoji, {super.key, this.size = 40});

  final String emoji;
  final double size;

  static const _art = {
    '👶': 'baby',
    '🙂': 'baby',
    '👧': 'girl',
    '👦': 'boy',
    '🧒': 'kid',
    '🐱': 'cat',
    '🐶': 'dog',
    '🐻': 'bear',
    '🐸': 'frog',
    '🦊': 'fox',
    '🐼': 'panda',
    '🦄': 'unicorn',
    '🌟': 'star',
  };

  /// Whether [emoji] has a painted head.
  static bool hasArt(String emoji) => _art.containsKey(emoji);

  @override
  Widget build(BuildContext context) {
    final name = _art[emoji];
    if (name == null) {
      return SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(emoji, style: TextStyle(fontSize: size * 0.7)),
        ),
      );
    }
    return Image.asset(
      'assets/images/avatars/$name.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(emoji, style: TextStyle(fontSize: size * 0.7)),
        ),
      ),
    );
  }
}
