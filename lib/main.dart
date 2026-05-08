import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/streak_provider.dart';
import 'providers/theme_provider.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Crashlytics needs all uncaught zone errors funneled through one entrypoint,
  // so the whole bootstrap runs inside runZonedGuarded.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Disable collection in debug so dev crashes don't pollute prod dashboards.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Load active profile BEFORE providers are created so all SharedPreferences
    // reads use the correct namespace from the very first build.
    final profiles = await ProfileService.init();

    // Seed Firebase user properties for cohort slicing on D1/D7/D30 dashboards.
    if (profiles.isNotEmpty) {
      final active = profiles.firstWhere(
        (p) => p.id == ProfileService.activeId,
        orElse: () => profiles.first,
      );
      AnalyticsService.instance.setLanguageProperty(active.language);
      AnalyticsService.instance.setAgeLevelProperty(active.level);
    }

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));
    runApp(ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          (ref) => ProfileNotifier(ref, profiles),
        ),
      ],
      child: const TalkingCardsApp(),
    ));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class TalkingCardsApp extends ConsumerStatefulWidget {
  const TalkingCardsApp({super.key});

  @override
  ConsumerState<TalkingCardsApp> createState() => _TalkingCardsAppState();
}

class _TalkingCardsAppState extends ConsumerState<TalkingCardsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop voiceover the moment the app leaves the foreground (screen lock,
    // home button, app switcher) — otherwise long poems keep playing in the
    // background, which surprises parents.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AudioService.instance.stop();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // Refresh engagement reminders only on resume (never in build).
    final lang = ref.read(languageProvider);
    final streak = ref.read(streakProvider).currentStreak;
    NotificationService.instance
        .refreshEngagement(lang: lang, currentStreak: streak);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      // App switcher / a11y title — neutralized brand for the bilingual build.
      // Per-locale OS-level display name lives in:
      //   • Android: res/values/strings.xml + values-uk/strings.xml
      //   • iOS:     ios/Runner/{en,uk}.lproj/InfoPlist.strings
      title: 'FirstWords Cards',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        if (AnalyticsService.instance.observer != null)
          AnalyticsService.instance.observer!,
      ],
      theme: ThemeData(
        colorSchemeSeed: kAccent,
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: kAccent,
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}