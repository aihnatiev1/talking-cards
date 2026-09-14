import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/utils/motion.dart';
import 'package:talking_cards/widgets/entrance_stagger.dart';

/// The entrance wave of ux-gap-audit G11: a grid arrives item by item,
/// 40 ms apart, and every item still ends up on screen — including the one
/// a `GridView.builder` only creates when the child scrolls to it.
void main() {
  final step = DT.motion.stagger;
  final enter = DT.motion.enter;

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Widget list(int count, {bool scope = true}) {
    final column = Column(
      children: [
        for (var i = 0; i < count; i++)
          StaggeredEntrance(key: ValueKey(i), index: i, child: Text('item $i')),
      ],
    );
    return host(scope ? StaggerScope(child: column) : column);
  }

  // Scoped to the item's own StaggeredEntrance: MaterialApp's route
  // transition is a FadeTransition too, and it would answer first.
  double opacityOf(WidgetTester tester, int index) {
    final fade = find.descendant(
      of: find.byKey(ValueKey(index)),
      matching: find.byType(FadeTransition),
    );
    return tester.widget<FadeTransition>(fade.first).opacity.value;
  }

  Finder itemFades() => find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      );

  group('full motion', () {
    testWidgets('items start hidden and arrive 40 ms apart', (tester) async {
      await tester.pumpWidget(list(4));

      // Frame one: nothing has faded in yet, so the grid does not flash.
      expect(opacityOf(tester, 0), 0);
      expect(opacityOf(tester, 3), 0);

      // The first item's own fade is over before the last one's has begun
      // to matter — that difference *is* the stagger.
      await tester.pump(enter);
      expect(opacityOf(tester, 0), 1);
      expect(opacityOf(tester, 3), lessThan(1));
      expect(opacityOf(tester, 1), greaterThan(opacityOf(tester, 3)));
    });

    testWidgets('every item is fully visible after step * n + enter',
        (tester) async {
      await tester.pumpWidget(list(4));
      await tester.pump(step * 3 + enter);
      for (var i = 0; i < 4; i++) {
        expect(opacityOf(tester, i), 1, reason: 'item $i');
      }
    });

    testWidgets('the wave is capped, so a long grid does not crawl',
        (tester) async {
      await tester.pumpWidget(list(21));
      // 21 × 40 ms would be 840 ms; the cap ends the wave at 320 + 260.
      await tester.pump(DT.motion.staggerCap + enter);
      expect(opacityOf(tester, 20), 1);
    });

    testWidgets('pumpAndSettle terminates', (tester) async {
      await tester.pumpWidget(list(8));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 7), 1);
    });

    testWidgets('an item built after the wave has passed appears at once',
        (tester) async {
      // What a GridView.builder does when the child scrolls: the tile is
      // created seconds later and must not replay an entrance.
      const scope = StaggerScope(child: _LateItem(key: ValueKey('late')));
      await tester.pumpWidget(host(scope));
      await tester.pump(step * 4 + enter);
      await tester.tap(find.text('add'));
      await tester.pump();
      expect(itemFades(), findsNothing);
      expect(find.text('item 4'), findsOneWidget);
    });
  });

  group('reduced motion', () {
    setUp(() => MotionPolicy.debugOverride = MotionMode.test);
    tearDown(() => MotionPolicy.debugOverride = null);

    testWidgets('no animation at all: the first frame is the final frame',
        (tester) async {
      await tester.pumpWidget(list(4));
      expect(itemFades(), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.text('item $i'), findsOneWidget);
      }
      await tester.pumpAndSettle();
    });
  });

  testWidgets('works without a scope, using its own default step',
      (tester) async {
    await tester.pumpWidget(list(3, scope: false));
    expect(opacityOf(tester, 2), 0);
    await tester.pump(step * 2 + enter);
    expect(opacityOf(tester, 2), 1);
  });
}

/// A list that grows by one item on demand, to model a scroll-in tile.
class _LateItem extends StatefulWidget {
  const _LateItem({super.key});

  @override
  State<_LateItem> createState() => _LateItemState();
}

class _LateItemState extends State<_LateItem> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => setState(() => _added = true),
          child: const Text('add'),
        ),
        if (_added)
          const StaggeredEntrance(index: 4, child: Text('item 4')),
      ],
    );
  }
}
