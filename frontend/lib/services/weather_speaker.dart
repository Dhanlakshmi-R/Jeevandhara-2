import 'package:flutter_tts/flutter_tts.dart';

/// Speaks text aloud. Behind an interface so the weather panel can be built and
/// tested without a text-to-speech plugin.
abstract class WeatherSpeaker {
  /// Reads [text] in [locale], resolving once speech finishes.
  Future<void> speak(String text, {required String locale});

  Future<void> stop();

  void dispose();
}

/// Real implementation backed by `flutter_tts`.
class TtsWeatherSpeaker implements WeatherSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.45);
      // Makes `speak`'s future resolve when playback actually ends, so the
      // Listen button can flip back to idle without a completion callback.
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Older platform channels may not expose every setter; keep going.
    }
    _configured = true;
  }

  @override
  Future<void> speak(String text, {required String locale}) async {
    await _ensureConfigured();
    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      // Unsupported locale: fall back to the engine default.
    }
    try {
      await _tts.stop();
    } catch (_) {}
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
  }
}

/// Does nothing — used when a host wants the panel without audio (or in tests).
class SilentWeatherSpeaker implements WeatherSpeaker {
  const SilentWeatherSpeaker();

  @override
  Future<void> speak(String text, {required String locale}) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
