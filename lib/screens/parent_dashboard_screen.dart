import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/weak_words_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/activity_chart.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/word_wall_share.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return DefaultTabController(
      length: 6,
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
                  profile.active?.name ?? s('Малюк', 'Kiddo'),
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
          bottom: TabBar(
            isScrollable:
                MediaQuery.of(context).size.width < kLargeScreen,
            tabAlignment:
                MediaQuery.of(context).size.width >= kLargeScreen
                    ? TabAlignment.fill
                    : TabAlignment.start,
            labelStyle: TextStyle(
                fontSize: responsiveFont(context, 13),
                fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                TextStyle(fontSize: responsiveFont(context, 13)),
            tabs: [
              Tab(text: s('Огляд', 'Overview')),
              Tab(text: s('Тиждень', 'Week')),
              Tab(text: s('Слова', 'Words')),
              Tab(text: s('Паки', 'Packs')),
              Tab(text: s('Ігри', 'Games')),
              Tab(text: s('Помилки', 'Mistakes')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _WeeklyTab(),
            _WordsTab(),
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
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

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
            label: s('Серія', 'Streak'),
            value: isEn
                ? '${streak.currentStreak} d.'
                : '${streak.currentStreak} дн.',
            color: kStreakOrange,
          ),
          _StatCard(
            emoji: '📚',
            label: s('Переглянуто', 'Seen'),
            value: isEn
                ? '$wordsSeenTotal ${wordsSeenTotal == 1 ? 'card' : 'cards'}'
                : '$wordsSeenTotal карток',
            color: kAccent,
          ),
        ]),
        const SizedBox(height: 12),
        _statRow([
          _StatCard(
            emoji: '✅',
            label: s('Паки пройдено', 'Packs done'),
            value: '${completedPacks.length}',
            color: Colors.green,
          ),
          _StatCard(
            emoji: '📅',
            label: s('Активних днів', 'Active days'),
            value: '$activeDays',
            color: kTeal,
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle(s('Досягнення', 'Achievements')),
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
          Text(emoji, style: TextStyle(fontSize: responsiveFont(context, 24))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveFont(context, 18),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: responsiveFont(context, 12),
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
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    final weeklyMsg = totalWeek == 0
        ? s('Ще немає активності цього тижня.',
            'No activity this week yet.')
        : totalWeek < 20
            ? s('Гарний початок! Продовжуй кожен день 💪',
                'Nice start! Keep going every day 💪')
            : totalWeek < 50
                ? s('Чудовий прогрес! 🌟', 'Great progress! 🌟')
                : s('Неймовірна активність цього тижня! 🏆',
                    'Amazing week of activity! 🏆');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn
                ? 'Cards in 7 days: $totalWeek'
                : 'Карток за 7 днів: $totalWeek',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ActivityChart(data: chartData, isEn: isEn),
          const SizedBox(height: 24),
          Text(
            weeklyMsg,
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
//  Tab 3 — Word Wall (learned words)
// ─────────────────────────────────────────────

class _WordsTab extends ConsumerWidget {
  const _WordsTab();

  static const _learnedThreshold = 2; // SM-2 repetitions for "learned"

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srs = ref.watch(srsProvider);
    final packsAsync = ref.watch(packsProvider);
    final profile = ref.watch(profileProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final childName = profile.active?.name ?? s('Малюк', 'Kiddo');

    final learnedIds = srs.cards.values
        .where((c) => c.repetitions >= _learnedThreshold)
        .map((c) => c.cardId)
        .toSet();

    if (learnedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BloomMascot(size: 88),
              const SizedBox(height: 16),
              Text(
                s(
                  'Поки немає вивчених слів.\nГрайте у вікторину — і вони з\'являться тут!',
                  'No learned words yet.\nPlay the quiz and they\'ll show up here!',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return packsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(s('Помилка', 'Error'))),
      data: (packs) {
        // Group learned cards by pack, preserve original card order in pack
        final groups = <(String packId, String packTitle, String packIcon, List<CardModel> cards)>[];
        final allLearnedCards = <CardModel>[];
        for (final pack in packs) {
          final cards = pack.cards
              .where((c) => learnedIds.contains(c.id))
              .toList();
          if (cards.isEmpty) continue;
          groups.add((pack.id, pack.title, pack.icon, cards));
          allLearnedCards.addAll(cards);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WordWallHeader(
              childName: childName,
              learnedCount: allLearnedCards.length,
              isEn: isEn,
              onShare: () => shareWordWall(
                context: context,
                childName: childName,
                learnedCards: allLearnedCards,
                isEn: isEn,
              ),
            ),
            const SizedBox(height: 20),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(group.$3, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${group.$4.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: group.$4.length,
                itemBuilder: (_, i) =>
                    _LearnedTile(card: group.$4[i]),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _WordWallHeader extends StatelessWidget {
  final String childName;
  final int learnedCount;
  final bool isEn;
  final VoidCallback onShare;

  const _WordWallHeader({
    required this.childName,
    required this.learnedCount,
    required this.isEn,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccent, kTeal],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn
                      ? "$childName's Word Wall"
                      : 'Стіна слів — $childName',
                  style: TextStyle(
                    fontSize: responsiveFont(context, 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$learnedCount',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 36),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        isEn
                            ? (learnedCount == 1 ? 'word' : 'words')
                            : 'слів',
                        style: TextStyle(
                          fontSize: responsiveFont(context, 13),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(isEn ? 'Share' : 'Поділитись'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kAccent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnedTile extends StatelessWidget {
  final CardModel card;

  const _LearnedTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: card.colorBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: card.colorAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: card.image != null
                  ? Image.asset(
                      'assets/images/webp/${card.image}.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          card.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        card.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.sound,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: responsiveFont(context, 11),
            fontWeight: FontWeight.w700,
            color: card.colorAccent,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 4 — Pack progress
// ─────────────────────────────────────────────

class _PacksTab extends ConsumerWidget {
  const _PacksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final packProgress = ref.watch(packProgressProvider);
    final completedPacks = ref.watch(completedPacksProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

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
                          isEn
                              ? '$seen / $total ${total == 1 ? 'card' : 'cards'}'
                              : '$seen / $total карток',
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
      error: (_, __) =>
          Center(child: Text(s('Помилка завантаження', 'Loading error'))),
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
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final played = stats.where((g) => g.plays > 0).toList();

        if (played.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎮', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    s(
                        'Ще не грали в жодну гру.\nЗапустіть будь-яку гру з головного екрану!',
                        'No games played yet.\nTry any game from the home screen!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
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
                    label: s('Всього сесій', 'Total sessions'),
                    value: '$totalPlays',
                    color: kAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    emoji: favorite.emoji,
                    label: s('Улюблена гра', 'Favorite game'),
                    value: isEn ? favorite.labelEn : favorite.labelUk,
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              s('Всі ігри', 'All games'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...stats.map((g) => _GameStatRow(stat: g, isEn: isEn)),
          ],
        );
      },
    );
  }
}

class _GameStatRow extends StatelessWidget {
  final GameStat stat;
  final bool isEn;
  const _GameStatRow({required this.stat, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final hasPlays = stat.plays > 0;
    final s = AppS(isEn);
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
            Text(stat.emoji,
                style: TextStyle(fontSize: responsiveFont(context, 24))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEn ? stat.labelEn : stat.labelUk,
                style: TextStyle(
                  fontSize: responsiveFont(context, 14),
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
                    '${stat.plays} ${_playsLabel(stat.plays, isEn)}',
                    style: TextStyle(
                      fontSize: responsiveFont(context, 13),
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                    ),
                  ),
                  if (stat.bestScore > 0)
                    Text(
                      '${s('рекорд', 'best')}: ${stat.bestScore} ⭐',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 11),
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ] else
              Text(
                s('не грали', 'not played'),
                style: TextStyle(
                    fontSize: responsiveFont(context, 12),
                    color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  String _playsLabel(int n, bool isEn) {
    if (isEn) return n == 1 ? 'time' : 'times';
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
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    if (mistakes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                s(
                    'Поки немає помилок!\nПродовжуйте грати у вікторину.',
                    'No mistakes yet!\nKeep playing the quiz.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5),
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
              subtitle: card.text.isEmpty
                  ? null
                  : Text(
                      card.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
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
