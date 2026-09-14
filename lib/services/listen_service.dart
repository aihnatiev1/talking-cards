import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio_service.dart';
import 'voice_gate.dart';

/// The microphone half of Speak & Repeat: it notices that the child took
/// a turn, and nothing else.
///
/// Four rules, and they are the feature:
///
///  1. **Off until a grown-up turns it on.** [enabled] is false until the
///     parent passes the gate in settings; every entry point checks it.
///  2. **Nothing is stored and nothing is sent.** The plugin streams
///     amplitudes, not audio, and no file is ever opened. There is no
///     upload path in this class to disable.
///  3. **It never listens while the app is talking**, so Bloom cannot
///     praise the child for his own voice — the commonest way a feature
///     like this "works" in a demo and fails in a room.
///  4. **It never judges.** The outcome is `spoke` or `quiet`; there is
///     no third value, and no place for one.
class ListenService {
  ListenService._();
  static final instance = ListenService._();

  /// How often the amplitude is polled. 100 ms is four samples inside the
  /// shortest thing we will call a word.
  static const sampleInterval = Duration(milliseconds: 100);

  // Built on first real use: the plugin talks to the platform in its own
  // constructor, so a test (or a build with the microphone never turned
  // on) must not construct one at all.
  AudioRecorder? _recorderOrNull;
  AudioRecorder get _recorder => _recorderOrNull ??= AudioRecorder();

  /// A grown-up turned the microphone on for this profile.
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  /// Live level while a turn is open, for the only thing the child sees:
  /// something that reacts to their voice. 0..1.
  final ValueNotifier<double> level = ValueNotifier(0);

  VoiceGate? _room;
  Timer? _poll;
  Completer<VoiceOutcome>? _turn;

  /// Tests and the debug HUD: feed samples by hand instead of a mic.
  @visibleForTesting
  bool debugSilentMode = false;

  /// Tests only: run the same clock faster, so a six-second window is not
  /// six seconds of test.
  @visibleForTesting
  Duration? debugInterval;

  Duration get _interval => debugInterval ?? sampleInterval;

  bool get isListening => _turn != null;

  Future<bool> hasPermission() =>
      debugSilentMode ? Future.value(false) : _recorder.hasPermission();

  /// Opens one turn and completes when the child speaks or the window
  /// closes. Returns [VoiceOutcome.quiet] immediately when the microphone
  /// is off — every caller must work in that case, because most families
  /// will never turn it on.
  Future<VoiceOutcome> listenOnce() async {
    if (!enabled.value || _turn != null) return VoiceOutcome.quiet;
    if (AudioService.instance.isSpeaking.value) {
      // Rule 3: the app is still talking. A caller that waits for the word
      // to finish never hits this; the guard is for the one that forgets.
      return VoiceOutcome.quiet;
    }
    if (!debugSilentMode && !await _recorder.hasPermission()) {
      return VoiceOutcome.quiet;
    }

    final gate = _room?.restart() ??
        VoiceGate(sampleIntervalMs: sampleInterval.inMilliseconds);
    // The gate always counts in real milliseconds; only the polling clock
    // is sped up, so a test exercises the same thresholds.
    _room = gate;
    final turn = Completer<VoiceOutcome>();
    _turn = turn;

    if (!debugSilentMode) {
      // A stream, not a file: `record` needs a sink, and the one place a
      // recording could exist is this call — so it goes nowhere.
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1),
      );
      stream.listen(null, cancelOnError: true);
    }

    _poll = Timer.periodic(_interval, (_) async {
      if (turn.isCompleted) return;
      final db = debugSilentMode
          ? VoiceGate.quietRoom
          : (await _recorder.getAmplitude()).current;
      level.value = _levelOf(db, gate.floorDb);
      final outcome = gate.add(db);
      if (outcome != null) await _finish(outcome);
    });

    return turn.future;
  }

  /// Stops a turn early — the child pressed on, the screen closed.
  Future<void> cancel() => _finish(VoiceOutcome.quiet);

  Future<void> _finish(VoiceOutcome outcome) async {
    _poll?.cancel();
    _poll = null;
    level.value = 0;
    if (!debugSilentMode &&
        _recorderOrNull != null &&
        await _recorder.isRecording()) {
      await _recorder.stop();
    }
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete(outcome);
  }

  /// dBFS → 0..1 for the animation, measured from the room up.
  static double _levelOf(double db, double? floor) {
    final base = floor ?? VoiceGate.quietRoom;
    final over = (db - base) / 30.0;
    return over.clamp(0.0, 1.0);
  }

  /// Tests only: forget the calibrated room.
  @visibleForTesting
  void debugReset() {
    _poll?.cancel();
    _poll = null;
    _room = null;
    _turn = null;
    level.value = 0;
  }
}
