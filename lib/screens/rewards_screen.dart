import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/streak_provider.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../utils/uk_grammar.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  static const _accent = kAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final s = AppS(ref.read(languageProvider) == 'en');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s('Нагороди', 'Rewards'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Current streak display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    s.isEn
                        ? '${streak.currentStreak} days'
                        : '${streak.currentStreak} ${dayWord(streak.currentStreak)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s('поспіль', 'streak'),
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Badges grid
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s('Значки', 'Badges'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: milestones.map((m) {
                final earned = streak.currentStreak >= m.days;
                return _BadgeCard(
                  badge: m.badge,
                  label: m.label,
                  earned: earned,
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Bonus cards
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s('Бонусні картки', 'Bonus cards'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: milestones.map((m) {
                final earned = streak.unlockedRewards.contains(m.bonusEmoji);
                return _BonusCard(emoji: m.bonusEmoji, earned: earned);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

}

class _BadgeCard extends StatelessWidget {
  final String badge;
  final String label;
  final bool earned;

  const _BadgeCard({
    required this.badge,
    required this.label,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: earned
            ? const Color(0xFFFFD93D).withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned
              ? const Color(0xFFFFD93D).withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            badge,
            style: TextStyle(
              fontSize: 44,
              color: earned ? null : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: earned ? Colors.grey[800] : Colors.grey[400],
            ),
          ),
          if (!earned)
            Text(
              '🔒',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  final String emoji;
  final bool earned;

  const _BonusCard({required this.emoji, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: earned
            ? kTeal.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned
              ? kTeal.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Center(
        child: Text(
          earned ? emoji : '❓',
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}
