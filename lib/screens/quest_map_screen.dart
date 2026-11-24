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

import '../widgets/quest_journey_map.dart';
import '../widgets/kid_screen.dart';
import '../widgets/reward_pack_picker.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/kid_routes.dart';
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
  bool _claimingReward = false;
  bool _pickerOpen = false;
  bool _travelling = false;
  bool _animateReward = false;

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
  Future<void> _travel(
    Widget screen, {
    required bool game,
    QuestTask? completeOnReturn,
  }) async {
    if (_travelling) return;
    _travelling = true;
    final questOwner = ref.read(dailyQuestProvider.notifier);
    final before = ref.read(dailyQuestProvider).completed;
    try {
      await Navigator.of(
        context,
      ).push(game ? KidRoutes.game(screen) : KidRoutes.content(screen));
      if (!mounted ||
          !identical(questOwner, ref.read(dailyQuestProvider.notifier))) {
        return;
      }
      if (completeOnReturn != null) {
        await questOwner.completeTask(completeOnReturn);
      }
    } finally {
      _travelling = false;
    }
    if (!mounted ||
        !identical(questOwner, ref.read(dailyQuestProvider.notifier))) {
      return;
    }
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
        skipAnimation: !_animateReward,
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
      backdrop: 'assets/images/backdrops/home_sky.webp',
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
          _travel(CardsScreen(pack: pack, source: 'quest_map'), game: false);
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
          completeOnReturn: QuestTask.reviewOldCard,
        );
      case QuestTask.playQuiz:
        // GuessScreen calls completeTask(playQuiz) on its own Results screen.
        if (theme != null && theme.cards.length >= 4) {
          _travel(
            GuessScreen(
              returnToAdventure: true,
              cards: theme.cards,
              // Every tile of the round is already one subject; naming it
              // keeps the distractor picker inside it.
              cardGroups: {for (final c in theme.cards) c.id: theme.group.name},
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
            GuessScreen(
              cards: playable,
              cardGroups: cardGroupsOf(packs),
              returnToAdventure: true,
            ),
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

  Future<void> _showPackPicker(
    BuildContext context,
    List<PackModel> packs,
  ) async {
    final quest = ref.read(dailyQuestProvider);
    if (_pickerOpen ||
        _claimingReward ||
        !quest.allDone ||
        quest.rewardClaimed) {
      return;
    }
    final bonusCards = ref.read(bonusCardsProvider);
    final lockedPacks = packs
        .where(
          (p) =>
              p.isLocked &&
              p.cards.length >
                  p.effectiveFreePreviewCount + (bonusCards[p.id] ?? 0),
        )
        .toList();
    if (lockedPacks.isEmpty) {
      await ref.read(dailyQuestProvider.notifier).claimReward();
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppS(ref.read(languageProvider) == 'en')(
              'Усі картки вже відкрито. Пригоду завершено!',
              'All cards are already unlocked. Adventure complete!',
            ),
          ),
        ),
      );
      return;
    }
    _pickerOpen = true;
    try {
      final selected = await showModalBottomSheet<PackModel>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        showDragHandle: false,
        useSafeArea: true,
        builder: (ctx) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .85,
          ),
          child: SingleChildScrollView(
            child: RewardPackPicker(
              packs: lockedPacks,
              isEn: ref.read(languageProvider) == 'en',
              bonusCards: bonusCards,
              onPick: (pack) => Navigator.of(ctx).pop(pack),
            ),
          ),
        ),
      );
      if (mounted && selected != null) await _unlockAndReveal(selected);
    } finally {
      _pickerOpen = false;
    }
  }

  Future<void> _unlockAndReveal(PackModel pack) async {
    final quest = ref.read(dailyQuestProvider);
    if (_claimingReward || !quest.allDone || quest.rewardClaimed) return;
    final bonus = ref.read(bonusCardsProvider)[pack.id] ?? 0;
    final cardIndex = pack.effectiveFreePreviewCount + bonus;
    if (cardIndex >= pack.cards.length) return;
    _claimingReward = true;
    // Keep the notifiers before the await: the map may be dismissed while
    // preferences are being saved. The same grant still finishes once.
    final bonuses = ref.read(bonusCardsProvider.notifier);
    final quests = ref.read(dailyQuestProvider.notifier);
    try {
      await bonuses.unlockOne(pack.id);
      if (mounted) {
        setState(() {
          _lastUnlockedCard = pack.cards[cardIndex];
          _lastUnlockedPack = pack;
          _animateReward = true;
        });
      }
      // build swaps the map for the reveal on this SAME route. Popping the
      // reveal therefore returns home, without a second reveal underneath.
      await quests.claimReward(
        cardId: pack.cards[cardIndex].id,
        packId: pack.id,
      );
    } finally {
      _claimingReward = false;
    }
  }
}
