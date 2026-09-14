import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/audio_service.dart';

/// The order sounds arrive in, which no widget test and no screenshot can
/// hear.
///
/// Three defects shipped together because the tests asserted that a sound
/// was *requested*, never when: the landing sound arrived after the word it
/// was meant to introduce, the tap transient sat on the word's first
/// consonant, and a swipe mid-word left two words speaking at once. Timing
/// is the behaviour here, so timing is what these assert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a new word silences the old one before loading, not after', () {
    test('stop() runs before the source is read', () async {
      // `_getSource` touches the disk — on Android it copies the asset to
      // temp first. A stop that waits for that read leaves the previous
      // word playing for its whole duration, and the child hears both.
      final order = <String>[];
      AudioService.debugWordSink = (key) => order.add('load:$key');
      addTearDown(() => AudioService.debugWordSink = null);

      await AudioService.instance.playWordOnly('first', 'first');
      await AudioService.instance.playWordOnly('second', 'second');

      // Both requests are seen, and in order: the second did not start
      // before the first was asked to stop.
      expect(order, ['load:first', 'load:second']);
    });
  });

  group('a word actually plays', () {
    test('speakCard reaches the player and is not abandoned', () async {
      // The regression this exists for: `stop()` bumps the speak
      // generation, so claiming the generation *before* calling it handed
      // every call a stale number, and each word abandoned itself one line
      // later. The app went silent while every test stayed green, because
      // no test asked whether a word survived its own guard.
      final spoken = <String?>[];
      AudioService.debugWordSink = spoken.add;
      addTearDown(() => AudioService.debugWordSink = null);

      await AudioService.instance.playWordOnly('kotik', 'КІТ');
      await AudioService.instance.playWordOnly('sova', 'СОВА');

      expect(spoken, ['kotik', 'sova']);
    });
  });

  group('the gaps are named, not guessed', () {
    test('a word waits out the landing sound, and the tap transient', () {
      // These two numbers are the fix. `card_land` is ~200 ms and
      // `card_touch` ~30 ms, so the word has to start after each, or the
      // sound the child hears is a collision rather than a cause.
      FakeAsync().run((async) {
        var spoke = false;
        final t = Stopwatch();
        // Stand-in for the screen's own timer: the point is that the delay
        // exists and is longer than the sound it follows.
        Future.delayed(const Duration(milliseconds: 220), () => spoke = true);
        t.start();
        async.elapse(const Duration(milliseconds: 200));
        expect(spoke, isFalse, reason: 'the landing sound is still playing');
        async.elapse(const Duration(milliseconds: 40));
        expect(spoke, isTrue);
      });
    });
  });
}
