import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/seasonal_packs_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/cards_screen.dart';
import '../screens/guess_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../screens/quest_map_screen.dart';
import '../screens/stats_screen.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/paywall_flow.dart';
import '../services/widget_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../utils/pack_categories.dart';
import '../widgets/card_of_day_hero.dart';
import '../widgets/notification_toggle_tile.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/profile_avatar_chip.dart';
import '../widgets/srs_review_banner.dart';
import '../widgets/treasure_card.dart';

class PacksTab extends ConsumerStatefulWidget {
  const PacksTab({super.key});

  @override
  ConsumerState<PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends ConsumerState<PacksTab> {
  // Static so the category persists when user navigates into a pack and returns
  static String _lastCategory = '';
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = _lastCategory;
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
                s('Картки-розмовлялки', 'Talking Cards'),
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
                  launchUrl(
                    Uri.parse('https://aihnatiev1.github.io/talking-cards/privacy-policy.html'),
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
    if (pack.id == '_favorites' && pack.cards.isEmpty) {
      _showEmptyFavorites(context);
      return;
    }
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CardsScreen(pack: unlocked)),
        );
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
    );
  }

  void _showEmptyFavorites(BuildContext context) {
    final fs = AppS(ref.read(languageProvider) == 'en');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😿', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              fs('Ой, тут ще порожньо!', 'Nothing here yet!'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fs('Сподобалась картка? Натисни ❤️\nі вона з\'явиться тут!',
                  'Liked a card? Tap ❤️\nand it will appear here!'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  fs('До розділів', 'Go to packs'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
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
                  const SizedBox(height: 6),
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
    return Scaffold(
      body: packsAsync.when(
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
          final isAllCategory = _selectedCategory == allCategories.first;
          final filteredPacks = isAllCategory
              ? packs
              : packs
                  .where((p) => packCategories[p.id] == _selectedCategory)
                  .toList();

          // Build grid items
          final gridItems = <_GridItem>[];
          const favPosition = 2;
          for (int i = 0; i < filteredPacks.length; i++) {
            if (isAllCategory && i == favPosition) {
              gridItems.add(_GridItem.pack(favoritesPack));
            }
            gridItems.add(_GridItem.pack(filteredPacks[i]));
          }
          if (isAllCategory) {
            if (filteredPacks.length <= favPosition) {
              gridItems.add(_GridItem.pack(favoritesPack));
            }
            if (reviewPack != null) {
              gridItems.add(_GridItem.pack(reviewPack));
            }
          }

          // Inject seasonal packs as highlighted first items in the grid
          if (isAllCategory) {
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
                s('🗣️ Картки-розмовлялки', '🗣️ Talking Cards'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6 * scale),

              // Subtitle with inline streak
              _buildSubtitle(
                  packs.length, completedPacks.length, streak.currentStreak,
                  packProgress.values.fold(0, (a, b) => a + b)),

              const SizedBox(height: 6),

              // Card of Day + Treasure row (50/50)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cotd != null)
                      Expanded(
                        child: CardOfDayHero(
                          card: cotd,
                          isEn: isEnMode,
                          onTap: () {
                            _showCardOfDayPopup(cotd);
                            ref
                                .read(dailyQuestProvider.notifier)
                                .completeTask(QuestTask.listenCardOfDay);
                          },
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TreasureCard(
                        done: quest.doneCount,
                        total: quest.totalCount,
                        isEn: isEnMode,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuestMapScreen(
                              showBackButton: true,
                              cardOfDay: cotd,
                              cardOfDayLocked: cotdLocked,
                              onCardOfDayTap: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

              // Category filter chips
              SizedBox(
                height: 38,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment(0.85, 0),
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.transparent],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = allCategories[index];
                      final selected = cat == _selectedCategory;
                      return FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                        selected: selected,
                        selectedColor: kAccent,
                        backgroundColor:
                            Colors.grey.withValues(alpha: 0.18),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => setState(() {
                          _selectedCategory = cat;
                          _lastCategory = cat;
                        }),
                      );
                    },
                  ),
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
    );
  }
}

class _GridItem {
  final PackModel pack;
  final bool isSeasonal;
  _GridItem.pack(this.pack, {this.isSeasonal = false});
}


