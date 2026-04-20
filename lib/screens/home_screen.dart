import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/notification_service.dart';
import '../services/paywall_flow.dart';
import '../services/whatsnew_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../tabs/packs_tab.dart';
import '../tabs/games_tab.dart';
import 'coloring_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _showWelcomeIfNeeded();
    _maybeShowPaywallFromReminder();
  }

  /// If the app was cold-launched via the day-3 reminder notification AND the
  /// user is still on the free tier, surface the paywall after the welcome
  /// screen has settled. Single-shot per launch — flag is consumed here.
  Future<void> _maybeShowPaywallFromReminder() async {
    if (!NotificationService.instance.launchedFromPaywallReminder) return;
    NotificationService.instance.launchedFromPaywallReminder = false;
    if (ref.read(isProProvider)) return;
    // Let HomeScreen finish painting + welcome dialog dismiss; ~1.2s feels
    // natural and avoids stacking dialogs.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    await runPaywallFlow(context, ref);
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
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.4),
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          PacksTab(),
          GamesTab(),
          ColoringScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_rounded),
            label: s('Картки', 'Cards'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sports_esports_rounded),
            label: s('Ігри', 'Games'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.palette_rounded),
            label: s('Малюємо', 'Coloring'),
          ),
        ],
      ),
    );
  }
}
