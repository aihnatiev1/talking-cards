import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/bloom_reactions_provider.dart';
import 'providers/language_provider.dart';
import 'providers/packs_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_evidence_provider.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/engage_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/purchase_service.dart';
import 'utils/app_startup.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Crashlytics needs all uncaught zone errors funneled through one entrypoint,
  // so the whole bootstrap runs inside runZonedGuarded.
  await runZonedGuarded<Future<void>>(() async {
    AppStartup.begin();
    WidgetsFlutterBinding.ensureInitialized();
    _capImageCache();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Disable collection in debug so dev crashes don't pollute prod dashboards.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    // Same for Analytics — emulator/dev runs were showing up as real "new
    // users" and skewing the funnel (e.g. the fake 12.08 spike).
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(!kDebugMode);

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

    // Phones stay portrait; tablets may lie flat "like the TV" — many
    // families hand the child an old tablet in landscape (audit #29). The
    // 600dp shortest side is Android's own tablet threshold.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestDp =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    await SystemChrome.setPreferredOrientations(shortestDp >= 600
        ? DeviceOrientation.values
        : const [DeviceOrientation.portraitUp]);
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

/// Flutter's default image cache is 100 MB / 1000 entries — a ceiling
/// sized for a phone with plenty of headroom, not for the 2016 tablet a
/// family hands the child (rule 10). Card art ships at 640 px wide, so one
/// full-screen decode is 640x858 RGBA ~ 2.2 MB and one grid tile ~ 0.55 MB.
///
/// What the app actually needs warm at any moment:
///   * the swiper: current card plus the three `_precacheAround` neighbours
///     at hero width ~ 9 MB;
///   * a 21-tile pack grid ~ 12 MB;
///   * the screen the child just came from, so going back is instant.
///
/// 40 MB holds all three with room to spare and still leaves the rest of a
/// 1 GB device to the engine. The cap only bounds images nothing is
/// painting right now — anything on screen is kept alive by its own
/// `ImageStream` regardless — so a smaller cache costs a re-decode on a
/// return trip, never a blank card. The entry cap stops a long session of
/// small thumbnails from filling the cache with bookkeeping.
void _capImageCache() {
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 40 << 20
    ..maximumSize = 150;
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
    PurchaseService.instance.isPro.addListener(_syncPro);
  }

  @override
  void dispose() {
    PurchaseService.instance.isPro.removeListener(_syncPro);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// `isProProvider` is seeded once, at first read. An entitlement can land
  /// much later than that — a slow store verification, an Ask to Buy
  /// approval, the silent restore at launch — and without this bridge a
  /// family that already paid keeps looking at locked packs until the app
  /// is restarted.
  void _syncPro() {
    final isPro = PurchaseService.instance.isPro.value;
    if (isPro) _refreshTrialReport(); // A trial may have just started.
    if (ref.read(isProProvider) == isPro) return;
    ref.read(isProProvider.notifier).state = isPro;
  }

  /// Reminders speak from context, not from a counter: the pack the family
  /// opened last and a few words the child actually recognises.
  Future<void> _refreshEngagement() async {
    final lang = ref.read(languageProvider);
    final lastPack = await EngageService.instance.lastPackTitle();
    if (!mounted) return;
    NotificationService.instance.refreshEngagement(
      lang: lang,
      lastPackTitle: lastPack,
      familiarWords: _familiarWords(limit: 3),
    );
  }

  /// Words with real evidence behind them — recognised in a game or marked
  /// by a grown-up. Never plain views: seeing a card is not knowing a word.
  List<String> _familiarWords({required int limit}) {
    final known = ref.read(wordEvidenceProvider).evidencedIds;
    if (known.isEmpty) return const [];
    final packs = ref.read(packsProvider).valueOrNull;
    if (packs == null) return const [];
    final words = <String>[];
    for (final pack in packs) {
      for (final card in pack.cards) {
        if (known.contains(card.id) && !words.contains(card.sound)) {
          words.add(card.sound);
          if (words.length >= limit) return words;
        }
      }
    }
    return words;
  }

  /// Keeps the day-5 trial report current with what the child has learned.
  /// Called when the app is put away — the numbers then reflect the session
  /// that just ended — and when it comes back, so the notification that
  /// fires carries the latest figures the phone has.
  void _refreshTrialReport() {
    final started = PurchaseService.instance.trialStartedAt;
    if (started == null) return;
    // Words with evidence — recognised in a game or marked by the grown-up.
    // Views deliberately excluded: the report would otherwise claim the
    // child "knows" every card that scrolled past.
    final learnedIds = ref.read(wordEvidenceProvider).evidencedIds;
    String? bestPack;
    final packs = ref.read(packsProvider).valueOrNull;
    if (packs != null && learnedIds.isNotEmpty) {
      int best = 0;
      for (final p in packs) {
        final n = p.cards.where((c) => learnedIds.contains(c.id)).length;
        if (n > best) (best, bestPack) = (n, p.title);
      }
    }
    final name = ref.read(profileProvider).active?.name.trim() ?? '';
    NotificationService.instance.scheduleTrialProgressReport(
      trialStartedAt: started,
      lang: ref.read(languageProvider),
      childName: name.isEmpty || name == 'Малюк' ? null : name,
      learnedWords: learnedIds.length,
      bestPack: bestPack,
    );
  }

  /// When the app last left the foreground — Bloom greets a child who has
  /// been away more than five minutes (bloom_character.md §3.1).
  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop voiceover the moment the app leaves the foreground (screen lock,
    // home button, app switcher) — otherwise long poems keep playing in the
    // background, which surprises parents.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AudioService.instance.stop();
      _pausedAt ??= DateTime.now();
      ref.read(bloomReactionsProvider.notifier).appPaused();
      _refreshTrialReport();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    ref.read(bloomReactionsProvider.notifier).appResumed(
          pausedAt == null ? Duration.zero : DateTime.now().difference(pausedAt),
        );
    // Refresh engagement reminders only on resume (never in build).
    _refreshEngagement();
    _refreshTrialReport();
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
      // One light theme from DT (lib/utils/app_theme.dart); dark is kept
      // only for the parent-zone toggle and mirrors the previous values.
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}