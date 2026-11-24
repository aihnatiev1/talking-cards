import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_model.dart';
import '../providers/card_of_day_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/open_content_pack.dart';
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

    final tiles = <Widget>[
      if (daily != null) _cardOfDayTile(context, s, daily.$1),
      _Tile(
        tileKey: const ValueKey('home-games'),
        icon: const AppArt('puzzle', size: 44),
        label: s('Ігри', 'Games'),
        onTap: () {
          AudioService.instance.stop();
          Navigator.of(context).push(KidRoutes.content(const GamesTab()));
        },
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
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(flex: i == 0 && daily != null ? 3 : 2, child: tiles[i]),
        ],
      ],
    );
  }

  Widget _cardOfDayTile(BuildContext context, AppS s, card) {
    return KidTap(
      key: const ValueKey('home-card-of-day'),
      onLongPress: () => _showCardSheet(context, s, card),
      onTap: () {
        AnalyticsService.instance.logCardOfDayTap(card.id);
        AnalyticsService.instance.logFirstAction('hero_cta');
        AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
        ref
            .read(dailyQuestProvider.notifier)
            .completeTask(QuestTask.listenCardOfDay);
      },
      child: Container(
        height: MediaQuery.textScalerOf(context).scale(_Tile.height),
        padding: const EdgeInsets.all(6),
        decoration: _Tile.decoration,
        child: Row(
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: 1,
                child: CardImage.forCard(card, padding: EdgeInsets.zero),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconView(AppIcon.sound, size: 22),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      card.sound,
                      style: _Tile.labelStyle,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(this.label, style: _Tile.labelStyle, maxLines: 1),
          ),
        ],
      ),
    ),
  );
}
