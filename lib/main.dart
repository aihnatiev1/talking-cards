import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: SmartApp()));
}

class SmartApp extends ConsumerWidget {
  const SmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Розмовлялки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kAccent,
        useMaterial3: true,
        fontFamily: 'Roboto',
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
