import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'services/analytics_service.dart';
import 'services/profile_service.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load active profile BEFORE providers are created so all SharedPreferences
  // reads use the correct namespace from the very first build.
  final profiles = await ProfileService.init();

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
}

class TalkingCardsApp extends ConsumerWidget {
  const TalkingCardsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Розмовлялки',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.instance.observer],
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
