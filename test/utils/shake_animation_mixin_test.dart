import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/shake_animation_mixin.dart';

class _ShakeHost extends ConsumerStatefulWidget {
  const _ShakeHost();
  @override
  ConsumerState<_ShakeHost> createState() => _ShakeHostState();
}

class _ShakeHostState extends ConsumerState<_ShakeHost>
    with TickerProviderStateMixin, ShakeAnimationMixin {
  @override
  void initState() {
    super.initState();
    initShake();
  }

  @override
  void dispose() {
    disposeShake();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('shaking:${shakingId ?? "none"}'),
          wrapShake(const Text('A'), id: 'a'),
          wrapShake(const Text('B'), id: 'b'),
          ElevatedButton(
            onPressed: () => shake(id: 'a'),
            child: const Text('shakeA'),
          ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: _ShakeHost())),
  );
}

void main() {
  group('ShakeAnimationMixin', () {
    testWidgets('shakingId starts as null', (tester) async {
      await _pump(tester);
      expect(find.text('shaking:none'), findsOneWidget);
    });

    testWidgets('shake(id:) sets shakingId then clears after animation',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('shakeA'));
      await tester.pump();
      expect(find.text('shaking:a'), findsOneWidget);
      // Animation duration default 380ms
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('shaking:none'), findsOneWidget);
    });

    testWidgets('shake controller is a real AnimationController',
        (tester) async {
      await _pump(tester);
      final state =
          tester.state<_ShakeHostState>(find.byType(_ShakeHost));
      expect(state.shakeController, isA<AnimationController>());
      expect(state.shakeController.duration,
          const Duration(milliseconds: 380));
    });

    testWidgets('initShake accepts custom duration and amplitude',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: _CustomShakeHost())),
      );
      final state = tester.state<_CustomShakeHostState>(
          find.byType(_CustomShakeHost));
      expect(state.shakeController.duration,
          const Duration(milliseconds: 600));
    });

    testWidgets('wrapShake renders child', (tester) async {
      await _pump(tester);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });
}

class _CustomShakeHost extends ConsumerStatefulWidget {
  const _CustomShakeHost();
  @override
  ConsumerState<_CustomShakeHost> createState() => _CustomShakeHostState();
}

class _CustomShakeHostState extends ConsumerState<_CustomShakeHost>
    with TickerProviderStateMixin, ShakeAnimationMixin {
  @override
  void initState() {
    super.initState();
    initShake(duration: const Duration(milliseconds: 600), amplitude: 20);
  }

  @override
  void dispose() {
    disposeShake();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}
