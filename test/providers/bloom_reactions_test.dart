import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/providers/bloom_reactions_provider.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/design_tokens.dart';

/// Bloom's brain on a fake clock (docs/design/bloom_character.md §5.3,
/// §5.6): priorities, debounces, hint and sleep timers, and the sound rule
/// "never over a word".
void main() {
  final epoch = DateTime(2026, 9, 13, 10);

  /// Builds a notifier whose every clock read comes from [async].
  ({
    BloomReactions bloom,
    ValueNotifier<bool> speaking,
    List<BloomSound> sounds,
  }) make(
    FakeAsync async, {
    int level = 2,
  }) {
    final speaking = ValueNotifier<bool>(false);
    final sounds = <BloomSound>[];
    final bloom = BloomReactions(
      profileLevel: () => level,
      speaking: speaking,
      playSound: sounds.add,
      now: () => async.getClock(epoch).now(),
    );
    return (bloom: bloom, speaking: speaking, sounds: sounds);
  }

  setUp(() {
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
  });

  group('priorities', () {
    test('cheer interrupts a lower one-shot; a lower one is dropped', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        t.bloom.packOpened();
        expect(t.bloom.state.emotion, BloomEmotion.curious);

        t.bloom.packCompleted();
        expect(t.bloom.state.emotion, BloomEmotion.cheer);
        expect(t.bloom.state.hops, 3);

        // A happy (6) during a cheer (7) is thrown away, not queued.
        final serial = t.bloom.state.serial;
        t.bloom.success(BloomSuccessTier.micro);
        expect(t.bloom.state.emotion, BloomEmotion.cheer);
        expect(t.bloom.state.serial, serial);

        // Cheer does not restart itself either.
        t.bloom.packCompleted();
        expect(t.bloom.state.serial, serial);

        // Afterglow: the happy face with no hop, then idle.
        async.elapse(DT.motion.bloomCheerBig);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        expect(t.bloom.state.hops, 0);
        async.elapse(DT.motion.bloomAfterglow);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('happy is debounced: a hop in the air keeps flying', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        t.bloom.bloomTapped();
        final serial = t.bloom.state.serial;
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(const Duration(milliseconds: 200));
        t.bloom.bloomTapped();
        expect(t.bloom.state.serial, serial, reason: 'no restart mid-hop');
        async.elapse(DT.motion.celebrate);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('listen is a level: it returns after a one-shot', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        t.speaking.value = true;
        expect(t.bloom.state.emotion, BloomEmotion.listen);
        expect(t.bloom.state.level, BloomLevel.listen);

        t.bloom.success(BloomSuccessTier.micro);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(DT.motion.celebrate);
        expect(t.bloom.state.emotion, BloomEmotion.listen,
            reason: 'the word is still playing');

        // Release only after the hysteresis gap.
        t.speaking.value = false;
        expect(t.bloom.state.emotion, BloomEmotion.listen);
        async.elapse(DT.motion.bloomListenRelease);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('a pause inside a phrase does not drop listen', () {
      fakeAsync((async) {
        final t = make(async);
        t.speaking.value = true;
        t.speaking.value = false;
        async.elapse(const Duration(milliseconds: 60));
        t.speaking.value = true;
        async.elapse(const Duration(seconds: 1));
        expect(t.bloom.state.emotion, BloomEmotion.listen);
        t.bloom.dispose();
      });
    });
  });

  group('sleep', () {
    test('falls asleep after sleepAfter, only from plain idle', () {
      fakeAsync((async) {
        final t = make(async, level: 3);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        // Hints fire first (10 s, then +8 s) — two of them, then quiet.
        async.elapse(const Duration(seconds: 10));
        expect(t.bloom.state.emotion, BloomEmotion.point);
        expect(t.sounds, [BloomSound.hmm]);
        async.elapse(const Duration(seconds: 8));
        expect(t.bloom.state.emotion, BloomEmotion.point);
        expect(t.bloom.state.swipeGesture, isTrue,
            reason: 'the second hint on the cards shows the swipe');
        expect(t.sounds, [BloomSound.hmm], reason: 'second hint is silent');
        async.elapse(const Duration(seconds: 8));
        expect(t.bloom.state.emotion, BloomEmotion.idle,
            reason: 'at most two hints per target');

        async.elapse(const Duration(seconds: 4));
        expect(t.bloom.state.emotion, BloomEmotion.sleep);
        expect(t.bloom.state.level, BloomLevel.sleep);
        expect(t.sounds.last, BloomSound.zzz);
        t.bloom.dispose();
      });
    });

    test('sleep never interrupts a cheer, and a touch wakes with happy', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered(
          'x',
          const BloomScene(sleepAfter: Duration(seconds: 1)),
        );
        t.bloom.packCompleted();
        async.elapse(const Duration(seconds: 1));
        expect(t.bloom.state.emotion, BloomEmotion.cheer,
            reason: 'sleep waits for a quiet moment');
        async.elapse(const Duration(seconds: 3));
        expect(t.bloom.state.emotion, BloomEmotion.sleep);

        t.bloom.userTouch(Offset.zero);
        expect(t.bloom.state.level, BloomLevel.idle);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(DT.motion.celebrate);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('a word playing keeps Bloom awake', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered(
          'x',
          const BloomScene(sleepAfter: Duration(seconds: 1)),
        );
        t.speaking.value = true;
        async.elapse(const Duration(seconds: 5));
        expect(t.bloom.state.emotion, BloomEmotion.listen);
        t.bloom.dispose();
      });
    });

    test('auto-advance scene: no hints, no sleep, listen still works', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered(
          'cards',
          BloomScene.cards.copyWith(hintsEnabled: false, clearSleep: true),
        );
        async.elapse(const Duration(minutes: 2));
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        expect(t.sounds, isEmpty);
        t.speaking.value = true;
        expect(t.bloom.state.emotion, BloomEmotion.listen);
        t.bloom.dispose();
      });
    });
  });

  group('debounces and rate limits', () {
    test('giggle at most once per 1.5 s; the hop always', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.bloomTapped();
        expect(t.sounds, [BloomSound.giggle]);
        async.elapse(DT.motion.celebrate);
        t.bloom.bloomTapped();
        expect(t.sounds, [BloomSound.giggle], reason: 'still inside 1.5 s');
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(const Duration(seconds: 1));
        t.bloom.bloomTapped();
        expect(t.sounds, [BloomSound.giggle, BloomSound.giggle]);
        t.bloom.dispose();
      });
    });

    test('greeting at most once per five minutes', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.appEntered();
        expect(t.sounds, [BloomSound.hi]);
        async.elapse(const Duration(minutes: 1));
        t.bloom.appEntered();
        expect(t.sounds, [BloomSound.hi]);
        // A short pause is not an event; a long one is.
        t.bloom.appResumed(const Duration(minutes: 2));
        expect(t.sounds, [BloomSound.hi]);
        t.bloom.appResumed(const Duration(minutes: 6));
        expect(t.sounds, [BloomSound.hi, BloomSound.hi]);
        expect(t.bloom.state.emotion, BloomEmotion.wave);
        t.bloom.dispose();
      });
    });

    test('every N-th forward card hops, silently, at most once per 3 s', () {
      fakeAsync((async) {
        final t = make(async, level: 1);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        for (var i = 1; i <= 2; i++) {
          t.bloom.cardAdvanced(i);
          expect(t.bloom.state.emotion, BloomEmotion.idle);
        }
        t.bloom.cardAdvanced(3);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        expect(t.sounds, isEmpty, reason: 'the pause belongs to the word');
        async.elapse(DT.motion.celebrate);
        // Three more inside the 3 s gap — no second hop.
        for (var i = 4; i <= 6; i++) {
          t.bloom.cardAdvanced(i);
        }
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('level 2 hops every fifth card', () {
      fakeAsync((async) {
        final t = make(async, level: 2);
        for (var i = 1; i <= 4; i++) {
          t.bloom.cardAdvanced(i);
        }
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.cardAdvanced(5);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        t.bloom.dispose();
      });
    });
  });

  group('sound', () {
    test('never over a word — dropped, not delayed', () {
      fakeAsync((async) {
        final t = make(async);
        t.speaking.value = true;
        t.bloom.bloomTapped();
        expect(t.bloom.state.emotion, BloomEmotion.happy, reason: 'pose yes');
        expect(t.sounds, isEmpty, reason: 'sound no');
        async.elapse(const Duration(seconds: 2));
        expect(t.sounds, isEmpty, reason: 'and not later either');
        t.bloom.dispose();
      });
    });

    test('the cheer itself is silent — its voice is the celebration\'s', () {
      // `success_large` at 0 and praise / `bloom_yay` at 400 both come from
      // FeedbackService (sound_palette §6.20–21); a `yay` here would land
      // on top of the fanfare.
      fakeAsync((async) {
        final t = make(async);
        t.bloom.packCompleted();
        expect(t.bloom.state.emotion, BloomEmotion.cheer);
        expect(t.sounds, isEmpty);
        async.elapse(const Duration(seconds: 3));
        expect(t.sounds, isEmpty);
        t.bloom.dispose();
      });
    });

    test('cardAdvanced reports the progress step on the hop cadence', () {
      fakeAsync((async) {
        final t = make(async, level: 2);
        final steps = <int?>[];
        for (var i = 1; i <= 5; i++) {
          steps.add(t.bloom.cardAdvanced(i));
        }
        expect(steps, [null, null, null, null, 1]);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(DT.motion.celebrate);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        for (var i = 6; i <= 10; i++) {
          steps.add(t.bloom.cardAdvanced(i));
        }
        expect(steps.last, 2);
        // The second step lands inside the 3 s hop gap: no hop, still a
        // step — the sound belongs to the screen, the hop to Bloom.
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
      });
    });

    test('hint hums only when Bloom is the only actor', () {
      fakeAsync((async) {
        final t = make(async, level: 1);
        t.bloom.sceneEntered(
          'game',
          const BloomScene(hintsEnabled: true, soloActor: false),
        );
        async.elapse(const Duration(seconds: 6));
        expect(t.bloom.state.emotion, BloomEmotion.point);
        expect(t.sounds, isEmpty);
        t.bloom.dispose();
      });
    });
  });

  group('feedback pipeline', () {
    test('reacts to FeedbackService events without its own subscriptions',
        () {
      fakeAsync((async) {
        final t = make(async);
        FeedbackService.instance.event(FeedbackEvent.correct);
        expect(t.bloom.state.emotion, BloomEmotion.happy);
        async.elapse(DT.motion.celebrate);
        FeedbackService.instance.event(FeedbackEvent.wrong);
        expect(t.bloom.state.emotion, BloomEmotion.curious);
        async.elapse(DT.motion.bloomCurious);
        FeedbackService.instance.event(FeedbackEvent.roundDone);
        expect(t.bloom.state.emotion, BloomEmotion.cheer);
        async.elapse(DT.motion.bloomCheerBig + DT.motion.bloomAfterglow);
        // Parent-facing bell: Bloom stays out of it.
        FeedbackService.instance.event(FeedbackEvent.milestone);
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        t.bloom.dispose();
        // Disposed: unsubscribed, so this must not throw.
        FeedbackService.instance.event(FeedbackEvent.correct);
      });
    });
  });

  group('scenes', () {
    test('a pushed scene takes the stage and hands it back on leave', () {
      fakeAsync((async) {
        final t = make(async);
        t.bloom.sceneEntered('home', BloomScene.home);
        expect(t.bloom.scene, BloomScene.home);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        expect(t.bloom.scene, BloomScene.cards);
        expect(t.bloom.state.ambient, BloomAmbient.blinkOnly);
        // Updating the active scene keeps it active.
        t.bloom.sceneEntered(
          'cards',
          BloomScene.cards.copyWith(ambient: BloomAmbient.breathe),
        );
        expect(t.bloom.state.ambient, BloomAmbient.breathe);
        t.bloom.sceneLeft('cards');
        expect(t.bloom.scene, BloomScene.home);
        t.bloom.sceneLeft('home');
        expect(t.bloom.scene, BloomScene.still);
        t.bloom.dispose();
      });
    });

    test('paused: timers stop; resumed: they arm again', () {
      fakeAsync((async) {
        final t = make(async, level: 1);
        t.bloom.sceneEntered('cards', BloomScene.cards);
        t.bloom.appPaused();
        async.elapse(const Duration(minutes: 1));
        expect(t.bloom.state.emotion, BloomEmotion.idle);
        expect(t.sounds, isEmpty);
        t.bloom.appResumed(Duration.zero);
        async.elapse(const Duration(seconds: 6));
        expect(t.bloom.state.emotion, BloomEmotion.point);
        t.bloom.dispose();
      });
    });
  });
}
