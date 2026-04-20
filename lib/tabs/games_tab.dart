import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../screens/articulation_screen.dart';
import '../screens/guess_screen.dart';
import '../screens/memory_match_screen.dart';
import '../screens/odd_one_out_screen.dart';
import '../screens/opposite_game_screen.dart';
import '../screens/plural_game_screen.dart';
import '../screens/repeat_game_screen.dart';
import '../screens/rhyme_game_screen.dart';
import '../screens/sort_game_setup_screen.dart';
import '../screens/sound_filter_screen.dart';
import '../screens/sound_position_screen.dart';
import '../screens/syllable_game_screen.dart';
import '../services/paywall_flow.dart';
import '../utils/constants.dart';

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
    final lang = ref.read(languageProvider);
    final playable = lang == 'en'
        ? allCards.where((c) => c.image != null).toList()
        : allCards.where((c) => c.image != null).toList(); // images required
    if (playable.length < 6) return;
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final pack = packs.firstWhere(
      (p) => !p.isLocked && !p.id.startsWith('_'),
      orElse: () => packs.first,
    );
    Navigator.of(context).push(
        _gameRoute(MemoryMatchScreen(pack: pack, cards: playable)));
  }

  void _openSortGame(List<PackModel> packs) {
    final lang = ref.read(languageProvider);
    final playablePacks = packs
        .where((p) =>
            !p.id.startsWith('_') &&
            !p.isLocked &&
            p.cards.length >= 3 &&
            (lang == 'en'
                ? p.cards.any((c) => c.image != null)
                : p.cards.any((c) => c.audioKey != null)))
        .toList();
    if (playablePacks.length < 2) return;
    Navigator.of(context).push(
        _gameRoute(SortGameSetupScreen(packs: playablePacks)));
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

  void _openRepeatGame(List<CardModel> allCards) {
    final lang = ref.read(languageProvider);
    final cards = lang == 'en'
        ? allCards.where((c) => c.image != null).toList()
        : allCards;
    if (cards.length < 4) return;
    Navigator.of(context).push(_gameRoute(RepeatGameScreen(cards: cards)));
  }

  void _openSoundFilter() {
    Navigator.of(context).push(_gameRoute(const SoundFilterScreen()));
  }

  void _openSoundPosition() {
    Navigator.of(context).push(_gameRoute(const SoundPositionSetupScreen()));
  }

  void _openRhymeGame() {
    Navigator.of(context).push(_gameRoute(const RhymeGameScreen()));
  }

  void _openArticulation() {
    Navigator.of(context).push(_gameRoute(const ArticulationScreen()));
  }

  void _openPluralGame() {
    Navigator.of(context).push(_gameRoute(const PluralGameScreen()));
  }

  void _openOppositeGame(List<PackModel> packs) {
    final oppPack = packs.where((p) => p.id == 'opposites').firstOrNull;
    if (oppPack == null || oppPack.cards.length < 4) return;
    Navigator.of(context)
        .push(_gameRoute(OppositeGameScreen(pack: oppPack)));
  }

  void _openSyllableGame(List<CardModel> allCards) {
    const vowels = {'А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я'};
    final cards = allCards
        .where((c) =>
            !c.sound.contains('-') &&
            c.sound.toUpperCase().split('').any(vowels.contains))
        .toList();
    if (cards.length < 4) return;
    Navigator.of(context).push(_gameRoute(SyllableGameScreen(cards: cards)));
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(packsProvider);
    final isEn = ref.watch(languageProvider) == 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(isEn ? '🎮 Games' : '🎮 Ігри'),
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
          final hasSortGame = packs
                  .where((p) =>
                      !p.id.startsWith('_') &&
                      !p.isLocked &&
                      p.cards.length >= 3)
                  .length >=
              2;

          final lockedHintCards = isEn
              ? 'Open more cards in Packs first'
              : 'Спочатку відкрий більше карток у Картках';
          final lockedHintPacks = isEn
              ? 'Open at least 2 packs to play'
              : 'Відкрий хоча б 2 паки щоб грати';

          final games = [
            // FREE — showcase core value (audio guess, memory, articulation).
            (
              emoji: '🎧',
              uk: 'Вгадай\nзвук',
              en: 'Guess\nword',
              color: kAccent,
              tap: playableCount >= 4 ? () => _openQuiz(allCards) : null,
              lockedHint: lockedHintCards,
              isPaid: false,
            ),
            (
              emoji: '🧠',
              uk: 'Знайди\nпару',
              en: 'Find\npair',
              color: kTeal,
              tap: playableCount >= 6 ? () => _openMemoryMatch(allCards) : null,
              lockedHint: lockedHintCards,
              isPaid: false,
            ),
            (
              emoji: '👅',
              uk: 'Гімнас-\nтика',
              en: 'Articul.',
              color: const Color(0xFF6A1B9A),
              tap: () => _openArticulation(),
              lockedHint: '',
              isPaid: false,
            ),
            // PAID — therapeutic / advanced learning behind paywall.
            (
              emoji: '🗂️',
              uk: 'По\nкупках',
              en: 'Sort\nit!',
              color: const Color(0xFFFF8C42),
              tap: hasSortGame ? () => _openSortGame(packs) : null,
              lockedHint: lockedHintPacks,
              isPaid: true,
            ),
            (
              emoji: '🔍',
              uk: 'Знайди\nзайве',
              en: 'Odd\none out',
              color: const Color(0xFF7B61FF),
              tap: hasSortGame ? () => _openOddOneOut(packs) : null,
              lockedHint: lockedHintPacks,
              isPaid: true,
            ),
            (
              emoji: '🎤',
              uk: 'Повтори\nза мною',
              en: 'Repeat\nme',
              color: const Color(0xFF00BFA5),
              tap: playableCount >= 4 ? () => _openRepeatGame(allCards) : null,
              lockedHint: lockedHintCards,
              isPaid: true,
            ),
            (
              emoji: '🥁',
              uk: 'Рахуй\nсклади',
              en: 'Count\nsyllables',
              color: const Color(0xFFE91E8C),
              tap: playableCount >= 4 ? () => _openSyllableGame(allCards) : null,
              lockedHint: lockedHintCards,
              isPaid: true,
            ),
            (
              emoji: '↔️',
              uk: 'Протилеж-\nності',
              en: 'Opposites',
              color: const Color(0xFF8E44AD),
              tap: () => _openOppositeGame(packs),
              lockedHint: '',
              isPaid: true,
            ),
            (
              emoji: '🔤',
              uk: 'За\nзвуком',
              en: 'By\nsound',
              color: const Color(0xFF00897B),
              tap: () => _openSoundFilter(),
              lockedHint: '',
              isPaid: true,
            ),
            (
              emoji: '🎵',
              uk: 'Знайди\nриму',
              en: 'Find\nrhyme',
              color: const Color(0xFFE91E8C),
              tap: () => _openRhymeGame(),
              lockedHint: '',
              isPaid: true,
            ),
            (
              emoji: '🎯',
              uk: 'Де живе\nзвук?',
              en: 'Sound\npos.',
              color: const Color(0xFF1565C0),
              tap: () => _openSoundPosition(),
              lockedHint: '',
              isPaid: true,
            ),
            (
              emoji: '1️⃣',
              uk: 'Один —\nБагато',
              en: 'One —\nMany',
              color: const Color(0xFF00897B),
              tap: () => _openPluralGame(),
              lockedHint: '',
              isPaid: true,
            ),
          ];

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: games.length,
            itemBuilder: (context, i) {
              final g = games[i];
              final disabled = g.tap == null;
              final isPro = ref.watch(isProProvider);
              final locked = g.isPaid && !isPro;

              void handleTap() {
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
                if (locked) {
                  runPaywallFlow(context, ref);
                  return;
                }
                g.tap?.call();
              }

              return AnimatedOpacity(
                opacity: disabled ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: GestureDetector(
                  onTap: handleTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: g.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: g.color.withValues(alpha: 0.30),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(g.emoji, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 4),
                              Text(
                                isEn ? g.en : g.uk,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: g.color,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (disabled)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Text('🔒', style: TextStyle(fontSize: 14)),
                          )
                        else if (locked)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '💎',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
