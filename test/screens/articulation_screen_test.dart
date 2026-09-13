import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/screens/articulation_screen.dart';
import 'package:talking_cards/widgets/articulation_art.dart';

/// The twelve exercise drawings are still being produced, so the screen has
/// to be correct in both worlds: dignified without them, and out of the way
/// the moment they land. The first case is the one that bites — an `Image`
/// over a file that is not there routes its throw to `FlutterError.onError`,
/// which `main.dart` files as a fatal crash.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(Widget child, {AssetBundle? bundle}) {
    final app = ProviderScope(child: MaterialApp(home: child));
    return bundle == null
        ? app
        : DefaultAssetBundle(bundle: bundle, child: app);
  }

  testWidgets('the sheet builds with no illustrations on the device',
      (tester) async {
    await tester.pumpWidget(host(const ArticulationScreen()));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Лопатка'), findsOneWidget);
    // Every tile falls back to the painted mouth, none to an emoji.
    expect(
      find.byType(ArticulationArtPlaceholder),
      findsWidgets,
      reason: 'a missing drawing must still leave something in the slot',
    );
  });

  testWidgets('a drawing that exists is shown instead of the placeholder',
      (tester) async {
    // Decoding a real PNG needs the platform's own async, not the fake
    // clock, so the whole load runs inside runAsync.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 120,
            height: 120,
            child: ArticulationArt(id: 'spatula'),
          ),
          bundle: _StubBundle({ArticulationArt.assetPath('spatula')}),
        ),
      );
      await tester.idle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ArticulationArtPlaceholder), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a drawing that is absent never throws', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 120,
          height: 120,
          child: ArticulationArt(id: 'nothing_here'),
        ),
        bundle: _StubBundle(const {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ArticulationArtPlaceholder), findsOneWidget);
  });

  testWidgets('the detail screen walks the whole set and counts honestly',
      (tester) async {
    await tester.pumpWidget(
      host(const ArticulationDetailScreen(initialIndex: 0, isEn: false)),
    );
    await tester.pump();

    expect(find.text('1 з 12'), findsOneWidget);
    expect(find.text('Лопатка'), findsOneWidget);
    // No game framing left: no "Далі ▶", no reps, a neutral way out.
    expect(find.text('Завершити'), findsOneWidget);
    expect(find.textContaining('▶'), findsNothing);

    // «Попередня» is disabled on the first exercise.
    final previous = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Попередня'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(previous.onPressed, isNull);

    for (var i = 1; i < articulationExercises.length; i++) {
      await tester.tap(find.text('Наступна'));
      await tester.pump();
      expect(find.text('${i + 1} з 12'), findsOneWidget);
      expect(find.text(articulationExercises[i].name), findsOneWidget);
    }

    // ...and stops at the end instead of wrapping into nothing.
    final next = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Наступна'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(next.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the target sounds are named, not tucked into 11 sp chips',
      (tester) async {
    await tester.pumpWidget(
      host(const ArticulationDetailScreen(initialIndex: 1, isEn: false)),
    );
    await tester.pump();

    expect(find.text('ГОТУЄ ЗВУКИ'), findsOneWidget);
    for (final sound in articulationExercises[1].sounds) {
      final style = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('sound_$sound')),
              matching: find.byType(Text),
            ),
          )
          .style;
      expect(style?.fontSize, greaterThanOrEqualTo(18));
    }
  });

  test('every exercise has an id, and the ids are unique file names', () {
    final ids = articulationExercises.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => RegExp(r'^[a-z_]+$').hasMatch(id)), isTrue);
  });
}

/// Answers only for the assets it was told exist; everything else throws
/// the way the real bundle does for a file that is not in the manifest.
class _StubBundle extends CachingAssetBundle {
  _StubBundle(this.present);

  final Set<String> present;

  @override
  Future<ByteData> load(String key) async {
    // `AssetImage` asks for the manifest before the file, to pick a dpr
    // variant. An empty manifest means "no variants" — the plain key wins.
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(
            <Object?, Object?>{},
          ) ??
          ByteData(0);
    }
    if (!present.contains(key)) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.view(Uint8List.fromList(_pixel).buffer);
  }
}

/// A 1×1 transparent PNG — the decoder only has to succeed.
const _pixel = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
