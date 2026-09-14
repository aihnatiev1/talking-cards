import 'dart:math' as math;

/// What a listening turn came to. Never a judgement of *how* the child
/// said the word — only whether they took a turn at all.
enum VoiceOutcome {
  /// The child made a sound long enough to be an attempt.
  spoke,

  /// The window closed without one. Not a failure, and never told to the
  /// child as one: Bloom simply says it again and waits.
  quiet,
}

/// Decides "the child said something" from a stream of loudness samples.
///
/// Deliberately *not* speech recognition. Ukrainian on-device ASR is
/// trained on adult speech; a two-year-old's «жаба» is often «ба», and a
/// recogniser that says "wrong" to a child who said it right is the worst
/// thing a speech app can do. So this measures the one thing that is
/// honest to measure: did a voice happen.
///
/// It calibrates to the room instead of trusting a fixed threshold — a
/// kitchen with a television is a different room from a bedroom at night —
/// and it needs sound to last [minSpeechMs] so a door or a tap does not
/// count as a word.
///
/// Pure logic on purpose: the microphone plugin feeds it, the tests feed
/// it by hand.
class VoiceGate {
  /// The microphone is not worth listening to for its first moments: an
  /// iOS capture session reports its own silent floor (about -160 dBFS)
  /// until the engine is running. Calibrating on those samples puts the
  /// room far below where it really is, and then every ordinary sample
  /// clears floor + [thresholdDb] — the gate "hears a voice" in an empty
  /// room, which is exactly what it did on the first device run.
  static const warmupMs = 300;

  /// At or below this a reading is the plugin saying "no signal", not a
  /// quiet room, and it never counts — neither as calibration nor as
  /// speech.
  static const invalidDb = -100.0;

  /// Loudness floor is the median of the first [calibrationMs] of samples
  /// after the warm-up.
  static const calibrationMs = 500;

  /// How far above the room a sound must be, in dBFS.
  static const thresholdDb = 8.0;

  /// Shorter than this is a bump, a tap, a chair — not a turn.
  static const minSpeechMs = 300;

  /// Nothing said by then: the turn ends quietly.
  static const windowMs = 6000;

  VoiceGate({required this.sampleIntervalMs});

  /// How often [add] is called, in milliseconds.
  final int sampleIntervalMs;

  final List<double> _calibration = [];
  double? _floor;
  int _elapsedMs = 0;
  int _loudRunMs = 0;
  VoiceOutcome? _outcome;

  /// The room's own level once calibrated, for diagnostics.
  double? get floorDb => _floor;

  /// Null until the turn is decided.
  VoiceOutcome? get outcome => _outcome;

  /// Feed one loudness reading in dBFS (quiet ≈ -60, loud ≈ -10).
  ///
  /// Returns the outcome as soon as there is one, and keeps returning it.
  VoiceOutcome? add(double db) {
    if (_outcome != null) return _outcome;
    _elapsedMs += sampleIntervalMs;

    // The window is counted from the start throughout, so a slow warm-up
    // or calibration on a slow device cannot eat the whole turn.
    if (_elapsedMs <= warmupMs) {
      if (_elapsedMs >= windowMs) _outcome = VoiceOutcome.quiet;
      return _outcome;
    }

    if (_floor == null && _elapsedMs <= warmupMs + calibrationMs) {
      if (db > invalidDb) _calibration.add(db);
      if (_elapsedMs >= windowMs) _outcome = VoiceOutcome.quiet;
      return _outcome;
    }

    if (_floor == null) {
      // Every calibration sample was the plugin's "no signal" value: the
      // microphone is not delivering. Keep waiting rather than commit to a
      // floor that would make noise out of nothing.
      if (_calibration.isEmpty) {
        if (db > invalidDb) _calibration.add(db);
        if (_elapsedMs >= windowMs) _outcome = VoiceOutcome.quiet;
        return _outcome;
      }
      _floor = _median(_calibration);
    }

    if (db > invalidDb && db >= _floor! + thresholdDb) {
      _loudRunMs += sampleIntervalMs;
      if (_loudRunMs >= minSpeechMs) {
        _outcome = VoiceOutcome.spoke;
        return _outcome;
      }
    } else {
      // A gap breaks the run: two coughs are not a word.
      _loudRunMs = 0;
    }

    if (_elapsedMs >= windowMs) _outcome = VoiceOutcome.quiet;
    return _outcome;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return -60;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// A fresh turn on the same room: the floor is kept, the run is not.
  VoiceGate restart() {
    final next = VoiceGate(sampleIntervalMs: sampleIntervalMs);
    if (_floor != null) {
      next._floor = _floor;
      next._elapsedMs = warmupMs + calibrationMs;
      next._calibration.add(_floor!);
    }
    return next;
  }

  /// Convenience for tests and for the debug HUD.
  static double quietRoom = -55;
  static double childVoice = math.max(-20, quietRoom + thresholdDb + 4);
}
