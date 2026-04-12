import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps [SpeechToText] with a simpler API for single-word recognition.
///
/// iOS only — on non-iOS platforms [isAvailable] is always false and
/// all methods are no-ops.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final _stt = SpeechToText();
  bool _initialized = false;
  bool _available = false;

  /// True after a successful [init] call and speech recognition is supported.
  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  // ── Init ─────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Only wire up on iOS (requirement: iOS only for Phase 5)
    if (!Platform.isIOS) return;

    try {
      _available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );
    } catch (e) {
      _available = false;
      if (kDebugMode) debugPrint('SpeechService: init failed — $e');
    }
  }

  // ── Listen ───────────────────────────────────

  /// Start listening for a single Ukrainian word.
  ///
  /// [onResult] is called with the final recognised text (trimmed, lower-case).
  /// Listening stops automatically after [pauseFor] of silence (default 3 s).
  Future<void> startListening({
    required ValueChanged<String> onResult,
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    if (!_available || _stt.isListening) return;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) {
            onResult(result.recognizedWords.trim().toLowerCase());
          }
        },
        localeId: 'uk-UA',
        listenFor: listenFor,
        pauseFor: pauseFor,
        cancelOnError: true,
        partialResults: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('SpeechService: listen error — $e');
    }
  }

  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> cancelListening() async {
    if (_stt.isListening) await _stt.cancel();
  }

  // ── Matching ─────────────────────────────────

  /// Returns true if [recognized] matches [target] (card's `sound` field).
  ///
  /// Handles:
  ///  - Case-insensitive comparison
  ///  - Hyphenated repetitions like "МУ-МУ-МУ" → checks each segment
  ///  - Partial containment for longer targets
  static bool matches(String recognized, String target) {
    final r = recognized.trim().toLowerCase();
    if (r.isEmpty) return false;

    final t = target.trim().toLowerCase();

    if (r == t) return true;

    // Strip hyphens: "му-му-му" → "му"
    final segments = t
        .split('-')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (segments.contains(r)) return true;

    // Allow "корівка" to match "корова" or similar close words? — skip for now.
    // Simple substring: recognized fully contained in target
    if (t.contains(r) && r.length >= 2) return true;

    return false;
  }

  // ── Private ──────────────────────────────────

  void _onError(SpeechRecognitionError error) {
    if (kDebugMode) {
      debugPrint('SpeechService error: ${error.errorMsg}');
    }
  }

  void _onStatus(String status) {
    if (kDebugMode) debugPrint('SpeechService status: $status');
  }
}
