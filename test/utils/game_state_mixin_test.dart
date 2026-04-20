import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/daily_quest_provider.dart';
import 'package:talking_cards/utils/game_state_mixin.dart';

class _Host extends ConsumerStatefulWidget {
  final String id;
  final int max;
  final QuestTask? task;
  final bool stats;
  const _Host({
    this.id = 'test_game',
    this.max = 3,
    this.task = QuestTask.playQuiz,
    this.stats = true,
  });
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with GameStateMixin {
  @override
  String get gameId => widget.id;
  @override
  int get maxRounds => widget.max;
  @override
  QuestTask? get questTask => widget.task;
  @override
  bool get recordToStats => widget.stats;

  @override
  void initState() {
    super.initState();
    startGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('score:$score'),
          Text('round:$roundsPlayed'),
          Text('finished:$finished'),
          ElevatedButton(
              onPressed: () => setState(scorePoint),
              child: const Text('point')),
          ElevatedButton(
              onPressed: () => setState(() => nextRound()),
              child: const Text('next')),
          ElevatedButton(
              onPressed: () => completeGame(), child: const Text('complete')),
          ElevatedButton(onPressed: resetGame, child: const Text('reset')),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, {Widget? home}) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: home ?? const _Host())),
  );
}

class _DefaultsHost extends ConsumerStatefulWidget {
  const _DefaultsHost();
  @override
  ConsumerState<_DefaultsHost> createState() => _DefaultsHostState();
}

class _DefaultsHostState extends ConsumerState<_DefaultsHost>
    with GameStateMixin {
  @override
  String get gameId => 'defaults_host';

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}

void main() {
  group('GameStateMixin', () {
    testWidgets('initial state: score=0, round=0, finished=false',
        (tester) async {
      await _pump(tester);
      expect(find.text('score:0'), findsOneWidget);
      expect(find.text('round:0'), findsOneWidget);
      expect(find.text('finished:false'), findsOneWidget);
    });

    testWidgets('scorePoint increments score', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('point'));
      await tester.pump();
      expect(find.text('score:1'), findsOneWidget);
      await tester.tap(find.text('point'));
      await tester.pump();
      expect(find.text('score:2'), findsOneWidget);
    });

    testWidgets('nextRound increments roundsPlayed', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('next'));
      await tester.pump();
      expect(find.text('round:1'), findsOneWidget);
    });

    testWidgets('nextRound triggers completion past maxRounds',
        (tester) async {
      await _pump(tester); // max=3
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('next'));
        await tester.pump();
      }
      expect(find.text('finished:false'), findsOneWidget);
      // 4th call → exceeds max=3, triggers completion
      await tester.tap(find.text('next'));
      await tester.pump();
      expect(find.text('finished:true'), findsOneWidget);
    });

    testWidgets('completeGame sets finished without bumping rounds',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('complete'));
      await tester.pump();
      expect(find.text('finished:true'), findsOneWidget);
      expect(find.text('round:0'), findsOneWidget);
    });

    testWidgets('resetGame clears state', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('point'));
      await tester.tap(find.text('next'));
      await tester.tap(find.text('complete'));
      await tester.pump();
      await tester.tap(find.text('reset'));
      await tester.pump();
      expect(find.text('score:0'), findsOneWidget);
      expect(find.text('round:0'), findsOneWidget);
      expect(find.text('finished:false'), findsOneWidget);
    });

    testWidgets('default questTask is playQuiz, default recordToStats=true',
        (tester) async {
      // Smoke test the defaults via a host with no overrides beyond gameId.
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: _DefaultsHost())),
      );
      final state =
          tester.state<_DefaultsHostState>(find.byType(_DefaultsHost));
      expect(state.questTask, QuestTask.playQuiz);
      expect(state.recordToStats, isTrue);
      expect(state.maxRounds, 10);
    });

    testWidgets('custom questTask = null is honored', (tester) async {
      await _pump(tester,
          home: const _Host(task: null, stats: false));
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.questTask, isNull);
    });
  });
}
