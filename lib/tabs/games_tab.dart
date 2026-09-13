import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/app_review_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../screens/articulation_screen.dart';
import '../screens/bubble_pop_screen.dart';
import '../screens/guess_screen.dart';
import '../screens/memory_match_screen.dart';
import '../screens/odd_one_out_screen.dart';
import '../screens/opposite_game_screen.dart';
import '../screens/repeat_game_screen.dart';
import '../services/audio_service.dart';
import '../services/paywall_flow.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../providers/content_pack_provider.dart';
import '../widgets/card_image.dart';
import '../widgets/entrance_stagger.dart';
import '../widgets/kid_tap.dart';

class GamesTab extends ConsumerStatefulWidget {
  const GamesTab({super.key});

  @override
  ConsumerState<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends ConsumerState<GamesTab> {
  void _openQuiz(List<CardModel> allCards) {
    final lang = ref.read(languageProvider);
    // Playable = real recorded audio AND a webp illustration — the game
    // renders images (never emoji) and plays recordings (never TTS).
    final List<CardModel> cards;
    if (lang == 'en') {
      cards = allCards
          .where(
            (c) =>
                c.image != null && AudioService.instance.hasSound(c.audioKey),
          )
          .toList();
    } else {
      cards = allCards
          .where((c) => c.audioKey != null && c.image != null)
          .toList();
    }
    if (cards.length < 4) return;
    // The packs are still here — hand the game the semantics the flat
    // card list lost, so its distractors can come from one set (§19).
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    _openGame(
      KidRoutes.game(
        GuessScreen(cards: cards, cardGroups: cardGroupsOf(packs)),
      ),
    );
  }

  /// Every game goes through here so the one automatic review ask a
  /// first-time family gets lands on the games list, after the screen and
  /// its celebration are gone — never over a dialog a toddler is tapping.
  Future<void> _openGame(Route<void> route) async {
    await Navigator.of(context).push(route);
    if (!mounted) return;
    await ref.read(appReviewControllerProvider).askIfFirstGamePending();
  }

  void _openMemoryMatch(List<CardModel> allCards) {
    final playable = allCards.where((c) => c.image != null).toList();
    if (playable.length < 6) return;
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final pack = packs.firstWhere(
      (p) => !p.isLocked && !p.id.startsWith('_'),
      orElse: () => packs.first,
    );
    // No pair count from here: the board sizes itself from the profile's
    // level and from how calm the last rounds were
    // (memory_match_redesign §6).
    _openGame(
      KidRoutes.game(MemoryMatchScreen(pack: pack, cards: playable)),
    );
  }

  static const _oddOneOutExclude = {
    'adjectives',
    'actions',
    'opposites',
    'phrases',
    'rozmovlyalky',
    'poems',
    'sound_r',
    'sound_l',
    'sound_sh',
    'sound_s',
    'sound_z',
    'sound_zh',
    'sound_ch',
    'sound_shch',
    'sound_ts',
    'en_actions',
    'en_opposites',
  };

  void _openOddOneOut(List<PackModel> packs) {
    final lang = ref.read(languageProvider);
    final playablePacks = packs
        .where(
          (p) =>
              !p.id.startsWith('_') &&
              !p.isLocked &&
              !_oddOneOutExclude.contains(p.id) &&
              p.cards.length >= 4 &&
              (lang == 'en' ? p.cards.any((c) => c.image != null) : true),
        )
        .toList();
    if (playablePacks.length < 2) return;
    _openGame(KidRoutes.game(OddOneOutScreen(packs: playablePacks)));
  }

  void _openRepeatGame(List<PackModel> packs) {
    // Repeat After Me asks the child to say a real word, so exclude phrase /
    // verse / babble packs (rozmovlyalky = ай/ба/ва, poems, phrases — not
    // single words). Also require a webp illustration so the child has
    // something to anchor the word to visually.
    final cards = packs
        .where(
          (p) =>
              !p.id.startsWith('_') && !PackModel.nonWordPackIds.contains(p.id),
        )
        .expand((p) => p.cards)
        .where((c) => c.image != null)
        .toList();
    if (cards.length < 4) return;
    _openGame(KidRoutes.game(RepeatGameScreen(cards: cards)));
  }

  void _openArticulation() {
    _openGame(KidRoutes.game(const ArticulationScreen()));
  }

  void _openOppositeGame(List<PackModel> packs) {
    final isEn = ref.read(languageProvider) == 'en';
    final id = isEn ? 'en_opposites' : 'opposites';
    final oppPack = packs.where((p) => p.id == id).firstOrNull;
    if (oppPack == null || oppPack.cards.length < 4) return;
    Navigator.of(context).push(KidRoutes.game(OppositeGameScreen(pack: oppPack)));
  }

  /// Pick the first card with a webp image from the given pool.
  CardModel? _pickThumb(List<CardModel> pool, {int skip = 0}) {
    final withImage = pool.where((c) => c.image != null).toList();
    if (withImage.isEmpty) return null;
    return withImage[skip % withImage.length];
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(packsProvider);
    final isEn = ref.watch(languageProvider) == 'en';

    return Scaffold(
      backgroundColor: DT.bgWarm,
      appBar: AppBar(
        title: Text(
          isEn ? '🎮 Games' : '🎮 Ігри',
          style: DT.h1.copyWith(fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐢', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  isEn ? 'Oops, didn\'t load' : 'Ой, не завантажилось',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(packsProvider),
                  icon: const AppIconView(AppIcon.replay, size: 22),
                  label: Text(isEn ? 'Try again' : 'Спробувати ще раз'),
                ),
              ],
            ),
          ),
        ),
        data: (packs) {
          // Word-based games (Guess, Memory, thumbnails) must not pull cards
          // from phrase/verse/babble packs, or a poem plays instead of a word.
          // …nor from paid packs whose illustrations are still arriving via
          // the Play asset pack — a game with blank tiles is worse than a
          // game with fewer cards.
          final contentReady = ref.watch(contentPackProvider).isReady;
          final allCards = packs
              .where((p) => !PackModel.nonWordPackIds.contains(p.id))
              .where((p) => contentReady || p.isFree)
              .expand((p) => p.cards)
              .toList();
          final playableCount = isEn
              ? allCards
                    .where(
                      (c) =>
                          c.image != null &&
                          AudioService.instance.hasSound(c.audioKey),
                    )
                    .length
              : allCards
                    .where((c) => c.audioKey != null && c.image != null)
                    .length;

          final toddlerGames = <_BigGame>[
            _BigGame(
              title: isEn ? 'Guess the word' : 'Вгадай звук',
              subtitle: isEn
                  ? 'Listen and tap the card'
                  : 'Слухай і тисни картку',
              color: DT.sky,
              bg: DT.skyTint,
              thumb: _pickThumb(allCards, skip: 0),
              badge: AppIcon.gameGuess,
              onTap: playableCount >= 4 ? () => _openQuiz(allCards) : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
            _BigGame(
              title: isEn ? 'Find the pair' : 'Знайди пару',
              subtitle: isEn
                  ? 'Flip cards, match pairs'
                  : 'Відкривай і шукай пари',
              color: DT.mint,
              bg: DT.mintTint,
              thumb: _pickThumb(allCards, skip: 5),
              badge: AppIcon.gameMatch,
              onTap: playableCount >= 6
                  ? () => _openMemoryMatch(allCards)
                  : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
            _BigGame(
              title: isEn ? 'Pop the bubbles' : 'Лопай бульбашки',
              subtitle: isEn ? 'Pop, pop, pop!' : 'Лоп-лоп-лоп!',
              color: DT.coral,
              bg: DT.coralTint,
              thumb: _pickThumb(allCards, skip: 9),
              badge: AppIcon.gameBubbles,
              onTap: playableCount >= 5
                  ? () => Navigator.of(
                      context,
                    ).push(KidRoutes.game(const BubblePopScreen()))
                  : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
            _BigGame(
              title: isEn ? 'Repeat after me' : 'Повтори за мною',
              subtitle: isEn
                  ? 'Say the word, grown-up taps'
                  : 'Скажи слово, дорослий натискає',
              color: DT.peach,
              bg: DT.peachTint,
              thumb: _pickThumb(allCards, skip: 12),
              badge: AppIcon.gameRepeat,
              onTap: playableCount >= 4 ? () => _openRepeatGame(packs) : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
          ];

          final parentGames = <_BigGame>[
            _BigGame(
              title: isEn ? 'Articulation' : 'Артикуляційна',
              subtitle: isEn
                  ? 'Daily tongue & lip workout'
                  : 'Щоденна гімнастика язика',
              color: DT.violet,
              bg: DT.violetTint,
              thumb: null,
              badge: AppIcon.gameArticulation,
              onTap: _openArticulation,
              lockedHint: '',
            ),
          ];

          final advancedPacks = packs
              .where(
                (p) =>
                    !p.id.startsWith('_') &&
                    !p.isLocked &&
                    !_oddOneOutExclude.contains(p.id) &&
                    p.cards.length >= 4 &&
                    (isEn ? p.cards.any((c) => c.image != null) : true),
              )
              .toList();
          // Whether buying would actually help: a locked pack that would
          // qualify if it were open. Without this the hint can send a
          // parent to the paywall for something a purchase cannot fix.
          final oddUnlockable = packs.any(
            (p) =>
                !p.id.startsWith('_') &&
                p.isLocked &&
                !_oddOneOutExclude.contains(p.id) &&
                p.cards.length >= 4 &&
                (isEn ? p.cards.any((c) => c.image != null) : true),
          );
          final oddShort = 2 - advancedPacks.length;

          final oppPackId = isEn ? 'en_opposites' : 'opposites';
          final oppPack = packs.where((p) => p.id == oppPackId).firstOrNull;
          final oppLocked = oppPack?.isLocked ?? false;
          final oppPlayable =
              oppPack != null && !oppPack.isLocked && oppPack.cards.length >= 4;
          final advancedGames = <_BigGame>[
            _BigGame(
              title: isEn ? 'Odd one out' : 'Знайди зайве',
              subtitle: isEn
                  ? 'Spot the different one'
                  : 'Знайди не таке, як інші',
              color: DT.violet,
              bg: DT.violetTint,
              thumb: _pickThumb(allCards, skip: 20),
              badge: AppIcon.gameOdd,
              onTap: advancedPacks.length >= 2
                  ? () => _openOddOneOut(packs)
                  : null,
              // "Open at least 2 packs" said nothing a parent could act
              // on: which packs, opened how, and why two. Name the number
              // still missing, say that unlocking is what does it, and
              // make the tap go there.
              lockedHint: isEn
                  ? (oddUnlockable
                        ? 'This game needs 2 open packs — '
                              '${oddShort == 1 ? "unlock one more" : "unlock two"}'
                        : 'This game needs 2 packs with pictures')
                  : (oddUnlockable
                        ? 'Грі потрібні 2 відкриті паки — '
                              'розблокуй ще ${oddShort == 1 ? "один" : "два"}'
                        : 'Грі потрібні 2 паки з картинками'),
              onLockedTap: oddUnlockable
                  ? () => runPaywallFlow(context, ref, source: 'games_lock')
                  : null,
            ),
            _BigGame(
              title: isEn ? 'Opposites' : 'Протилежності',
              subtitle: isEn
                  ? 'Big↔small, hot↔cold'
                  : 'Великий↔малий, тепло↔холод',
              color: DT.pink,
              bg: DT.pinkTint,
              thumb: oppPack != null ? _pickThumb(oppPack.cards) : null,
              badge: AppIcon.gameOpposites,
              onTap: oppPlayable ? () => _openOppositeGame(packs) : null,
              lockedHint: isEn
                  ? (oppLocked
                        ? 'Subscribe to unlock Opposites'
                        : 'Opposites pack is empty')
                  : (oppLocked
                        ? 'Розблокуй пак «Протилежності»'
                        : 'Пак «Протилежності» порожній'),
              onLockedTap: oppLocked
                  ? () => runPaywallFlow(context, ref, source: 'games_lock')
                  : null,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              _SectionHeader(
                title: isEn ? 'For little ones' : 'Для малят',
                subtitle: isEn ? 'ages 1–3' : '1–3 роки',
                emoji: '🧸',
              ),
              const SizedBox(height: 10),
              _GameGrid(games: toddlerGames),
              const SizedBox(height: 22),
              _SectionHeader(
                title: isEn ? 'For grown-ups' : 'Для батьків',
                subtitle: isEn ? 'speech therapy' : 'мовленнєва терапія',
                emoji: '👨‍👧',
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  for (final game in parentGames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: DT.violetTint,
                        borderRadius: BorderRadius.circular(22),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: AppIconView(
                              AppIcon.gameArticulation,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            game.title,
                            style: DT.tileTitle.copyWith(color: DT.textPrimary),
                          ),
                          subtitle: Text(game.subtitle),
                          trailing: const AppIconView(
                            AppIcon.play,
                            size: 18,
                            color: DT.textMuted,
                          ),
                          onTap: () {
                            KidTap.feedback();
                            game.onTap?.call();
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: isEn ? 'For older kids' : 'Для старших',
                subtitle: isEn ? 'ages 3+' : '3+',
                emoji: '🎓',
              ),
              const SizedBox(height: 10),
              _GameGrid(games: advancedGames),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Helper data + widgets
// ─────────────────────────────────────────────

class _BigGame {
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final CardModel? thumb;
  final AppIcon badge; // small floating sticker in the tile's corner
  final VoidCallback? onTap;
  final String lockedHint;

  /// When the tile is in disabled state (`onTap == null`) and this callback
  /// is set, tapping invokes it instead of the default snackbar — used to
  /// route the user straight to the paywall when the lock is subscription-
  /// gated rather than skill-gated ("open more packs").
  final VoidCallback? onLockedTap;

  _BigGame({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.thumb,
    required this.badge,
    required this.onTap,
    required this.lockedHint,
    this.onLockedTap,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(title, style: DT.h2.copyWith(fontSize: 19)),
          const SizedBox(width: 8),
          Text(subtitle, style: DT.caption.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  final List<_BigGame> games;
  const _GameGrid({required this.games});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = scale > 1.5 || box.maxWidth < 310
            ? 1
            : (box.maxWidth / 170).floor().clamp(2, 4);
        final width = (box.maxWidth - (columns - 1) * 16) / columns;
        double measure(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
          )..layout(maxWidth: width - 28);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        double titleHeight = 0, subtitleHeight = 0;
        for (final game in games) {
          final title = measure(game.title, DT.tileTitle);
          final subtitle = measure(
            game.subtitle,
            DT.body.copyWith(fontSize: 12),
          );
          if (title > titleHeight) titleHeight = title;
          if (subtitle > subtitleHeight) subtitleHeight = subtitle;
        }
        final textHeight = titleHeight + subtitleHeight + 26;
        return StaggerScope(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 18,
              crossAxisSpacing: 16,
              mainAxisExtent: width * .96 + textHeight + 4,
            ),
            itemCount: games.length,
            // Tiles land one after another (G11) instead of the whole board
            // appearing in one frame.
            itemBuilder: (_, i) => StaggeredEntrance(
              key: ValueKey(games[i].title),
              index: i,
              child: _BigGameTile(game: games[i], textHeight: textHeight),
            ),
          ),
        );
      },
    );
  }
}

class _BigGameTile extends StatelessWidget {
  final _BigGame game;
  final double textHeight;
  const _BigGameTile({required this.game, required this.textHeight});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final disabled = g.onTap == null;

    // Locked or not, the tap itself is answered (audit #13, #23).
    return KidTap(
      onTap: () {
        if (disabled) {
          if (g.onLockedTap != null) {
            g.onLockedTap!();
            return;
          }
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(g.lockedHint)),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        g.onTap?.call();
      },
      child: AnimatedOpacity(
        opacity: disabled ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: g.bg,
            borderRadius: BorderRadius.circular(DT.rLg + 2),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: g.color.withValues(alpha: .28),
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: g.color.withValues(alpha: .12),
                offset: const Offset(0, 9),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Illustration area
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.5),
                          child: CardImage(
                            name: g.thumb?.image,
                            // Never shown: `fallback` wins whenever there
                            // is no picture, but the slot is non-nullable
                            // by contract.
                            fallbackEmoji: '•',
                            fallback: AppIconView(g.badge, size: 64),
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ),
                    // Floating sticker badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: g.color.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AppIconView(g.badge, size: 24),
                      ),
                    ),
                    if (disabled)
                      const Positioned(
                        top: 10,
                        right: 10,
                        // The smiling padlock (never grey), sticker-edged so
                        // it reads on the thumbnail without a disc.
                        child: AppIconView(
                          AppIcon.lock,
                          size: 30,
                          sticker: true,
                        ),
                      ),
                  ],
                ),
              ),
              // One measured caption height keeps artwork aligned across the row.
              SizedBox(
                height: textHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: DT.tileTitle.copyWith(
                          color: DT.onTint(g.color),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        g.subtitle,
                        style: DT.body.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
