import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../services/paywall_flow.dart';
import '../services/notification_service.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/parental_gate.dart';
import 'cards_screen.dart';
import 'guess_screen.dart';
import 'stats_screen.dart';

/// Category mapping: pack id → category name
const _packCategories = <String, String>{
  'rozmovlyalky': 'Мовлення',
  'animals': 'Світ навколо',
  'transport': 'Світ навколо',
  'home': 'Побут',
  'food': 'Побут',
  'emotions': 'Розвиток',
};

const _allCategories = ['Все', 'Мовлення', 'Світ навколо', 'Побут', 'Розвиток'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _showWelcomeIfNeeded();
  }

  Future<void> _showWelcomeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcome_shown') == true) return;
    await prefs.setBool('welcome_shown', true);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👋', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text(
                'Привіт!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Тут зібрані картки зі звуками для малят.\n\n'
                '👆 Натисни на картку — почуєш звук\n'
                '👈 Свайпни — наступна картка\n'
                '🔊 Звук вмикається автоматично',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.4),
              ),
              const SizedBox(height: 20),
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
                  child: const Text('Почнемо! 🎉',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext _) async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗣️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Картки-розмовлялки',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Версія ${info.version}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 16),
              Text(
                'Яскраві картки зі звуками для найменших. '
                'Слухай — вивчай — повторюй!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: const Text('Політика конфіденційності'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Підтримка'),
              ),
              const _NotificationToggle(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child:
                    Text('Закрити', style: TextStyle(color: Colors.grey[400])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPackTap(BuildContext context, PackModel pack) {
    if (pack.id == '_favorites' && pack.cards.isEmpty) {
      _showEmptyFavorites(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
    );
  }

  void _showEmptyFavorites(BuildContext context) {
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
            const Text(
              'Ой, тут ще порожньо!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Сподобалась картка? Натисни ❤️\nі вона з\'явиться тут!',
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
                child: const Text(
                  'До розділів',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuiz(List<CardModel> allCards) {
    final playable = allCards.where((c) => c.audioKey != null).toList();
    if (playable.length < 4) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuessScreen(cards: playable)),
    );
  }

  void _showCardOfDayPopup(CardModel card, bool isFromLockedPack) {
    AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    final isPro = ref.read(isProProvider);
    final isFav = ref.read(favoritesProvider).contains(card.id);

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
            // Mini card preview
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
                        'assets/images/png/${card.image}.png',
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
            // Listen button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => AudioService.instance
                    .speakCard(card.audioKey, card.sound, card.text),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Слухати ще раз',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
            // Add to favorites
            if (!isFav)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isFromLockedPack && !isPro) {
                      // Show upsell
                      Navigator.of(ctx).pop();
                      _showFavUpsell(card);
                    } else {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggle(card.id);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Додано в улюблені ❤️'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Додати в улюблені'),
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
                AudioService.instance.stop();
                Navigator.of(ctx).pop();
              },
              child: Text('Закрити',
                  style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    );
  }

  void _showFavUpsell(CardModel card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              'Сподобалась картка?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Оформи підписку і отримай доступ\nдо всіх карток та розділів!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  runPaywallFlow(context, ref);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Дізнатись більше',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Я подумаю',
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deterministic daily card based on date seed.
  /// Returns (card, isFromLockedPack).
  (CardModel, bool)? _cardOfTheDay(List<PackModel> packs) {
    final allCards = packs.expand((p) => p.cards).toList();
    if (allCards.isEmpty) return null;
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final card = allCards[Random(seed).nextInt(allCards.length)];
    final pack = packs.firstWhere((p) => p.cards.contains(card));
    return (card, pack.isLocked);
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

    return Scaffold(
      body: SafeArea(
        child: packsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Помилка: $e')),
          data: (packs) {
            final allCards = packs.expand((p) => p.cards).toList();
            final playableCount =
                allCards.where((c) => c.audioKey != null).length;
            final cotdResult = _cardOfTheDay(packs);
            final cotd = cotdResult?.$1;
            final cotdLocked = cotdResult?.$2 ?? false;
            final reviewCardIds =
                ref.watch(reviewProvider.notifier).reviewCardIds;

            // Virtual packs
            final favCards =
                allCards.where((c) => favorites.contains(c.id)).toList();
            final favoritesPack = PackModel(
              id: '_favorites',
              title: 'Улюблені',
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
                  title: 'Повторення',
                  icon: '🔄',
                  color: const Color(0xFF45B7D1),
                  isLocked: false,
                  isFree: true,
                  cards: reviewCards,
                );
              }
            }

            // Filter by category
            final filteredPacks = _selectedCategory == 'Все'
                ? packs
                : packs
                    .where(
                        (p) => _packCategories[p.id] == _selectedCategory)
                    .toList();

            // Build grid items
            final gridItems = <_GridItem>[];
            const favPosition = 2;
            const quizPosition = 5;
            for (int i = 0; i < filteredPacks.length; i++) {
              if (_selectedCategory == 'Все') {
                if (i == favPosition) {
                  gridItems.add(_GridItem.pack(favoritesPack));
                }
                if (i == quizPosition && playableCount >= 4) {
                  gridItems.add(_GridItem.quiz(allCards));
                }
              }
              gridItems.add(_GridItem.pack(filteredPacks[i]));
            }
            if (_selectedCategory == 'Все') {
              if (filteredPacks.length <= favPosition) {
                gridItems.add(_GridItem.pack(favoritesPack));
              }
              if (filteredPacks.length <= quizPosition &&
                  playableCount >= 4) {
                gridItems.add(_GridItem.quiz(allCards));
              }
              if (reviewPack != null) {
                gridItems.add(_GridItem.pack(reviewPack));
              }
            }

            return Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.only(top: 12, left: 12, right: 12),
                  child: Row(
                    children: [
                      IconButton(
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
                      IconButton(
                        icon: Icon(Icons.info_outline_rounded,
                            color: Colors.grey[400], size: 26),
                        onPressed: () => _showAbout(context),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '🗣️ Картки-розмовлялки',
                  style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),

                // Subtitle with inline streak
                _buildSubtitle(
                    packs.length, completedPacks.length, streak.currentStreak),

                // Card of the Day — compact inline row
                if (cotd != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _CardOfDayButton(
                      card: cotd,
                      onTap: () => _showCardOfDayPopup(cotd, cotdLocked),
                    ),
                  ),

                const SizedBox(height: 8),

                // Category filter chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _allCategories[index];
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
                            Colors.grey.withValues(alpha: 0.1),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: gridItems.length,
                    itemBuilder: (context, index) {
                      final item = gridItems[index];
                      if (item.isQuiz) {
                        return _QuizGridCard(
                            onTap: () => _openQuiz(item.quizCards!));
                      }
                      final pack = item.pack!;
                      return PackGridCard(
                        pack: pack,
                        isCompleted: completedPacks.contains(pack.id),
                        progress: packProgress[pack.id] ?? 0,
                        onTap: () => _onPackTap(context, pack),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubtitle(int total, int done, int streak) {
    if (done == 0 && streak <= 1) {
      return Text(
        'Обери розділ і почнемо!',
        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
      );
    }
    final parts = <String>[];
    if (done > 0) parts.add('Розділів пройдено $done/$total');
    if (streak > 1) parts.add('🔥 $streak дн.');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parts.join(' · '),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: kStreakOrange,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
        ],
      ),
    );
  }
}

class _GridItem {
  final PackModel? pack;
  final List<CardModel>? quizCards;
  bool get isQuiz => quizCards != null;

  _GridItem.pack(PackModel p) : pack = p, quizCards = null;
  _GridItem.quiz(List<CardModel> cards) : pack = null, quizCards = cards;
}

class _CardOfDayButton extends StatefulWidget {
  final CardModel card;
  final VoidCallback onTap;

  const _CardOfDayButton({required this.card, required this.onTap});

  @override
  State<_CardOfDayButton> createState() => _CardOfDayButtonState();
}

class _CardOfDayButtonState extends State<_CardOfDayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.card.colorAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.card.colorAccent.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Text(widget.card.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Картка дня',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.card.colorAccent,
                      ),
                    ),
                    Text(
                      widget.card.sound,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            widget.card.colorAccent.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  size: 22,
                  color: widget.card.colorAccent.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizGridCard extends StatelessWidget {
  final VoidCallback onTap;

  const _QuizGridCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: kAccent.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'pack_icon_quiz',
              child: Material(
                color: Colors.transparent,
                child: Text('🎧', style: TextStyle(fontSize: 44)),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Вгадай звук',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kAccent,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Вікторина',
              style: TextStyle(fontSize: 12, color: kAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatefulWidget {
  const _NotificationToggle();

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await NotificationService.instance.isEnabled;
    if (mounted) setState(() { _enabled = enabled; _loaded = true; });
  }

  Future<void> _toggle() async {
    final passed = await ParentalGate.show(context);
    if (!passed || !mounted) return;
    final newValue = !_enabled;
    await NotificationService.instance.setEnabled(newValue);
    if (mounted) setState(() => _enabled = newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _enabled
            ? Icons.notifications_active
            : Icons.notifications_off_outlined,
        size: 18,
      ),
      label:
          Text(_enabled ? 'Сповіщення увімкнено' : 'Увімкнути сповіщення'),
    );
  }
}
