import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/feedback_service.dart';

/// The feedback table is a contract: every event has a row, every row
/// either names a sound that ships or is silent on purpose, and the muted
/// mode used by widget tests records instead of playing.
void main() {
  setUp(() {
    FeedbackService.debugMute = true;
    FeedbackService.debugLog.clear();
  });
  tearDown(() {
    FeedbackService.debugMute = false;
    FeedbackService.debugLog.clear();
  });

  test('every event has a row', () {
    for (final e in FeedbackEvent.values) {
      expect(FeedbackService.table.containsKey(e), isTrue,
          reason: '$e has no row in FeedbackService.table');
    }
  });

  test('every row names a shipped sfx or is explicitly silent', () {
    for (final entry in FeedbackService.table.entries) {
      final spec = entry.value;
      if (spec.isSilent) continue; // FeedbackSpec.silent — a choice.
      final file = File('assets/audio_sfx/${spec.sfx}.wav');
      expect(file.existsSync(), isTrue,
          reason: '${entry.key} → "${spec.sfx}" is not in assets/audio_sfx/');
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

  test('wrong is soft: no haptic, quieter and lower than a tap', () {
    final wrong = FeedbackService.instance.specOf(FeedbackEvent.wrong);
    final tap = FeedbackService.instance.specOf(FeedbackEvent.tap);
    expect(wrong.haptic, FeedbackHaptic.none);
    expect(wrong.volume, lessThan(tap.volume));
    expect(wrong.pitch, lessThan(tap.pitch));
  });

  test('the three wins cheer; the parent milestone does not', () {
    for (final e in [
      FeedbackEvent.roundDone,
      FeedbackEvent.gameDone,
      FeedbackEvent.packDone,
    ]) {
      expect(FeedbackService.instance.specOf(e).praise, isTrue, reason: '$e');
    }
    expect(
      FeedbackService.instance.specOf(FeedbackEvent.milestone).praise,
      isFalse,
    );
  });

  test('debugMute records events instead of playing them', () {
    FeedbackService.instance.event(FeedbackEvent.tap);
    FeedbackService.instance.event(FeedbackEvent.correct, isEn: true);
    FeedbackService.instance.event(FeedbackEvent.tap, sound: false);
    expect(
      FeedbackService.debugLog,
      [FeedbackEvent.tap, FeedbackEvent.correct, FeedbackEvent.tap],
    );
  });
}
