import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../screens/articulation_screen.dart';
import '../screens/bubble_pop_screen.dart';
import '../screens/guess_screen.dart';
import '../screens/memory_match_screen.dart';
import '../screens/odd_one_out_screen.dart';
import '../screens/opposite_game_screen.dart';
import '../screens/repeat_game_screen.dart';
import '../utils/design_tokens.dart';

/// Smooth fade+scale transition for games.
Route<T> _gameRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.93, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
            opacity: fade, child: ScaleTransition(scale: scale, child: child));
      },
    );

class GamesTab extends ConsumerStatefulWidget {
  const GamesTab({super.key});

  @override
  ConsumerState<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends ConsumerState<GamesTab> {
  void _openQuiz(List<CardModel> allCards) {
    final lang = ref.read(languageProvider);
    final List<CardModel> cards;
    final String? ttsLocale;
    if (lang == 'en') {
      cards = allCards.where((c) => c.image != null).toList();
      ttsLocale = 'en-US';
    } else {
      cards = allCards.where((c) => c.audioKey != null).toList();
      ttsLocale = null;
    }
    if (cards.length < 4) return;
    Navigator.of(context).push(
        _gameRoute(GuessScreen(cards: cards, ttsLocale: ttsLocale)));
  }

  void _openMemoryMatch(List<CardModel> allCards) {
    final playable = allCards.where((c) => c.image != null).toList();
    if (playable.length < 6) return;
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final pack = packs.firstWhere(
      (p) => !p.isLocked && !p.id.startsWith('_'),
      orElse: () => packs.first,
    );
    Navigator.of(context).push(
        _gameRoute(MemoryMatchScreen(pack: pack, cards: playable)));
  }

  static const _oddOneOutExclude = {
    'adjectives', 'actions', 'opposites', 'phrases', 'rozmovlyalky',
    'sound_r', 'sound_l', 'sound_sh', 'sound_s', 'sound_z',
    'sound_zh', 'sound_ch', 'sound_shch', 'sound_ts',
    'en_actions', 'en_opposites',
  };

  void _openOddOneOut(List<PackModel> packs) {
    final lang = ref.read(languageProvider);
    final playablePacks = packs
        .where((p) =>
            !p.id.startsWith('_') &&
            !p.isLocked &&
            !_oddOneOutExclude.contains(p.id) &&
            p.cards.length >= 4 &&
            (lang == 'en' ? p.cards.any((c) => c.image != null) : true))
        .toList();
    if (playablePacks.length < 2) return;
    Navigator.of(context).push(
        _gameRoute(OddOneOutScreen(packs: playablePacks)));
  }

  void _openRepeatGame(List<PackModel> packs) {
    // Repeat After Me asks the child to say a real word. Rozmovlyalky
    // ("розмовлялки") are babble-sound combos (ай / ба / ва) — not words, so
    // exclude them. Also require a webp illustration so the child has
    // something to anchor the word to visually.
    const excluded = {'rozmovlyalky'};
    final cards = packs
        .where((p) => !p.id.startsWith('_') && !excluded.contains(p.id))
        .expand((p) => p.cards)
        .where((c) => c.image != null)
        .toList();
    if (cards.length < 4) return;
    Navigator.of(context).push(_gameRoute(RepeatGameScreen(cards: cards)));
  }

  void _openArticulation() {
    Navigator.of(context).push(_gameRoute(const ArticulationScreen()));
  }

  void _openOppositeGame(List<PackModel> packs) {
    final isEn = ref.read(languageProvider) == 'en';
    final id = isEn ? 'en_opposites' : 'opposites';
    final oppPack = packs.where((p) => p.id == id).firstOrNull;
    if (oppPack == null || oppPack.cards.length < 4) return;
    Navigator.of(context)
        .push(_gameRoute(OppositeGameScreen(pack: oppPack)));
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(packsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(isEn ? 'Try again' : 'Спробувати ще раз'),
                ),
              ],
            ),
          ),
        ),
        data: (packs) {
          final allCards = packs.expand((p) => p.cards).toList();
          final playableCount = isEn
              ? allCards.where((c) => c.image != null).length
              : allCards.where((c) => c.audioKey != null).length;

          final toddlerGames = <_BigGame>[
            _BigGame(
              title: isEn ? 'Guess the word' : 'Вгадай звук',
              subtitle: isEn ? 'Listen and tap the card' : 'Слухай і тисни картку',
              color: DT.sky,
              bg: DT.skyTint,
              thumb: _pickThumb(allCards, skip: 0),
              badge: '🎧',
              onTap: playableCount >= 4 ? () => _openQuiz(allCards) : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
            _BigGame(
              title: isEn ? 'Find the pair' : 'Знайди пару',
              subtitle: isEn ? 'Flip cards, match pairs' : 'Відкривай і шукай пари',
              color: DT.mint,
              bg: DT.mintTint,
              thumb: _pickThumb(allCards, skip: 5),
              badge: '🧠',
              onTap: playableCount >= 6 ? () => _openMemoryMatch(allCards) : null,
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
              badge: '🫧',
              onTap: playableCount >= 5
                  ? () => Navigator.of(context)
                      .push(_gameRoute(const BubblePopScreen()))
                  : null,
              lockedHint: isEn
                  ? 'Open more cards in Packs first'
                  : 'Спочатку відкрий більше карток',
            ),
            _BigGame(
              title: isEn ? 'Repeat after me' : 'Повтори за мною',
              subtitle: isEn ? 'Say the word, grown-up taps' : 'Скажи слово, дорослий натискає',
              color: DT.peach,
              bg: DT.peachTint,
              thumb: _pickThumb(allCards, skip: 12),
              badge: '🎤',
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
              badge: '👅',
              onTap: _openArticulation,
              lockedHint: '',
            ),
          ];

          final advancedPacks = packs
              .where((p) =>
                  !p.id.startsWith('_') &&
                  !p.isLocked &&
                  !_oddOneOutExclude.contains(p.id) &&
                  p.cards.length >= 4 &&
                  (isEn ? p.cards.any((c) => c.image != null) : true))
              .toList();
          final oppPackId = isEn ? 'en_opposites' : 'opposites';
          final hasOpposites = packs
                  .where((p) => p.id == oppPackId)
                  .firstOrNull
                  ?.cards
                  .length ??
              0;
          final oppPack = packs.where((p) => p.id == oppPackId).firstOrNull;
          final advancedGames = <_BigGame>[
            _BigGame(
              title: isEn ? 'Odd one out' : 'Знайди зайве',
              subtitle: isEn ? 'Spot the different one' : 'Знайди не таке, як інші',
              color: DT.violet,
              bg: DT.violetTint,
              thumb: _pickThumb(allCards, skip: 20),
              badge: '🔍',
              onTap: advancedPacks.length >= 2
                  ? () => _openOddOneOut(packs)
                  : null,
              lockedHint: isEn
                  ? 'Open at least 2 packs to play'
                  : 'Відкрий хоча б 2 паки щоб грати',
            ),
            _BigGame(
              title: isEn ? 'Opposites' : 'Протилежності',
              subtitle: isEn ? 'Big↔small, hot↔cold' : 'Великий↔малий, тепло↔холод',
              color: DT.pink,
              bg: DT.pinkTint,
              thumb: oppPack != null ? _pickThumb(oppPack.cards) : null,
              badge: '↔️',
              onTap: hasOpposites >= 4 ? () => _openOppositeGame(packs) : null,
              lockedHint: isEn
                  ? 'Opposites pack is empty'
                  : 'Пак «Протилежності» порожній',
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
              _GameGrid(games: parentGames),
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
  final String badge; // emoji shown as small floating sticker
  final VoidCallback? onTap;
  final String lockedHint;

  _BigGame({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.thumb,
    required this.badge,
    required this.onTap,
    required this.lockedHint,
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
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(title, style: DT.h2.copyWith(fontSize: 19)),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: DT.caption.copyWith(fontSize: 13),
          ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: games.length,
      itemBuilder: (_, i) => _BigGameTile(game: games[i]),
    );
  }
}

class _BigGameTile extends StatefulWidget {
  final _BigGame game;
  const _BigGameTile({required this.game});

  @override
  State<_BigGameTile> createState() => _BigGameTileState();
}

class _BigGameTileState extends State<_BigGameTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final disabled = g.onTap == null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        if (disabled) {
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
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: g.bg,
              borderRadius: BorderRadius.circular(DT.rLg + 2),
              border: Border.all(
                color: g.color.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: DT.shadowSoft(g.color),
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
                            child: Center(
                              child: g.thumb?.image != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Image.asset(
                                        'assets/images/webp/${g.thumb!.image}.webp',
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Text(
                                      g.badge,
                                      style: const TextStyle(fontSize: 72),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      // Floating emoji badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
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
                          child: Text(g.badge,
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      if (disabled)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🔒',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Text area
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          style: DT.tileTitle.copyWith(color: g.color),
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
      ),
    );
  }
}
