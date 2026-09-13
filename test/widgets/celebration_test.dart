import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/celebration.dart';
import 'package:talking_cards/widgets/kid_screen.dart';

/// The one celebration (motion audit 2026-09-13 §4):
///
/// * a tap on the barrier never dismisses — a toddler's stray tap used to
///   land on Home;
/// * the pills ignore taps in the first 600 ms, when the child's finger is
///   often still on the glass from the last swipe;
/// * everything is one-shot: the overlay settles;
/// * under reduced motion the content still renders and the gate stays;
/// * the sound (tada + praise, or the milestone bell) is asked for exactly
///   once, through FeedbackService.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // celebrate() goes through the shared overlay queue; a test that ends
    // with the overlay still up must not block the next one.
    debugResetKidOverlayQueue();
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance
        .debugConfigure(padAssets: const {}, bundled: true);
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
    MotionPolicy.debugOverride = null;
  });

  /// Pumps a host screen with one launcher and opens the celebration.
  Future<({int Function() done, int Function() again})> open(
    WidgetTester tester, {
    CelebrationTier tier = CelebrationTier.round,
  }) async {
    var done = 0;
    var again = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => celebrate(
                  context,
                  tier: tier,
                  isEn: false,
                  childName: 'Соня',
                  packTitle: 'Тваринки',
                  packIcon: '🐾',
                  title: tier == CelebrationTier.milestone
                      ? 'Серія 7 днів!'
                      : null,
                  badge: tier == CelebrationTier.milestone ? '🏅' : null,
                  onAgain: () => again++,
                  onDone: () => done++,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // push
    await tester.pump(); // first celebration frame
    return (done: () => done, again: () => again);
  }

  testWidgets('tapping the barrier does not dismiss', (tester) async {
    final r = await open(tester);
    await tester.pump(const Duration(seconds: 1));
    // Top-left corner: pure barrier, far from the card and its pills.
    await tester.tapAt(const Offset(12, 40));
    await tester.pump();
    expect(find.byType(Celebration), findsOneWidget);
    expect(r.done(), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('pills ignore taps in the first 600 ms, then pop once and '
      'call back', (tester) async {
    final r = await open(tester);
    final done = find.text('Готово');
    expect(done, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(done, warnIfMissed: false);
    await tester.pump();
    expect(r.done(), 0, reason: 'gate still closed at 300 ms');
    expect(find.byType(Celebration), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(done);
    await tester.pump();
    expect(r.done(), 1);
    expect(r.again(), 0);
    await tester.pumpAndSettle();
    expect(find.byType(Celebration), findsNothing,
        reason: 'the overlay popped itself before calling onDone');
    expect(find.text('open'), findsOneWidget,
        reason: 'only the overlay popped — the host screen is still there');
  });

  testWidgets('the celebration is one-shot: it settles', (tester) async {
    await open(tester);
    // Would time out on an infinite repeat().
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Молодець, Соня!'), findsOneWidget);
    expect(find.text('Ще раз'), findsOneWidget);
  });

  testWidgets('reduced motion renders the content, keeps the gate, settles '
      'fast', (tester) async {
    MotionPolicy.debugOverride = MotionMode.reduced;
    final r = await open(tester);
    expect(find.text('Молодець, Соня!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Готово'), warnIfMissed: false);
    await tester.pump();
    expect(r.done(), 0, reason: 'the 600 ms gate is not motion');

    // Only the gate's worth of clock, no 2.5 s choreography.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'reduced motion must not keep the master controller ticking');

    await tester.tap(find.text('Готово'));
    await tester.pump();
    expect(r.done(), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('round asks FeedbackService for roundDone exactly once',
      (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(
      FeedbackService.debugLog.where((e) => e == FeedbackEvent.roundDone),
      hasLength(1),
    );
    expect(FeedbackService.debugLog, isNot(contains(FeedbackEvent.packDone)));
  });

  testWidgets('pack asks for packDone exactly once and shows the pack',
      (tester) async {
    await open(tester, tier: CelebrationTier.pack);
    await tester.pumpAndSettle();
    expect(
      FeedbackService.debugLog.where((e) => e == FeedbackEvent.packDone),
      hasLength(1),
    );
    expect(find.text('Тваринки пройдено!'), findsOneWidget);
    expect(find.text('На головну'), findsOneWidget);
    expect(find.text('Грати знову'), findsOneWidget);
  });

  testWidgets('milestone rings the bell once, no cheer, one pill',
      (tester) async {
    await open(tester, tier: CelebrationTier.milestone);
    await tester.pumpAndSettle();
    expect(
      FeedbackService.debugLog.where((e) => e == FeedbackEvent.milestone),
      hasLength(1),
    );
    expect(find.text('Серія 7 днів!'), findsOneWidget);
    expect(find.text('Так тримати!'), findsOneWidget);
    expect(find.text('Ще раз'), findsNothing);
  });
}
