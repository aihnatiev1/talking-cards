import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/bloom_reactions_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import '../services/paywall_flow.dart';
import '../services/analytics_service.dart';
import '../services/whatsnew_service.dart';
import '../utils/app_startup.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/notification_opt_in_dialog.dart';
import '../widgets/parental_gate.dart';
import 'parent_dashboard_screen.dart';
import '../tabs/packs_tab.dart';
import '../tabs/games_tab.dart';
import 'coloring_screen.dart';
import '../widgets/playful_navigation_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// The tab the parent/child picked — what the navigation bar highlights.
  int _tab = 0;

  /// The tab the stack is actually showing. Lags [_tab] by half a
  /// fade-through: the old tab fades out first, then this flips and the
  /// new one fades in (motion audit §5, "перемикання табів").
  int _visibleTab = 0;

  /// Fade-through (`DT.motion.tabFade`, 180 ms): out over the first half,
  /// in over the second. Content never moves — for a child the tabs must
  /// stay exactly where they were.
  static final Duration _fadeThrough = DT.motion.tabFade;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: _fadeThrough);
    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_fadeCtrl);
    _fadeCtrl.addListener(_swapAtMidpoint);
    _logAppReadyOnce();
    _runFirstFrameFlow();
    _maybeShowPaywallFromReminder();
    _maybeOpenTrialReport();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// The stack switches tabs while nothing is visible — at the midpoint of
  /// the fade-through — so the new tab is never seen appearing in place.
  void _swapAtMidpoint() {
    if (_fadeCtrl.value < 0.5 || _visibleTab == _tab) return;
    setState(() => _visibleTab = _tab);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    if (MotionPolicy.of(context).reduce) {
      _fadeCtrl.stop();
      _fadeCtrl.value = 0;
      setState(() {
        _tab = i;
        _visibleTab = i;
      });
      return;
    }
    setState(() => _tab = i);
    // Mid-flight and already showing the previous target: start over so the
    // newest choice also gets its fade-out. Still fading out: let it run —
    // the midpoint swap reads the latest [_tab].
    if (!_fadeCtrl.isAnimating || _fadeCtrl.value >= 0.5) {
      _fadeCtrl.forward(from: 0);
    }
  }

  /// Greeting first, then the notification ask — in that order, and for
  /// returning users too. Reminders are the only thing that brings a parent
  /// back on day two, and `notification_opened` was 0 across 60 days because
  /// most of the base never granted permission.
  Future<void> _runFirstFrameFlow() async {
    await _showWelcomeIfNeeded();
    if (!mounted) return;
    // The intro-modal queue is empty: Bloom says hello
    // (bloom_character.md §3.1). Nothing blocks on it.
    ref.read(bloomReactionsProvider.notifier).appEntered();
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
    await runPaywallFlow(context, ref, source: 'reminder');
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
    Navigator.of(context).push(KidRoutes.sheet(const ParentDashboardScreen()));
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
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
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    s("Почнемо! 🎉", "Let's go! 🎉"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeCtrl,
        builder: (_, child) => IgnorePointer(
          // A tap on a half-faded tab would land on whichever tab happens to
          // be in the stack at that instant; hold input for 180 ms instead.
          ignoring: _fadeCtrl.isAnimating,
          child: child,
        ),
        child: FadeTransition(
          opacity: _fade,
          child: IndexedStack(
            index: _visibleTab,
            children: [
              TickerMode(enabled: _visibleTab == 0, child: const PacksTab()),
              TickerMode(enabled: _visibleTab == 1, child: const GamesTab()),
              TickerMode(
                enabled: _visibleTab == 2,
                child: const ColoringScreen(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PlayfulNavigationBar(
        selectedIndex: _tab,
        isEn: isEn,
        onSelected: _selectTab,
      ),
    );
  }
}
