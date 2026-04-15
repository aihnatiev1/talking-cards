import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class WhatsNewService {
  WhatsNewService._();
  static final instance = WhatsNewService._();

  // Bump this key string each release to re-trigger the overlay.
  static const _seenKey = 'whats_new_seen_v1_2';

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
  Future<void> showIfNeeded(BuildContext context) async {
    if (!await shouldShow()) return;
    await markSeen();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WhatsNewSheet(),
    );
  }
}

// ─────────────────────────────────────────────
//  Bottom sheet UI
// ─────────────────────────────────────────────

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet();

  @override
  Widget build(BuildContext context) {
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
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text(
            'Що нового!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Велике оновлення — спеціально для розвитку мовлення',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          // Feature list
          ..._features.map((f) => _FeatureRow(
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
              child: const Text(
                'Чудово, грати!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
  ('🎮', '5 нових ігор', 'Знайди зайве, Протилежності, Рахуй склади, Повтори за мною, За звуком',
      Color(0xFF6C63FF)),
  ('📦', '11 логопедичних паків', 'Дії, Протилежності та 9 паків за звуком: Р, Л, Ш, С, З, Ж, Ч, Щ, Ц',
      Color(0xFF00BFA5)),
  ('🎤', 'Мікрофон на Android', 'Гра «Повтори за мною» тепер працює на обох платформах',
      Color(0xFFE91E63)),
  ('📊', 'Статистика ігор', 'У батьківській панелі — нова вкладка «Ігри» з рекордами',
      Color(0xFFF57F17)),
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
