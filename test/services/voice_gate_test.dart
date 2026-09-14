import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/voice_gate.dart';

/// Release B's promise: the app never tells a child their pronunciation
/// was wrong. It only notices that they took a turn — so the only thing
/// worth testing is that "took a turn" is hard to fake and hard to miss.
void main() {
  VoiceGate gate() => VoiceGate(sampleIntervalMs: 100);

  VoiceOutcome? feed(VoiceGate g, double db, int ms) {
    VoiceOutcome? out;
    for (var t = 0; t < ms; t += g.sampleIntervalMs) {
      out = g.add(db);
    }
    return out;
  }

  test('a quiet room alone is never an attempt', () {
    final g = gate();
    expect(feed(g, -55, VoiceGate.windowMs), VoiceOutcome.quiet);
  });

  test('a voice over the room, long enough, is an attempt', () {
    final g = gate();
    feed(g, -55, VoiceGate.calibrationMs);
    expect(feed(g, -40, 400), VoiceOutcome.spoke);
  });

  test('a bump is not a word', () {
    final g = gate();
    feed(g, -55, VoiceGate.calibrationMs);
    // 100 ms spike, then quiet again, repeated: never a 300 ms run.
    for (var i = 0; i < 12; i++) {
      g.add(-30);
      feed(g, -55, 400);
    }
    expect(g.outcome, VoiceOutcome.quiet, reason: 'spikes never add up');
  });

  test('a loud room raises the bar instead of triggering on itself', () {
    // A kitchen with a television: the floor is high, and the same -40 dB
    // that counted in a quiet room is now just the room.
    final g = gate();
    feed(g, -42, VoiceGate.calibrationMs);
    expect(feed(g, -40, 1000), isNot(VoiceOutcome.spoke));
    // The child still gets through by being louder than the television.
    expect(feed(g, -25, 400), VoiceOutcome.spoke);
  });

  test('the turn ends on its own, even mid-calibration', () {
    final g = VoiceGate(sampleIntervalMs: 1000);
    expect(feed(g, -55, VoiceGate.windowMs), VoiceOutcome.quiet);
  });

  test('a decided turn stays decided', () {
    final g = gate();
    feed(g, -55, VoiceGate.calibrationMs);
    feed(g, -30, 400);
    expect(g.outcome, VoiceOutcome.spoke);
    expect(feed(g, -55, 5000), VoiceOutcome.spoke);
  });

  test('the next turn keeps the room, not the run', () {
    final g = gate();
    feed(g, -50, VoiceGate.calibrationMs);
    feed(g, -30, 400);
    final next = g.restart();
    expect(next.outcome, isNull);
    expect(next.floorDb, g.floorDb);
    // No re-calibration needed: the child can answer immediately.
    expect(feed(next, -30, 400), VoiceOutcome.spoke);
  });
}
