import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class WhatsNewService {
  WhatsNewService._();
  static final instance = WhatsNewService._();

  // Bump this key string each release to re-trigger the overlay.
  static const _seenKey = 'whats_new_seen_v2_0';

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  /// Show the "What's New" bottom sheet once per release.
  /// Returns immediately if already seen.
  Future<void> showIfNeeded(BuildContext context, {bool isEn = false}) async {
    if (!await shouldShow()) return;
    await markSeen();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhatsNewSheet(isEn: isEn),
    );
  }
}

// ─────────────────────────────────────────────
//  Bottom sheet UI
// ─────────────────────────────────────────────

class _WhatsNewSheet extends StatelessWidget {
  final bool isEn;
  const _WhatsNewSheet({required this.isEn});

  @override
  Widget build(BuildContext context) {
    final features = isEn ? _featuresEn : _features;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          const Text('✨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            isEn ? "What's new!" : 'Що нового!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            isEn
                ? 'Big update — new game, a bunny friend, and a daily ritual'
                : 'Велике оновлення — нові ігри, друг-зайчик і щоденний ритуал',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          // Feature list
          ...features.map((f) => _FeatureRow(
                emoji: f.$1,
                title: f.$2,
                subtitle: f.$3,
                color: f.$4,
              )),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isEn ? 'Awesome, let\'s go!' : 'Чудово, грати!',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// (emoji, title, subtitle, color)
const _features = [
  ('🫧', 'Нова гра «Бульбашки»',
      'Лопай бульки з картинками — Pop-It-стиль із словами',
      Color(0xFFE91E63)),
  ('🐰', 'Зайчик Bloom вітається',
      'Тапни його на головній чи в грі — він підстрибне у відповідь',
      Color(0xFFF57F17)),
  ('🃏', '«Сьогодні» на головній',
      '3 кроки щодня: картка дня → пак → гра. Маленький ритуал — велика звичка',
      Color(0xFF6C63FF)),
  ('🌟', 'Скарбничка слів',
      'Колекція всього, що вже знає малюк — нові слова з\'являються самі',
      Color(0xFF00BFA5)),
  ('🔥', 'Серії та нагороди',
      'Святкуємо 3, 7, 14 і 30 днів поспіль з вибухом конфеті',
      Color(0xFFFF6F4D)),
];

const _featuresEn = [
  ('🫧', 'New game: Pop the bubbles',
      'Pop bubbles with cards inside — Pop-It style with real words',
      Color(0xFFE91E63)),
  ('🐰', 'Bloom the bunny says hi',
      'Tap him on the home screen or in games — he bounces back at you',
      Color(0xFFF57F17)),
  ('🃏', "Today's plan on home",
      '3 steps a day: today\'s card → today\'s pack → a game. Small ritual, big habit',
      Color(0xFF6C63FF)),
  ('🌟', 'Treasure box of words',
      "Your child's growing word collection — new ones appear automatically",
      Color(0xFF00BFA5)),
  ('🔥', 'Streaks and rewards',
      'Celebrate 3, 7, 14, and 30 days in a row with a burst of confetti',
      Color(0xFFFF6F4D)),
];

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
