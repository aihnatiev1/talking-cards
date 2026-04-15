import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/parent_auth_provider.dart';
import '../providers/seasonal_packs_provider.dart';
import '../providers/srs_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/whatsnew_service.dart';
import '../services/widget_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../services/paywall_flow.dart';
import '../services/notification_service.dart';
import '../widgets/pack_grid_card.dart';
import '../widgets/parental_gate.dart';
import '../widgets/profile_avatar_chip.dart';
import 'cards_screen.dart';
import 'guess_screen.dart';
import 'memory_match_screen.dart';
import 'articulation_screen.dart';
import 'odd_one_out_screen.dart';
import 'plural_game_screen.dart';
import 'opposite_game_screen.dart';
import 'repeat_game_screen.dart';
import 'rhyme_game_screen.dart';
import 'sort_game_setup_screen.dart';
import 'sound_filter_screen.dart';
import 'sound_position_screen.dart';
import 'syllable_game_screen.dart';
import 'parent_dashboard_screen.dart';
import 'parent_pin_screen.dart';
import 'quest_map_screen.dart';
import 'stats_screen.dart';

/// Category mapping: pack id → category name (Ukrainian)
const _packCategoriesUk = <String, String>{
  'rozmovlyalky': 'Мовлення',
  'animals': 'Світ навколо',
  'transport': 'Світ навколо',
  'home': 'Побут',
  'food': 'Побут',
  'emotions': 'Розвиток',
  'colors': 'Розвиток',
  'body': 'Розвиток',
  'phrases': 'Мовлення',
  'actions': 'Розвиток',
  'opposites': 'Розвиток',
  'adjectives': 'Розвиток',
  'sound_r': 'Звуки',
  'sound_l': 'Звуки',
  'sound_sh': 'Звуки',
  'sound_s': 'Звуки',
  'sound_z': 'Звуки',
  'sound_zh': 'Звуки',
  'sound_ch': 'Звуки',
  'sound_shch': 'Звуки',
  'sound_ts': 'Звуки',
};

/// Category mapping for English packs
const _packCategoriesEn = <String, String>{
  'en_animals': 'Nature',
  'en_home': 'Home',
  'en_emotions': 'Feelings',
  'en_transport': 'Transport',
  'en_food': 'Food',
  'en_colors': 'Learning',
  'en_body': 'Learning',
  'en_actions': 'Learning',
  'en_opposites': 'Learning',
};

const _allCategoriesUk = ['Все', 'Мовлення', 'Світ навколо', 'Побут', 'Розвиток', 'Звуки'];
const _allCategoriesEn = ['All', 'Nature', 'Home', 'Feelings', 'Transport', 'Food', 'Learning'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Static so the category persists when user navigates into a pack and returns
  static String _lastCategory = '';
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = _lastCategory;
    _showWelcomeIfNeeded();
  }

  Future<void> _showWelcomeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcome_shown') == true) {
      // Existing user — show "What's New" instead of welcome
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) WhatsNewService.instance.showIfNeeded(context);
      }
      return;
    }
    await prefs.setBool('welcome_shown', true);
    if (!mounted) return;

    final s = AppS(ref.read(languageProvider) == 'en');
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
              Text(
                s('Привіт!', 'Hello!'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                s(
                  'Тут зібрані картки зі звуками для малят.\n\n'
                  '👆 Натисни на картку — почуєш звук\n'
                  '👈 Свайпни — наступна картка\n'
                  '🔊 Звук вмикається автоматично',
                  'Flash cards with words for little ones.\n\n'
                  '👆 Tap a card — hear the word\n'
                  '👈 Swipe — next card\n'
                  '🔊 Sound plays automatically',
                ),
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
                  child: Text(s("Почнемо! 🎉", "Let's go! 🎉"),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openParentArea(BuildContext context) async {
    final notifier = ref.read(parentAuthProvider.notifier);
    final hasPin = await notifier.hasPin();
    final isAuthenticated = ref.read(parentAuthProvider);
    if (!mounted) return;
    if (isAuthenticated) {
      // Already authenticated this session — skip PIN
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => const ParentDashboardScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentPinScreen(isSetup: !hasPin),
      ),
    );
  }

  void _showAbout(BuildContext _) async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🗣️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                s('Картки-розмовлялки', 'Talking Cards'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(s('Версія ${info.version}', 'Version ${info.version}'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 16),
              Text(
                s(
                  'Яскраві картки зі звуками для найменших. '
                  'Слухай — вивчай — повторюй!',
                  'Flash cards with sounds for little ones. '
                  'Listen — learn — repeat!',
                ),
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  launchUrl(
                    Uri.parse('https://aihnatiev1.github.io/talking-cards/privacy-policy.html'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: Text(s('Політика конфіденційності', 'Privacy Policy')),
              ),
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('mailto:skillar.app@gmail.com');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri);
                  } else if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('skillar.app@gmail.com')),
                    );
                  }
                },
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(s('Підтримка', 'Support')),
              ),
              const _NotificationToggle(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openParentArea(context);
                },
                icon: const Icon(Icons.family_restroom, size: 18),
                label: Text(s('Батьківський режим', 'Parent area')),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s('Закрити', 'Close'),
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                ),
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
    // Opening any pack counts as reviewing for the quest
    if (pack.id == '_review' || !pack.id.startsWith('_')) {
      ref
          .read(dailyQuestProvider.notifier)
          .completeTask(QuestTask.reviewOldCard);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardsScreen(pack: pack)),
    );
  }

  void _showEmptyFavorites(BuildContext context) {
    final fs = AppS(ref.read(languageProvider) == 'en');
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
            Text(
              fs('Ой, тут ще порожньо!', 'Nothing here yet!'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fs('Сподобалась картка? Натисни ❤️\nі вона з\'явиться тут!',
                  'Liked a card? Tap ❤️\nand it will appear here!'),
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
                child: Text(
                  fs('До розділів', 'Go to packs'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reward picker moved to QuestMapScreen

  /// Smooth fade+scale transition for games — avoids the jarring iOS slide.
  Route<T> _gameRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
              parent: animation, curve: Curves.easeOut);
          final scale = Tween<double>(begin: 0.93, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
              opacity: fade, child: ScaleTransition(scale: scale, child: child));
        },
      );

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
        : allCards.where((c) => c.audioKey != null).toList();
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

  void _openOddOneOut(List<PackModel> packs) {
    final lang = ref.read(languageProvider);
    final playablePacks = packs
        .where((p) =>
            !p.id.startsWith('_') &&
            !p.isLocked &&
            p.cards.length >= 3 &&
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
    Navigator.of(context)
        .push(_gameRoute(const SoundPositionSetupScreen()));
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

  void _showCardOfDayPopup(CardModel card, bool isFromLockedPack) {
    AnalyticsService.instance.logCardOfDayTap(card.id);
    AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    final isPro = ref.read(isProProvider);
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
                        'assets/images/webp/${card.image}.webp',
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
                label: Text(ps('Слухати ще раз', 'Listen again'),
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
                        SnackBar(
                          content: Text(ps('Додано в улюблені ❤️', 'Added to favorites ❤️')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.favorite_border),
                  label: Text(ps('Додати в улюблені', 'Add to favorites')),
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
                Navigator.of(ctx).pop();
              },
              child: Text(ps('Закрити', 'Close'),
                  style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      AudioService.instance.stop();
    });
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
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    // Scale factor relative to a 375pt-wide reference device (iPhone SE/8)
    final scale = (screenWidth / 375).clamp(0.85, 1.3);

    return Scaffold(
      body: packsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (packs) {
            final allCards = packs.expand((p) => p.cards).toList();
            final isEnMode = ref.read(languageProvider) == 'en';
            final s = AppS(isEnMode);
            final packCategories = isEnMode ? _packCategoriesEn : _packCategoriesUk;
            final allCategories = isEnMode ? _allCategoriesEn : _allCategoriesUk;
            // Reset selected category when language changes
            if (_selectedCategory.isEmpty ||
                !allCategories.contains(_selectedCategory)) {
              Future.microtask(() =>
                  setState(() => _selectedCategory = allCategories.first));
            }
            // EN cards have no audioKey — use image presence instead
            final playableCount = isEnMode
                ? allCards.where((c) => c.image != null).length
                : allCards.where((c) => c.audioKey != null).length;
            final cotdResult = _cardOfTheDay(packs);
            final cotd = cotdResult?.$1;
            final cotdLocked = cotdResult?.$2 ?? false;
            if (cotd != null) {
              WidgetService.instance.updateCardOfDay(cotd);
            }
            final reviewCardIds =
                ref.watch(reviewProvider.notifier).reviewCardIds;

            // Virtual packs
            final favCards =
                allCards.where((c) => favorites.contains(c.id)).toList();
            final favoritesPack = PackModel(
              id: '_favorites',
              title: s('Улюблені', 'Favorites'),
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
                  title: s('Повторення', 'Review'),
                  icon: '🔄',
                  color: const Color(0xFF45B7D1),
                  isLocked: false,
                  isFree: true,
                  cards: reviewCards,
                );
              }
            }

            // Filter by category
            final isAllCategory = _selectedCategory == allCategories.first;
            final filteredPacks = isAllCategory
                ? packs
                : packs
                    .where((p) => packCategories[p.id] == _selectedCategory)
                    .toList();

            // Build grid items
            final gridItems = <_GridItem>[];
            const favPosition = 2;
            for (int i = 0; i < filteredPacks.length; i++) {
              if (isAllCategory && i == favPosition) {
                gridItems.add(_GridItem.pack(favoritesPack));
              }
              gridItems.add(_GridItem.pack(filteredPacks[i]));
            }
            if (isAllCategory) {
              if (filteredPacks.length <= favPosition) {
                gridItems.add(_GridItem.pack(favoritesPack));
              }
              if (reviewPack != null) {
                gridItems.add(_GridItem.pack(reviewPack));
              }
            }

            // Inject seasonal packs as highlighted first items in the grid
            if (isAllCategory) {
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

            return Column(
              children: [
                // Status bar spacing (replaces SafeArea top)
                SizedBox(height: topPadding),
                // Top bar
                Padding(
                  padding:
                      EdgeInsets.only(top: 4 * scale, left: 12, right: 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: isDark
                            ? s('Світла тема', 'Light theme')
                            : s('Темна тема', 'Dark theme'),
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
                      const ProfileAvatarChip(),
                      GestureDetector(
                        onLongPress: () => _openParentArea(context),
                        child: IconButton(
                          tooltip: s('Про додаток', 'About'),
                          icon: Icon(Icons.info_outline_rounded,
                              color: Colors.grey[400], size: 26),
                          onPressed: () => _showAbout(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  s('🗣️ Картки-розмовлялки', '🗣️ Talking Cards'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6 * scale),

                // Subtitle with inline streak
                _buildSubtitle(
                    packs.length, completedPacks.length, streak.currentStreak,
                    packProgress.values.fold(0, (a, b) => a + b)),

                // Hero section: Card of Day + Daily Quest
                // IntrinsicHeight equalises card heights; stretch fills them.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cotd != null)
                        Expanded(
                          child: _CardOfDayHero(
                            card: cotd,
                            isEn: isEnMode,
                            onTap: () {
                              _showCardOfDayPopup(cotd, cotdLocked);
                              ref
                                  .read(dailyQuestProvider.notifier)
                                  .completeTask(QuestTask.listenCardOfDay);
                            },
                          ),
                        ),
                      if (cotd != null) const SizedBox(width: 10),
                      Expanded(
                        child: _DailyQuestHero(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => QuestMapScreen(
                                  cardOfDay: cotd,
                                  cardOfDayLocked: cotdLocked,
                                  onCardOfDayTap: () {
                                    if (cotd != null) {
                                      _showCardOfDayPopup(cotd, cotdLocked);
                                      ref
                                          .read(dailyQuestProvider.notifier)
                                          .completeTask(
                                              QuestTask.listenCardOfDay);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )),
                ),

                // SRS review banner — shown when cards are due (near "today" hero)
                _SrsReviewBanner(
                  allCards: allCards,
                  onTap: (cards) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuessScreen(
                        cards: cards,
                        ttsLocale: isEnMode ? 'en-US' : null,
                      ),
                    ),
                  ),
                ),

                // Games section
                _GamesSection(
                  playableCount: playableCount,
                  hasSortGame: packs
                          .where((p) =>
                              !p.id.startsWith('_') &&
                              !p.isLocked &&
                              p.cards.length >= 3)
                          .length >=
                      2,
                  onQuiz: () => _openQuiz(allCards),
                  onMemory: () => _openMemoryMatch(allCards),
                  onSort: () => _openSortGame(packs),
                  onOddOneOut: () => _openOddOneOut(packs),
                  onRepeat: () => _openRepeatGame(allCards),
                  onSyllable: () => _openSyllableGame(allCards),
                  onOpposite: () => _openOppositeGame(packs),
                  onSoundFilter: _openSoundFilter,
                  onSoundPosition: _openSoundPosition,
                  onRhyme: _openRhymeGame,
                  onArticulation: _openArticulation,
                  onPlural: _openPluralGame,
                ),

                const SizedBox(height: 8),

                // Category filter chips
                SizedBox(
                  height: 38,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment(0.85, 0),
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.transparent],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = allCategories[index];
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
                            Colors.grey.withValues(alpha: 0.18),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => setState(() {
                          _selectedCategory = cat;
                          _lastCategory = cat;
                        }),
                      );
                    },
                  ),
                  ),
                ),

                const SizedBox(height: 8),

                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16 * scale, vertical: 4),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12 * scale,
                      crossAxisSpacing: 12 * scale,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: gridItems.length,
                    itemBuilder: (context, index) {
                      final item = gridItems[index];
                      final pack = item.pack;
                      return PackGridCard(
                        key: ValueKey(pack.id),
                        pack: pack,
                        isCompleted: completedPacks.contains(pack.id),
                        progress: packProgress[pack.id] ?? 0,
                        isSeasonal: item.isSeasonal,
                        onTap: () => _onPackTap(context, pack),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
    );
  }

  Widget _buildSubtitle(int total, int done, int streak, int totalViewed) {
    final s = AppS(ref.read(languageProvider) == 'en');
    if (done == 0 && streak <= 1 && totalViewed == 0) {
      return Text(
        s('Почни і побачиш свій прогрес тут!',
            'Start learning and track your progress here!'),
        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (streak > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kStreakOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                s('🔥 $streak дн.', '🔥 $streak days'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kStreakOrange,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            done > 0
                ? s('⭐ $done/$total розділів', '⭐ $done/$total packs')
                : s('🃏 Переглянуто $totalViewed карток',
                    '🃏 Viewed $totalViewed cards'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
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
  final PackModel pack;
  final bool isSeasonal;
  _GridItem.pack(this.pack, {this.isSeasonal = false});
}

/// Shared card shell used by Card of Day, Daily Quest and game buttons.
/// Provides consistent: gradient bg, colored border, soft shadow, radius-16.
class _AppCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  const _AppCard({
    required this.color,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: constraints,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _CardOfDayHero extends StatefulWidget {
  final CardModel card;
  final VoidCallback onTap;
  final bool isEn;

  const _CardOfDayHero(
      {required this.card, required this.onTap, this.isEn = false});

  @override
  State<_CardOfDayHero> createState() => _CardOfDayHeroState();
}

class _CardOfDayHeroState extends State<_CardOfDayHero>
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
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
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
    final accent = widget.card.colorAccent;
    return ScaleTransition(
      scale: _scale,
      child: _AppCard(
        color: accent,
        onTap: widget.onTap,
        constraints: const BoxConstraints(minHeight: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge — always at top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isEn ? '🔊 Card of the day' : '🔊 Картка дня',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            // Emoji + word centred in remaining space
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.card.emoji,
                        style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.card.sound,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyQuestHero extends ConsumerWidget {
  final VoidCallback onTap;

  const _DailyQuestHero({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(dailyQuestProvider);
    final done = quest.doneCount;
    final total = quest.totalCount;
    final allDone = quest.allDone;
    final claimed = quest.rewardClaimed;
    final s = AppS(ref.watch(languageProvider) == 'en');

    final Color accentColor;
    if (claimed) {
      accentColor = Colors.green[600]!;
    } else if (allDone) {
      accentColor = kAccent;
    } else {
      accentColor = Colors.orange[700]!;
    }

    return _AppCard(
      color: accentColor,
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: 110),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Badge + counter ──────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    claimed
                        ? s('✨ Зроблено', '✨ Done')
                        : (allDone
                            ? s('🎉 Готово!', '🎉 Done!')
                            : s('🎯 Завдання', '🎯 Tasks')),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$done/$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // ── Progress bar ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? done / total : 0,
                minHeight: 5,
                backgroundColor: Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            // ── Main content fills remaining height ──────
            Expanded(
              child: Center(
                child: claimed
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(s('🎁 Скарб знайдено!', '🎁 Treasure found!'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            )),
                      )
                    : allDone
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(s('🎁 Забери скарб!', '🎁 Claim reward!'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                )),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: QuestTask.values
                                    .take(quest.totalCount)
                                    .map((task) {
                                  final isDone =
                                      quest.completed.contains(task);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDone
                                            ? Colors.orange
                                            : Colors.orange
                                                .withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: isDone
                                              ? Colors.orange
                                              : Colors.orange
                                                  .withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isDone
                                          ? const Icon(Icons.check,
                                              size: 10,
                                              color: Colors.white)
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  s('Відкрий карту 🗺️', 'Open map 🗺️'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
    );
  }
}

// ─────────────────────────────────────────────
//  Games section
// ─────────────────────────────────────────────

class _GamesSection extends ConsumerWidget {
  final int playableCount;
  final bool hasSortGame;
  final VoidCallback onQuiz;
  final VoidCallback onMemory;
  final VoidCallback onSort;
  final VoidCallback onOddOneOut;
  final VoidCallback onRepeat;
  final VoidCallback onSyllable;
  final VoidCallback onOpposite;
  final VoidCallback onSoundFilter;
  final VoidCallback onSoundPosition;
  final VoidCallback onRhyme;
  final VoidCallback onArticulation;
  final VoidCallback onPlural;

  const _GamesSection({
    required this.playableCount,
    required this.hasSortGame,
    required this.onQuiz,
    required this.onMemory,
    required this.onSort,
    required this.onOddOneOut,
    required this.onRepeat,
    required this.onSyllable,
    required this.onOpposite,
    required this.onSoundFilter,
    required this.onSoundPosition,
    required this.onRhyme,
    required this.onArticulation,
    required this.onPlural,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (playableCount < 4) return const SizedBox.shrink();
    final isEn = ref.watch(languageProvider) == 'en';

    final games = [
      (emoji: '🎧', uk: 'Вгадай\nзвук',     en: 'Guess\nword',    color: kAccent,                      tap: onQuiz),
      (emoji: '🧠', uk: 'Знайди\nпару',      en: 'Find\npair',     color: kTeal,                         tap: playableCount >= 6 ? onMemory : null),
      (emoji: '🗂️',uk: 'По\nкупках',       en: 'Sort\nit!',      color: const Color(0xFFFF8C42),       tap: hasSortGame ? onSort : null),
      (emoji: '🔍', uk: 'Знайди\nзайве',     en: 'Odd\none out',   color: const Color(0xFF7B61FF),       tap: hasSortGame ? onOddOneOut : null),
      (emoji: '🎤', uk: 'Повтори\nза мною',  en: 'Repeat\nme',     color: const Color(0xFF00BFA5),       tap: onRepeat),
      (emoji: '🥁', uk: 'Рахуй\nсклади',     en: 'Count\nsyllables',color: const Color(0xFFE91E8C),      tap: onSyllable),
      (emoji: '↔️', uk: 'Протилеж-\nності', en: 'Opposites',      color: const Color(0xFF8E44AD),       tap: onOpposite),
      (emoji: '🔤', uk: 'За\nзвуком',        en: 'By\nsound',      color: const Color(0xFF00897B),       tap: onSoundFilter),
      (emoji: '🎵', uk: 'Знайди\nриму',      en: 'Find\nrhyme',    color: const Color(0xFFE91E8C),       tap: onRhyme),
      (emoji: '🎯', uk: 'Де живе\nзвук?',   en: 'Sound\npos.',    color: const Color(0xFF1565C0),       tap: onSoundPosition),
      (emoji: '👅', uk: 'Гімнас-\nтика',    en: 'Articul.',       color: const Color(0xFF6A1B9A),       tap: onArticulation),
      (emoji: '1️⃣',uk: 'Один —\nБагато',   en: 'One —\nMany',    color: const Color(0xFF00897B),       tap: onPlural),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            isEn ? '🎮 Games' : '🎮 Ігри',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kAccent,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final g = games[i];
              return _GameChip(
                emoji: g.emoji,
                label: isEn ? g.en : g.uk,
                color: g.color,
                onTap: g.tap,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Compact chip for horizontal scroll ──────────────────────────
class _GameChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _GameChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 82,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.30),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Full-size button (kept for potential future use) ─────────────
class _GameButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _GameButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: _AppCard(
        color: color,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _SeasonalPacksRow removed — seasonal packs are now injected
// directly as the first items in the pack grid (see gridItems builder)

// ─────────────────────────────────────────────
//  SRS review banner
// ─────────────────────────────────────────────

class _SrsReviewBanner extends ConsumerWidget {
  final List<CardModel> allCards;
  final void Function(List<CardModel>) onTap;

  const _SrsReviewBanner({required this.allCards, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srs = ref.watch(srsProvider);
    if (srs.dueCount == 0) return const SizedBox.shrink();
    final s = AppS(ref.watch(languageProvider) == 'en');

    // Resolve due CardModels from the full cards list
    final dueCards = allCards
        .where((c) => srs.dueIds.contains(c.id) && c.audioKey != null)
        .take(20) // cap at 20 per session
        .toList();
    if (dueCards.isEmpty) return const SizedBox.shrink();

    const color = Color(0xFF00BCD4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: () => onTap(dueCards),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            children: [
              const Text('🔁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s('Повторити сьогодні', 'Review today'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      s('${dueCards.length} карток чекають',
                          '${dueCards.length} cards waiting'),
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class _NotificationToggle extends ConsumerStatefulWidget {
  const _NotificationToggle();

  @override
  ConsumerState<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends ConsumerState<_NotificationToggle> {
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
      label: Builder(builder: (_) {
        final s = AppS(ref.read(languageProvider) == 'en');
        return Text(_enabled
            ? s('Сповіщення увімкнено', 'Notifications on')
            : s('Увімкнути сповіщення', 'Enable notifications'));
      }),
    );
  }
}
