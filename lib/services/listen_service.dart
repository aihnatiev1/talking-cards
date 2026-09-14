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

  /// The raw numbers behind [level], for the parent-side tuning HUD:
  /// the sample in dBFS and the room floor the gate calibrated to (null
  /// until calibration ends). Nothing in the child's UI reads this — it
  /// exists so the thresholds can be checked in a real room instead of
  /// guessed.
  final ValueNotifier<({double db, double? floorDb})?> sample =
      ValueNotifier(null);

  /// What the last finished turn looked like, kept after it ends: a
  /// verdict with no numbers behind it cannot be acted on, and the HUD
  /// exists to be acted on. `peakDb` is the loudest sample of the turn.
  final ValueNotifier<
    ({double? floorDb, double peakDb, int ms, VoiceOutcome outcome})?
  >
  lastTurn = ValueNotifier(null);

  VoiceGate? _room;
  Timer? _poll;
  Completer<VoiceOutcome>? _turn;
  double _peak = VoiceGate.invalidDb;
  int _turnMs = 0;

  /// The audio session is currently borrowed for recording.
  bool _holdingSession = false;

  /// Test seam: stands in for the real session switch, which needs a
  /// platform channel. Called with true to borrow, false to return.
  @visibleForTesting
  Future<void> Function(bool listening)? debugSessionHook;

  Future<void> _borrowSession(bool listening) async {
    final hook = debugSessionHook;
    if (hook != null) return hook(listening);
    if (listening) {
      await AudioService.instance.beginListening();
    } else {
      await AudioService.instance.endListening();
    }
  }

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
    _peak = VoiceGate.invalidDb;
    _turnMs = 0;

    // The app owns the audio session (AudioService), so the recorder must
    // not configure it: a plugin-managed session switches iOS to a record
    // category and never switches back, and from the next card on the
    // whole app is silent — which is what the first successful turn did on
    // device. Borrow the session explicitly, and give it back in [_finish],
    // on every path out.
    await _borrowSession(true);
    _holdingSession = true;

    if (!debugSilentMode) {
      await _recorder.ios?.manageAudioSession(false);
      try {
        // A stream, not a file: `record` needs a sink, and the one place a
        // recording could exist is this call — so it goes nowhere.
        final stream = await _recorder.startStream(
          const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1),
        );
        stream.listen(null, cancelOnError: true);
      } catch (e) {
        // A microphone that will not open must not take the app's sound
        // with it: hand the session back and end the turn quietly.
        if (kDebugMode) debugPrint('ListenService: startStream failed: $e');
        await _finish(VoiceOutcome.quiet);
        return turn.future;
      }
    }

    _poll = Timer.periodic(_interval, (_) async {
      if (turn.isCompleted) return;
      final db = debugSilentMode
          ? VoiceGate.quietRoom
          : (await _recorder.getAmplitude()).current;
      level.value = _levelOf(db, gate.floorDb);
      sample.value = (db: db, floorDb: gate.floorDb);
      _turnMs += _interval.inMilliseconds;
      if (db > _peak) _peak = db;
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
    sample.value = null;
    if (_turn != null) {
      lastTurn.value = (
        floorDb: _room?.floorDb,
        peakDb: _peak,
        ms: _turnMs,
        outcome: outcome,
      );
    }
    if (!debugSilentMode &&
        _recorderOrNull != null &&
        await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (_holdingSession) {
      _holdingSession = false;
      await _borrowSession(false);
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
