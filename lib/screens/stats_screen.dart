import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/streak_provider.dart';
import '../screens/cards_screen.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../utils/uk_grammar.dart';
import '../widgets/activity_chart.dart';
import '../widgets/parental_gate.dart';
import '../widgets/share_progress_card.dart';

/// The parent's report: packs completed, minutes, the week's activity and
/// every pack's progress row.
///
/// Parent-only by construction (ux-gap-audit G14, CLAUDE.md rule 7). It
/// used to hang off the streak chip on the child's home screen — one tap
/// from a toddler's finger to a screen of charts, a share sheet and a way
/// into any pack. The child's own rewards moved to the treasure box
/// (`KidWordWallScreen`); what is left here is for a grown-up, so the only
/// way in is [open], which asks the gate first. The share button *inside*
/// is not gated a second time: the gate has already been passed to get
/// here.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// Asks the parental gate, then pushes the screen. Returns `true` when
  /// the gate was passed. Never construct a route to [StatsScreen]
  /// directly — `test/screens/rewards_album_test.dart` guards this.
  static Future<bool> open(BuildContext context, {required bool isEn}) async {
    final ok = await showParentalGate(context, isEn: isEn);
    if (!ok || !context.mounted) return false;
    await Navigator.of(context).push(KidRoutes.sheet(const StatsScreen()));
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final completed = ref.watch(completedPacksProvider);
    final progress = ref.watch(packProgressProvider);
    final streak = ref.watch(streakProvider);
    ref.watch(dailyStatsProvider);
    final dailyNotifier = ref.read(dailyStatsProvider.notifier);

    final s = AppS(ref.read(languageProvider) == 'en');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: DT.brand),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s('Прогрес дитини', "Child's Progress"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: DT.brand),
            onPressed: () {
              final packs = packsAsync.valueOrNull ?? [];
              shareProgress(
                context: context,
                completedPacks: completed.length,
                totalPacks: packs.length,
                seenCards: progress.entries.where((e) => !e.key.startsWith('_')).fold<int>(0, (s, e) => s + e.value),
                totalCards:
                    packs.fold<int>(0, (s, p) => s + p.cards.length),
                streak: streak.currentStreak,
                badges: streak.unlockedRewards,
                isEn: ref.read(languageProvider) == 'en',
              );
            },
          ),
        ],
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (packs) {
          final totalPacks = packs.length;
          final completedCount = completed.length;
          final totalCards =
              packs.fold<int>(0, (sum, p) => sum + p.cards.length);
          final seenCards = progress.entries
              .where((e) => !e.key.startsWith('_'))
              .fold<int>(0, (sum, e) => sum + e.value);
          final totalViews = dailyNotifier.totalViews;
          final approxMinutes = (totalViews * 5 / 60).round();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Summary banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DT.brand, DT.teal],
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
                              s('Розділів пройдено', 'Packs completed'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedCount / $totalPacks',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s('$seenCards з $totalCards карток переглянуто',
                                '$seenCards of $totalCards cards viewed'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The streak is a read-out here, not a door: the
                      // rewards album belongs to the child and lives in the
                      // treasure box (G14), not two taps inside the
                      // parent's report.
                      if (streak.currentStreak >= 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🔥 ${streak.currentStreak}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                s.isEn
                                    ? 'days'
                                    : dayWord(streak.currentStreak),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (approxMinutes > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          DT.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            DT.brand.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('⏱️',
                            style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          s('~$approxMinutes хв навчання', '~$approxMinutes min learning'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DT.brand,
                          ),
                        ),
                        Text(
                          s('$totalViews переглядів карток', '$totalViews card views'),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s('Активність за тиждень', 'Activity this week'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ActivityChart(data: dailyNotifier.last7Days(), isEn: s.isEn),
                const SizedBox(height: 24),
                ...packs.map((pack) {
                  final packProgress = progress[pack.id] ?? 0;
                  final packTotal = pack.cards.length;
                  final isDone = completed.contains(pack.id);
                  final ratio =
                      packTotal > 0 ? packProgress / packTotal : 0.0;

                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      KidRoutes.content(
                        CardsScreen(pack: pack, source: 'parent_stats'),
                      ),
                    ),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(pack.icon,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pack.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: pack.color,
                                    ),
                                  ),
                                  if (isDone) ...[
                                    const SizedBox(width: 6),
                                    const Text('⭐',
                                        style:
                                            TextStyle(fontSize: 14)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: pack.color
                                      .withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          pack.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$packProgress/$packTotal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? pack.color
                                : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
