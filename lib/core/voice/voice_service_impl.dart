import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_service.dart';

/// [speech_to_text] + [flutter_tts], русская локаль.
class VoiceServiceImpl implements VoiceService {
  VoiceServiceImpl();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _ttsReady = false;
  bool _deliveredFinal = false;

  @override
  Future<bool> init() async {
    final speechOk = await _speech.initialize(
      onError: (e) => debugPrint('[Voice] STT error: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('[Voice] STT status: $s'),
    );
    if (!_ttsReady) {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.48);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    }
    return speechOk;
  }

  @override
  Future<void> startListening(
    void Function(String text) onResult, {
    void Function(String partial)? onPartial,
  }) async {
    final ok = await init();
    if (!ok || !_speech.isAvailable) return;

    _deliveredFinal = false;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (_deliveredFinal) return;

        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;

        if (!result.finalResult) {
          onPartial?.call(text);
          return;
        }

        _deliveredFinal = true;
        debugPrint('[Voice] recognized: $text');
        onResult(text);
      },
      localeId: 'ru_RU',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    await _speech.stop();
  }

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }
}
