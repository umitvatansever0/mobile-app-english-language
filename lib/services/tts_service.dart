import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cihazın kendi metin-okuma motoruyla İngilizce telaffuz (ücretsiz, çevrimdışı çalışabilir).
/// Ses kalitesi cihaza göre değişir.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  String _accent = 'en-US';
  bool _ready = false;

  Future<void> init(String accent) async {
    _accent = accent;
    try {
      await _tts.setLanguage(_accent);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
      }
      _ready = true;
    } catch (e) {
      debugPrint('TTS başlatılamadı: $e');
    }
  }

  Future<void> setAccent(String accent) async {
    _accent = accent;
    if (_ready) await _tts.setLanguage(accent);
  }

  Future<void> speak(String text) async {
    if (!_ready) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS hatası: $e');
    }
  }

  Future<void> stop() async {
    if (_ready) await _tts.stop();
  }
}
