import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import '../services/paywall_flow.dart';
import '../services/analytics_service.dart';
import '../services/whatsnew_service.dart';
import '../utils/app_startup.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/notification_opt_in_dialog.dart';
import '../widgets/parental_gate.dart';
import 'parent_dashboard_screen.dart';
import '../tabs/packs_tab.dart';
import '../tabs/games_tab.dart';
import 'coloring_screen.dart';
import '../widgets/kid_tap.dart';

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
    _logAppReadyOnce();
    _runFirstFrameFlow();
    _maybeShowPaywallFromReminder();
    _maybeOpenTrialReport();
  }

  /// Greeting first, then the notification ask — in that order, and for
  /// returning users too. Reminders are the only thing that brings a parent
  /// back on day two, and `notification_opened` was 0 across 60 days because
  /// most of the base never granted permission.
  Future<void> _runFirstFrameFlow() async {
    await _showWelcomeIfNeeded();
    if (!mounted) return;
    // Not in the first session: the child has just tapped three cards and
    // the parent has just closed the paywall — a permission ask here was the
    // fifth modal before the first real card (audit #5). The next launch is
    // a parent who came back on purpose; that is when to ask.
    if (AppStartup.viaOnboarding) return;
    await maybeAskNotificationOptIn(context, ref);
  }

  /// Marks the end of cold start: usable UI on screen. Paired with
  /// `splash_timeout`, this separates "install bounced" from "install never
  /// got past the splash" — a distinction analytics could not make before.
  void _logAppReadyOnce() {
    if (AppStartup.readyLogged) return;
    AppStartup.readyLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logAppReady(
        AppStartup.clock.elapsedMilliseconds,
        viaOnboarding: AppStartup.viaOnboarding,
      );
    });
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

  /// Opened from the day-5 trial progress notification: take the parent to
  /// the dashboard that has the numbers the notification quoted — through
  /// the gate, because the child taps notifications too.
  Future<void> _maybeOpenTrialReport() async {
    if (!NotificationService.instance.launchedFromTrialReport) return;
    NotificationService.instance.launchedFromTrialReport = false;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final ok = await showParentalGate(
      context,
      isEn: ref.read(languageProvider) == 'en',
    );
    if (!ok || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    );
  }

  Future<void> _showWelcomeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcome_shown') == true) {
      // Existing user — show "What's New" instead of welcome
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          final isEn = ref.read(languageProvider) == 'en';
          await WhatsNewService.instance.showIfNeeded(context, isEn: isEn);
        }
      }
      return;
    }
    await prefs.setBool('welcome_shown', true);
    if (!mounted) return;
    // A fresh install always arrives here through onboarding, whose magic
    // moment has just had the child tap three cards and hear three words.
    // Re-explaining "tap a card — hear the word" in a six-line dialog was
    // pure corridor (audit #5). Kept only for the no-onboarding path.
    if (AppStartup.viaOnboarding) return;

    final isEn = ref.read(languageProvider) == 'en';
    final s = AppS(isEn);
    // Personalise the greeting with the name the parent entered in onboarding.
    // Fall back to a neutral "Hello!" if the default profile name ("Малюк"/
    // "Kid") wasn't customised.
    final name = ref.read(profileProvider).active?.name.trim() ?? '';
    final isDefaultName = name.isEmpty || name == 'Малюк' || name == 'Kid';
    final greeting = isDefaultName
        ? s('Привіт!', 'Hello!')
        : s('Привіт, $name!', 'Hello, $name!');
    await showDialog<void>(
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
                greeting,
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
      // Lift the bar off the content with a soft shadow so the grid doesn't
      // appear to run underneath it.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        // 72dp tall with 30dp icons: the 56dp Material bar with grey
        // 24dp glyphs was below the child's minimum target and did not read
        // as buttons (audit #27). Every switch is felt and heard.
        child: NavigationBar(
          height: 72,
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            if (i != _tab) KidTap.feedback();
            setState(() => _tab = i);
          },
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.16),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.grid_view_rounded, size: 30),
              selectedIcon: const Icon(Icons.grid_view_rounded,
                  size: 30, color: Color(0xFF6C63FF)),
              label: s('Картки', 'Cards'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.sports_esports_rounded, size: 30),
              selectedIcon: const Icon(Icons.sports_esports_rounded,
                  size: 30, color: Color(0xFF6C63FF)),
              label: s('Ігри', 'Games'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.palette_rounded, size: 30),
              selectedIcon: const Icon(Icons.palette_rounded,
                  size: 30, color: Color(0xFF6C63FF)),
              label: s('Малюємо', 'Coloring'),
            ),
          ],
        ),
      ),
    );
  }
}
