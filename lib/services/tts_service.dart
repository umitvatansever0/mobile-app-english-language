import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cihazın kendi metin-okuma motoruyla Amerikan İngilizcesi telaffuz.
///
/// Sadece `setLanguage('en-US')` demek yetmiyor: bazı cihazlarda (özellikle
/// Samsung motoru ya da en-US sesi yüklü olmayan cihazlarda) motor varsayılan
/// Türkçe sesle okuyor ve kelimeler Türkçe aksanlı çıkıyor. Bu yüzden:
///  1) Android'de mümkünse Google TTS motoru seçilir,
///  2) yüklü sesler arasından açıkça bir en-US sesi seçilip `setVoice` ile atanır
///     (çevrimdışı ve yüksek kaliteli olanlar öncelikli).
class TtsService {
  static const locale = 'en-US';
  static const _googleEngine = 'com.google.android.tts';

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _preferGoogleEngine();
      }
      await _tts.setLanguage(locale);
      await _selectUsVoice();
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

  Future<void> _preferGoogleEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains(_googleEngine)) {
        await _tts.setEngine(_googleEngine);
      }
    } catch (e) {
      debugPrint('TTS motoru seçilemedi: $e');
    }
  }

  Future<void> _selectUsVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final voices = [
        for (final v in raw)
          if (v is Map) v.map((k, val) => MapEntry(k.toString(), val?.toString() ?? '')),
      ];
      final us = voices.where((v) => pickableUsVoice(v)).toList()..sort((a, b) => voiceScore(b) - voiceScore(a));
      if (us.isEmpty) return;
      final best = us.first;
      await _tts.setVoice({'name': best['name']!, 'locale': best['locale']!});
      debugPrint('TTS sesi: ${best['name']} (${best['locale']})');
    } catch (e) {
      debugPrint('TTS sesi seçilemedi: $e');
    }
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

String _normLocale(String l) => l.replaceAll('_', '-').toLowerCase();

/// Ses gerçekten Amerikan İngilizcesi mi? (Android'de "en-us", iOS'ta "en-US".)
@visibleForTesting
bool pickableUsVoice(Map<String, String> v) {
  if ((v['name'] ?? '').isEmpty) return false;
  return _normLocale(v['locale'] ?? '') == 'en-us';
}

/// Yüksek puan = daha iyi ses. İnternet gerektirmeyen, yüksek kaliteli sesler önce.
@visibleForTesting
int voiceScore(Map<String, String> v) {
  var s = 0;
  final quality = (v['quality'] ?? '').toLowerCase();
  if (quality.contains('premium')) s += 40;
  if (quality.contains('enhanced')) s += 30;
  if (quality == 'very high' || quality == 'very_high') s += 30;
  if (quality == 'high') s += 20;
  if ((v['network_required'] ?? '') == '1' || (v['network_required'] ?? '') == 'true') s -= 50;
  if ((v['name'] ?? '').toLowerCase().contains('local')) s += 5;
  return s;
}
