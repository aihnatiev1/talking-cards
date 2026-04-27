import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_service.dart';
import '../services/engage_service.dart';
import '../services/remote_config_service.dart';
import '../services/widget_service.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _loadingDone = false;
  bool _animDone = false;
  bool _imageReady = false;
  bool _showOnboarding = false;
  String? _deepLink;
  bool _isEnLang = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    // Start loading in background
    _initServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imageReady) {
      precacheImage(
        const AssetImage('assets/images/webp/splash.webp'),
        context,
      ).then((_) {
        if (!mounted) return;
        setState(() => _imageReady = true);
        _ctrl.forward();
        Future.delayed(const Duration(milliseconds: 1200), () {
          _animDone = true;
          _navigateIfReady();
        });
      });
    }
  }

  Future<void> _initServices() async {
    // Each service swallows its own errors so a single failing init never
    // strands the splash on an infinite loader.
    Future<void> guard(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (e, st) {
        debugPrint('splash: $name failed: $e\n$st');
      }
    }

    await Future.wait([
      guard('remoteConfig', () => RemoteConfigService.instance.init()),
      guard('widget', () => WidgetService.instance.init()),
      guard('purchase', () => PurchaseService.instance.init()),
      guard('audio', () => AudioService.instance.precache()),
      guard('notifications', () => NotificationService.instance.init()),
    ]);

    // Schedule day-3 soft paywall reminder for non-pro users; cancel for pro.
    await guard('paywallReminder', () async {
      if (PurchaseService.instance.isPro.value) {
        await NotificationService.instance.cancelPaywallReminder();
      } else {
        await NotificationService.instance.schedulePaywallReminderIfNeeded();
      }
    });

    await guard('deepLink', () async {
      _deepLink = await EngageService.instance.getInitialLink();
    });
    EngageService.instance.publishFromPrefs();

    // Read the active profile's learning language so the splash title
    // matches before MaterialApp picks it up.
    final prefs = await SharedPreferences.getInstance();
    try {
      final activeId = prefs.getString('active_profile_id') ?? 'default';
      final raw = prefs.getStringList('app_profiles') ?? const [];
      for (final s in raw) {
        final j = json.decode(s) as Map<String, dynamic>;
        if (j['id'] == activeId && j['lang'] == 'en') {
          if (mounted) setState(() => _isEnLang = true);
          break;
        }
      }
    } catch (_) {}
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) {
      // Existing user upgrading from <1.1.0: they have real pack progress
      // but no onboarding_done flag. We must NOT key on streak_current —
      // StreakNotifier auto-writes that on every cold start, so a fresh
      // install would already look "existing" by the time splash reads
      // prefs and the kid would never see onboarding (iOS first launch bug).
      final hasExistingData = prefs.getKeys().any((k) =>
          k.startsWith('pack_progress_') ||
          k.startsWith('completed_packs'));
      if (hasExistingData) {
        // Silently mark done — don't interrupt an existing user with onboarding
        await prefs.setBool('onboarding_done', true);
        _showOnboarding = false;
      } else {
        _showOnboarding = true;
      }
    } else {
      _showOnboarding = false;
    }

    _loadingDone = true;
    _navigateIfReady();
  }

  void _navigateIfReady() {
    if (!_loadingDone || !_animDone || !mounted) return;

    Widget dest = _showOnboarding ? const OnboardingScreen() : const HomeScreen();

    // Handle deep links: talkingcards://cards/{packId} → CardsScreen
    // talkingcards://home or unknown → HomeScreen
    final link = _deepLink;
    if (link != null && !_showOnboarding) {
      final uri = Uri.tryParse(link);
      if (uri != null && uri.scheme == 'talkingcards') {
        if (uri.host == 'quest') {
          // Navigate to home and let it open quest map
          dest = const HomeScreen();
        }
        // cards/{packId} is handled post-navigation via HomeScreen state
        // For simplicity we navigate home and let the user tap the pack
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _imageReady
            ? FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/webp/splash.webp',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  _isEnLang ? 'FirstWords Cards' : 'Картки-розмовлялки',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}
