import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_model.dart';
import '../models/card_model.dart';
import '../providers/card_of_day_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/open_content_pack.dart';
import '../screens/coloring_hub_screen.dart';
import '../screens/quest_map_screen.dart';
import '../services/widget_service.dart';
import '../tabs/games_tab.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import 'card_image.dart';
import 'kid_tap.dart';
import 'play_components.dart';

/// One row of equal tiles under the lesson banner: the card of the day (its
/// own picture), Games, and — only when there is something behind them —
/// Review (cards due) or Favorites.
///
/// Draw and Treasures live in «My world»; Profiles is the avatar in the
/// header; stickers are inside Treasures. Each used to be a tile here too,
/// which made six small boxes of equal weight and pushed the card packs off
/// the first screen.
class HomeQuickRow extends ConsumerStatefulWidget {
  const HomeQuickRow({super.key});
  @override
  ConsumerState<HomeQuickRow> createState() => _HomeQuickRowState();
}

class _HomeQuickRowState extends ConsumerState<HomeQuickRow> {
  String? _syncedCard;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final packs = ref.watch(packsProvider).valueOrNull ?? [];
    final daily = ref.watch(cardOfDaySelectorProvider)(packs);
    if (daily != null && _syncedCard != daily.$1.id) {
      _syncedCard = daily.$1.id;
      WidgetService.instance.updateCardOfDay(daily.$1);
    }
    final favorites = ref.watch(favoritesProvider);
    ref.watch(reviewProvider);
    final due = ref.read(reviewProvider.notifier).reviewCardIds;
    final allCards = packs.expand((p) => p.cards).toList();
    final favCards = allCards.where((c) => favorites.contains(c.id)).toList();
    final dueCards = allCards.where((c) => due.contains(c.id)).toList();

    final quest = ref.watch(dailyQuestProvider);
    final tiles = <Widget>[
      _QuestTile(
        quest: quest,
        label: s('Скарб дня', 'Daily treasure'),
        onTap: () => Navigator.of(context).push(
          KidRoutes.content(
            QuestMapScreen(
              cardOfDay: daily?.$1,
              cardOfDayLocked: daily?.$2 ?? false,
              onCardOfDayTap: () {},
            ),
          ),
        ),
      ),
      if (daily != null)
        _CardOfDayTile(
          card: daily.$1,
          label: s('Слово дня', 'Today’s word'),
          onTap: () {
            final card = daily.$1;
            AnalyticsService.instance.logCardOfDayTap(card.id);
            AnalyticsService.instance.logFirstAction('hero_cta');
            AudioService.instance.speakCard(
              card.audioKey,
              card.sound,
              card.text,
            );
            ref
                .read(dailyQuestProvider.notifier)
                .completeTask(QuestTask.listenCardOfDay);
          },
          onLongPress: () => _showCardSheet(context, s, daily.$1),
        ),
      if (dueCards.length >= 5)
        _Tile(
          tileKey: const ValueKey('home-review'),
          icon: const AppIconView(AppIcon.replay, size: 40),
          label: s('Повторення', 'Review'),
          onTap: () => openContentPack(
            context,
            ref,
            PackModel(
              id: '_review',
              title: s('Повторення', 'Review'),
              icon: '🔄',
              color: DT.sky,
              isLocked: false,
              isFree: true,
              cards: dueCards,
            ),
            source: 'home_review',
          ),
        )
      else if (favCards.isNotEmpty)
        _Tile(
          tileKey: const ValueKey('home-favorites'),
          icon: const AppIconView(AppIcon.star, size: 40),
          label: s('Улюблені', 'Favorites'),
          onTap: () => openContentPack(
            context,
            ref,
            PackModel(
              id: '_favorites',
              title: s('Улюблені', 'Favorites'),
              icon: '❤️',
              color: DT.streakOrange,
              isLocked: false,
              isFree: true,
              cards: favCards,
            ),
            source: 'home_favorites',
          ),
        ),
    ];
    // A short phone keeps a pack on the first screen (the owner's rule):
    // there the doors join the small tiles in one row instead of taking a
    // row of their own.
    if (MediaQuery.sizeOf(context).height < 760) {
      final all = [
        _Tile(
          tileKey: const ValueKey('home-games'),
          icon: const AppArt('gamepad', size: 44),
          label: s('Ігри', 'Games'),
          onTap: () {
            AudioService.instance.stop();
            Navigator.of(context).push(KidRoutes.content(const GamesTab()));
          },
        ),
        _Tile(
          tileKey: const ValueKey('home-draw'),
          icon: const AppArt('palette', size: 44),
          label: s('Малювати', 'Draw'),
          onTap: () {
            AudioService.instance.stop();
            Navigator.of(
              context,
            ).push(KidRoutes.content(const ColoringHubScreen()));
          },
        ),
        ...tiles.take(2),
      ];
      return Row(
        children: [
          for (var i = 0; i < all.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: all[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        // The two things children come back for — games and drawing — as
        // big picture doors. Drawing is the most played activity in the
        // app and used to sit two taps away on the third tab.
        Row(
          children: [
            Expanded(
              child: _Door(
                doorKey: const ValueKey('home-games'),
                art: 'gamepad',
                label: s('Ігри', 'Games'),
                tint: DT.sky,
                onTap: () {
                  AudioService.instance.stop();
                  Navigator.of(
                    context,
                  ).push(KidRoutes.content(const GamesTab()));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Door(
                doorKey: const ValueKey('home-draw'),
                art: 'palette',
                label: s('Малювати', 'Draw'),
                tint: DT.streakOrange,
                onTap: () {
                  AudioService.instance.stop();
                  Navigator.of(
                    context,
                  ).push(KidRoutes.content(const ColoringHubScreen()));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ],
    );
  }

  void _showCardSheet(BuildContext context, AppS s, card) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 140, child: CardImage.forCard(card)),
                Text(card.sound, style: DT.h2),
                Text(card.text, style: DT.body, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                PlayAction(
                  label: s('Слухати ще раз', 'Listen again'),
                  icon: AppIcon.sound,
                  onPressed: () => AudioService.instance.speakCard(
                    card.audioKey,
                    card.sound,
                    card.text,
                  ),
                ),
                if (!ref.read(favoritesProvider).contains(card.id)) ...[
                  const SizedBox(height: 12),
                  PlayAction(
                    label: s('Додати в улюблені', 'Add to favorites'),
                    icon: AppIcon.star,
                    secondary: true,
                    onPressed: () {
                      ref.read(favoritesProvider.notifier).toggle(card.id);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s('Закрити', 'Close')),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => AudioService.instance.stop());
  }
}

/// A big picture door: one painted object, one word.
class _Door extends StatelessWidget {
  const _Door({
    required this.doorKey,
    required this.art,
    required this.label,
    required this.tint,
    required this.onTap,
  });
  final Key doorKey;
  final String art;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KidTap(
    key: doorKey,
    onTap: onTap,
    child: Container(
      height: MediaQuery.textScalerOf(context).scale(124),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: .14), DT.surfaceWhite),
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.surfaceWhite, width: 4),
        boxShadow: DT.shadowSoft(tint),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppArt(art, size: 72),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: DT.tileTitle.copyWith(color: DT.textPrimary),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Key tileKey;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  static const height = 84.0;
  static final decoration = BoxDecoration(
    color: DT.surfaceWhite,
    borderRadius: BorderRadius.circular(DT.rMd),
    border: Border.all(color: DT.outline, width: 2),
  );
  static final labelStyle = DT.caption.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: DT.textPrimary,
  );

  @override
  Widget build(BuildContext context) => KidTap(
    key: tileKey,
    onTap: onTap,
    child: Container(
      height: MediaQuery.textScalerOf(context).scale(height),
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(this.label, style: _Tile.labelStyle, maxLines: 1),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Today's five tasks as a picture: the gift, five stars, lit as they are
/// done. Opens the quest map.
class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.quest,
    required this.label,
    required this.onTap,
  });
  final DailyQuestState quest;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KidTap(
    key: const ValueKey('home-daily-quest'),
    onTap: onTap,
    child: Container(
      height: MediaQuery.textScalerOf(context).scale(_Tile.height),
      decoration: _Tile.decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // One picture, one word. Progress is a badge on the chest, not
          // a number squeezed into the caption.
          SizedBox(
            height: 46,
            width: 62,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(child: AppArt('chest', size: 46)),
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: quest.allDone ? DT.success : DT.brand,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DT.surfaceWhite, width: 2),
                    ),
                    child: Text(
                      '${quest.allDone ? quest.totalCount : quest.doneCount}/${quest.totalCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: _Tile.labelStyle, maxLines: 1),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The card of the day: its picture, and an answer to the tap — the picture
/// hops, the frame lights up and the speaker turns to waves for as long as
/// the word is being said.
class _CardOfDayTile extends StatefulWidget {
  const _CardOfDayTile({
    required this.card,
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });
  final CardModel card;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  @override
  State<_CardOfDayTile> createState() => _CardOfDayTileState();
}

class _CardOfDayTileState extends State<_CardOfDayTile> {
  bool _playing = false;
  Timer? _end;

  @override
  void dispose() {
    _end?.cancel();
    super.dispose();
  }

  void _tap() {
    widget.onTap();
    setState(() => _playing = true);
    _end?.cancel();
    _end = Timer(DT.motion.rewardReveal, () {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final d = reduce ? Duration.zero : DT.motion.base;
    return KidTap(
      key: const ValueKey('home-card-of-day'),
      onLongPress: widget.onLongPress,
      onTap: _tap,
      child: AnimatedContainer(
        duration: d,
        height: MediaQuery.textScalerOf(context).scale(_Tile.height),
        decoration: BoxDecoration(
          color: _playing ? DT.mintTint : DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: _playing ? DT.brand : DT.outline, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Today's picture as a little rounded card, the same size as the
            // chest and the puzzle, with the "listen" ear as its badge.
            AnimatedScale(
              scale: _playing ? 1.12 : 1,
              duration: d,
              curve: Curves.easeOutBack,
              child: SizedBox(
                height: 46,
                width: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox.square(
                          dimension: 46,
                          child: CardImage.forCard(
                            widget.card,
                            fit: BoxFit.cover,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: DT.surfaceWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _playing ? DT.brand : DT.outline,
                            width: 2,
                          ),
                        ),
                        child: const AppArt('listen', size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // While it speaks, the caption is the word itself: the tap
                // used to change a tint and nothing a parent could read.
                child: Text(
                  _playing ? widget.card.sound : widget.label,
                  style: _Tile.labelStyle.copyWith(
                    color: _playing ? DT.brand : null,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
