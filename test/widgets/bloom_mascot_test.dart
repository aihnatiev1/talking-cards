import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/bloom_reactions_provider.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';
import 'package:talking_cards/widgets/kid_tap.dart';

/// The widget half of Bloom (docs/design/bloom_character.md §5.5–5.6):
/// a 72 dp hit zone around a 56 dp drawing, a tap that reaches the brain,
/// a frozen state that needs no `ProviderScope`, and — under reduced
/// motion — a tree that settles no matter what the brain is doing.
void main() {
  setUp(() {
    FeedbackService.debugMute = true;
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
    MotionPolicy.debugOverride = null;
  });

  Widget host(Widget child, {ProviderContainer? container}) {
    final app = MaterialApp(home: Scaffold(body: Center(child: child)));
    if (container == null) return ProviderScope(child: app);
    return UncontrolledProviderScope(container: container, child: app);
  }

  testWidgets('hit zone is 72 dp around a 56 dp drawing', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    await tester.pumpWidget(host(
      const BloomMascot(size: 56, state: BloomState.still(BloomEmotion.idle)),
    ));
    expect(tester.getSize(find.byType(BloomMascot)), const Size(72, 72));
    expect(tester.getSize(find.byType(CustomPaint).last), const Size(56, 56));
  });

  testWidgets('a frozen state renders without a ProviderScope',
      (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BloomMascot(
            size: 96,
            state: BloomState.still(BloomEmotion.cheer, hops: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BloomMascot), findsOneWidget);
    // Frozen Bloom has no brain to hop with: not a button.
    expect(find.byType(KidTap), findsNothing);
  });

  testWidgets('a tap reaches the brain: happy, and a hop', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(
      const BloomMascot(size: 56),
      container: container,
    ));
    await tester.tap(find.byType(BloomMascot));
    await tester.pump();
    expect(container.read(bloomReactionsProvider).emotion, BloomEmotion.happy);
    // Let the brain's one-shot timer run out, then unmount so the blink
    // timer is cancelled with the widget.
    await tester.pump(DT.motion.celebrate);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('interactive: false is decorative', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    await tester.pumpWidget(host(
      const BloomMascot(size: 56, interactive: false),
    ));
    expect(find.byType(KidTap), findsNothing);
    final semantics = tester.getSemantics(find.byType(BloomMascot));
    expect(semantics.label, 'Bloom');
  });

  testWidgets('under MotionMode.test every reaction settles', (tester) async {
    MotionPolicy.debugOverride = MotionMode.test;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(
      const BloomMascot(size: 56),
      container: container,
    ));
    final brain = container.read(bloomReactionsProvider.notifier);
    brain.sceneEntered('cards', BloomScene.cards);
    brain.packOpened();
    await tester.pumpAndSettle();
    brain.packCompleted();
    await tester.pumpAndSettle();
    expect(find.byType(BloomMascot), findsOneWidget);
    // No pose or gesture ticker may be left running while the brain's own
    // clock (a Timer, not a ticker) counts the cheer down.
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(DT.motion.bloomCheerBig);
    await tester.pump(DT.motion.bloomAfterglow);
    expect(container.read(bloomReactionsProvider).emotion, BloomEmotion.idle);
    // Leaving the scene cancels the hint and sleep timers.
    brain.sceneLeft('cards');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with motion on, a one-shot ticks and then rests',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(
      const BloomMascot(size: 56),
      container: container,
    ));
    final brain = container.read(bloomReactionsProvider.notifier);
    brain.bloomTapped();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'the hop is playing');
    await tester.pump(DT.motion.celebrate);
    await tester.pump(DT.motion.bloomPose);
    await tester.pump();
    expect(container.read(bloomReactionsProvider).emotion, BloomEmotion.idle);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'at rest Bloom schedules no frames — only the blink Timer');
    await tester.pumpWidget(const SizedBox());
  });
}
