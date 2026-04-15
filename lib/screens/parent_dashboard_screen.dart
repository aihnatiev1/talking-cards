import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/weak_words_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../utils/constants.dart';
import '../widgets/activity_chart.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: GestureDetector(
            onTap: () => showProfileSelector(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.active?.avatarEmoji ?? '👶',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  profile.active?.name ?? 'Малюк',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Colors.grey[500]),
              ],
            ),
          ),
          centerTitle: false,
          bottom: const TabBar(
            isScrollable: false,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 13),
            tabs: [
              Tab(text: 'Огляд'),
              Tab(text: 'Тиждень'),
              Tab(text: 'Паки'),
              Tab(text: 'Ігри'),
              Tab(text: 'Помилки'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _WeeklyTab(),
            _PacksTab(),
            _GamesTab(),
            _WeakWordsTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 1 — Overview
// ─────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final packProgress = ref.watch(packProgressProvider);
    final completedPacks = ref.watch(completedPacksProvider);
    final dailyStats = ref.watch(dailyStatsProvider);

    final wordsSeenTotal = packProgress.values.fold(0, (a, b) => a + b);
    final activeDays = dailyStats.values
        .where((v) => v > 0)
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _statRow([
          _StatCard(
            emoji: '🔥',
            label: 'Серія',
            value: '${streak.currentStreak} дн.',
            color: kStreakOrange,
          ),
          _StatCard(
            emoji: '📚',
            label: 'Переглянуто',
            value: '$wordsSeenTotal карток',
            color: kAccent,
          ),
        ]),
        const SizedBox(height: 12),
        _statRow([
          _StatCard(
            emoji: '✅',
            label: 'Паки пройдено',
            value: '${completedPacks.length}',
            color: Colors.green,
          ),
          _StatCard(
            emoji: '📅',
            label: 'Активних днів',
            value: '$activeDays',
            color: kTeal,
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle('Досягнення'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: streak.unlockedRewards
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _statRow(List<Widget> children) => Row(
        children: children
            .map((c) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c)))
            .toList(),
      );

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 2 — Weekly chart
// ─────────────────────────────────────────────

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dailyStatsProvider); // rebuild when stats change
    final chartData = ref.read(dailyStatsProvider.notifier).last7Days();
    final totalWeek =
        chartData.fold(0, (sum, e) => sum + e.value);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Карток за 7 днів: $totalWeek',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ActivityChart(data: chartData),
          const SizedBox(height: 24),
          Text(
            totalWeek == 0
                ? 'Ще немає активності цього тижня.'
                : totalWeek < 20
                    ? 'Гарний початок! Продовжуй кожен день 💪'
                    : totalWeek < 50
                        ? 'Чудовий прогрес! 🌟'
                        : 'Неймовірна активність цього тижня! 🏆',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 3 — Pack progress
// ─────────────────────────────────────────────

class _PacksTab extends ConsumerWidget {
  const _PacksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final packProgress = ref.watch(packProgressProvider);
    final completedPacks = ref.watch(completedPacksProvider);

    return packsAsync.when(
      data: (packs) {
        final regular =
            packs.where((p) => !p.id.startsWith('_')).toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: regular.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final pack = regular[i];
            final seen = packProgress[pack.id] ?? 0;
            final total = pack.cards.length;
            final ratio = total > 0 ? seen / total : 0.0;
            final isDone = completedPacks.contains(pack.id);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pack.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: pack.color.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                children: [
                  Text(pack.icon,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: pack.color,
                                ),
                              ),
                            ),
                            if (isDone)
                              const Text('⭐',
                                  style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                pack.color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                pack.color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$seen / $total карток',
                          style: TextStyle(
                            fontSize: 11,
                            color: pack.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Помилка завантаження')),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 4 — Games
// ─────────────────────────────────────────────

class _GamesTab extends ConsumerWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gameStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final played = stats.where((g) => g.plays > 0).toList();

        if (played.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎮', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'Ще не грали в жодну гру.\nЗапустіть будь-яку гру з головного екрану!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final totalPlays = stats.fold(0, (s, g) => s + g.plays);
        final favorite = stats.reduce(
          (a, b) => a.plays >= b.plays ? a : b,
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Summary row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    emoji: '🎮',
                    label: 'Всього сесій',
                    value: '$totalPlays',
                    color: kAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    emoji: favorite.emoji,
                    label: 'Улюблена гра',
                    value: favorite.labelUk,
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Всі ігри',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...stats.map((g) => _GameStatRow(stat: g)),
          ],
        );
      },
    );
  }
}

class _GameStatRow extends StatelessWidget {
  final GameStat stat;
  const _GameStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final hasPlays = stat.plays > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasPlays
              ? kAccent.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPlays
                ? kAccent.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Text(stat.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                stat.labelUk,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasPlays ? null : Colors.grey[500],
                ),
              ),
            ),
            if (hasPlays) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.plays} ${_playsLabel(stat.plays)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                    ),
                  ),
                  if (stat.bestScore > 0)
                    Text(
                      'рекорд: ${stat.bestScore} ⭐',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ] else
              Text(
                'не грали',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  String _playsLabel(int n) {
    if (n == 1) return 'раз';
    if (n >= 2 && n <= 4) return 'рази';
    return 'разів';
  }
}

// ─────────────────────────────────────────────
//  Tab 5 — Weak words
// ─────────────────────────────────────────────

class _WeakWordsTab extends ConsumerWidget {
  const _WeakWordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakes = ref.watch(weakWordsProvider);
    final packsAsync = ref.watch(packsProvider);

    if (mistakes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                'Поки немає помилок!\nПродовжуйте грати у вікторину.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final weakWordsNotifier = ref.read(weakWordsProvider.notifier);
    final top = weakWordsNotifier.topMistakes();

    return packsAsync.when(
      data: (packs) {
        // Build a cardId → CardModel lookup
        final cardMap = <String, CardModel>{};
        for (final pack in packs) {
          for (final card in pack.cards) {
            cardMap[card.id] = card;
          }
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: top.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1),
          itemBuilder: (_, i) {
            final entry = top[i];
            final card = cardMap[entry.key];
            if (card == null) return const SizedBox.shrink();

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: card.colorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child:
                      Text(card.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              title: Text(
                card.sound,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                card.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.value}×',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
