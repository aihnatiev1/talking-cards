import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/app_review_provider.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/last_pack_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/review_provider.dart';
import '../providers/seasonal_packs_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/streak_provider.dart';
import '../screens/cards_screen.dart';
import '../screens/kid_word_wall_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../screens/quest_map_screen.dart';
import '../screens/stats_screen.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/profile_service.dart';
import '../services/widget_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../utils/pack_categories.dart';
import '../widgets/app_logo_mark.dart';
import '../widgets/activity_categories.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/bubble_pop.dart';
import '../widgets/card_image.dart';
import '../widgets/daily_hero_card.dart';
import '../widgets/entrance_stagger.dart';
import '../widgets/notification_toggle_tile.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/parental_gate.dart';
import '../widgets/profile_avatar_chip.dart';
import '../widgets/settings_action_row.dart';
import '../widgets/streak_chip.dart';
import '../widgets/streak_milestone_overlay.dart';
import '../widgets/kid_tap.dart';
import '../services/open_content_pack.dart';
import '../widgets/cue_pill.dart';

class PacksTab extends ConsumerStatefulWidget {
  const PacksTab({super.key, this.catalogueOnly = false});

  final bool catalogueOnly;

  @override
  ConsumerState<PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends ConsumerState<PacksTab> {
  // Static so the category persists when user navigates into a pack and returns
  static String _lastCategory = '';
  String _selectedCategory = '';
  bool _milestoneShowing = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _lastCategory;
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

  Future<void> _openParentArea(BuildContext context) async {
    // Parental gate: a worded-math question keeps random toddler taps out
    // of the parent area (and the review/share actions inside it).
    final ok = await showParentalGate(
      context,
      isEn: ref.read(languageProvider) == 'en',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).push(KidRoutes.sheet(const ParentDashboardScreen()));
  }

  void _showAbout(BuildContext _) async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppLogoMark(
                  size: 64,
                  semanticsLabel: s('Картки-розмовлялки', 'FirstWords Cards'),
                ),
                const SizedBox(height: 12),
                Text(
                  s('Картки-розмовлялки', 'FirstWords Cards'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s('Версія ${info.version}', 'Version ${info.version}'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s(
                    'Яскраві картки зі звуками для найменших. '
                        'Слухай — вивчай — повторюй!',
                    'Flash cards with sounds for little ones. '
                        'Listen — learn — repeat!',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SettingsActionRow(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final isEn = ref.read(languageProvider) == 'en';
                    launchUrl(
                      Uri.parse(
                        isEn
                            ? 'https://aihnatiev1.github.io/talking-cards/privacy-policy-en.html'
                            : 'https://aihnatiev1.github.io/talking-cards/privacy-policy.html',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: Icons.privacy_tip_outlined,
                  label: s('Політика конфіденційності', 'Privacy Policy'),
                ),
                SettingsActionRow(
                  onTap: () async {
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
                  icon: Icons.mail_outline,
                  label: s('Підтримка', 'Support'),
                ),
                const NotificationToggleTile(),
                // Theme toggle intentionally NOT here: this dialog is one tap
                // from the child's home screen — it moved behind the parental
                // gate (parent dashboard → Settings).
                SettingsActionRow(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // Charts, minutes and a share sheet — a parent screen,
                    // so it asks the gate itself (G14).
                    StatsScreen.open(
                      context,
                      isEn: ref.read(languageProvider) == 'en',
                    );
                  },
                  icon: Icons.insights_outlined,
                  label: s('Прогрес дитини', "Child's progress"),
                ),
                SettingsActionRow(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openParentArea(context);
                  },
                  icon: Icons.family_restroom,
                  label: s('Батьківський режим', 'Parent area'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(
                        ctx,
                      ).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      s('Закрити', 'Close'),
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Which door a pack was opened by. `pack_open` fires inside
  /// [CardsScreen], which cannot know whether the child came from the
  /// grid, the hero or the day's plan — so the door is recorded here and
  /// read there.
  Future<void> _onPackTap(
    BuildContext context,
    PackModel pack, {
    String source = 'other',
    int? position,
  }) => openContentPack(context, ref, pack, source: source, position: position);

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
                  SizedBox(
                    height: 140,
                    child: CardImage.forCard(card, padding: EdgeInsets.zero),
                  ),
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
                onPressed: () => AudioService.instance.speakCard(
                  card.audioKey,
                  card.sound,
                  card.text,
                ),
                icon: const AppIconView(
                  AppIcon.sound,
                  size: 24,
                  color: Colors.white,
                ),
                label: Text(
                  ps('Слухати ще раз', 'Listen again'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: card.colorAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                        content: Text(
                          ps('Додано в улюблені ❤️', 'Added to favorites ❤️'),
                        ),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(
                ps('Закрити', 'Close'),
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      AudioService.instance.stop();
    });
  }

  /// Whether the step the hero itself stands for is finished — the Card of
  /// the Day listens, or (Continue / Start here) the day's cards. Mirrors
  /// the `heroDone:` each branch of [_buildDailyHero] passes.
  bool _heroTaskDone(DailyQuestState quest, {required bool heroIsCardOfDay}) =>
      quest.completed.contains(
        heroIsCardOfDay ? QuestTask.listenCardOfDay : QuestTask.viewCards3,
      );

  /// The single above-the-fold block: hero (Continue, or Card of the Day) plus
  /// the two remaining daily steps as compact buttons in the same frame.
  ///
  /// The daily-quest wiring is unchanged — the hero simply *is* one of the
  /// three steps now, so the same [QuestTask]s get completed and the same
  /// analytics fire; only the presentation collapsed from two framed cards
  /// into one.
  Widget _buildDailyHero(
    BuildContext context, {
    required List<PackModel> packs,
    required CardModel? cotd,
    required bool cotdLocked,
    required DailyQuestState questState,
    required Set<String> completedPacks,
    required PackModel? continuePack,
    required int continueProgress,
    required bool isEn,
    required Widget mascot,
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

    final listenDone = questState.completed.contains(QuestTask.listenCardOfDay);
    final viewDone = questState.completed.contains(QuestTask.viewCards3);
    // The Quest Map awards the daily card only after ALL five core tasks are
    // done (listen + view3 + play + view5 + reviewOldCard). The third strip
    // stone gates the celebration on those remaining hidden tasks too, so the
    // strip can't pretend the day is finished while the map still has steps
    // pending.
    final playDone =
        questState.completed.contains(QuestTask.playQuiz) &&
        questState.completed.contains(QuestTask.viewCards5) &&
        questState.completed.contains(QuestTask.reviewOldCard);

    final allDone = questState.allDone;
    // Release A — the card answers one question: what now?
    //
    //  * steps, not minutes, carry the progress line (`2 з 5 виконано`);
    //  * a profile that has done nothing at all gets an invitation, not a
    //    progress report at 0 %, and a shorter first session;
    //  * Bloom says one line and it always names the next action.
    final stepsDone = questState.doneCount;
    final stepsTotal = questState.totalCount;
    final sHero = AppS(isEn);
    // Nothing done today, nothing finished ever, nothing in progress: a
    // profile that has not started, not one that is at 0 % of today.
    final firstVisit =
        questState.completed.isEmpty &&
        completedPacks.isEmpty &&
        continueProgress == 0;
    // One step ≈ a minute of a child's attention; rounded up so the card
    // never promises less than it asks for.
    final bloomLine = firstVisit
        ? sHero('Ходімо, я покажу', 'Come on, I will show you')
        : allDone
        ? (questState.rewardClaimed
              ? sHero('Завтра: нові слова', 'Tomorrow: new words')
              : sHero(
                  'Усі кроки пройдено. Відкриємо скарб?',
                  'All steps complete. Let’s open the treasure!',
                ))
        : !listenDone
        ? sHero('Далі: послухай картку', 'Next: listen to the card')
        : !viewDone
        ? sHero('Далі: погортай картки', 'Next: swipe some cards')
        : !playDone
        ? sHero('Далі: пограємо', 'Next: a game')
        : sHero('Далі: помалюємо', 'Next: let\'s draw');
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
        : !questState.completed.contains(QuestTask.drawPicture)
        ? 4
        : 0;

    void openQuestMap() {
      Navigator.of(context).push(
        KidRoutes.content(
          QuestMapScreen(
            showBackButton: true,
            cardOfDay: cotd,
            cardOfDayLocked: cotdLocked,
            onCardOfDayTap: () {},
          ),
        ),
      );
    }

    // Tap = the word (audit A1-9): the card speaks and the illustration
    // bounces; the parent's sheet (favourites, listen again) is on the
    // hero's long-press — see [_showCardOfDayPopup].
    void openCardOfDay() {
      if (cotd == null) return;
      AnalyticsService.instance.logCardOfDayTap(cotd.id);
      AnalyticsService.instance.logFirstAction('hero_cta');
      AudioService.instance.speakCard(cotd.audioKey, cotd.sound, cotd.text);
      ref
          .read(dailyQuestProvider.notifier)
          .completeTask(QuestTask.listenCardOfDay);
    }

    final cardTask = DailyTask(
      icon: AppIcon.stepListen,
      label: isEn ? "Today's Card" : 'Картка дня',
      onLongPress: cotd == null ? null : () => _showCardOfDayPopup(cotd),
      isDone: listenDone,
      isActive: firstPending == 1,
      onTap: () {
        AnalyticsService.instance.logTodayPlanStoneTap(
          stoneId: 1,
          wasDone: listenDone,
          wasActive: firstPending == 1,
        );
        openCardOfDay();
      },
    );
    final packTask = DailyTask(
      icon: AppIcon.stepCards,
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
        if (rp != null) _onPackTap(context, rp, source: 'today_plan');
      },
    );
    // The day's plan is finished. The row says «Обрати гру», so it opens
    // the games tab and nothing else: it used to send Pro users to the
    // quest map and free users to a card reveal, which is not what the
    // words promise (playtest). Nothing here starts a new lesson — the
    // day's work is done, the rest of the app is simply open.
    void onAllDone() {
      ref.read(homeTabRequestProvider.notifier).state = kGamesTabIndex;
    }

    final pack = continuePack ?? recommendedPack;
    return DailyHeroCard(
      title: isEn ? 'A little adventure' : 'Маленька пригода',
      accent: DT.brand,
      image: cotd?.image ?? pack?.cover ?? pack?.cards.firstOrNull?.image,
      fallbackEmoji: cotd?.emoji ?? pack?.icon ?? '🃏',
      progress: firstVisit ? null : stepsDone / stepsTotal,
      heroDone: allDone,
      mascot: mascot,
      onHeroTap: allDone && questState.rewardClaimed ? onAllDone : openQuestMap,
      actionLabel: allDone
          ? (questState.rewardClaimed
                ? (isEn ? 'Choose a game' : 'Обрати гру')
                : (isEn ? 'Open the treasure' : 'Відкрити скарб'))
          : (stepsDone > 0
                ? (isEn ? 'Continue adventure' : 'Продовжити пригоду')
                : (isEn ? 'Start adventure' : 'Почати пригоду')),
      tasks: [if (cotd != null) cardTask, if (pack != null) packTask],
      collapseTasks: true,
      stepsDone: firstVisit ? null : stepsDone,
      stepsTotal: stepsTotal,
      firstVisit: firstVisit,
      bloomLine: bloomLine,
      isEn: isEn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(packsProvider);
    final completedPacks = ref.watch(completedPacksProvider);
    final packProgress = ref.watch(packProgressProvider);
    final favorites = ref.watch(favoritesProvider);
    final streak = ref.watch(streakProvider);
    final quest = ref.watch(dailyQuestProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.85, 1.3);

    final sErr = AppS(ref.read(languageProvider) == 'en');

    // Streak milestone celebration: trigger once when a new milestone unlocks.
    final pending = ref.read(streakProvider.notifier).pendingCelebration;
    if (!widget.catalogueOnly && pending != null && !_milestoneShowing) {
      _milestoneShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final isEnNow = ref.read(languageProvider) == 'en';
        final childName = ref.read(profileProvider).active?.name ?? '';
        AnalyticsService.instance.logStreakMilestone(pending.days);
        await showStreakMilestone(
          context,
          milestone: pending,
          childName: childName,
          isEn: isEnNow,
          onCelebrated: () =>
              ref.read(streakProvider.notifier).markCelebrated(pending.id),
        );
        if (!mounted) return;
        _milestoneShowing = false;
        // A repeating "we're proud" beat, right after the celebration dialog
        // closes — the app's only recurring moment where a parent is watching
        // and pleased. Guarded by a 45-day cooldown inside the controller.
        await ref
            .read(appReviewControllerProvider)
            .maybeRequestAfterWin('streak_${pending.days}');
      });
    }

    return Scaffold(
      // The home's painted sky shows through.
      backgroundColor: Colors.transparent,
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
                  const AppIconView(AppIcon.replay, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    sErr(
                      'Ой, щось не завантажилось',
                      'Oops, something didn\'t load',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sErr(
                      'Перевір інтернет і спробуй ще раз',
                      'Check your connection and try again',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(packsProvider),
                    icon: const AppIconView(
                      AppIcon.replay,
                      size: 22,
                      color: Colors.white,
                    ),
                    label: Text(sErr('Спробувати ще раз', 'Try again')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DT.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
            final packCategories = isEnMode
                ? packCategoriesEn
                : packCategoriesUk;
            final allCategories = isEnMode ? allCategoriesEn : allCategoriesUk;

            if (_selectedCategory.isEmpty ||
                !allCategories.contains(_selectedCategory)) {
              Future.microtask(
                () => setState(() => _selectedCategory = allCategories.first),
              );
            }

            final cotdResult = cardOfTheDay(packs);
            final cotd = cotdResult?.$1;
            final cotdLocked = cotdResult?.$2 ?? false;
            if (cotd != null) {
              WidgetService.instance.updateCardOfDay(cotd);
            }

            final reviewCardIds = ref
                .watch(reviewProvider.notifier)
                .reviewCardIds;

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
                  color: DT.teal,
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

            // Favorites are scoped to the open category tab — each of
            // Мовлення/Звуки/Світ shows its own hearts, first in the grid.
            final favCards = filteredPacks
                .expand((p) => p.cards)
                .where((c) => favorites.contains(c.id))
                .toList();
            final favoritesPack = PackModel(
              id: '_favorites',
              title: s('Улюблені', 'Favorites'),
              icon: '❤️',
              color: DT.streakOrange,
              isLocked: false,
              isFree: true,
              cards: favCards,
            );

            // Build grid items
            final gridItems = <_GridItem>[
              for (final p in filteredPacks) _GridItem.pack(p),
            ];
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

            // Favorites go first — inserted after the seasonal loop so they
            // beat even the highlighted seasonal pack to the top slot.
            if (favCards.isNotEmpty) {
              gridItems.insert(0, _GridItem.pack(favoritesPack));
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
                      // Title shares the row with streak/profile/info instead of
                      // occupying a line of its own — ~15% less vertical chrome
                      // before the first real content block.
                      Expanded(
                        // Reserve a gutter: StreakChip pulses (scales past its
                        // layout box) and used to graze the title's last letter.
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            // The emoji is gone and the name is on two
                            // lines. Sharing one line with the streak,
                            // the avatar and the info button left the
                            // title about 55 % of the width, and
                            // scaleDown obligingly shrank a 19 sp name to
                            // something nearer 12 — the app's own name,
                            // set smaller than its captions.
                            child: CuePill(
                              child: Text(
                                widget.catalogueOnly
                                    ? s('Картки', 'Cards')
                                    : s(
                                        'Картки-\nрозмовлялки',
                                        'FirstWords\nCards',
                                      ),
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 22 * scale,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  color: DT.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // A "🔥 1" on the very first open is noise in the
                      // header (audit #16); a streak becomes a thing to keep
                      // on day two.
                      if (streak.currentStreak >= 2) ...[
                        StreakChip(
                          streak: streak.currentStreak,
                          // The flame is the child's own counter, so it
                          // opens the child's own collection — the stickers
                          // the streak has been earning (G14). The parent's
                          // report moved behind the gate
                          // (`StatsScreen.open`, in the About sheet).
                          onTap: () => Navigator.of(context).push(
                            KidRoutes.sheet(
                              const KidWordWallScreen(
                                initialTab: TreasureTab.stickers,
                              ),
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
                          // The parents' door: the same painted padlock as
                          // on the Play home, not a grey system "i".
                          icon: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: DT.surfaceWhite.withValues(alpha: .9),
                              shape: BoxShape.circle,
                            ),
                            child: const AppArt('padlock', size: 32),
                          ),
                          // About opens the privacy policy and a mail
                          // client — outside the app, so behind the gate
                          // like every other parent action (audit #14).
                          onPressed: () async {
                            final ok = await showParentalGate(
                              context,
                              isEn: ref.read(languageProvider) == 'en',
                            );
                            if (ok && context.mounted) _showAbout(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Streak/progress chip lives in the top header now (StreakChip);
                // the inline subtitle here was a duplicate readout — removed.
                const SizedBox(height: 6),

                // One scroll for everything below the top bar. The hero and
                // the category row used to sit fixed above a grid that got
                // only what was left — on an iPhone a strip about a third
                // of the screen tall for the packs themselves (owner,
                // 2026-10-06). Now the hero scrolls away, the categories
                // stay pinned, and the grid has the whole screen.
                Expanded(
                  // The tiles arrive one after another (G11); the scope
                  // remembers when the grid appeared so a tile scrolled to
                  // later shows up at once instead of replaying the wave.
                  child: StaggerScope(
                    child: CustomScrollView(
                      slivers: [
                        if (!widget.catalogueOnly)
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                // One hero block: Continue / Card of the Day + the day's two
                                // remaining steps, all inside a single frame.
                                // Capped at heroMaxWidth and centred so a tablet gets a
                                // card, not a 150 dp strip across 1194 px.
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    0,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: DT.size.heroMaxWidth,
                                      ),
                                      child: _HeroWithBloom(
                                        semanticsLabel: isEnMode
                                            ? 'Bloom'
                                            : 'Блум',
                                        heroDone: _heroTaskDone(
                                          quest,
                                          heroIsCardOfDay:
                                              continuePack == null &&
                                              cotd != null,
                                        ),
                                        builder: (context, mascot) =>
                                            _buildDailyHero(
                                              context,
                                              packs: packs,
                                              cotd: cotd,
                                              cotdLocked: cotdLocked,
                                              questState: quest,
                                              completedPacks: completedPacks,
                                              continuePack: continuePack,
                                              continueProgress:
                                                  continueProgress,
                                              isEn: isEnMode,
                                              mascot: mascot,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Treasure box — kid-facing entry to learned-words collection.
                                // Hidden until at least one word is "learned" (SRS reps >= 2).
                                _TreasureBoxBanner(isEn: isEnMode),

                                // SRS review entry lives in the grid as the "Повторення"
                                // virtual pack — the extra banner here just stacked a third
                                // call-to-action above the fold.
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedCategories(
                            background: DT.surfaceWhite.withValues(alpha: .85),
                            extent: ActivityCategories.heightFor(
                              context,
                              allCategories,
                            ),
                            child: ActivityCategories(
                              labels: allCategories,
                              selected: _selectedCategory,
                              onSelected: (newCat) {
                                if (newCat == _selectedCategory) return;
                                AnalyticsService.instance.logCategorySwitch(
                                  newCat,
                                );
                                setState(() {
                                  _selectedCategory = newCat;
                                  _lastCategory = newCat;
                                });
                              },
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16 * scale,
                            4,
                            16 * scale,
                            8,
                          ),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) => SliverGrid(
                              gridDelegate: PackGridCard.gridDelegate(
                                context,
                                constraints.crossAxisExtent,
                                gridItems.map((item) => item.pack.title),
                              ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = gridItems[index];
                                final pack = item.pack;
                                return StaggeredEntrance(
                                  key: ValueKey(pack.id),
                                  index: index,
                                  child: PackGridCard(
                                    pack: pack,
                                    isCompleted: completedPacks.contains(
                                      pack.id,
                                    ),
                                    progress: packProgress[pack.id] ?? 0,
                                    isSeasonal: item.isSeasonal,
                                    onTap: () => _onPackTap(
                                      context,
                                      pack,
                                      source: 'library_grid',
                                      position: index,
                                    ),
                                  ),
                                );
                              }, childCount: gridItems.length),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
                    ),
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

/// Keep the category shelf visible while browsing; its extent follows
/// the actual system text size.
class _PinnedCategories extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color background;

  final double extent;

  const _PinnedCategories({
    required this.child,
    required this.background,
    required this.extent,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_PinnedCategories old) =>
      old.child != child ||
      old.background != background ||
      old.extent != extent;
}

/// The daily hero with Bloom S peeking out from behind the illustration
/// (ux-gap G5; bloom_character.md §4.2 z-rule): body behind the picture,
/// feet on the hero's bottom line, looking right at the play disc. Bloom is
/// built here — the one live `BloomMascot` on this route — and handed to
/// [builder], which places him *under* the illustration in z so he never
/// covers it.
///
/// This widget is also the home tab's stage in Bloom's brain: it enters
/// the `home` scene on mount, leaves it while the tab is hidden
/// (`TickerMode` off under `IndexedStack` or an opaque route), points his
/// hint at the play disc, and tells him he may breathe once the hero has
/// stopped pulsing ([heroDone]) — with hints off then, so he never points
/// at a check mark.
class _HeroWithBloom extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, Widget mascot) builder;
  final bool heroDone;
  final String semanticsLabel;

  const _HeroWithBloom({
    required this.builder,
    required this.heroDone,
    required this.semanticsLabel,
  });

  @override
  ConsumerState<_HeroWithBloom> createState() => _HeroWithBloomState();
}

class _HeroWithBloomState extends ConsumerState<_HeroWithBloom> {
  static final Object _sceneKey = Object();

  /// From Bloom (lower-left of the text column) to the play disc (right,
  /// a little above his eye line).
  static const _playDirection = Alignment(1, -0.2);

  bool _onStage = false;

  /// Resolved once, not per call: `ref` is dead inside `dispose`, and a
  /// getter that reaches for it there throws — taking every line after it
  /// down with it. That is how a word kept playing over the home screen:
  /// `_bloom.sceneLeft()` sat above `AudioService.stop()` in dispose, so
  /// the stop never ran. Nothing in dispose may touch `ref`.
  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  BloomScene get _scene => BloomScene.home.copyWith(
    ambient: widget.heroDone ? BloomAmbient.breathe : BloomAmbient.blinkOnly,
    hintsEnabled: !widget.heroDone,
  );

  void _enter() {
    _bloom.sceneEntered(_sceneKey, _scene);
    _bloom.hintTargetChanged(_playDirection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _onStage) return;
    _onStage = visible;
    // Not during build: the provider must not change while widgets are
    // being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_onStage) {
        _enter();
      } else {
        _bloom.sceneLeft(_sceneKey);
      }
    });
  }

  @override
  void didUpdateWidget(_HeroWithBloom old) {
    super.didUpdateWidget(old);
    if (old.heroDone == widget.heroDone || !_onStage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _onStage) _enter();
    });
  }

  @override
  void dispose() {
    if (_onStage) _bloom.sceneLeft(_sceneKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mascot = BloomMascot(
      size: DT.size.mascotCompanionOf(context),
      semanticsLabel: widget.semanticsLabel,
    );
    return widget.builder(context, mascot);
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

    final word = isEn ? (count == 1 ? 'word' : 'words') : _ukWord(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: KidTap(
        onTap: () {
          Navigator.of(
            context,
          ).push(KidRoutes.sheet(const KidWordWallScreen()));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DT.brand.withValues(alpha: 0.92), DT.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: DT.shadowSoft(DT.brand),
          ),
          child: Row(
            children: [
              // The drawn chest, not an emoji: this banner is the door to
              // the treasure box (G14), and the door should look like the
              // thing behind it.
              const AppIconView(
                AppIcon.rewardChestClosed,
                size: 34,
                sticker: true,
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
              const AppIconView(
                AppIcon.rewardChestClosed,
                size: 36,
                sticker: true,
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
