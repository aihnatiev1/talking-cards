import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/widgets/card_image.dart';

/// The one widget allowed to draw a card illustration, and therefore the
/// one place the "content may not be here" contract is enforced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = AssetPackService.instance;
  const pad = {
    'assets/pad_content/images/webp/paid.webp',
  };
  const all = {
    'assets/images/webp/free.webp',
    'assets/pad_content/images/webp/paid.webp',
  };

  CardModel card(String id, {String? image}) => CardModel(
        id: id,
        sound: id,
        text: id,
        emoji: '🐶',
        colorBg: const Color(0xFFFFFFFF),
        colorAccent: const Color(0xFF000000),
        image: image,
      );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: SizedBox.square(
            dimension: 200,
            child: child,
          ))),
        ),
      );

  setUp(() {
    CardImage.debugResetReported();
    service.debugConfigure(padAssets: pad, bundled: true, allAssets: all);
  });

  testWidgets('content on the device is drawn', (tester) async {
    await pump(tester, CardImage.forCard(card('c', image: 'free')));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('🐶'), findsNothing);
  });

  testWidgets('a pack still downloading shows the emoji, never a spinner',
      (tester) async {
    // A two-year-old reads a spinner as "broken". The emoji is the same
    // thing the card shows when it has no illustration at all, so the
    // screen stays legible instead of turning into a loading state.
    service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);

    await pump(tester, CardImage.forCard(card('c', image: 'paid')));

    expect(find.text('🐶'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a card with no illustration shows its emoji', (tester) async {
    await pump(tester, CardImage.forCard(card('c')));
    expect(find.text('🐶'), findsOneWidget);
  });

  testWidgets('an asset missing from the build shows the emoji',
      (tester) async {
    await pump(tester, CardImage.forCard(card('c', image: 'kartoplya')));
    expect(find.text('🐶'), findsOneWidget);
  });

  testWidgets('undelivered content reports nothing to FlutterError',
      (tester) async {
    // The regression that matters. main.dart routes FlutterError.onError
    // into recordFlutterFatalError, so anything that reaches it is filed
    // as a crash — which is how two intact, merely-undownloaded webp files
    // became fatal crashes on 2026-09-08.
    service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await pump(tester, CardImage.forCard(card('c', image: 'paid')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
  });

  testWidgets('the placeholder becomes the picture when the pack lands',
      (tester) async {
    // Without watching the pack state a tile that missed once stays blank
    // until some unrelated rebuild happens by.
    service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
    await pump(tester, CardImage.forCard(card('c', image: 'paid')));
    expect(find.text('🐶'), findsOneWidget);

    service.debugConfigure(
      padAssets: pad,
      bundled: false,
      packPath: '/data/pack',
      allAssets: all,
      state: ContentPackState.ready,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('🐶'), findsNothing);
  });
}
