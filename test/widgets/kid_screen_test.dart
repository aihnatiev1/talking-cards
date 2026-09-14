import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/kid_screen.dart';

/// `KidScreen` — the one shell for the kid zone (F6).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Geometry below assumes a 390×844 phone, not the 800×600 default.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
    MotionPolicy.debugOverride = MotionMode.test;
    debugResetKidOverlayQueue();
  });
  tearDown(() {
    MotionPolicy.debugOverride = null;
    debugResetKidOverlayQueue();
  });

  /// Home → pushes [screen]; the test then interacts with the pushed page.
  Future<void> pumpPushed(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => screen),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  group('header controls', () {
    testWidgets('back button pops', (tester) async {
      await pumpPushed(
        tester,
        const KidScreen(body: Text('inside')),
      );
      expect(find.text('inside'), findsOneWidget);
      expect(find.byType(KidBackButton), findsOneWidget);
      expect(find.byType(KidCloseButton), findsNothing);

      await tester.tap(find.byType(KidBackButton));
      await tester.pumpAndSettle();

      expect(find.text('inside'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('game close button pops', (tester) async {
      await pumpPushed(
        tester,
        const KidScreen.game(body: Text('inside')),
      );
      expect(find.byType(KidCloseButton), findsOneWidget);
      expect(find.byType(KidBackButton), findsNothing);

      await tester.tap(find.byType(KidCloseButton));
      await tester.pumpAndSettle();

      expect(find.text('inside'), findsNothing);
    });

    testWidgets('back and close are at least 72 dp on both axes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: KidScreen(body: SizedBox())),
      );
      final back = tester.getSize(find.byType(KidBackButton));
      expect(back.width, greaterThanOrEqualTo(DT.size.tapMin));
      expect(back.height, greaterThanOrEqualTo(DT.size.tapMin));

      await tester.pumpWidget(
        const MaterialApp(home: KidScreen.game(body: SizedBox())),
      );
      final close = tester.getSize(find.byType(KidCloseButton));
      expect(close.width, greaterThanOrEqualTo(DT.size.tapMin));
      expect(close.height, greaterThanOrEqualTo(DT.size.tapMin));
    });

    testWidgets('the control is top-left inside the safe area',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
          ),
          child: MaterialApp(home: KidScreen(body: SizedBox())),
        ),
      );
      final rect = tester.getRect(find.byType(KidBackButton));
      expect(rect.left, DT.sp12);
      expect(rect.top, 47 + DT.sp8);
    });

    testWidgets('a custom leading and onTap override the default',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KidScreen(
            leading: KidCloseButton(onTap: () => tapped++),
            body: const SizedBox(),
          ),
        ),
      );
      await tester.tap(find.byType(KidCloseButton));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('showLeading: false keeps the slot, hides the control',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: KidScreen(
            showLeading: false,
            title: Text('t'),
            body: SizedBox(),
          ),
        ),
      );
      expect(find.byType(KidBackButton), findsNothing);
      // The title is still centred on the screen.
      final title = tester.getCenter(find.text('t'));
      expect(title.dx, closeTo(390 / 2, 1));
    });
  });

  group('progress pill', () {
    Future<double> fillWidth(WidgetTester tester, double value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KidScreen.game(progress: value, body: const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(KidProgressPill.fillKey)).width;
    }

    testWidgets('is absent when progress is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: KidScreen.game(body: SizedBox())),
      );
      expect(find.byType(KidProgressPill), findsNothing);
    });

    testWidgets('is 8 dp tall and its width follows the value',
        (tester) async {
      final half = await fillWidth(tester, 0.5);
      final full = await fillWidth(tester, 1.0);
      final none = await fillWidth(tester, 0.0);

      expect(tester.getSize(find.byType(KidProgressPill)).height,
          KidScreen.progressHeight);
      expect(none, 0);
      expect(half, closeTo(full / 2, 0.5));
      // Track spans the screen minus the horizontal inset on both sides.
      expect(full, 390 - DT.sp24 * 2);
    });

    testWidgets('clamps values outside 0..1', (tester) async {
      final over = await fillWidth(tester, 1.7);
      final under = await fillWidth(tester, -3);
      expect(over, 390 - DT.sp24 * 2);
      expect(under, 0);
    });
  });

  group('slots', () {
    testWidgets('bottom sits under the body, mascot corner bottom-right',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: KidScreen(
            body: ColoredBox(color: Colors.red, key: Key('body')),
            bottom: SizedBox(height: 80, key: Key('bottom')),
            mascotCorner: SizedBox.square(dimension: 64, key: Key('bloom')),
          ),
        ),
      );
      final body = tester.getRect(find.byKey(const Key('body')));
      final bottom = tester.getRect(find.byKey(const Key('bottom')));
      final bloom = tester.getRect(find.byKey(const Key('bloom')));

      expect(body.top, KidScreen.headerHeight);
      expect(bottom.top, body.bottom);
      expect(bottom.bottom, 844);
      // Bloom sits in the body's bottom-right padding, above the bar.
      expect(bloom.right, 390 - DT.sp16);
      expect(bloom.bottom, body.bottom - DT.sp16);
    });

    testWidgets('background override and accent scope', (tester) async {
      late Color seen;
      await tester.pumpWidget(
        MaterialApp(
          home: KidScreen(
            accent: DT.coral,
            background: DT.skyTint,
            body: Builder(builder: (context) {
              seen = KidScreen.accentOf(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(seen, DT.coral);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, DT.skyTint);
    });
  });

  group('showKidOverlay', () {
    testWidgets('queues: the second overlay waits for the first to close',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const Scaffold(body: Text('home'));
          }),
        ),
      );

      final first = showKidOverlay<String>(ctx, const Text('first'));
      final second = showKidOverlay<String>(ctx, const Text('second'));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
      expect(isKidOverlayShowing, isTrue);

      Navigator.of(ctx).pop('one');
      await tester.pumpAndSettle();

      expect(await first, 'one');
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);

      Navigator.of(ctx).pop('two');
      await tester.pumpAndSettle();

      expect(await second, 'two');
      expect(find.text('second'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(isKidOverlayShowing, isFalse);
    });

    testWidgets('the screen underneath stays visible (non-opaque route)',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const Scaffold(body: Text('home'));
          }),
        ),
      );
      showKidOverlay<void>(ctx, const Text('over'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('over'), findsOneWidget);
    });
  });

  testWidgets('an empty header band collapses instead of sitting there',
      (tester) async {
    // Colouring hides the control and has no title: 88 dp of nothing above
    // the picture is a gap, not a header.
    await tester.pumpWidget(
      const MaterialApp(
        home: KidScreen.game(showLeading: false, body: Text('body')),
      ),
    );
    final headerless = tester.getTopLeft(find.text('body')).dy;

    await tester.pumpWidget(
      const MaterialApp(home: KidScreen.game(body: Text('body'))),
    );
    final withHeader = tester.getTopLeft(find.text('body')).dy;

    expect(headerless, lessThan(withHeader));
    expect(withHeader - headerless, KidScreen.headerHeight);
  });
}
