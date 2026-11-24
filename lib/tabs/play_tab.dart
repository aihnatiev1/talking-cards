import '../providers/streak_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/app_review_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/streak_milestone_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/play_topic.dart';
import '../screens/profile_selector_screen.dart';
import '../services/audio_service.dart';
import '../widgets/kid_tap.dart';
import '../providers/home_tab_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../screens/quest_map_screen.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/last_pack_provider.dart';
import '../models/pack_model.dart';
import '../providers/play_session_provider.dart';
import '../screens/play_lesson_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../utils/design_tokens.dart';
import '../utils/app_icons.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../widgets/parental_gate.dart';
import '../widgets/play_components.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/home_quick_row.dart';
import '../providers/card_of_day_provider.dart';
import '../services/open_content_pack.dart';

class PlayTab extends ConsumerStatefulWidget {
  const PlayTab({super.key, this.active = true});
  final bool active;
  @override
  ConsumerState<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends ConsumerState<PlayTab> {
  bool _opening = false;
  bool _milestoneShowing = false;

  Future<void> _open(PlayTopic topic) async {
    if (_opening) return;
    final packs = ref.read(packsProvider).valueOrNull;
    if (packs == null) return;
    final cards = topic.cards(packs);
    if (cards.length != 3) return;
    final journal = ref.read(playSessionProvider.notifier);
    setState(() => _opening = true);
    try {
      await journal.start(topic.id, cards.map((c) => c.id).toList());
      if (!mounted ||
          !identical(journal, ref.read(playSessionProvider.notifier))) {
        return;
      }
      await Navigator.of(
        context,
      ).push(KidRoutes.game(PlayLessonScreen(topic: topic, cards: cards)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(languageProvider) == 'en'
                  ? 'Could not save. Please try again.'
                  : 'Не вдалося зберегти. Спробуйте ще раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(streakProvider);
    final pending = ref.read(streakProvider.notifier).pendingCelebration;
    final homeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (pending != null &&
        widget.active &&
        homeIsCurrent &&
        !_milestoneShowing) {
      final owner = ref.read(streakProvider.notifier);
      final profileId = ref.read(profileProvider).activeId;
      _milestoneShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final homeRoute = ModalRoute.of(context);
        if (!widget.active ||
            !(homeRoute?.isCurrent ?? true) ||
            ref.read(profileProvider).activeId != profileId ||
            !identical(owner, ref.read(streakProvider.notifier)) ||
            owner.pendingCelebration?.id != pending.id) {
          setState(() => _milestoneShowing = false);
          return;
        }
        AnalyticsService.instance.logStreakMilestone(pending.days);
        await showStreakMilestone(
          context,
          milestone: pending,
          childName: ref.read(profileProvider).active?.name ?? '',
          isEn: ref.read(languageProvider) == 'en',
          onCelebrated: () {
            if (mounted &&
                ref.read(profileProvider).activeId == profileId &&
                identical(owner, ref.read(streakProvider.notifier))) {
              owner.markCelebrated(pending.id);
            }
          },
        );
        if (!mounted) return;
        setState(() => _milestoneShowing = false);
        if (!widget.active ||
            !(homeRoute?.isCurrent ?? true) ||
            ref.read(profileProvider).activeId != profileId) {
          return;
        }
        await ref
            .read(appReviewControllerProvider)
            .maybeRequestAfterWin('streak_${pending.days}');
      });
    }
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final catalogue = ref.watch(packsProvider);
    final daily = ref.watch(dailyQuestProvider);
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  const _ProfileButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('home-daily-quest'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(72, 72),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        KidRoutes.content(
                          QuestMapScreen(
                            cardOfDay: ref
                                .read(cardOfDaySelectorProvider)(
                                  catalogue.valueOrNull ?? [],
                                )
                                ?.$1,
                            cardOfDayLocked:
                                ref
                                    .read(cardOfDaySelectorProvider)(
                                      catalogue.valueOrNull ?? [],
                                    )
                                    ?.$2 ??
                                false,
                            onCardOfDayTap: () {},
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const AppArt('gift', size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  s('Завдання дня', 'Daily tasks'),
                                  style: DT.tileTitle,
                                ),
                                const SizedBox(height: 2),
                                // Stars, not «1/5»: a child can count lit
                                // stars, nobody under five reads a fraction.
                                if (daily.rewardClaimed || daily.allDone)
                                  Text(
                                    daily.rewardClaimed
                                        ? s(
                                            'Скарб отримано',
                                            'Treasure collected',
                                          )
                                        : s(
                                            'Забрати скарб',
                                            'Collect treasure',
                                          ),
                                    style: DT.caption,
                                  )
                                else
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < daily.totalCount;
                                          i++
                                        )
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: AppIconView(
                                              AppIcon.star,
                                              size: 22,
                                              color: i < daily.doneCount
                                                  ? DT.sunBurst
                                                  : DT.outline,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s('Для батьків', 'For parents'),
                    constraints: const BoxConstraints(
                      minWidth: 72,
                      minHeight: 72,
                    ),
                    onPressed: () async {
                      final ok = await showParentalGate(context, isEn: isEn);
                      if (ok && context.mounted) {
                        Navigator.of(
                          context,
                        ).push(KidRoutes.sheet(const ParentDashboardScreen()));
                      }
                    },
                    icon: const AppIconView(
                      AppIcon.lock,
                      color: DT.textSecondary,
                    ),
                  ),
                ],
              ),
              if (catalogue.hasValue) ..._hero(isEn, s),
              const SizedBox(height: 8),
              const HomeQuickRow(),
              if (ref.watch(playSessionProvider).hasError)
                TextButton(
                  onPressed: () => ref.invalidate(playSessionProvider),
                  child: Text(
                    s('Повторити завантаження заняття', 'Retry loading lesson'),
                  ),
                ),
              if (catalogue.isLoading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (catalogue.hasError)
                PlayPanel(
                  child: Column(
                    children: [
                      Text(
                        s(
                          'Не вдалося відкрити картки',
                          'Could not open your cards',
                        ),
                        style: DT.h2,
                      ),
                      const SizedBox(height: 16),
                      PlayAction(
                        label: s('Спробувати ще', 'Try again'),
                        icon: AppIcon.replay,
                        onPressed: () {
                          ref.invalidate(packsProvider);
                          ref.invalidate(playSessionProvider);
                        },
                      ),
                    ],
                  ),
                )
              else
                ..._content(isEn, s),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _hero(bool isEn, AppS s) {
    final packs = ref.watch(packsProvider).requireValue;
    final journal = ref.watch(playSessionProvider).valueOrNull;
    final available = PlayTopic.all
        .where((topic) => topic.cards(packs).length == 3)
        .toList();
    final topic = PlayTopic.pick(available, journal);
    final session = topic == null ? null : journal?.sessions[topic.id];
    final complete = session?.complete ?? false;
    final continuing = session != null && session.step > 0 && !complete;
    return [
      if (topic != null && journal != null)
        _HeroCard(
          topic: topic,
          cards: topic.cards(packs),
          complete: complete,
          continuing: continuing,
          opening: _opening,
          label: complete
              ? s('До мого світу', 'My world')
              : continuing
              ? s('Продовжити', 'Continue')
              : s('Грати', 'Play'),
          icon: complete ? AppIcon.catWorld : AppIcon.play,
          title: topic.title(isEn),
          onPressed: () {
            if (complete) {
              ref.read(homeDestinationProvider.notifier).state =
                  HomeDestination.world;
            } else {
              _open(topic);
            }
          },
        ),
      if (complete && topic != null)
        TextButton.icon(
          onPressed: _opening ? null : () => _open(topic),
          icon: const AppIconView(AppIcon.replay),
          label: Text(s('Пограти ще', 'Play again')),
        ),
    ];
  }

  Widget _shelfItem(
    BuildContext context,
    AppS s,
    PackModel pack,
    int position, {
    required bool isContinue,
    required int progress,
    required bool completed,
  }) {
    final card = PackGridCard(
      key: ValueKey('home-pack-${pack.id}'),
      pack: pack,
      progress: progress,
      isCompleted: completed,
      onTap: () => openContentPack(
        context,
        ref,
        pack,
        source: isContinue ? 'home_continue' : 'home_packs',
        position: position,
      ),
    );
    if (!isContinue) return card;
    return KeyedSubtree(
      key: const ValueKey('home-continue-pack'),
      child: Stack(
        children: [
          Positioned.fill(child: card),
          Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: DT.brand,
                  borderRadius: BorderRadius.circular(DT.rMd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIconView(
                      AppIcon.play,
                      size: 18,
                      color: DT.surfaceWhite,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s('Далі', 'Next'),
                      style: DT.caption.copyWith(
                        color: DT.surfaceWhite,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(bool isEn, AppS s) {
    final packs = ref.watch(packsProvider).requireValue;
    final lastId = ref.watch(lastOpenedPackProvider);
    final ordered = [
      ...packs.where((p) => !p.isLocked && p.cards.isNotEmpty),
      ...packs.where((p) => p.isLocked && p.cards.isNotEmpty),
    ];
    // The pack the child was in leads the shelf, marked: «continue» is a
    // pack, not another row of text between the banner and the grid.
    final last = ordered.where((p) => p.id == lastId).firstOrNull;
    final shelf = [if (last != null) last, ...ordered.where((p) => p != last)];
    final progress = ref.watch(packProgressProvider);
    final completed = ref.watch(completedPacksProvider);
    final grid = PackGridCard.gridDelegate(
      context,
      (MediaQuery.sizeOf(context).width.clamp(0, 640) - 40).toDouble(),
      shelf.map((p) => p.title),
      compact: true,
    );

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(s('Паки карток', 'Card packs'), style: DT.h2)),
            TextButton(
              key: const ValueKey('home-all-packs'),
              style: TextButton.styleFrom(minimumSize: const Size(72, 48)),
              onPressed: () =>
                  ref.read(homeDestinationProvider.notifier).state =
                      HomeDestination.cards,
              child: Text(s('Усі', 'All')),
            ),
          ],
        ),
      ),
      for (var start = 0; start < shelf.length; start += grid.crossAxisCount)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: SizedBox(
            height: grid.mainAxisExtent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var offset = 0;
                  offset < grid.crossAxisCount;
                  offset++
                ) ...[
                  if (offset > 0) const SizedBox(width: 16),
                  Expanded(
                    child: start + offset >= shelf.length
                        ? const SizedBox.shrink()
                        : _shelfItem(
                            context,
                            s,
                            shelf[start + offset],
                            start + offset,
                            isContinue: last != null && start + offset == 0,
                            progress: progress[shelf[start + offset].id] ?? 0,
                            completed: completed.contains(
                              shelf[start + offset].id,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

/// The lesson as a banner, not a poster: the animal on its little meadow on
/// the left, the name and the one big button on the right. About 120 dp, so
/// the card packs — what people open the app for — stay on the first screen.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.topic,
    required this.cards,
    required this.complete,
    required this.continuing,
    required this.opening,
    required this.label,
    required this.icon,
    required this.title,
    required this.onPressed,
  });
  final PlayTopic topic;
  final List<CardModel> cards;
  final bool complete;
  final bool continuing;
  final bool opening;
  final String label;
  final AppIcon icon;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(DT.sp12),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: KidTap(
              sound: null,
              onTap: opening ? null : onPressed,
              child: Semantics(
                button: true,
                label: title,
                child: PlayScene(
                  cards: cards.isEmpty ? const [] : [cards.first],
                  celebrate: complete,
                  height: 104,
                  showBloom: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: DT.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DT.tileTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DT.sp8),
                PlayAction(
                  label: label,
                  icon: icon,
                  onPressed: opening ? null : onPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The active child's avatar, opening the profile selector. The parents'
/// entry beside the stars is a padlock; this is the child's own face, so the
/// two can't be mistaken for each other.
class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(profileProvider).active;
    return KidTap(
      key: const ValueKey('home-profiles'),
      sound: null,
      onTap: () {
        AudioService.instance.stop();
        showProfileSelector(context);
      },
      child: Semantics(
        button: true,
        label: AppS(ref.watch(languageProvider) == 'en')('Профілі', 'Profiles'),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            shape: BoxShape.circle,
            border: Border.all(color: DT.outline, width: 2),
          ),
          child: Text(
            active?.avatarEmoji ?? '🙂',
            style: const TextStyle(fontSize: 30),
          ),
        ),
      ),
    );
  }
}
