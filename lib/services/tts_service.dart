import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for English cards (no recorded audio available).
///
/// Uses the platform's native TTS engine:
///   iOS  → AVSpeechSynthesizer
///   Android → TextToSpeech API
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final _tts = FlutterTts();
  bool _initialized = false;

  /// Call once during app startup (SplashScreen._initServices).
  Future<void> init() async {
    try {
      await _tts.setSpeechRate(0.45); // slower — clearer for kids
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('TtsService: init failed — $e');
    }
  }

  /// Speak [text] using the given [locale] (e.g. 'en-US', 'uk-UA').
  /// Stops any currently playing speech first.
  Future<void> speak(String text, {String locale = 'en-US'}) async {
    if (!_initialized || text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      // Ukrainian is naturally a bit slower — bump rate slightly
      await _tts.setSpeechRate(locale.startsWith('uk') ? 0.5 : 0.45);
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('TtsService: speak error — $e');
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  bool get isAvailable => _initialized;
}
