import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/last_pack_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/review_provider.dart';
import '../providers/seasonal_packs_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/card_reveal_screen.dart';
import '../screens/cards_screen.dart';
import '../screens/guess_screen.dart';
import '../screens/kid_word_wall_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../screens/quest_map_screen.dart';
import '../screens/stats_screen.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/paywall_flow.dart';
import '../services/profile_service.dart';
import '../services/purchase_service.dart';
import '../services/widget_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/pack_categories.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/bubble_pop.dart';
import '../widgets/card_of_day_hero.dart';
import '../widgets/continue_hero.dart';
import '../widgets/notification_toggle_tile.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/profile_avatar_chip.dart';
import '../widgets/srs_review_banner.dart';
import '../widgets/streak_chip.dart';
import '../widgets/streak_milestone_overlay.dart';
import '../widgets/today_plan_strip.dart';

class PacksTab extends ConsumerStatefulWidget {
  const PacksTab({super.key});

  @override
  ConsumerState<PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends ConsumerState<PacksTab> {
  // Static so the category persists when user navigates into a pack and returns
  static String _lastCategory = '';
  String _selectedCategory = '';
  bool _milestoneShowing = false;

  /// One-time hint shown beneath Today's Plan on the first session, before
  /// the user has tapped any stone. Cleared after first dismissal so it never
  /// reappears even if the kid lets streaks lapse.
  static const _todayPlanIntroKey = 'today_plan_intro_seen_v1';
  bool _todayPlanIntroVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _lastCategory;
    _maybeShowTodayPlanIntro();
  }

  Future<void> _maybeShowTodayPlanIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_todayPlanIntroKey) ?? false;
    if (!seen && mounted) {
      setState(() => _todayPlanIntroVisible = true);
    }
  }

  Future<void> _dismissTodayPlanIntro() async {
    if (!_todayPlanIntroVisible) return;
    setState(() => _todayPlanIntroVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayPlanIntroKey, true);
  }

  Future<void> _maybeLogTodayPlanComplete(bool allDone) async {
    if (!allDone) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    final key = '${ProfileService.prefix}today_plan_logged_$todayKey';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    await AnalyticsService.instance.logTodayPlanComplete();
  }

  void _openParentArea(BuildContext context) {
    // Dashboard is view-only stats; no PIN needed. Destructive actions
    // (profile deletion) still have their own confirmation dialogs.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    );
  }

  void _showAbout(BuildContext _) async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🗣️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                s('Картки-розмовлялки', 'FirstWords Cards'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(s('Версія ${info.version}', 'Version ${info.version}'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 16),
              Text(
                s(
                  'Яскраві картки зі звуками для найменших. '
                  'Слухай — вивчай — повторюй!',
                  'Flash cards with sounds for little ones. '
                  'Listen — learn — repeat!',
                ),
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final isEn = ref.read(languageProvider) == 'en';
                  launchUrl(
                    Uri.parse(isEn
                        ? 'https://aihnatiev1.github.io/talking-cards/privacy-policy-en.html'
                        : 'https://aihnatiev1.github.io/talking-cards/privacy-policy.html'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: Text(s('Політика конфіденційності', 'Privacy Policy')),
              ),
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('mailto:skillar.app@gmail.com');
                  final canLaunch = await canLaunchUrl(uri);
                  if (canLaunch) {
                    launchUrl(uri);
                  } else if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('skillar.app@gmail.com')),
                    );
                  }
                },
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(s('Підтримка', 'Support')),
              ),
              const NotificationToggleTile(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openParentArea(context);
                },
                icon: const Icon(Icons.family_restroom, size: 18),
                label: Text(s('Батьківський режим', 'Parent area')),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s('Закрити', 'Close'),
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPackTap(BuildContext context, PackModel pack) async {
    if (pack.id == '_review' || !pack.id.startsWith('_')) {
      ref
          .read(dailyQuestProvider.notifier)
          .completeTask(QuestTask.reviewOldCard);
    }
    // Locked packs: show paywall first (high-intent moment).
    // If user dismisses, still let them preview the free cards.
    if (pack.isLocked) {
      final purchased = await runPaywallFlow(context, ref);
      if (!context.mounted) return;
      if (purchased) {
        // After purchase, packsProvider rebuilds with isLocked=false.
        // Pull the unlocked version before navigating.
        final unlocked = ref
                .read(packsProvider)
                .valueOrNull
                ?.firstWhere((p) => p.id == pack.id, orElse: () => pack) ??
            pack;
        ref.read(lastOpenedPackProvider.notifier).record(unlocked.id);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CardsScreen(pack: unlocked)),
        );
        return;
      }
    }
    ref.read(lastOpenedPackProvider.notifier).record(pack.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
    );
  }

  void _showCardOfDayPopup(CardModel card) {
    AnalyticsService.instance.logCardOfDayTap(card.id);
    AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    final isFav = ref.read(favoritesProvider).contains(card.id);
    final ps = AppS(ref.read(languageProvider) == 'en');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: card.colorBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  if (card.image != null)
                    SizedBox(
                      height: 140,
                      child: Image.asset(
                        'assets/images/webp/${card.image}.webp',
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Text(card.emoji, style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 12),
                  Text(
                    card.sound,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: card.colorAccent,
                    ),
                  ),
                  if (card.text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        card.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => AudioService.instance
                    .speakCard(card.audioKey, card.sound, card.text),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(ps('Слухати ще раз', 'Listen again'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: card.colorAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!isFav)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(favoritesProvider.notifier).toggle(card.id);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ps('Додано в улюблені ❤️', 'Added to favorites ❤️')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite_border),
                  label: Text(ps('Додати в улюблені', 'Add to favorites')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(ps('Закрити', 'Close'),
                  style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      AudioService.instance.stop();
    });
  }

  Widget _buildTodayPlanStrip(
    BuildContext context, {
    required List<PackModel> packs,
    required CardModel? cotd,
    required bool cotdLocked,
    required DailyQuestState questState,
    required Set<String> completedPacks,
    required bool isEn,
  }) {
    // Recommended pack: first non-locked, non-virtual, non-completed.
    PackModel? recommendedPack;
    for (final p in packs) {
      if (p.isLocked) continue;
      if (p.id.startsWith('_')) continue;
      if (completedPacks.contains(p.id)) continue;
      recommendedPack = p;
      break;
    }
    // Fallback: everything completed → first unlocked non-virtual pack
    if (recommendedPack == null) {
      for (final p in packs) {
        if (!p.isLocked && !p.id.startsWith('_')) {
          recommendedPack = p;
          break;
        }
      }
    }

    final listenDone =
        questState.completed.contains(QuestTask.listenCardOfDay);
    final viewDone = questState.completed.contains(QuestTask.viewCards3);
    // The Quest Map awards the daily card only after ALL five core tasks are
    // done (listen + view3 + play + view5 + reviewOldCard). The third strip
    // stone gates the celebration on those remaining hidden tasks too, so the
    // strip can't pretend the day is finished while the map still has steps
    // pending.
    final playDone = questState.completed.contains(QuestTask.playQuiz) &&
        questState.completed.contains(QuestTask.viewCards5) &&
        questState.completed.contains(QuestTask.reviewOldCard);

    final allDone = questState.allDone;
    if (allDone) {
      // Fire-and-forget; internal guard prevents duplicate logs per day.
      unawaited(_maybeLogTodayPlanComplete(allDone));
    }

    // First pending stone drives the pulse animation.
    final firstPending = !listenDone
        ? 1
        : !viewDone
            ? 2
            : !playDone
                ? 3
                : 0;

    void openQuestMap() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuestMapScreen(
            showBackButton: true,
            cardOfDay: cotd,
            cardOfDayLocked: cotdLocked,
            onCardOfDayTap: () {},
          ),
        ),
      );
    }

    final stones = <TodayPlanStone>[
      TodayPlanStone(
        emoji: '🔊',
        label: isEn ? "Today's Card" : 'Картка дня',
        isDone: listenDone,
        isActive: firstPending == 1,
        onTap: () {
          AnalyticsService.instance.logTodayPlanStoneTap(
            stoneId: 1,
            wasDone: listenDone,
            wasActive: firstPending == 1,
          );
          if (cotd != null) {
            _showCardOfDayPopup(cotd);
            ref
                .read(dailyQuestProvider.notifier)
                .completeTask(QuestTask.listenCardOfDay);
          }
        },
      ),
      TodayPlanStone(
        emoji: '🃏',
        label: isEn ? "Today's Pack" : 'Пак дня',
        isDone: viewDone,
        isActive: firstPending == 2,
        onTap: () {
          AnalyticsService.instance.logTodayPlanStoneTap(
            stoneId: 2,
            wasDone: viewDone,
            wasActive: firstPending == 2,
          );
          final rp = recommendedPack;
          if (rp != null) _onPackTap(context, rp);
        },
      ),
      TodayPlanStone(
        emoji: '🗺️',
        label: isEn ? 'Daily Adventure' : 'Пригода дня',
        isDone: playDone,
        isActive: firstPending == 3,
        onTap: () {
          AnalyticsService.instance.logTodayPlanStoneTap(
            stoneId: 3,
            wasDone: playDone,
            wasActive: firstPending == 3,
          );
          openQuestMap();
        },
      ),
    ];

    // When the day's plan is finished, the whole strip becomes one big tap
    // target: Pro users go straight into the Daily Adventure, free users
    // see the won-card reveal (or quest map if the reward isn't built yet).
    void onAllDone() {
      final isPro = PurchaseService.instance.isPro.value;
      if (isPro) {
        openQuestMap();
        return;
      }
      // Find the most recently won card if any. quest.rewardCardId points
      // to the card unlocked by yesterday's plan.
      final reward = ref.read(dailyQuestProvider);
      if (reward.rewardClaimed && reward.rewardCardId != null) {
        for (final p in packs) {
          final card = p.cards.where((c) => c.id == reward.rewardCardId).firstOrNull;
          if (card != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CardRevealScreen(
                card: card,
                pack: p,
                newTotal: PackModel.freePreviewCount,
                skipAnimation: true,
                onShare: (_) {},
                onGoToPack: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CardsScreen(pack: p)),
                  );
                },
              ),
            ));
            return;
          }
        }
      }
      // No reward card yet — fall back to the quest map so the kid sees
      // the next milestone they're working toward.
      openQuestMap();
    }

    return TodayPlanStrip(
      stones: stones,
      isEn: isEn,
      onViewAll: openQuestMap,
      onAllDoneTap: allDone ? onAllDone : null,
    );
  }

  Widget _buildSubtitle(int total, int done, int streak, int totalViewed) {
    final s = AppS(ref.read(languageProvider) == 'en');
    if (done == 0 && streak <= 1 && totalViewed == 0) {
      return Text(
        s('Почни і побачиш свій прогрес тут!',
            'Start learning and track your progress here!'),
        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (streak > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kStreakOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                s('🔥 $streak дн.', '🔥 $streak days'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kStreakOrange,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            done > 0
                ? s('⭐ $done/$total розділів', '⭐ $done/$total packs')
                : s('🃏 Переглянуто $totalViewed карток',
                    '🃏 Viewed $totalViewed cards'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(packsProvider);
    final completedPacks = ref.watch(completedPacksProvider);
    final packProgress = ref.watch(packProgressProvider);
    final favorites = ref.watch(favoritesProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final streak = ref.watch(streakProvider);
    final quest = ref.watch(dailyQuestProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.85, 1.3);

    final sErr = AppS(ref.read(languageProvider) == 'en');

    // Streak milestone celebration: trigger once when a new milestone unlocks.
    final pending =
        ref.read(streakProvider.notifier).pendingCelebration;
    if (pending != null && !_milestoneShowing) {
      _milestoneShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final isEnNow = ref.read(languageProvider) == 'en';
        final childName =
            ref.read(profileProvider).active?.name ?? '';
        await showStreakMilestone(
          context,
          milestone: pending,
          childName: childName,
          isEn: isEnNow,
          onCelebrated: () => ref
              .read(streakProvider.notifier)
              .markCelebrated(pending.bonusEmoji),
        );
        if (mounted) _milestoneShowing = false;
      });
    }

    return Scaffold(
      body: GestureDetector(
        // Sago Mini-style ambient delight: tap on empty area spawns a bubble
        // that floats up and pops. Translucent so children still get taps.
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) => showBubblePop(context, details.globalPosition),
        child: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐢', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  sErr('Ой, щось не завантажилось', 'Oops, something didn\'t load'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  sErr('Перевір інтернет і спробуй ще раз',
                      'Check your connection and try again'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(packsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(sErr('Спробувати ще раз', 'Try again')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (packs) {
          final allCards = packs.expand((p) => p.cards).toList();
          final isEnMode = ref.read(languageProvider) == 'en';
          final lastPackId = ref.watch(lastOpenedPackProvider);
          PackModel? continuePack;
          if (lastPackId != null) {
            for (final p in packs) {
              if (p.id == lastPackId) {
                continuePack = p;
                break;
              }
            }
          }
          final continueProgress = continuePack != null
              ? (packProgress[continuePack.id] ?? 0)
              : 0;
          final s = AppS(isEnMode);
          final packCategories = isEnMode ? packCategoriesEn : packCategoriesUk;
          final allCategories = isEnMode ? allCategoriesEn : allCategoriesUk;

          if (_selectedCategory.isEmpty ||
              !allCategories.contains(_selectedCategory)) {
            Future.microtask(() =>
                setState(() => _selectedCategory = allCategories.first));
          }

          final cotdResult = cardOfTheDay(packs);
          final cotd = cotdResult?.$1;
          final cotdLocked = cotdResult?.$2 ?? false;
          if (cotd != null) {
            WidgetService.instance.updateCardOfDay(cotd);
          }

          final reviewCardIds =
              ref.watch(reviewProvider.notifier).reviewCardIds;

          // Virtual packs
          final favCards =
              allCards.where((c) => favorites.contains(c.id)).toList();
          final favoritesPack = PackModel(
            id: '_favorites',
            title: s('Улюблені', 'Favorites'),
            icon: '❤️',
            color: kStreakOrange,
            isLocked: false,
            isFree: true,
            cards: favCards,
          );

          PackModel? reviewPack;
          if (reviewCardIds.length >= 5) {
            final reviewCards = allCards
                .where((c) => reviewCardIds.contains(c.id))
                .toList();
            if (reviewCards.length >= 5) {
              reviewPack = PackModel(
                id: '_review',
                title: s('Повторення', 'Review'),
                icon: '🔄',
                color: const Color(0xFF45B7D1),
                isLocked: false,
                isFree: true,
                cards: reviewCards,
              );
            }
          }

          // Filter by category
          final filteredPacks = packs
              .where((p) => packCategories[p.id] == _selectedCategory)
              .toList();

          // Build grid items
          final gridItems = <_GridItem>[
            for (final p in filteredPacks) _GridItem.pack(p),
          ];
          if (favCards.isNotEmpty) {
            gridItems.add(_GridItem.pack(favoritesPack));
          }
          if (reviewPack != null) {
            gridItems.add(_GridItem.pack(reviewPack));
          }

          // Inject seasonal packs as highlighted first items — only in "World" tab
          if (_selectedCategory == 'Світ' || _selectedCategory == 'World') {
            final seasonalPacks =
                ref.watch(activeSeasonalPacksProvider).valueOrNull ?? [];
            for (int i = seasonalPacks.length - 1; i >= 0; i--) {
              final sp = seasonalPacks[i];
              gridItems.insert(
                0,
                _GridItem.pack(
                  PackModel(
                    id: sp.id,
                    title: sp.localizedTitle(isEnMode),
                    icon: sp.icon,
                    color: sp.color,
                    isLocked: false,
                    isFree: true,
                    cards: sp.cards,
                  ),
                  isSeasonal: true,
                ),
              );
            }
          }

          final topPadding = MediaQuery.of(context).padding.top;

          return Column(
            children: [
              SizedBox(height: topPadding),
              // Top bar
              Padding(
                padding: EdgeInsets.only(top: 4 * scale, left: 12, right: 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: isDark
                          ? s('Світла тема', 'Light theme')
                          : s('Темна тема', 'Dark theme'),
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: Colors.grey[400],
                        size: 26,
                      ),
                      onPressed: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                    const Spacer(),
                    if (streak.currentStreak > 0) ...[
                      StreakChip(
                        streak: streak.currentStreak,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const ProfileAvatarChip(),
                    GestureDetector(
                      onLongPress: () => _openParentArea(context),
                      child: IconButton(
                        tooltip: s('Про додаток', 'About'),
                        icon: Icon(Icons.info_outline_rounded,
                            color: Colors.grey[400], size: 26),
                        onPressed: () => _showAbout(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                s('🗣️ Картки-розмовлялки', '🗣️ FirstWords Cards'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6 * scale),

              // Streak/progress chip lives in the top header now (StreakChip);
              // the inline subtitle here was a duplicate readout — removed.
              const SizedBox(height: 6),

              // Hero: Continue or Card of the Day — full-width
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: continuePack != null
                    ? Builder(builder: (_) {
                        final cp = continuePack!;
                        return ContinueHero(
                          pack: cp,
                          progress: continueProgress,
                          isEn: isEnMode,
                          onTap: () {
                            AnalyticsService.instance
                                .logContinueHeroTap(cp.id);
                            _onPackTap(context, cp);
                          },
                        );
                      })
                    : cotd != null
                        ? CardOfDayHero(
                            card: cotd,
                            isEn: isEnMode,
                            onTap: () {
                              _showCardOfDayPopup(cotd);
                              ref
                                  .read(dailyQuestProvider.notifier)
                                  .completeTask(QuestTask.listenCardOfDay);
                            },
                          )
                        : const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),

              // Today's Plan — 3-stone daily path backed by dailyQuestProvider
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildTodayPlanStrip(
                  context,
                  packs: packs,
                  cotd: cotd,
                  cotdLocked: cotdLocked,
                  questState: quest,
                  completedPacks: completedPacks,
                  isEn: isEnMode,
                ),
              ),

              // First-launch coachmark for the strip — fades in on initial
              // session and self-dismisses as soon as the kid taps any stone.
              if (_todayPlanIntroVisible)
                _TodayPlanIntroHint(
                  isEn: isEnMode,
                  isVisible: quest.completed.isEmpty,
                  onDismiss: _dismissTodayPlanIntro,
                ),

              // Treasure box — kid-facing entry to learned-words collection.
              // Hidden until at least one word is "learned" (SRS reps >= 2).
              _TreasureBoxBanner(isEn: isEnMode),

              // SRS review banner
              SrsReviewBanner(
                allCards: allCards,
                onTap: (cards) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GuessScreen(
                      cards: cards,
                      ttsLocale: isEnMode ? 'en-US' : null,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Category filter chips — segmented pill control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (int i = 0; i < allCategories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _CategoryChip(
                          label: allCategories[i],
                          selected: allCategories[i] == _selectedCategory,
                          onSelected: () {
                            final newCat = allCategories[i];
                            if (newCat != _selectedCategory) {
                              AnalyticsService.instance
                                  .logCategorySwitch(newCat);
                            }
                            setState(() {
                              _selectedCategory = newCat;
                              _lastCategory = newCat;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(16 * scale, 4, 16 * scale, 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10 * scale,
                    crossAxisSpacing: 10 * scale,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: gridItems.length,
                  itemBuilder: (context, index) {
                    final item = gridItems[index];
                    final pack = item.pack;
                    return PackGridCard(
                      key: ValueKey(pack.id),
                      pack: pack,
                      isCompleted: completedPacks.contains(pack.id),
                      progress: packProgress[pack.id] ?? 0,
                      isSeasonal: item.isSeasonal,
                      onTap: () => _onPackTap(context, pack),
                    );
                  },
                ),
              ),

            ],
          );
        },
      ),
      ),
    );
  }
}

/// Compact home banner that mirrors the kid Word Wall stat: count + Bloom.
/// Hidden when the child has zero "learned" cards (SRS reps >= 2) to avoid
/// teasing an empty treasure box.
class _TreasureBoxBanner extends ConsumerWidget {
  final bool isEn;
  const _TreasureBoxBanner({required this.isEn});

  static const _learnedThreshold = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srs = ref.watch(srsProvider);
    final count = srs.cards.values
        .where((c) => c.repetitions >= _learnedThreshold)
        .length;
    if (count == 0) return const SizedBox.shrink();

    final word = isEn
        ? (count == 1 ? 'word' : 'words')
        : _ukWord(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const KidWordWallScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kAccent.withValues(alpha: 0.92), kTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: DT.shadowSoft(kAccent),
          ),
          child: Row(
            children: [
              const BloomMascot(
                size: 44,
                emotion: BloomEmotion.waving,
                interactive: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEn ? 'Treasure box' : 'Скарбничка',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 11),
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: responsiveFont(context, 22),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            word,
                            style: TextStyle(
                              fontSize: responsiveFont(context, 12),
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
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ukWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'слово';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return 'слова';
    }
    return 'слів';
  }
}

class _GridItem {
  final PackModel pack;
  final bool isSeasonal;
  _GridItem.pack(this.pack, {this.isSeasonal = false});
}

const _categoryIcons = <String, String>{
  'Мовлення': '💬',
  'Звуки': '🔤',
  'Світ': '🌍',
  'Speaking': '💬',
  'Sounds': '🔤',
  'World': '🌍',
};

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcons[label];
    final display = icon != null ? '$icon $label' : label;
    return FilterChip(
      label: Center(
        child: Text(
          display,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
      selected: selected,
      selectedColor: kAccent,
      backgroundColor: Colors.grey.withValues(alpha: 0.18),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

/// Soft, dismissable hint shown beneath the Today's Plan strip on the very
/// first session. Animates out the moment the kid taps any stone (driven by
/// the [isVisible] flag from the parent), and persists "seen" state once the
/// fade-out completes so it never reappears.
class _TodayPlanIntroHint extends StatelessWidget {
  final bool isEn;
  final bool isVisible;
  final VoidCallback onDismiss;

  const _TodayPlanIntroHint({
    required this.isEn,
    required this.isVisible,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      onEnd: () {
        if (!isVisible) onDismiss();
      },
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn
                      ? 'Finish 3 daily steps to unlock a new card 🎁'
                      : 'Виконай 3 щоденні кроки і отримай нову картку 🎁',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

