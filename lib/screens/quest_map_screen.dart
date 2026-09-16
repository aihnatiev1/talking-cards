import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../models/quest_theme.dart';
import '../providers/bonus_cards_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../services/profile_service.dart';

import '../utils/app_icons.dart';
import '../utils/motion.dart';
import '../widgets/app_icon_painters.dart';
import '../widgets/card_image.dart';
import '../widgets/quest_journey_map.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/kid_routes.dart';
import '../widgets/share_progress_card.dart';
import 'card_reveal_screen.dart';
import 'cards_screen.dart';
import 'guess_screen.dart';

class QuestMapScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  final CardModel? cardOfDay;
  final bool cardOfDayLocked;
  final VoidCallback onCardOfDayTap;

  const QuestMapScreen({
    super.key,
    this.showBackButton = true,
    required this.cardOfDay,
    required this.cardOfDayLocked,
    required this.onCardOfDayTap,
  });

  @override
  ConsumerState<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends ConsumerState<QuestMapScreen> {
  CardModel? _lastUnlockedCard;
  PackModel? _lastUnlockedPack;

  /// The stop that finished while the child was away, so the map can show
  /// her *what changed* when she walks back onto it (п. 25: «повернення до
  /// конкретної зупинки з помітним оновленням стану»). Cleared as soon as
  /// she sets off again.
  QuestTask? _justCompleted;

  /// The cards a themed day may be built from: unlocked, real packs only,
  /// every card with a picture and a voice. A verse pack has neither a
  /// single word nor a single picture, so it cannot carry a subject.
  List<CardModel> _themeCandidates(List<PackModel> packs) {
    final isEn = ref.read(languageProvider) == 'en';
    return [
      for (final pack in packs)
        if (!pack.isLocked &&
            !pack.id.startsWith('_') &&
            !PackModel.nonWordPackIds.contains(pack.id))
          for (final card in pack.cards)
            if (card.image != null &&
                (isEn
                    ? AudioService.instance.hasSound(card.audioKey)
                    : card.audioKey != null))
              card,
    ];
  }

  /// Memo of the last [_themeOf], keyed by what can change it. Picking the
  /// theme buckets every unlocked card, and `build` runs on every tap of
  /// the map — the work is done once a day, not once a frame.
  (String, int, String?)? _themeKey;
  QuestTheme? _theme;

  /// The theme of the day, led by the card of the day whenever that card
  /// belongs to a set with enough material.
  QuestTheme? _themeOf(List<PackModel> packs) {
    final profile = ProfileService.prefix;
    final day = DateTime.now();
    final key = (
      '${day.year}-${day.month}-${day.day}$profile',
      packs.fold<int>(packs.length, (h, p) => h * 31 + p.cards.length),
      widget.cardOfDayLocked ? null : widget.cardOfDay?.id,
    );
    if (_themeKey == key) return _theme;
    _themeKey = key;
    return _theme = QuestThemes.of(
      _themeCandidates(packs),
      day: day,
      profile: profile,
      preferred: widget.cardOfDayLocked ? null : widget.cardOfDay,
    );
  }

  /// Opens [screen] and, on the way back, notices which quest stop the trip
  /// finished — the map then pops that stop instead of quietly turning it
  /// green somewhere off screen.
  Future<void> _travel(Widget screen, {required bool game}) async {
    final before = ref.read(dailyQuestProvider).completed;
    await Navigator.of(context).push(
      game ? KidRoutes.game(screen) : KidRoutes.content(screen),
    );
    if (!mounted) return;
    final after = ref.read(dailyQuestProvider).completed;
    final fresh = after.difference(before);
    if (fresh.isEmpty) return;
    setState(() => _justCompleted = fresh.first);
    FeedbackService.instance.event(FeedbackEvent.progressStep);
  }

  @override
  Widget build(BuildContext context) {
    final quest = ref.watch(dailyQuestProvider);
    final packsAsync = ref.watch(packsProvider);
    final packs = packsAsync.valueOrNull ?? [];
    final isEn = ref.watch(languageProvider) == 'en';

    // Restore unlocked card/pack from persisted IDs
    CardModel? rewardCard;
    PackModel? rewardPack;
    if (quest.rewardClaimed &&
        quest.rewardCardId != null &&
        quest.rewardPackId != null &&
        packs.isNotEmpty) {
      rewardPack = packs.where((p) => p.id == quest.rewardPackId).firstOrNull;
      if (rewardPack != null) {
        rewardCard = rewardPack.cards
            .where((c) => c.id == quest.rewardCardId)
            .firstOrNull;
      }
    }
    // Also use locally cached values
    rewardCard ??= _lastUnlockedCard;
    rewardPack ??= _lastUnlockedPack;

    // If reward is claimed and we have the card — show full reveal screen
    if (quest.rewardClaimed && rewardCard != null && rewardPack != null) {
      final bonus = ref.read(bonusCardsProvider)[rewardPack.id] ?? 0;
      final newTotal = rewardPack.effectiveFreePreviewCount + bonus;
      return CardRevealScreen(
        card: rewardCard,
        pack: rewardPack,
        newTotal: newTotal,
        skipAnimation: true,
        onShare: (ctx) {
          final completed = ref.read(completedPacksProvider);
          final allPacks = ref.read(packsProvider).valueOrNull ?? [];
          final progress = ref.read(packProgressProvider);
          shareProgress(
            context: ctx,
            completedPacks: completed.length,
            totalPacks: allPacks.length,
            seenCards: progress.entries
                .where((e) => !e.key.startsWith('_'))
                .fold<int>(0, (s, e) => s + e.value),
            totalCards: allPacks.fold<int>(0, (s, p) => s + p.cards.length),
            streak: 0,
            isEn: ref.read(languageProvider) == 'en',
            badges: {},
          );
        },
        onGoToPack: () {
          Navigator.of(context).push(
            KidRoutes.content(
              CardsScreen(pack: rewardPack!, source: 'quest_reward'),
            ),
          );
        },
      );
    }

    // No text title — the map is the title. The journey widget paints its
    // own heading and counter.
    final theme = _themeOf(packs);
    return KidScreen(
      accent: DT.mint,
      background: DT.mintTint,
      showLeading: widget.showBackButton,
      body: QuestJourneyMap(
        quest: quest,
        isEn: isEn,
        // One picture says what today is about — the child reads the cat,
        // not the word «тварини» (rule 4).
        themeImage: theme?.image,
        themeLabel: theme?.semanticLabel(isEn),
        justCompleted: _justCompleted,
        onStopTap: (task) => _handleStopTap(context, task, packs, theme),
        onClaimTreasure: () => _showPackPicker(context, packs),
      ),
    );
  }

  // ─── Business logic (unchanged) ────────────────────────────

  void _handleStopTap(
    BuildContext context,
    QuestTask task,
    List<PackModel> packs,
    QuestTheme? theme,
  ) {
    // Setting off again: whatever was celebrated on the way back has been
    // seen by now.
    if (_justCompleted != null) setState(() => _justCompleted = null);

    // The day's deck. Without a theme (a brand-new install with almost
    // nothing unlocked) the stops fall back to what they always did — a
    // random open pack — rather than refusing to open.
    final themePack = theme?.asPack(
      title: AppS(ref.read(languageProvider) == 'en')(
        theme.title(false),
        theme.title(true),
      ),
      color: DT.mint,
    );
    PackModel? anyOpenPack() {
      final openPacks = packs
          .where((p) => !p.isLocked && !p.id.startsWith('_'))
          .toList();
      if (openPacks.isEmpty) return null;
      return openPacks[Random().nextInt(openPacks.length)];
    }

    switch (task) {
      case QuestTask.listenCardOfDay:
        // The hero of the theme is the card of the day whenever the two can
        // be the same; play it here and let the provider mark the task done
        // only once the audio actually starts — tapping the stop with an
        // empty callback (`() {}`) used to insta-complete it.
        final card = theme?.hero ?? widget.cardOfDay;
        if (card != null) {
          AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
          ref
              .read(dailyQuestProvider.notifier)
              .completeTask(QuestTask.listenCardOfDay);
        }
      case QuestTask.viewCards3:
      case QuestTask.viewCards5:
        // viewCards* is auto-completed by dailyQuestProvider once the child
        // has swiped through N cards — don't pre-complete here.
        final pack = themePack ?? anyOpenPack();
        if (pack != null) {
          _travel(
            CardsScreen(pack: pack, source: 'quest_map'),
            game: false,
          );
        }
      case QuestTask.reviewOldCard:
        // "Repeat after me" walks the same deck again — the whole point of
        // a theme is that the third meeting with the cat is not the first
        // meeting with a stranger. Opening a pack counts as the task; we
        // credit it after the child comes back, so she at least went in.
        final pack = themePack ?? anyOpenPack();
        if (pack == null) return;
        _travel(
          CardsScreen(pack: pack, source: 'quest_map'),
          game: false,
        ).then((_) {
          if (!mounted) return;
          ref
              .read(dailyQuestProvider.notifier)
              .completeTask(QuestTask.reviewOldCard);
        });
      case QuestTask.playQuiz:
        // GuessScreen calls completeTask(playQuiz) on its own Results screen.
        if (theme != null && theme.cards.length >= 4) {
          _travel(
            GuessScreen(
              cards: theme.cards,
              // Every tile of the round is already one subject; naming it
              // keeps the distractor picker inside it.
              cardGroups: {
                for (final c in theme.cards) c.id: theme.group.name,
              },
            ),
            game: true,
          );
          return;
        }
        final allCards = packs.expand((p) => p.cards).toList();
        final lang = ref.read(languageProvider);
        // Same sanitation as games_tab: real recorded audio + webp image.
        final playable = lang == 'en'
            ? allCards
                  .where(
                    (c) =>
                        c.image != null &&
                        AudioService.instance.hasSound(c.audioKey),
                  )
                  .toList()
            : allCards
                  .where((c) => c.audioKey != null && c.image != null)
                  .toList();
        if (playable.length >= 4) {
          _travel(
            GuessScreen(cards: playable, cardGroups: cardGroupsOf(packs)),
            game: true,
          );
        }
      case QuestTask.drawPicture:
        // The drawing shelf lives in a tab, not on a route this map can
        // push: leave the map and ask the home shell for it.
        Navigator.of(context).popUntil((r) => r.isFirst);
        ref.read(homeTabRequestProvider.notifier).state = kDrawTabIndex;
      case QuestTask.reviewSRSCards:
      case QuestTask.speakWords:
        // Bonus tasks — no specific navigation action needed
        break;
    }
  }

  void _showPackPicker(BuildContext context, List<PackModel> packs) {
    final lockedPacks = packs.where((p) => p.isLocked).toList();
    if (lockedPacks.isEmpty) {
      // All packs already unlocked — claim the reward directly
      ref.read(dailyQuestProvider.notifier).claimReward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppS(ref.read(languageProvider) == 'en')(
                '🎉 Усі паки вже відкрито — молодець!',
                '🎉 All packs already unlocked — great job!',
              ),
            ),
            backgroundColor: const Color(0xFFFFB347),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final bonusCards = ref.read(bonusCardsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PackPickerSheet(
        lockedPacks: lockedPacks,
        bonusCards: bonusCards,
        onPick: (pack) async {
          Navigator.of(ctx).pop();
          await _unlockAndReveal(pack);
        },
      ),
    );
  }

  Future<void> _unlockAndReveal(PackModel pack) async {
    final bonus = ref.read(bonusCardsProvider)[pack.id] ?? 0;
    final newTotal = pack.effectiveFreePreviewCount + bonus + 1;
    final cardIndex = (pack.effectiveFreePreviewCount + bonus).clamp(
      0,
      pack.cards.length - 1,
    );
    final card = pack.cards[cardIndex];

    await ref.read(bonusCardsProvider.notifier).unlockOne(pack.id);
    await ref
        .read(dailyQuestProvider.notifier)
        .claimReward(cardId: card.id, packId: pack.id);

    setState(() {
      _lastUnlockedCard = card;
      _lastUnlockedPack = pack;
    });

    if (!mounted) return;

    await Navigator.of(context).push(
      KidRoutes.content(
        CardRevealScreen(
          card: card,
          pack: pack,
          newTotal: newTotal,
          onShare: (ctx) {
            final completed = ref.read(completedPacksProvider);
            final allPacks = ref.read(packsProvider).valueOrNull ?? [];
            final progress = ref.read(packProgressProvider);
            shareProgress(
              context: ctx,
              completedPacks: completed.length,
              totalPacks: allPacks.length,
              seenCards: progress.entries
                  .where((e) => !e.key.startsWith('_'))
                  .fold<int>(0, (s, e) => s + e.value),
              totalCards: allPacks.fold<int>(0, (s, p) => s + p.cards.length),
              streak: 0,
              badges: {},
              isEn: ref.read(languageProvider) == 'en',
            );
          },
          onGoToPack: () {
            Navigator.of(context).push(
              KidRoutes.content(
                CardsScreen(pack: pack, source: 'quest_map'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PackPickerSheet extends ConsumerStatefulWidget {
  final List<PackModel> lockedPacks;
  final Map<String, int> bonusCards;
  final void Function(PackModel pack) onPick;

  const _PackPickerSheet({
    required this.lockedPacks,
    required this.bonusCards,
    required this.onPick,
  });

  @override
  ConsumerState<_PackPickerSheet> createState() => _PackPickerSheetState();
}

class _PackPickerSheetState extends ConsumerState<_PackPickerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: DT.motion.sheetEnter,
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // The gift is drawn, not an emoji, and one line of words is
          // enough: the covers below say what the choice is (rule 4).
          const AppIconView(AppIcon.rewardGift, size: 56),
          const SizedBox(height: 8),
          Text(
            AppS(ref.read(languageProvider) == 'en')(
              'Де відкрити картку?',
              'Where to open the card?',
            ),
            style: DT.h2,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(widget.lockedPacks.length, (i) {
              final pack = widget.lockedPacks[i];
              final bonus = widget.bonusCards[pack.id] ?? 0;
              final available =
                  pack.cards.length - pack.effectiveFreePreviewCount - bonus;
              final allUnlocked = available <= 0;
              final isSelected = _selectedIndex == i;
              // Cover, else the first card that has artwork — the same
              // fallback ladder as the pack grid tile.
              final thumb = pack.cards
                  .where((c) => c.image != null)
                  .firstOrNull;

              return AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) {
                  final delay = i * 0.1;
                  final t = ((_entryCtrl.value - delay) / (1 - delay)).clamp(
                    0.0,
                    1.0,
                  );
                  final scale = Curves.elasticOut.transform(t);
                  return Transform.scale(
                    scale: scale.clamp(0.0, 1.1),
                    child: child,
                  );
                },
                child: KidTap(
                  onTap: allUnlocked
                      ? null
                      : () {
                          setState(() => _selectedIndex = i);
                          Future.delayed(
                            DT.motion.base,
                            () => widget.onPick(pack),
                          );
                        },
                  child: AnimatedContainer(
                    duration: MotionPolicy.of(context).dur(DT.motion.quick),
                    width: 120,
                    padding: const EdgeInsets.all(DT.sp8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? pack.color.withValues(alpha: 0.2)
                          : pack.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(DT.rLg),
                      border: Border.all(
                        color: isSelected
                            ? pack.color
                            : pack.color.withValues(alpha: 0.2),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: Opacity(
                      opacity: allUnlocked ? 0.35 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The pack's own picture, not an emoji: the child
                          // chooses by what she will see inside.
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration:
                                MotionPolicy.of(context).dur(DT.motion.quick),
                            child: SizedBox(
                              width: 104,
                              height: 76,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(DT.rMd),
                                child: CardImage(
                                  name: pack.cover ?? thumb?.image,
                                  fallbackEmoji: pack.icon,
                                  fallback: isLetterIcon(pack.icon)
                                      ? Center(
                                          child: LetterStickerIcon(
                                            letter: pack.icon,
                                            color: pack.color,
                                            size: 52,
                                          ),
                                        )
                                      : null,
                                  background:
                                      pack.color.withValues(alpha: 0.06),
                                  padding: EdgeInsets.zero,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DT.sp4),
                          Text(
                            pack.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // The title is charcoal, not the pack colour:
                            // on the 8–20 % pack wash over `DT.bgWarm` a
                            // mint title measured 2.0:1. The tile still
                            // reads as the pack — the wash, the border and
                            // the cover carry it.
                            style: DT.tileTitle.copyWith(
                              fontSize: 13,
                              color: DT.textPrimary,
                            ),
                          ),
                          if (allUnlocked)
                            const Padding(
                              padding: EdgeInsets.only(top: DT.sp4),
                              child: AppIconView(AppIcon.check, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
