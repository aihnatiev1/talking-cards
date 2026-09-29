import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/packs_provider.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/tabs/games_tab.dart';

/// The Games tab's AppBar is transparent over a cream background. Flutter
/// reads a transparent AppBar as dark and turns the status bar white —
/// found on a simulator on 2026-09-29, where the clock and the battery
/// all but vanished on this tab and on the pale game skies above it.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(padAssets: const {}, bundled: true);
  });

  testWidgets('the Games tab asks for dark status-bar icons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [packsProvider.overrideWith((ref) async => const [])],
        child: const MaterialApp(home: GamesTab()),
      ),
    );
    await tester.pump();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);
  });
}
