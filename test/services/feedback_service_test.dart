import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/feedback_service.dart';
import 'package:talking_cards/utils/sfx.dart';

/// The feedback table is a contract: every event has a row, every row
/// either names a palette role that can sound today (its own file or the
/// placeholder it falls back to) or is silent on purpose, and the muted
/// mode used by widget tests records instead of playing.
void main() {
  setUp(() {
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
    FeedbackService.debugSounds.clear();
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
    FeedbackService.debugSounds.clear();
  });

  test('every event has a row', () {
    for (final e in FeedbackEvent.values) {
      expect(FeedbackService.table.containsKey(e), isTrue,
          reason: '$e has no row in FeedbackService.table');
    }
  });

  test('every row names a role that can sound today or is explicitly silent',
      () {
    for (final entry in FeedbackService.table.entries) {
      final role = entry.value.sound;
      if (role == null) continue; // FeedbackSpec.silent — a choice.
      final own = File(role.assetPath).existsSync();
      final standIn = File(role.fallbackPath).existsSync();
      expect(own || standIn, isTrue,
          reason: '${entry.key} → $role has neither ${role.assetPath} nor '
              'its placeholder ${role.fallbackPath}');
    }
  });

  test('pitch and volume stay inside what SoLoud will honour', () {
    for (final entry in FeedbackService.table.entries) {
      final spec = entry.value;
      expect(spec.pitch - spec.spread, greaterThanOrEqualTo(0.5),
          reason: '${entry.key} can dip below the 0.5 pitch clamp');
      expect(spec.pitch + spec.spread, lessThanOrEqualTo(2.0),
          reason: '${entry.key} can exceed the 2.0 pitch clamp');
      expect(spec.volume, inInclusiveRange(0.0, 1.0));
    }
  });

  test('a row inherits the role\'s mix unless it says otherwise', () {
    final tap = FeedbackService.instance.specOf(FeedbackEvent.tap);
    expect(tap.pitch, KidSound.tap.pitch);
    expect(tap.spread, KidSound.tap.spread);
    expect(tap.volume, KidSound.tap.volume);
    final bell = FeedbackService.instance.specOf(FeedbackEvent.milestone);
    expect(bell.sound, KidSound.successSmall);
    expect(bell.pitch, 0.85);
    expect(bell.volume, lessThan(KidSound.successSmall.volume));
  });

  test('wrong is soft: no haptic, quieter than a tap, never a buzzer', () {
    final wrong = FeedbackService.instance.specOf(FeedbackEvent.wrong);
    final tap = FeedbackService.instance.specOf(FeedbackEvent.tap);
    expect(wrong.haptic, FeedbackHaptic.none);
    expect(wrong.volume, lessThan(tap.volume));
    expect(wrong.sound, KidSound.miss);
    // Until the marimba file exists the placeholder pop stands in lower.
    expect(KidSound.miss.fallbackPitch, lessThan(1.0));
  });

  test('every SFX sits under the word', () {
    for (final entry in FeedbackService.table.entries) {
      if (entry.value.isSilent) continue;
      expect(entry.value.volume, lessThan(1.0),
          reason: '${entry.key} is as loud as the narrator');
    }
  });

  test('the three wins cheer at the 400 ms beat; the parent milestone does not',
      () {
    for (final e in [
      FeedbackEvent.roundDone,
      FeedbackEvent.gameDone,
      FeedbackEvent.packDone,
    ]) {
      final spec = FeedbackService.instance.specOf(e);
      expect(spec.praise, isTrue, reason: '$e');
      expect(spec.sound, KidSound.successLarge, reason: '$e');
      expect(spec.praiseAfter, const Duration(milliseconds: 400), reason: '$e');
    }
    expect(
      FeedbackService.instance.specOf(FeedbackEvent.milestone).praise,
      isFalse,
    );
  });

  test('progress steps climb and wait for the word; the swipe crossing is '
      'haptic only', () {
    final step = FeedbackService.instance.specOf(FeedbackEvent.progressStep);
    expect(step.sound, KidSound.successMedium);
    expect(step.ladder, greaterThan(0));
    expect(step.waitsForVoice, isTrue);
    final swipe = FeedbackService.instance.specOf(FeedbackEvent.swipe);
    expect(swipe.isSilent, isTrue);
    expect(swipe.haptic, FeedbackHaptic.light);
    final landed = FeedbackService.instance.specOf(FeedbackEvent.pageLanded);
    expect(landed.sound, KidSound.cardLand);
    expect(landed.pitch, lessThan(1.0), reason: 'the sound of weight');
  });

  test('presses map to events where Bloom should hear them', () {
    expect(FeedbackService.eventOf(KidSound.tap), FeedbackEvent.tap);
    expect(FeedbackService.eventOf(KidSound.cardTouch), FeedbackEvent.cardTouch);
    expect(FeedbackService.eventOf(KidSound.packOpen), FeedbackEvent.packOpen);
    expect(FeedbackService.eventOf(KidSound.flip), isNull);
  });

  test('debugMute records events and roles instead of playing them', () {
    FeedbackService.instance.event(FeedbackEvent.tap);
    FeedbackService.instance.event(FeedbackEvent.correct, isEn: true);
    FeedbackService.instance.event(FeedbackEvent.tap, sound: false);
    FeedbackService.instance.play(KidSound.flip);
    expect(
      FeedbackService.debugLog,
      [FeedbackEvent.tap, FeedbackEvent.correct, FeedbackEvent.tap],
    );
    expect(FeedbackService.debugSounds, [KidSound.flip]);
  });
}
