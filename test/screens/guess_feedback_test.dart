import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/models/card_model.dart';
import 'package:talking_cards/screens/guess_screen.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/services/audio_service.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/widgets/answer_feedback.dart';
import 'package:talking_cards/widgets/quiz_option.dart';
import '../helpers/motion.dart';

void main() {
  useTestMotion();
  testWidgets('success cancels the pending retry voice and updates Bloom cue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AssetPackService.instance.debugConfigure(
      padAssets: const {},
      bundled: true,
    );
    FeedbackService.debugMute = true;
    final heard = <String?>[];
    AudioService.debugWordSink = heard.add;
    addTearDown(() {
      FeedbackService.debugMute = false;
      AudioService.debugWordSink = null;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cards = [
      for (final (i, key) in ['sc07', 'szh05', 'as', 'mu'].indexed)
        CardModel(
          id: 'card-$i',
          sound: 'Слово $i',
          text: '',
          emoji: '',
          image: ['cat', 'dog', 'cow', 'horse'][i],
          audioKey: key,
          colorBg: Colors.white,
          colorAccent: Colors.teal,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: GuessScreen(cards: cards)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(heard, isNotEmpty);
    final targetKey = heard.last;
    final options = tester
        .widgetList<QuizOption>(find.byType(QuizOption))
        .toList();
    final wrong = options.firstWhere((o) => o.card.audioKey != targetKey);
    final right = options.firstWhere((o) => o.card.audioKey == targetKey);
    await tester.ensureVisible(find.byWidget(wrong));
    await tester.tap(find.byWidget(wrong));
    await tester.pump();
    expect(find.text('Послухай ще раз'), findsOneWidget);
    // The board rebuilt after the miss, so locate the current tile by id.
    final rightTile = find.byWidgetPredicate(
      (w) => w is QuizOption && w.card.id == right.card.id,
    );
    await tester.ensureVisible(rightTile);
    await tester.tap(rightTile);
    await tester.pump();
    expect(tester.widget<QuizOption>(rightTile).mark, AnswerMark.correct);
    expect(find.textContaining('Так! Це'), findsOneWidget);
    final countAtSuccess = heard.length;
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      heard.length,
      countAtSuccess,
      reason: 'The old retry must not cut across praise after success',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(heard.length, countAtSuccess);
    expect(tester.takeException(), isNull);
  });
}
